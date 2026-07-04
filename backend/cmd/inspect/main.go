package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer pool.Close()

	fmt.Println("Inspecting column types for users and events...")

	rows, err := pool.Query(ctx, `
		SELECT table_name, column_name, data_type 
		FROM information_schema.columns 
		WHERE table_name IN ('users', 'profiles', 'events') 
		ORDER BY table_name, ordinal_position;
	`)
	if err != nil {
		log.Fatalf("Query failed: %v", err)
	}
	defer rows.Close()

	for rows.Next() {
		var tableName, columnName, dataType string
		if err := rows.Scan(&tableName, &columnName, &dataType); err != nil {
			log.Fatalf("Row scan failed: %v", err)
		}
		fmt.Printf("Table: %s | Column: %s | Type: %s\n", tableName, columnName, dataType)
	}
}
