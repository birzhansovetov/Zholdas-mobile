package handler

import (
	"crypto/sha256"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"

	"github.com/birzhansovetov/zholdas-backend/internal/middleware"
)

func TestDeriveWSTicketKey(t *testing.T) {
	secret := "super-secure-jwt-secret"
	key := DeriveWSTicketKey(secret)

	expectedSum := sha256.Sum256([]byte("ws-ticket:" + secret))
	if len(key) != 32 {
		t.Fatalf("expected key length 32, got %d", len(key))
	}
	for i := range key {
		if key[i] != expectedSum[i] {
			t.Fatalf("key mismatch at index %d: expected %x, got %x", i, expectedSum[i], key[i])
		}
	}

	diffKey := DeriveWSTicketKey("another-secret")
	if string(key) == string(diffKey) {
		t.Fatal("different secrets must produce different derived keys")
	}
}

func TestWSTicket_ValidTicket(t *testing.T) {
	secret := "secret-test-jwt"
	key := DeriveWSTicketKey(secret)
	now := time.Now().Truncate(time.Second)
	userID := "00000000-0000-0000-0000-000000000001"
	eventID := int32(101)

	ticket, err := IssueWSTicket(userID, eventID, key, now)
	if err != nil {
		t.Fatalf("IssueWSTicket failed: %v", err)
	}
	if ticket == "" {
		t.Fatal("IssueWSTicket returned empty ticket")
	}

	store := NewJTIStore()
	claims, err := ValidateWSTicket(ticket, eventID, key, now.Add(10*time.Second), store)
	if err != nil {
		t.Fatalf("ValidateWSTicket failed on valid ticket: %v", err)
	}

	if claims.Subject != userID {
		t.Errorf("expected subject %s, got %s", userID, claims.Subject)
	}
	if claims.EventID != eventID {
		t.Errorf("expected eventID %d, got %d", eventID, claims.EventID)
	}
	if claims.ID == "" {
		t.Error("expected non-empty JTI claim")
	}
}

func TestWSTicket_Expired(t *testing.T) {
	secret := "secret-test-jwt"
	key := DeriveWSTicketKey(secret)
	now := time.Now().Truncate(time.Second)
	userID := "00000000-0000-0000-0000-000000000002"
	eventID := int32(102)

	ticket, err := IssueWSTicket(userID, eventID, key, now)
	if err != nil {
		t.Fatalf("IssueWSTicket failed: %v", err)
	}

	store := NewJTIStore()

	// Exactly at +60s or beyond (+61s), ticket must be expired
	expiredTime := now.Add(WSTicketDuration + 1*time.Second)
	_, err = ValidateWSTicket(ticket, eventID, key, expiredTime, store)
	if err == nil {
		t.Fatal("expected expired error, got nil")
	}
	if !errors.Is(err, ErrWSTicketExpired) {
		t.Errorf("expected ErrWSTicketExpired, got: %v", err)
	}

	// Much later in time
	farLater := now.Add(24 * time.Hour)
	_, err = ValidateWSTicket(ticket, eventID, key, farLater, store)
	if err == nil {
		t.Fatal("expected expired error for far future time, got nil")
	}
	if !errors.Is(err, ErrWSTicketExpired) {
		t.Errorf("expected ErrWSTicketExpired, got: %v", err)
	}
}

func TestWSTicket_WrongEventID(t *testing.T) {
	secret := "secret-test-jwt"
	key := DeriveWSTicketKey(secret)
	now := time.Now().Truncate(time.Second)
	userID := "00000000-0000-0000-0000-000000000003"
	issuedEventID := int32(103)
	requestedEventID := int32(999)

	ticket, err := IssueWSTicket(userID, issuedEventID, key, now)
	if err != nil {
		t.Fatalf("IssueWSTicket failed: %v", err)
	}

	store := NewJTIStore()
	_, err = ValidateWSTicket(ticket, requestedEventID, key, now.Add(5*time.Second), store)
	if err == nil {
		t.Fatal("expected error for mismatched event ID, got nil")
	}
	if !errors.Is(err, ErrWSTicketEventMismatch) {
		t.Errorf("expected ErrWSTicketEventMismatch, got: %v", err)
	}
}

func TestWSTicket_InvalidSignature(t *testing.T) {
	correctKey := DeriveWSTicketKey("correct-secret")
	wrongKey := DeriveWSTicketKey("wrong-secret")
	now := time.Now().Truncate(time.Second)
	userID := "00000000-0000-0000-0000-000000000004"
	eventID := int32(104)

	ticket, err := IssueWSTicket(userID, eventID, correctKey, now)
	if err != nil {
		t.Fatalf("IssueWSTicket failed: %v", err)
	}

	store := NewJTIStore()
	_, err = ValidateWSTicket(ticket, eventID, wrongKey, now.Add(5*time.Second), store)
	if err == nil {
		t.Fatal("expected signature verification failure, got nil")
	}
}

