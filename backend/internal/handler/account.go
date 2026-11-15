package handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// SQL fragment expressions for event messages sender attribution.
// When em.sender_deleted is true, message is displayed as an anonymized "Удалённый пользователь".
const (
	SQLSenderDeletedName     = "Удалённый пользователь"
	SQLSenderDeletedUsername = "deleted_user"
	SQLSenderAIName          = "Жорик (ИИ)"
	SQLSenderAIUsername      = "ai_helper"

	EventMessageSenderIDExpr        = "CASE WHEN em.sender_deleted THEN '' ELSE COALESCE(em.sender_id::text, '') END"
	EventMessageSenderNameExpr      = "CASE WHEN em.sender_deleted THEN 'Удалённый пользователь' ELSE COALESCE(p.full_name, 'Жорик (ИИ)') END"
	EventMessageSenderUsernameExpr  = "CASE WHEN em.sender_deleted THEN 'deleted_user' ELSE COALESCE(p.username, 'ai_helper') END"
	EventMessageSenderAvatarURLExpr = "CASE WHEN em.sender_deleted THEN '' ELSE COALESCE(p.avatar_url, '') END"
	LastMessageSenderExpr           = "CASE WHEN m.sender_deleted THEN 'Удалённый пользователь' ELSE COALESCE(p.full_name, '') END"
)

// FormatSenderProfile returns sender fields matching the SQL CASE WHEN logic.
// This pure function allows unit testing sender attribution logic without a database.
func FormatSenderProfile(senderDeleted bool, senderID *string, fullName *string, username *string, avatarURL *string) (id, name, user, avatar string) {
	if senderDeleted {
		return "", SQLSenderDeletedName, SQLSenderDeletedUsername, ""
	}
	if senderID != nil && *senderID != "" {
		id = *senderID
	}
	if fullName != nil && strings.TrimSpace(*fullName) != "" {
		name = *fullName
	} else {
		name = SQLSenderAIName
	}
	if username != nil && strings.TrimSpace(*username) != "" {
		user = *username
	} else {
		user = SQLSenderAIUsername
	}
	if avatarURL != nil {
		avatar = *avatarURL
	}
	return id, name, user, avatar
}

// DeleteOwnAccount permanently removes the authenticated user's account (DELETE /auth/me).
// In a single database transaction:
// 1. Existing chat messages are preserved and attributed to "Удалённый пользователь" (sender_deleted = true, sender_id = NULL).
// 2. Reports targeting or filed by the user are safely handled so they don't block foreign key deletion.
// 3. User device push tokens and sessions are removed.
// 4. User is removed from auth.users (cascades created events, profiles, etc.).
func (h *AuthHandler) DeleteOwnAccount(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID, ok := userIDVal.(string)
	if !ok || strings.TrimSpace(userID) == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	ctx := c.Request.Context()
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction: " + err.Error()})
		return
	}
	defer tx.Rollback(ctx)

	// 1. Preserve chat messages: mark as deleted sender and detach user ID.
	_, err = tx.Exec(ctx, `
		UPDATE event_messages
		SET sender_id = NULL, sender_deleted = TRUE
		WHERE sender_id = $1
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to anonymize event messages: " + err.Error()})
		return
	}

	// 2. Reports handling:
	// a) Detach reported_user_id on reports targeting specific messages or events so the complaint remains
	// for moderation without violating foreign key constraints when the user is deleted.
	_, err = tx.Exec(ctx, `
		UPDATE reports
		SET reported_user_id = NULL
		WHERE reported_user_id = $1 AND (message_id IS NOT NULL OR event_id IS NOT NULL)
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update report references: " + err.Error()})
		return
	}

	// b) Delete reports where this user was the sole reported target (profile complaint).
	_, err = tx.Exec(ctx, `
		DELETE FROM reports
		WHERE reported_user_id = $1
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to clean up user reports: " + err.Error()})
		return
	}

	// c) Delete complaints submitted by this user as reporter.
	_, err = tx.Exec(ctx, `
		DELETE FROM reports
		WHERE reporter_id = $1
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to clean up reporter reports: " + err.Error()})
		return
	}

	// 3. Delete user push tokens and active sessions.
	_, err = tx.Exec(ctx, "DELETE FROM user_device_tokens WHERE user_id = $1", userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete device tokens: " + err.Error()})
		return
	}

	_, err = tx.Exec(ctx, "DELETE FROM user_sessions WHERE user_id = $1", userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user sessions: " + err.Error()})
		return
	}

	// 4. Delete user record from auth.users (cascades profile, created events, participants).
	res, err := tx.Exec(ctx, "DELETE FROM auth.users WHERE id = $1", userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user: " + err.Error()})
		return
	}
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Account deleted"})
}
