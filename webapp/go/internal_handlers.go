package main

import (
	"net/http"
)

// このAPIをインスタンス内から一定間隔で叩かせることで、椅子とライドをマッチングさせる
func internalGetMatching(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	tx, err := db.Beginx()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	defer tx.Rollback()

	var chairs []Chair
	if err := tx.SelectContext(ctx, &chairs, "SELECT * FROM chairs WHERE is_matchable = TRUE"); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	var rides []Ride
	if err := tx.SelectContext(ctx, &rides, "SELECT * FROM rides WHERE chair_id IS NULL ORDER BY created_at ASC LIMIT ?", len(chairs)); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	remainingChairs := make(map[Chair]struct{}, len(chairs))
	for _, c := range chairs {
		remainingChairs[c] = struct{}{}
	}

	for _, r := range rides {
		var best Chair
		var bestDistance int
		for c := range remainingChairs {
			if c.Latitude == nil || c.Longitude == nil {
				continue
			}
			distance := calculateDistance(*c.Latitude, *c.Longitude, r.PickupLatitude, r.PickupLongitude)
			if best.ID == "" || bestDistance > distance {
				best = c
				bestDistance = distance
			}
		}
		if best.ID == "" {
			continue
		}
		delete(remainingChairs, best)

		if _, err := db.ExecContext(ctx, "UPDATE rides SET chair_id = ? WHERE id = ?", best.ID, r.ID); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		if _, err := db.ExecContext(ctx, "UPDATE chairs SET is_free = FALSE WHERE id = ?", best.ID); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}

		defer signalCharNotification(best.ID)
	}

	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
