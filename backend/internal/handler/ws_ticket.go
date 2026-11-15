package handler

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	// WSTicketAudience is the required JWT audience for WebSocket tickets.
	WSTicketAudience = "zholdas-ws"
	// WSTicketDuration is the lifetime of a WebSocket ticket (60 seconds).
	WSTicketDuration = 60 * time.Second
	// WSTicketExpiresInSeconds is the duration in seconds returned in responses.
	WSTicketExpiresInSeconds = 60
)

var (
	ErrWSTicketInvalid       = errors.New("invalid or expired ticket")
	ErrWSTicketExpired       = errors.New("ticket is expired")
	ErrWSTicketInvalidAud    = errors.New("invalid ticket audience")
	ErrWSTicketEventMismatch = errors.New("event id mismatch")
	ErrWSTicketJTIReplay     = errors.New("ticket has already been used")
	ErrWSTicketEmptySubject  = errors.New("empty subject")
	ErrWSTicketMissingJTI    = errors.New("missing jti claim")
	ErrWSTicketEmptyKey      = errors.New("secret key cannot be empty")
)

// WSTicketClaims contains claims for a short-lived event WebSocket ticket.
type WSTicketClaims struct {
	EventID int32 `json:"eid"`
	jwt.RegisteredClaims
}

// DeriveWSTicketKey derives a dedicated HMAC-SHA256 key from the base JWT secret:
// HMAC key = sha256("ws-ticket:" + jwtSecret)
func DeriveWSTicketKey(jwtSecret string) []byte {
	sum := sha256.Sum256([]byte("ws-ticket:" + jwtSecret))
	return sum[:]
}

// GenerateJTI generates a random hex string for the JWT ID (jti) claim.
func GenerateJTI() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("generate jti: %w", err)
	}
	return hex.EncodeToString(b), nil
}

// IssueWSTicket creates a short-lived signed WebSocket ticket JWT for user and event.
func IssueWSTicket(userID string, eventID int32, key []byte, now time.Time) (string, error) {
	jti, err := GenerateJTI()
	if err != nil {
		return "", err
	}
	return IssueWSTicketWithJTI(userID, eventID, key, now, jti)
}

// IssueWSTicketWithJTI creates a signed WebSocket ticket JWT with a specified JTI.
func IssueWSTicketWithJTI(userID string, eventID int32, key []byte, now time.Time, jti string) (string, error) {
	if len(key) == 0 {
		return "", ErrWSTicketEmptyKey
	}
	if strings.TrimSpace(userID) == "" {
		return "", ErrWSTicketEmptySubject
	}

	claims := &WSTicketClaims{
		EventID: eventID,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			Audience:  jwt.ClaimStrings{WSTicketAudience},
			ExpiresAt: jwt.NewNumericDate(now.Add(WSTicketDuration)),
			IssuedAt:  jwt.NewNumericDate(now),
			ID:        jti,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(key)
}

// JTIStore tracks used JWT IDs in-memory with thread-safety to enforce one-time usage.
type JTIStore struct {
	mu      sync.Mutex
	usedJTI map[string]time.Time
}

// NewJTIStore initializes an in-memory JTI store.
func NewJTIStore() *JTIStore {
	return &JTIStore{
		usedJTI: make(map[string]time.Time),
	}
}

// Use checks whether jti was already used, records it until expiresAt, and purges expired entries relative to now.
// Returns ErrWSTicketJTIReplay if jti was already recorded.
func (s *JTIStore) Use(jti string, expiresAt time.Time, now time.Time) error {
	if s == nil {
		return nil
	}
	if strings.TrimSpace(jti) == "" {
		return ErrWSTicketMissingJTI
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	// Periodic cleanup of expired entries relative to now
	for id, exp := range s.usedJTI {
		if !now.Before(exp) {
			delete(s.usedJTI, id)
		}
	}

	if _, exists := s.usedJTI[jti]; exists {
		return ErrWSTicketJTIReplay
	}

	s.usedJTI[jti] = expiresAt
	return nil
}

var defaultJTIStore = NewJTIStore()

// ValidateWSTicket parses and validates a WebSocket ticket with explicit time, key, and replay store.
func ValidateWSTicket(ticketStr string, expectedEventID int32, key []byte, now time.Time, store *JTIStore) (*WSTicketClaims, error) {
	if len(key) == 0 {
		return nil, ErrWSTicketEmptyKey
	}
	ticketStr = strings.TrimSpace(ticketStr)
	if ticketStr == "" {
		return nil, ErrWSTicketInvalid
	}

	claims := &WSTicketClaims{}
	parser := jwt.NewParser(
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
		jwt.WithTimeFunc(func() time.Time { return now }),
	)

	token, err := parser.ParseWithClaims(ticketStr, claims, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return key, nil
	})
	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrWSTicketExpired
		}
		if errors.Is(err, jwt.ErrTokenInvalidAudience) {
			return nil, ErrWSTicketInvalidAud
		}
		return nil, err
	}
	if !token.Valid {
		return nil, ErrWSTicketInvalid
	}

	// Verify audience explicitly
	hasAud := false
	for _, a := range claims.Audience {
		if a == WSTicketAudience {
			hasAud = true
			break
		}
	}
	if !hasAud {
		return nil, ErrWSTicketInvalidAud
	}

	// Verify expiration relative to given now
	if claims.ExpiresAt == nil || !now.Before(claims.ExpiresAt.Time) {
		return nil, ErrWSTicketExpired
	}

	// Verify event id matches route parameter
	if claims.EventID != expectedEventID {
		return nil, ErrWSTicketEventMismatch
	}

	// Verify user id
	if strings.TrimSpace(claims.Subject) == "" {
		return nil, ErrWSTicketEmptySubject
	}

	// Enforce single-use replay protection
	if store != nil {
		if claims.ID == "" {
			return nil, ErrWSTicketMissingJTI
		}
		if err := store.Use(claims.ID, claims.ExpiresAt.Time, now); err != nil {
			return nil, err
		}
	}

	return claims, nil
}
