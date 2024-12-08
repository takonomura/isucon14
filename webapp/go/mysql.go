package main

import (
	"database/sql"
	"log"
	"time"
)

func initDB(db *sql.DB) {
	waitDB(db)
	go pollDB(db)

	db.SetConnMaxLifetime(10 * time.Second)
	db.SetMaxIdleConns(512)
	db.SetMaxOpenConns(512)
}

func waitDB(db *sql.DB) {
	for {
		err := db.Ping()
		if err == nil {
			return
		}

		log.Printf("Failed to ping DB: %s", err)
		log.Println("Retrying...")
		time.Sleep(time.Second)
	}
}

func pollDB(db *sql.DB) {
	for {
		err := db.Ping()
		if err != nil {
			log.Printf("Failed to ping DB: %s", err)
		}

		time.Sleep(time.Second)
	}
}
