package handler

import (
	"strings"
	"testing"
)

func TestWithSenderDeletedFlag(t *testing.T) {
	q := `SELECT em.sender_deleted AS sender_deleted, CASE WHEN m.sender_deleted THEN 1 END, NOT event_messages.sender_deleted`

	if got := withSenderDeletedFlag(q, true); got != q {
		t.Fatalf("query must be unchanged when the column exists, got %q", got)
	}

	got := withSenderDeletedFlag(q, false)
	if strings.Contains(got, "em.sender_deleted") || strings.Contains(got, "event_messages.sender_deleted") {
		t.Fatalf("column references must be replaced, got %q", got)
	}
	if !strings.Contains(got, "false AS sender_deleted") {
		t.Fatalf("lateral alias must stay usable, got %q", got)
	}
	if !strings.Contains(got, "m.sender_deleted") {
		t.Fatalf("outer alias reference must stay, got %q", got)
	}
}
