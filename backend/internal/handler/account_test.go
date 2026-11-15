package handler

import (
	"strings"
	"testing"
)

func TestAccountSenderSQLExpr(t *testing.T) {
	// Verify that the SQL expressions properly handle em.sender_deleted
	if !strings.Contains(EventMessageSenderNameExpr, "sender_deleted") {
		t.Errorf("EventMessageSenderNameExpr missing sender_deleted check: %s", EventMessageSenderNameExpr)
	}
	if !strings.Contains(EventMessageSenderNameExpr, "Удалённый пользователь") {
		t.Errorf("EventMessageSenderNameExpr missing 'Удалённый пользователь': %s", EventMessageSenderNameExpr)
	}
	if !strings.Contains(EventMessageSenderUsernameExpr, "deleted_user") {
		t.Errorf("EventMessageSenderUsernameExpr missing 'deleted_user': %s", EventMessageSenderUsernameExpr)
	}
	if !strings.Contains(EventMessageSenderIDExpr, "sender_deleted") {
		t.Errorf("EventMessageSenderIDExpr missing sender_deleted check: %s", EventMessageSenderIDExpr)
	}
	if !strings.Contains(LastMessageSenderExpr, "sender_deleted") {
		t.Errorf("LastMessageSenderExpr missing sender_deleted check: %s", LastMessageSenderExpr)
	}
}

func TestFormatSenderProfile(t *testing.T) {
	idVal := "00000000-0000-0000-0000-000000000001"
	nameVal := "Алихан"
	usernameVal := "alikhan"
	avatarVal := "https://example.com/avatar.jpg"

	// 1. Deleted user sender
	id, name, user, avatar := FormatSenderProfile(true, &idVal, &nameVal, &usernameVal, &avatarVal)
	if id != "" {
		t.Errorf("Expected empty sender ID for deleted user, got %q", id)
	}
	if name != "Удалённый пользователь" {
		t.Errorf("Expected sender name 'Удалённый пользователь', got %q", name)
	}
	if user != "deleted_user" {
		t.Errorf("Expected sender username 'deleted_user', got %q", user)
	}
	if avatar != "" {
		t.Errorf("Expected empty avatar for deleted user, got %q", avatar)
	}

	// 2. Active human user
	id, name, user, avatar = FormatSenderProfile(false, &idVal, &nameVal, &usernameVal, &avatarVal)
	if id != idVal {
		t.Errorf("Expected sender ID %q, got %q", idVal, id)
	}
	if name != nameVal {
		t.Errorf("Expected sender name %q, got %q", nameVal, name)
	}
	if user != usernameVal {
		t.Errorf("Expected sender username %q, got %q", usernameVal, user)
	}
	if avatar != avatarVal {
		t.Errorf("Expected avatar %q, got %q", avatarVal, avatar)
	}

	// 3. AI assistant fallback (nil senderID and profile)
	id, name, user, avatar = FormatSenderProfile(false, nil, nil, nil, nil)
	if id != "" {
		t.Errorf("Expected empty sender ID for AI, got %q", id)
	}
	if name != "Жорик (ИИ)" {
		t.Errorf("Expected sender name 'Жорик (ИИ)', got %q", name)
	}
	if user != "ai_helper" {
		t.Errorf("Expected sender username 'ai_helper', got %q", user)
	}
	if avatar != "" {
		t.Errorf("Expected empty avatar for AI, got %q", avatar)
	}
}