func TestWSTicket_DifferentAudience(t *testing.T) {
	secret := "secret-test-jwt"
	key := DeriveWSTicketKey(secret)
	now := time.Now().Truncate(time.Second)
	userID := "00000000-0000-0000-0000-000000000005"
	eventID := int32(105)

	// Issue a ticket with an unexpected audience (e.g. "authenticated" or "other-aud")
	claims := &WSTicketClaims{
		EventID: eventID,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			Audience:  jwt.ClaimStrings{"authenticated"},
			ExpiresAt: jwt.NewNumericDate(now.Add(WSTicketDuration)),
			IssuedAt:  jwt.NewNumericDate(now),
			ID:        "test-custom-jti-1",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	ticket, err := token.SignedString(key)
	if err != nil {
		t.Fatalf("token sign failed: %v", err)
	}

	store := NewJTIStore()
	_, err = ValidateWSTicket(ticket, eventID, key, now.Add(5*time.Second), store)
	if err == nil {
		t.Fatal("expected error for token with wrong audience, got nil")
	}
	if !errors.Is(err, ErrWSTicketInvalidAud) {
		t.Errorf("expected ErrWSTicketInvalidAud, got: %v", err)
	}
}

func TestWSTicket_ReplayRejected(t *testing.T) {
	secret := "secret-test-jwt"
	key := DeriveWSTicketKey(secret)
	now := time.Now().Truncate(time.Second)
	userID := "00000000-0000-0000-0000-000000000006"
	eventID := int32(106)

	ticket, err := IssueWSTicket(userID, eventID, key, now)
	if err != nil {
		t.Fatalf("IssueWSTicket failed: %v", err)
	}

	store := NewJTIStore()

	// First verification must succeed
	claims, err := ValidateWSTicket(ticket, eventID, key, now, store)
	if err != nil {
		t.Fatalf("first verification failed: %v", err)
	}
	if claims.Subject != userID {
		t.Errorf("expected subject %s, got %s", userID, claims.Subject)
	}

	// Immediate or subsequent replay of the same ticket must be rejected
	_, err = ValidateWSTicket(ticket, eventID, key, now.Add(5*time.Second), store)
	if err == nil {
		t.Fatal("expected replay error on second validation, got nil")
	}
	if !errors.Is(err, ErrWSTicketJTIReplay) {
		t.Errorf("expected ErrWSTicketJTIReplay, got: %v", err)
	}

	// A new ticket with a new random JTI must succeed in the same store
	ticket2, err := IssueWSTicket(userID, eventID, key, now.Add(6*time.Second))
	if err != nil {
		t.Fatalf("IssueWSTicket second ticket failed: %v", err)
	}
	claims2, err := ValidateWSTicket(ticket2, eventID, key, now.Add(6*time.Second), store)
	if err != nil {
		t.Fatalf("second unique ticket validation failed: %v", err)
	}
	if claims2.ID == claims.ID {
		t.Fatal("two issued tickets should have different JTIs")
	}
}

func TestWSTicket_JTIStorePruning(t *testing.T) {
	store := NewJTIStore()
	now := time.Now().Truncate(time.Second)

	// Add an expired JTI directly
	store.usedJTI["expired-jti-1"] = now.Add(-10 * time.Second)
	store.usedJTI["valid-jti-1"] = now.Add(50 * time.Second)

	// Calling Use on a new JTI triggers cleanup
	err := store.Use("fresh-jti", now.Add(60*time.Second), now)
	if err != nil {
		t.Fatalf("store.Use failed: %v", err)
	}

	store.mu.Lock()
	defer store.mu.Unlock()

	if _, exists := store.usedJTI["expired-jti-1"]; exists {
		t.Error("expired JTI was not purged from store")
	}
	if _, exists := store.usedJTI["valid-jti-1"]; !exists {
		t.Error("valid JTI was unexpectedly purged from store")
	}
	if _, exists := store.usedJTI["fresh-jti"]; !exists {
		t.Error("fresh JTI was not added to store")
	}
}

func TestCreateWebSocketTicket_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := &EventHandler{}

	r := gin.New()
	r.POST("/events/:id/ws-ticket", h.CreateWebSocketTicket)

	req := httptest.NewRequest(http.MethodPost, "/events/1/ws-ticket", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401 Unauthorized, got %d", w.Code)
	}
}

func TestCreateWebSocketTicket_InvalidEventID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := &EventHandler{}

	r := gin.New()
	r.POST("/events/:id/ws-ticket", func(c *gin.Context) {
		c.Set("user_id", "test-user-uuid")
		h.CreateWebSocketTicket(c)
	})

	req := httptest.NewRequest(http.MethodPost, "/events/abc/ws-ticket", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400 Bad Request, got %d", w.Code)
	}
}

func TestCreateWebSocketTicket_NoDatabaseFailsClosed(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := &EventHandler{}
	h.SetJWTSecret("server-test-jwt-secret")

	r := gin.New()
	r.POST("/events/:id/ws-ticket", func(c *gin.Context) {
		c.Set("user_id", "test-user-123")
		h.CreateWebSocketTicket(c)
	})

	req := httptest.NewRequest(http.MethodPost, "/events/42/ws-ticket", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	// Without a database the membership check cannot run, so no ticket may be issued.
	if w.Code == http.StatusOK {
		t.Fatalf("expected an error without database, got 200: %s", w.Body.String())
	}
}

func TestWebSocketChatUpgrader_MissingParams(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := &EventHandler{}

	r := gin.New()
	r.GET("/events/:id/ws", h.WebSocketChatUpgrader)

	req := httptest.NewRequest(http.MethodGet, "/events/42/ws", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401 Unauthorized, got %d", w.Code)
	}
}

func TestWebSocketChatUpgrader_InvalidTicket(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := &EventHandler{}
	h.SetJWTSecret("my-secret")

	r := gin.New()
	r.GET("/events/:id/ws", h.WebSocketChatUpgrader)

	req := httptest.NewRequest(http.MethodGet, "/events/42/ws?ticket=invalid-garbage-ticket", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401 Unauthorized, got %d", w.Code)
	}
}

func TestWebSocketChatUpgrader_InvalidToken(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := &EventHandler{}
	h.SetJWTConfig(middleware.TokenConfig{Secret: "my-secret"})

	r := gin.New()
	r.GET("/events/:id/ws", h.WebSocketChatUpgrader)

	req := httptest.NewRequest(http.MethodGet, "/events/42/ws?token=invalid-garbage-token", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401 Unauthorized, got %d", w.Code)
	}
}
