package handler

import (
	"log"
	"net/http"
	"net/mail"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WaitlistHandler struct {
	pool *pgxpool.Pool
}

func NewWaitlistHandler(pool *pgxpool.Pool) *WaitlistHandler {
	return &WaitlistHandler{pool: pool}
}

type waitlistDTO struct {
	Email    string `json:"email"`
	Lang     string `json:"lang"`
	Platform string `json:"platform"`
	Source   string `json:"source"`
	// Honeypot: real visitors never see this field, bots tend to fill it.
	Website string `json:"website"`
}

// NormalizeWaitlistEmail trims and lowercases the address and reports whether it is a plain valid email.
func NormalizeWaitlistEmail(raw string) (string, bool) {
	email := strings.ToLower(strings.TrimSpace(raw))
	if email == "" || len(email) > 254 {
		return "", false
	}
	addr, err := mail.ParseAddress(email)
	if err != nil || addr.Address != email {
		return "", false
	}
	at := strings.LastIndex(email, "@")
	if at < 1 || !strings.Contains(email[at+1:], ".") {
		return "", false
	}
	return email, true
}

func normalizeWaitlistPlatform(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "ios":
		return "ios"
	case "android":
		return "android"
	default:
		return "any"
	}
}

func normalizeWaitlistSource(raw string) string {
	source := strings.TrimSpace(raw)
	if source == "" {
		return "landing"
	}
	if len(source) > 50 {
		source = source[:50]
	}
	return source
}

// JoinWaitlist stores an email from the landing page. Duplicates are accepted silently,
// so the response never reveals whether an address is already on the list.
func (h *WaitlistHandler) JoinWaitlist(c *gin.Context) {
	var dto waitlistDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	if strings.TrimSpace(dto.Website) != "" {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
		return
	}
	email, ok := NormalizeWaitlistEmail(dto.Email)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_email"})
		return
	}

	_, err := h.pool.Exec(c.Request.Context(), `
		INSERT INTO waitlist (email, lang, platform, source)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (email) DO NOTHING
	`, email, string(NormalizeLegalLang(dto.Lang)), normalizeWaitlistPlatform(dto.Platform), normalizeWaitlistSource(dto.Source))
	if err != nil {
		log.Printf("[Waitlist] Failed to save email: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server_error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
