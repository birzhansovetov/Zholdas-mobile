package handler

import (
	"context"
	"log"
	"strings"
	"sync/atomic"

	"github.com/jackc/pgx/v5/pgxpool"
)

// senderDeletedColumn reports whether event_messages.sender_deleted exists.
// Production applies migrations by hand, so the server must work both before
// and after migration 0021 is applied.
var senderDeletedColumn atomic.Bool

// DetectSchemaFeatures checks optional columns once at startup.
func DetectSchemaFeatures(ctx context.Context, pool *pgxpool.Pool) {
	if pool == nil {
		return
	}
	var exists bool
	err := pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_schema = current_schema() AND table_name = 'event_messages' AND column_name = 'sender_deleted'
		)
	`).Scan(&exists)
	if err != nil {
		log.Printf("schema check for event_messages.sender_deleted failed: %v", err)
		return
	}
	senderDeletedColumn.Store(exists)
	if !exists {
		log.Println("event_messages.sender_deleted is missing (migration 0021 not applied): deleted users' messages are removed instead of anonymized")
	}
}

// withSenderDeleted replaces references to the optional column with false
// when the column does not exist yet.
func withSenderDeleted(query string) string {
	return withSenderDeletedFlag(query, senderDeletedColumn.Load())
}

func withSenderDeletedFlag(query string, columnExists bool) string {
	if columnExists {
		return query
	}
	return strings.NewReplacer(
		"em.sender_deleted", "false",
		"event_messages.sender_deleted", "false",
	).Replace(query)
}
