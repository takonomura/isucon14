package main

import (
	"database/sql"
	"time"
)

type Chair struct {
	ID          string    `db:"id"`
	OwnerID     string    `db:"owner_id"`
	Name        string    `db:"name"`
	Model       string    `db:"model"`
	IsActive    bool      `db:"is_active"`
	AccessToken string    `db:"access_token"`
	CreatedAt   time.Time `db:"created_at"`
	UpdatedAt   time.Time `db:"updated_at"`
}

type ChairModel struct {
	Name  string `db:"name"`
	Speed int    `db:"speed"`
}

type ChairLocation struct {
	ID        string    `db:"id"`
	ChairID   string    `db:"chair_id"`
	Latitude  int       `db:"latitude"`
	Longitude int       `db:"longitude"`
	CreatedAt time.Time `db:"created_at"`
}

type User struct {
	ID             string    `db:"id"`
	Username       string    `db:"username"`
	Firstname      string    `db:"firstname"`
	Lastname       string    `db:"lastname"`
	DateOfBirth    string    `db:"date_of_birth"`
	AccessToken    string    `db:"access_token"`
	InvitationCode string    `db:"invitation_code"`
	CreatedAt      time.Time `db:"created_at"`
	UpdatedAt      time.Time `db:"updated_at"`
}

type PaymentToken struct {
	UserID    string    `db:"user_id"`
	Token     string    `db:"token"`
	CreatedAt time.Time `db:"created_at"`
}

type Ride struct {
	ID                   string         `db:"id"`
	UserID               string         `db:"user_id"`
	ChairID              sql.NullString `db:"chair_id"`
	PickupLatitude       int            `db:"pickup_latitude"`
	PickupLongitude      int            `db:"pickup_longitude"`
	DestinationLatitude  int            `db:"destination_latitude"`
	DestinationLongitude int            `db:"destination_longitude"`
	Evaluation           *int           `db:"evaluation"`
	CreatedAt            time.Time      `db:"created_at"`
	UpdatedAt            time.Time      `db:"updated_at"`
}

type RideStatus struct {
	ID          string     `db:"id"`
	RideID      string     `db:"ride_id"`
	Status      string     `db:"status"`
	CreatedAt   time.Time  `db:"created_at"`
	AppSentAt   *time.Time `db:"app_sent_at"`
	ChairSentAt *time.Time `db:"chair_sent_at"`
}

type Owner struct {
	ID                 string    `db:"id"`
	Name               string    `db:"name"`
	AccessToken        string    `db:"access_token"`
	ChairRegisterToken string    `db:"chair_register_token"`
	CreatedAt          time.Time `db:"created_at"`
	UpdatedAt          time.Time `db:"updated_at"`
}

type Coupon struct {
	UserID    string    `db:"user_id"`
	Code      string    `db:"code"`
	Discount  int       `db:"discount"`
	CreatedAt time.Time `db:"created_at"`
	UsedBy    *string   `db:"used_by"`
}
