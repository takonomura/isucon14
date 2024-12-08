package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/jmoiron/sqlx"
	"github.com/oklog/ulid/v2"
)

type chairPostChairsRequest struct {
	Name               string `json:"name"`
	Model              string `json:"model"`
	ChairRegisterToken string `json:"chair_register_token"`
}

type chairPostChairsResponse struct {
	ID      string `json:"id"`
	OwnerID string `json:"owner_id"`
}

func chairPostChairs(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	req := &chairPostChairsRequest{}
	if err := bindJSON(r, req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	if req.Name == "" || req.Model == "" || req.ChairRegisterToken == "" {
		writeError(w, http.StatusBadRequest, errors.New("some of required fields(name, model, chair_register_token) are empty"))
		return
	}

	owner := &Owner{}
	if err := db.GetContext(ctx, owner, "SELECT * FROM owners WHERE chair_register_token = ?", req.ChairRegisterToken); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, errors.New("invalid chair_register_token"))
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	chairID := ulid.Make().String()
	accessToken := secureRandomStr(32)

	_, err := db.ExecContext(
		ctx,
		"INSERT INTO chairs (id, owner_id, name, model, is_active, access_token) VALUES (?, ?, ?, ?, ?, ?)",
		chairID, owner.ID, req.Name, req.Model, false, accessToken,
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	http.SetCookie(w, &http.Cookie{
		Path:  "/",
		Name:  "chair_session",
		Value: accessToken,
	})

	writeJSON(w, http.StatusCreated, &chairPostChairsResponse{
		ID:      chairID,
		OwnerID: owner.ID,
	})
}

type postChairActivityRequest struct {
	IsActive bool `json:"is_active"`
}

func chairPostActivity(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	chair := ctx.Value("chair").(*Chair)

	req := &postChairActivityRequest{}
	if err := bindJSON(r, req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	_, err := db.ExecContext(ctx, "UPDATE chairs SET is_active = ? WHERE id = ?", req.IsActive, chair.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

type chairPostCoordinateResponse struct {
	RecordedAt int64 `json:"recorded_at"`
}

func chairPostCoordinate(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	req := &Coordinate{}
	if err := bindJSON(r, req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	chair := ctx.Value("chair").(*Chair)

	tx, err := db.Beginx()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	defer tx.Rollback()

	err = tx.GetContext(ctx, chair, "SELECT * FROM chairs WHERE id = ?", chair.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	distance := 0
	if chair.Latitude != nil && chair.Longitude != nil {
		distance = calculateDistance(*chair.Latitude, *chair.Longitude, req.Latitude, req.Longitude)
	}

	now := time.Now()
	if _, err := tx.ExecContext(
		ctx,
		`UPDATE chairs SET latitude = ?, longitude = ?, total_distance = total_distance + ?, location_updated_at = ? WHERE id = ?`,
		req.Latitude, req.Longitude, distance, now, chair.ID,
	); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	ride := &Ride{}
	if err := tx.GetContext(ctx, ride, `SELECT * FROM rides WHERE chair_id = ? ORDER BY updated_at DESC LIMIT 1`, chair.ID); err != nil {
		if !errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	} else {
		status, err := getLatestRideStatus(ctx, tx, ride.ID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		if status != "COMPLETED" && status != "CANCELED" {
			if req.Latitude == ride.PickupLatitude && req.Longitude == ride.PickupLongitude && status == "ENROUTE" {
				if _, err := tx.ExecContext(ctx, "INSERT INTO ride_statuses (id, ride_id, status) VALUES (?, ?, ?)", ulid.Make().String(), ride.ID, "PICKUP"); err != nil {
					writeError(w, http.StatusInternalServerError, err)
					return
				}
			}

			if req.Latitude == ride.DestinationLatitude && req.Longitude == ride.DestinationLongitude && status == "CARRYING" {
				if _, err := tx.ExecContext(ctx, "INSERT INTO ride_statuses (id, ride_id, status) VALUES (?, ?, ?)", ulid.Make().String(), ride.ID, "ARRIVED"); err != nil {
					writeError(w, http.StatusInternalServerError, err)
					return
				}
			}
		}
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, &chairPostCoordinateResponse{
		RecordedAt: now.UnixMilli(),
	})
}

type simpleUser struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type chairGetNotificationResponse struct {
	Data         *chairGetNotificationResponseData `json:"data"`
	RetryAfterMs int                               `json:"retry_after_ms"`
}

type chairGetNotificationResponseData struct {
	RideID                string     `json:"ride_id"`
	User                  simpleUser `json:"user"`
	PickupCoordinate      Coordinate `json:"pickup_coordinate"`
	DestinationCoordinate Coordinate `json:"destination_coordinate"`
	Status                string     `json:"status"`
}

type chairNotificationProcess struct {
	Chair *Chair
	Ride  Ride
	User  User

	LastRideID string
}

func (p *chairNotificationProcess) getLastNotification(ctx context.Context) (*chairGetNotificationResponseData, error) {
	tx, err := db.Beginx()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	yetSentRideStatus := RideStatus{}
	status := ""

	var rides []Ride
	if err := tx.SelectContext(ctx, &rides, `SELECT * FROM rides WHERE chair_id = ? ORDER BY updated_at DESC LIMIT 2`, p.Chair.ID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	if len(rides) == 0 {
		return nil, nil
	}

	rideIDs := make([]string, len(rides))
	for i, r := range rides {
		rideIDs[i] = r.ID
	}
	p.Ride = rides[0]
	ride := rides[0]

	query, args, err := sqlx.In("SELECT * FROM ride_statuses WHERE ride_id IN (?) AND chair_sent_at IS NULL ORDER BY status DESC, created_at ASC LIMIT 1", rideIDs)
	if err != nil {
		return nil, err
	}

	if err := tx.GetContext(ctx, &yetSentRideStatus, query, args...); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			status, err = getLatestRideStatus(ctx, tx, ride.ID)
			if err != nil {
				return nil, err
			}
		} else {
			return nil, err
		}
	} else {
		if ride.ID != yetSentRideStatus.RideID {
			ride = rides[1]
			slog.Info("detected second ride", "ride", ride.ID, "status", yetSentRideStatus.Status)
		}
		status = yetSentRideStatus.Status
	}
	if ride == rides[0] && status == "COMPLETED" {
		slog.Info("completed all rides", "ride", ride.ID)
		p.Ride = Ride{}
		p.LastRideID = ride.ID
	}

	var user User
	err = tx.GetContext(ctx, &user, "SELECT * FROM users WHERE id = ? FOR SHARE", ride.UserID)
	if err != nil {
		return nil, err
	}
	if ride == p.Ride {
		p.User = user
	}

	if yetSentRideStatus.ID != "" {
		_, err := tx.ExecContext(ctx, `UPDATE ride_statuses SET chair_sent_at = CURRENT_TIMESTAMP(6) WHERE id = ?`, yetSentRideStatus.ID)
		if err != nil {
			return nil, err
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	return &chairGetNotificationResponseData{
		RideID: ride.ID,
		User: simpleUser{
			ID:   user.ID,
			Name: fmt.Sprintf("%s %s", user.Firstname, user.Lastname),
		},
		PickupCoordinate: Coordinate{
			Latitude:  ride.PickupLatitude,
			Longitude: ride.PickupLongitude,
		},
		DestinationCoordinate: Coordinate{
			Latitude:  ride.DestinationLatitude,
			Longitude: ride.DestinationLongitude,
		},
		Status: status,
	}, nil
}

func (p *chairNotificationProcess) getUnsentNotification(ctx context.Context) (*chairGetNotificationResponseData, error) {
	if p.Ride.ID == "" {
		var ride Ride
		if err := db.GetContext(ctx, &ride, `SELECT * FROM rides WHERE chair_id = ? ORDER BY updated_at DESC LIMIT 1`, p.Chair.ID); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, nil
			}
			return nil, err
		}
		if ride.ID == p.LastRideID {
			slog.Info("ride.ID == p.LastRideID", "id", ride.ID)
			return nil, nil
		}
		p.Ride = ride
	}

	tx, err := db.Beginx()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	var status RideStatus
	if err := tx.GetContext(ctx, &status, "SELECT * FROM ride_statuses WHERE ride_id = ? AND chair_sent_at IS NULL ORDER BY created_at ASC LIMIT 1", p.Ride.ID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	_, err = tx.ExecContext(ctx, `UPDATE ride_statuses SET chair_sent_at = CURRENT_TIMESTAMP(6) WHERE id = ?`, status.ID)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	if p.User.ID == "" {
		err = db.GetContext(ctx, &p.User, "SELECT * FROM users WHERE id = ? FOR SHARE", p.Ride.UserID)
		if err != nil {
			return nil, err
		}
	}

	data := &chairGetNotificationResponseData{
		RideID: p.Ride.ID,
		User: simpleUser{
			ID:   p.User.ID,
			Name: fmt.Sprintf("%s %s", p.User.Firstname, p.User.Lastname),
		},
		PickupCoordinate: Coordinate{
			Latitude:  p.Ride.PickupLatitude,
			Longitude: p.Ride.PickupLongitude,
		},
		DestinationCoordinate: Coordinate{
			Latitude:  p.Ride.DestinationLatitude,
			Longitude: p.Ride.DestinationLongitude,
		},
		Status: status.Status,
	}

	if status.Status == "COMPLETED" {
		slog.Info("Completed Status", "ride", p.Ride.ID)
		p.LastRideID = p.Ride.ID
		p.Ride = Ride{}
		p.User = User{}
	}

	return data, nil
}

func chairGetNotificationSSE(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		slog.Warn("fallback to older notification")
		chairGetNotification(w, r)
		return
	}

	ctx := r.Context()
	chair := ctx.Value("chair").(*Chair)

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	writeMessage := func(v interface{}) error {
		slog.Info("write message", "v", v)
		buf, err := json.Marshal(v)
		if err != nil {
			return err
		}
		if _, err := w.Write([]byte("data: ")); err != nil {
			return err
		}
		if _, err := w.Write(buf); err != nil {
			return err
		}
		if _, err := w.Write([]byte("\n\n")); err != nil {
			return err
		}
		flusher.Flush()
		return nil
	}

	p := chairNotificationProcess{
		Chair: chair,
	}

	data, err := p.getLastNotification(ctx)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if data == nil {
		writeMessage(data)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case <-time.After(100 * time.Millisecond):
			data, err := p.getUnsentNotification(ctx)
			if err != nil {
				writeError(w, http.StatusInternalServerError, err)
				return
			}
			if err := writeMessage(data); err != nil {
				writeError(w, http.StatusInternalServerError, err)
				return
			}
		}
	}
}

func chairGetNotification(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	chair := ctx.Value("chair").(*Chair)

	tx, err := db.Beginx()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	defer tx.Rollback()
	yetSentRideStatus := RideStatus{}
	status := ""

	var rides []Ride
	if err := tx.SelectContext(ctx, &rides, `SELECT * FROM rides WHERE chair_id = ? ORDER BY updated_at DESC LIMIT 2`, chair.ID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeJSON(w, http.StatusOK, &chairGetNotificationResponse{
				RetryAfterMs: 1000,
			})
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	if len(rides) == 0 {
		writeJSON(w, http.StatusOK, &chairGetNotificationResponse{
			RetryAfterMs: 1000,
		})
		return
	}
	rideIDs := make([]string, len(rides))
	for i, r := range rides {
		rideIDs[i] = r.ID
	}
	ride := rides[0]

	query, args, err := sqlx.In("SELECT * FROM ride_statuses WHERE ride_id IN (?) AND chair_sent_at IS NULL ORDER BY status DESC, created_at ASC LIMIT 1", rideIDs)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	if err := tx.GetContext(ctx, &yetSentRideStatus, query, args...); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			status, err = getLatestRideStatus(ctx, tx, ride.ID)
			if err != nil {
				writeError(w, http.StatusInternalServerError, err)
				return
			}
		} else {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	} else {
		if ride.ID != yetSentRideStatus.RideID {
			ride = rides[1]
		}
		status = yetSentRideStatus.Status
	}

	user := &User{}
	err = tx.GetContext(ctx, user, "SELECT * FROM users WHERE id = ? FOR SHARE", ride.UserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	retryAfterMs := 500

	if yetSentRideStatus.ID != "" {
		retryAfterMs = 30
		_, err := tx.ExecContext(ctx, `UPDATE ride_statuses SET chair_sent_at = CURRENT_TIMESTAMP(6) WHERE id = ?`, yetSentRideStatus.ID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, &chairGetNotificationResponse{
		Data: &chairGetNotificationResponseData{
			RideID: ride.ID,
			User: simpleUser{
				ID:   user.ID,
				Name: fmt.Sprintf("%s %s", user.Firstname, user.Lastname),
			},
			PickupCoordinate: Coordinate{
				Latitude:  ride.PickupLatitude,
				Longitude: ride.PickupLongitude,
			},
			DestinationCoordinate: Coordinate{
				Latitude:  ride.DestinationLatitude,
				Longitude: ride.DestinationLongitude,
			},
			Status: status,
		},
		RetryAfterMs: retryAfterMs,
	})
}

type postChairRidesRideIDStatusRequest struct {
	Status string `json:"status"`
}

func chairPostRideStatus(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	rideID := r.PathValue("ride_id")

	chair := ctx.Value("chair").(*Chair)

	req := &postChairRidesRideIDStatusRequest{}
	if err := bindJSON(r, req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	tx, err := db.Beginx()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	defer tx.Rollback()

	ride := &Ride{}
	if err := tx.GetContext(ctx, ride, "SELECT * FROM rides WHERE id = ? FOR UPDATE", rideID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusNotFound, errors.New("ride not found"))
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	if ride.ChairID.String != chair.ID {
		writeError(w, http.StatusBadRequest, errors.New("not assigned to this ride"))
		return
	}

	switch req.Status {
	// Acknowledge the ride
	case "ENROUTE":
		if _, err := tx.ExecContext(ctx, "INSERT INTO ride_statuses (id, ride_id, status) VALUES (?, ?, ?)", ulid.Make().String(), ride.ID, "ENROUTE"); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	// After Picking up user
	case "CARRYING":
		status, err := getLatestRideStatus(ctx, tx, ride.ID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		if status != "PICKUP" {
			writeError(w, http.StatusBadRequest, errors.New("chair has not arrived yet"))
			return
		}
		if _, err := tx.ExecContext(ctx, "INSERT INTO ride_statuses (id, ride_id, status) VALUES (?, ?, ?)", ulid.Make().String(), ride.ID, "CARRYING"); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	default:
		writeError(w, http.StatusBadRequest, errors.New("invalid status"))
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
