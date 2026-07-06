package handler

import (
	"context"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type BanUserDTO struct {
	Reason string `json:"reason" binding:"required"`
}

type SystemSettingsResponse struct {
	AIEnabled         bool   `json:"ai_enabled"`
	AIRateLimitPer10m int    `json:"ai_rate_limit_per_10m"`
	DefaultCity       string `json:"default_city"`
}

type UpdateSystemSettingsDTO struct {
	AIEnabled         bool   `json:"ai_enabled"`
	AIRateLimitPer10m int    `json:"ai_rate_limit_per_10m" binding:"required,min=1,max=100"`
	DefaultCity       string `json:"default_city" binding:"required"`
}

type ReportResponse struct {
	ID               int32     `json:"id"`
	ReporterID       string    `json:"reporter_id"`
	ReporterName     string    `json:"reporter_name"`
	ReportedUserID   *string   `json:"reported_user_id,omitempty"`
	ReportedUserName *string   `json:"reported_user_name,omitempty"`
	EventID          *int32    `json:"event_id,omitempty"`
	EventTitle       *string   `json:"event_title,omitempty"`
	MessageID        *int32    `json:"message_id,omitempty"`
	MessageText      *string   `json:"message_text,omitempty"`
	Reason           string    `json:"reason"`
	Description      string    `json:"description"`
	CreatedAt        time.Time `json:"created_at"`
}

// GetSystemSettings returns admin-managed app settings.
func (h *AuthHandler) GetSystemSettings(c *gin.Context) {
	roleVal, exists := c.Get("user_role")
	if !exists || !hasAdminAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Admin role required"})
		return
	}

	settings, err := h.loadSystemSettings(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch system settings: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, settings)
}

// UpdateSystemSettings persists admin-managed app settings.
func (h *AuthHandler) UpdateSystemSettings(c *gin.Context) {
	adminIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	adminID := adminIDVal.(string)

	roleVal, exists := c.Get("user_role")
	if !exists || !hasAdminAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Admin role required"})
		return
	}

	var dto UpdateSystemSettingsDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	dto.DefaultCity = strings.TrimSpace(dto.DefaultCity)
	if dto.DefaultCity == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "default_city is required"})
		return
	}

	ctx := c.Request.Context()
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	upsert := `
		INSERT INTO system_settings (key, value, updated_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
	`
	if _, err = tx.Exec(ctx, upsert, "ai_enabled", strconv.FormatBool(dto.AIEnabled)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save ai_enabled: " + err.Error()})
		return
	}
	if _, err = tx.Exec(ctx, upsert, "ai_rate_limit_per_10m", strconv.Itoa(dto.AIRateLimitPer10m)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save ai_rate_limit_per_10m: " + err.Error()})
		return
	}
	if _, err = tx.Exec(ctx, upsert, "default_city", dto.DefaultCity); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save default_city: " + err.Error()})
		return
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO moderation_actions (moderator_id, action_type, target_type, target_id, details)
		VALUES ($1, 'update_settings', 'system', 'system_settings', $2)
	`, adminID, "Updated system settings")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log settings update: " + err.Error()})
		return
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, SystemSettingsResponse{
		AIEnabled:         dto.AIEnabled,
		AIRateLimitPer10m: dto.AIRateLimitPer10m,
		DefaultCity:       dto.DefaultCity,
	})
}

func (h *AuthHandler) loadSystemSettings(ctx context.Context) (SystemSettingsResponse, error) {
	settings := SystemSettingsResponse{
		AIEnabled:         true,
		AIRateLimitPer10m: 8,
		DefaultCity:       "Almaty",
	}

	rows, err := h.pool.Query(ctx, "SELECT key, value FROM system_settings WHERE key = ANY($1)", []string{
		"ai_enabled",
		"ai_rate_limit_per_10m",
		"default_city",
	})
	if err != nil {
		return settings, err
	}
	defer rows.Close()

	for rows.Next() {
		var key string
		var value string
		if err := rows.Scan(&key, &value); err != nil {
			return settings, err
		}

		switch key {
		case "ai_enabled":
			if parsed, err := strconv.ParseBool(value); err == nil {
				settings.AIEnabled = parsed
			}
		case "ai_rate_limit_per_10m":
			if parsed, err := strconv.Atoi(value); err == nil && parsed > 0 {
				settings.AIRateLimitPer10m = parsed
			}
		case "default_city":
			if trimmed := strings.TrimSpace(value); trimmed != "" {
				settings.DefaultCity = trimmed
			}
		}
	}

	return settings, rows.Err()
}

func normalizedAccessRole(role any) string {
	roleString, ok := role.(string)
	if !ok {
		return ""
	}
	return strings.ToLower(strings.TrimSpace(roleString))
}

func hasModerationAccess(role any) bool {
	normalizedRole := normalizedAccessRole(role)
	return normalizedRole == "moderator" || normalizedRole == "admin"
}

func hasAdminAccess(role any) bool {
	return normalizedAccessRole(role) == "admin"
}

// GetReports lists all active complaints (moderator or admin only)
func (h *AuthHandler) GetReports(c *gin.Context) {
	roleVal, exists := c.Get("user_role")
	if !exists || !hasModerationAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Moderator or Admin role required"})
		return
	}

	ctx := c.Request.Context()
	rows, err := h.pool.Query(ctx, `
		SELECT 
			r.id, r.reporter_id, p1.full_name as reporter_name,
			r.reported_user_id, p2.full_name as reported_user_name,
			r.event_id, e.title as event_title,
			r.message_id, m.text as message_text,
			r.reason, r.description, r.created_at
		FROM reports r
		JOIN profiles p1 ON r.reporter_id = p1.user_id
		LEFT JOIN profiles p2 ON r.reported_user_id = p2.user_id
		LEFT JOIN events e ON r.event_id = e.id
		LEFT JOIN event_messages m ON r.message_id = m.id
		ORDER BY r.created_at DESC
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reports: " + err.Error()})
		return
	}
	defer rows.Close()

	reports := []ReportResponse{}
	for rows.Next() {
		var rep ReportResponse
		var repName string
		var repUserName *string
		var evTitle *string
		var msgText *string

		err := rows.Scan(
			&rep.ID, &rep.ReporterID, &repName,
			&rep.ReportedUserID, &repUserName,
			&rep.EventID, &evTitle,
			&rep.MessageID, &msgText,
			&rep.Reason, &rep.Description, &rep.CreatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan report: " + err.Error()})
			return
		}
		rep.ReporterName = repName
		rep.ReportedUserName = repUserName
		rep.EventTitle = evTitle
		rep.MessageText = msgText
		reports = append(reports, rep)
	}

	c.JSON(http.StatusOK, reports)
}

// BanUser blocks a user from doing any active interactions
func (h *AuthHandler) BanUser(c *gin.Context) {
	moderatorIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	moderatorID := moderatorIDVal.(string)

	roleVal, exists := c.Get("user_role")
	if !exists || !hasModerationAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Moderator or Admin role required"})
		return
	}

	targetUserID := c.Param("id")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var dto BanUserDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	// 1. Insert ban record (triggers profiles update)
	_, err = tx.Exec(ctx, `
		INSERT INTO user_bans (user_id, banned_by, reason)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id) DO UPDATE SET reason = EXCLUDED.reason
	`, targetUserID, moderatorID, dto.Reason)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to insert user ban: " + err.Error()})
		return
	}

	// 2. Log moderation action
	_, err = tx.Exec(ctx, `
		INSERT INTO moderation_actions (moderator_id, action_type, target_type, target_id, details)
		VALUES ($1, 'ban', 'user', $2, $3)
	`, moderatorID, targetUserID, dto.Reason)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log moderation action: " + err.Error()})
		return
	}

	// 3. Create ban notification for user
	_, _ = tx.Exec(ctx, `
		INSERT INTO notifications (user_id, actor_id, notification_type, text)
		VALUES ($1, $2, 'ban', $3)
	`, targetUserID, moderatorID, "Ваш профиль был заблокирован модератором. Причина: "+dto.Reason)

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User banned successfully"})
}

// UnbanUser lifts ban block from user
func (h *AuthHandler) UnbanUser(c *gin.Context) {
	moderatorIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	moderatorID := moderatorIDVal.(string)

	roleVal, exists := c.Get("user_role")
	if !exists || !hasModerationAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Moderator or Admin role required"})
		return
	}

	targetUserID := c.Param("id")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	ctx := c.Request.Context()

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	// 1. Delete ban record (triggers profiles reset)
	res, err := tx.Exec(ctx, "DELETE FROM user_bans WHERE user_id = $1", targetUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove user ban: " + err.Error()})
		return
	}

	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "User ban not found"})
		return
	}

	// 2. Log moderation action
	_, err = tx.Exec(ctx, `
		INSERT INTO moderation_actions (moderator_id, action_type, target_type, target_id, details)
		VALUES ($1, 'unban', 'user', $2, 'Ban lifted by moderator')
	`, moderatorID, targetUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log moderation action: " + err.Error()})
		return
	}

	// 3. Create unban notification for user
	_, _ = tx.Exec(ctx, `
		INSERT INTO notifications (user_id, actor_id, notification_type, text)
		VALUES ($1, $2, 'unban', 'Ваш профиль был разблокирован модератором.')
	`, targetUserID, moderatorID)

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User unbanned successfully"})
}

// CloseReport deletes/dismisses the report
func (h *AuthHandler) CloseReport(c *gin.Context) {
	moderatorIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	moderatorID := moderatorIDVal.(string)

	roleVal, exists := c.Get("user_role")
	if !exists || !hasModerationAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Moderator or Admin role required"})
		return
	}

	reportIDStr := c.Param("id")
	reportID, err := strconv.Atoi(reportIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid report ID"})
		return
	}

	ctx := c.Request.Context()

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	// Delete report
	res, err := tx.Exec(ctx, "DELETE FROM reports WHERE id = $1", reportID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete report: " + err.Error()})
		return
	}

	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Report not found"})
		return
	}

	// Log close report moderation action
	_, err = tx.Exec(ctx, `
		INSERT INTO moderation_actions (moderator_id, action_type, target_type, target_id, details)
		VALUES ($1, 'close_report', 'report', $2, 'Report closed/resolved')
	`, moderatorID, reportID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log moderation action: " + err.Error()})
		return
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Report closed successfully"})
}

// GetModerationUsers returns all users in the system (moderator or admin only)
func (h *AuthHandler) GetModerationUsers(c *gin.Context) {
	roleVal, exists := c.Get("user_role")
	if !exists || !hasModerationAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Moderator or Admin role required"})
		return
	}

	ctx := c.Request.Context()
	rows, err := h.pool.Query(ctx, `
		SELECT
			p.user_id::text,
			p.username,
			p.full_name,
			COALESCE(p.avatar_url, ''),
			COALESCE(p.bio, ''),
			COALESCE(p.city, ''),
			COALESCE(p.gender, ''),
			COALESCE(p.birth_year, 0),
			CASE
				WHEN p.birth_year IS NULL OR p.birth_year < 1900 OR p.birth_year > EXTRACT(YEAR FROM CURRENT_DATE)::int THEN 0
				ELSE GREATEST(EXTRACT(YEAR FROM AGE(CURRENT_DATE, make_date(p.birth_year, 1, 1)))::int, 0)
			END AS age,
			p.role,
			p.is_banned,
			COALESCE(p.ban_reason, ''),
			p.created_at,
			COALESCE(au.email, ''),
			(au.email_confirmed_at IS NOT NULL) AS email_confirmed,
			au.last_sign_in_at,
			COALESCE(ev.events_count, 0),
			COALESCE(rr.reports_received, 0),
			COALESCE(rs.reports_sent, 0)
		FROM profiles p
		LEFT JOIN auth.users au ON p.user_id = au.id
		LEFT JOIN (
			SELECT creator_id, COUNT(*)::int AS events_count
			FROM events
			GROUP BY creator_id
		) ev ON ev.creator_id = p.user_id
		LEFT JOIN (
			SELECT reported_user_id, COUNT(*)::int AS reports_received
			FROM reports
			WHERE reported_user_id IS NOT NULL
			GROUP BY reported_user_id
		) rr ON rr.reported_user_id = p.user_id
		LEFT JOIN (
			SELECT reporter_id, COUNT(*)::int AS reports_sent
			FROM reports
			GROUP BY reporter_id
		) rs ON rs.reporter_id = p.user_id
		ORDER BY p.created_at DESC
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch users: " + err.Error()})
		return
	}
	defer rows.Close()

	type UserItem struct {
		UserID          string     `json:"user_id"`
		Username        string     `json:"username"`
		FullName        string     `json:"full_name"`
		AvatarURL       string     `json:"avatar_url"`
		Bio             string     `json:"bio"`
		City            string     `json:"city"`
		Gender          string     `json:"gender"`
		BirthYear       int        `json:"birth_year"`
		Age             int        `json:"age"`
		Role            string     `json:"role"`
		IsBanned        bool       `json:"is_banned"`
		BanReason       string     `json:"ban_reason"`
		CreatedAt       time.Time  `json:"created_at"`
		Email           string     `json:"email"`
		EmailConfirmed  bool       `json:"email_confirmed"`
		LastSignInAt    *time.Time `json:"last_sign_in_at,omitempty"`
		EventsCount     int        `json:"events_count"`
		ReportsReceived int        `json:"reports_received"`
		ReportsSent     int        `json:"reports_sent"`
	}

	users := []UserItem{}
	for rows.Next() {
		var u UserItem
		err := rows.Scan(
			&u.UserID,
			&u.Username,
			&u.FullName,
			&u.AvatarURL,
			&u.Bio,
			&u.City,
			&u.Gender,
			&u.BirthYear,
			&u.Age,
			&u.Role,
			&u.IsBanned,
			&u.BanReason,
			&u.CreatedAt,
			&u.Email,
			&u.EmailConfirmed,
			&u.LastSignInAt,
			&u.EventsCount,
			&u.ReportsReceived,
			&u.ReportsSent,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan user: " + err.Error()})
			return
		}
		users = append(users, u)
	}

	c.JSON(http.StatusOK, users)
}

// UpdateUserRole changes a user's role (admin only)
func (h *AuthHandler) UpdateUserRole(c *gin.Context) {
	moderatorIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	moderatorID := moderatorIDVal.(string)

	roleVal, exists := c.Get("user_role")
	if !exists || !hasAdminAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Admin role required"})
		return
	}

	targetUserID := c.Param("id")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var dto struct {
		Role string `json:"role" binding:"required"`
	}
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if dto.Role != "user" && dto.Role != "moderator" && dto.Role != "admin" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid role"})
		return
	}

	ctx := c.Request.Context()
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	res, err := tx.Exec(ctx, "UPDATE profiles SET role = $1 WHERE user_id = $2", dto.Role, targetUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update role: " + err.Error()})
		return
	}
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO moderation_actions (moderator_id, action_type, target_type, target_id, details)
		VALUES ($1, 'update_role', 'user', $2, $3)
	`, moderatorID, targetUserID, "Role changed to "+dto.Role)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log moderation action: " + err.Error()})
		return
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User role updated successfully"})
}

// DeleteUserPermanently removes a user permanently (admin only)
func (h *AuthHandler) DeleteUserPermanently(c *gin.Context) {
	moderatorIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	moderatorID := moderatorIDVal.(string)

	roleVal, exists := c.Get("user_role")
	if !exists || !hasAdminAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Admin role required"})
		return
	}

	targetUserID := c.Param("id")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	ctx := c.Request.Context()
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		INSERT INTO moderation_actions (moderator_id, action_type, target_type, target_id, details)
		VALUES ($1, 'delete_profile', 'user', $2, 'Profile deleted by admin')
	`, moderatorID, targetUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log moderation action: " + err.Error()})
		return
	}

	res, err := tx.Exec(ctx, "DELETE FROM auth.users WHERE id = $1", targetUserID)
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

	c.JSON(http.StatusOK, gin.H{"message": "User deleted permanently"})
}

// GetModerationEvents returns all events (moderator or admin only)
func (h *AuthHandler) GetModerationEvents(c *gin.Context) {
	roleVal, exists := c.Get("user_role")
	if !exists || !hasModerationAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Moderator or Admin role required"})
		return
	}

	ctx := c.Request.Context()
	rows, err := h.pool.Query(ctx, `
		SELECT
			e.id,
			e.creator_id::text,
			e.title,
			COALESCE(e.description, ''),
			e.category,
			e.status,
			COALESCE(e.location_name, ''),
			COALESCE(ST_Y(e.location::geometry), 0),
			COALESCE(ST_X(e.location::geometry), 0),
			e.start_time,
			e.end_time,
			e.max_participants,
			COALESCE(e.image_url, ''),
			COALESCE(e.visibility, 'public'),
			COALESCE(e.gender_filter, 'Все'),
			COALESCE(e.min_age, 0),
			COALESCE(e.max_age, 0),
			e.created_at,
			p.username AS creator_username,
			p.full_name AS creator_name,
			COALESCE(ep.participant_count, 0)
		FROM events e
		JOIN profiles p ON e.creator_id = p.user_id
		LEFT JOIN (
			SELECT event_id, COUNT(*)::int AS participant_count
			FROM event_participants
			GROUP BY event_id
		) ep ON ep.event_id = e.id
		ORDER BY e.start_time DESC
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch events: " + err.Error()})
		return
	}
	defer rows.Close()

	type EventItem struct {
		ID               int32     `json:"id"`
		CreatorID        string    `json:"creator_id"`
		Title            string    `json:"title"`
		Description      string    `json:"description"`
		Category         string    `json:"category"`
		Status           string    `json:"status"`
		LocationName     string    `json:"location_name"`
		Latitude         float64   `json:"latitude"`
		Longitude        float64   `json:"longitude"`
		StartTime        time.Time `json:"start_time"`
		EndTime          time.Time `json:"end_time"`
		MaxParticipants  int32     `json:"max_participants"`
		ImageURL         string    `json:"image_url"`
		Visibility       string    `json:"visibility"`
		GenderFilter     string    `json:"gender_filter"`
		MinAge           int       `json:"min_age"`
		MaxAge           int       `json:"max_age"`
		CreatedAt        time.Time `json:"created_at"`
		CreatorUsername  string    `json:"creator_username"`
		CreatorName      string    `json:"creator_name"`
		ParticipantCount int       `json:"participant_count"`
	}

	events := []EventItem{}
	for rows.Next() {
		var ev EventItem
		err := rows.Scan(
			&ev.ID,
			&ev.CreatorID,
			&ev.Title,
			&ev.Description,
			&ev.Category,
			&ev.Status,
			&ev.LocationName,
			&ev.Latitude,
			&ev.Longitude,
			&ev.StartTime,
			&ev.EndTime,
			&ev.MaxParticipants,
			&ev.ImageURL,
			&ev.Visibility,
			&ev.GenderFilter,
			&ev.MinAge,
			&ev.MaxAge,
			&ev.CreatedAt,
			&ev.CreatorUsername,
			&ev.CreatorName,
			&ev.ParticipantCount,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan event: " + err.Error()})
			return
		}
		events = append(events, ev)
	}

	c.JSON(http.StatusOK, events)
}

// UpdateEventStatus updates event status or deletes it (moderator or admin only)
func (h *AuthHandler) UpdateEventStatus(c *gin.Context) {
	moderatorIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	moderatorID := moderatorIDVal.(string)

	roleVal, exists := c.Get("user_role")
	if !exists || !hasModerationAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Moderator or Admin role required"})
		return
	}

	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	var dto struct {
		Status string `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if dto.Status != "active" && dto.Status != "closed" && dto.Status != "cancelled" && dto.Status != "deleted" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status"})
		return
	}

	ctx := c.Request.Context()
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	if dto.Status == "deleted" {
		_, err = tx.Exec(ctx, `
			INSERT INTO moderation_actions (moderator_id, action_type, target_type, target_id, details)
			VALUES ($1, 'delete_event', 'event', $2, 'Event deleted by moderator')
		`, moderatorID, strconv.Itoa(eventID))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log moderation action: " + err.Error()})
			return
		}

		_, err = tx.Exec(ctx, "DELETE FROM events WHERE id = $1", eventID)
	} else {
		_, err = tx.Exec(ctx, "UPDATE events SET status = $1 WHERE id = $2", dto.Status, eventID)
		if err == nil {
			_, err = tx.Exec(ctx, `
				INSERT INTO moderation_actions (moderator_id, action_type, target_type, target_id, details)
				VALUES ($1, 'update_event_status', 'event', $2, $3)
			`, moderatorID, strconv.Itoa(eventID), "Status changed to "+dto.Status)
		}
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update event status: " + err.Error()})
		return
	}
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Event status updated successfully"})
}

// GetModerationStats returns metrics for dashboard analytics (moderator or admin only)
func (h *AuthHandler) GetModerationStats(c *gin.Context) {
	roleVal, exists := c.Get("user_role")
	if !exists || !hasModerationAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Moderator or Admin role required"})
		return
	}

	ctx := c.Request.Context()

	var userCount int
	var eventCount int
	var activeEventCount int
	var messageCount int
	var reportCount int
	var banCount int
	var regToday int
	var reg7Days int
	var reg30Days int
	var events7Days int
	var events30Days int
	var messages7Days int
	var joins7Days int
	var actives7Days int

	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM profiles").Scan(&userCount)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM events").Scan(&eventCount)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM events WHERE status = 'active'").Scan(&activeEventCount)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM event_messages").Scan(&messageCount)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM reports").Scan(&reportCount)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM user_bans").Scan(&banCount)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM profiles WHERE created_at >= date_trunc('day', now())").Scan(&regToday)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM profiles WHERE created_at >= now() - interval '7 days'").Scan(&reg7Days)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM profiles WHERE created_at >= now() - interval '30 days'").Scan(&reg30Days)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM events WHERE created_at >= now() - interval '7 days'").Scan(&events7Days)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM events WHERE created_at >= now() - interval '30 days'").Scan(&events30Days)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM event_messages WHERE created_at >= now() - interval '7 days'").Scan(&messages7Days)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM event_participants WHERE joined_at >= now() - interval '7 days'").Scan(&joins7Days)
	_ = h.pool.QueryRow(ctx, "SELECT COUNT(*) FROM events WHERE status = 'active' AND created_at >= now() - interval '7 days'").Scan(&actives7Days)

	c.JSON(http.StatusOK, gin.H{
		"users":           userCount,
		"events":          eventCount,
		"active_events":   activeEventCount,
		"messages":        messageCount,
		"reports":         reportCount,
		"bans":            banCount,
		"reg_today":       regToday,
		"reg_7_days":      reg7Days,
		"reg_30_days":     reg30Days,
		"events_7_days":   events7Days,
		"events_30_days":  events30Days,
		"messages_7_days": messages7Days,
		"joins_7_days":    joins7Days,
		"actives_7_days":  actives7Days,
	})
}

// GetModerationAuditLogs returns recent moderation actions (admin only)
func (h *AuthHandler) GetModerationAuditLogs(c *gin.Context) {
	roleVal, exists := c.Get("user_role")
	if !exists || !hasAdminAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Admin role required"})
		return
	}

	ctx := c.Request.Context()

	rows, err := h.pool.Query(ctx, `
		SELECT
			ma.id,
			ma.moderator_id::text,
			COALESCE(p.full_name, p.username, au.email, 'Unknown moderator') AS moderator_name,
			ma.action_type,
			ma.target_type,
			ma.target_id::text,
			COALESCE(ma.details, ''),
			ma.created_at
		FROM moderation_actions ma
		LEFT JOIN profiles p ON p.user_id = ma.moderator_id
		LEFT JOIN auth.users au ON au.id = ma.moderator_id
		ORDER BY ma.created_at DESC
		LIMIT 200
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch audit logs: " + err.Error()})
		return
	}
	defer rows.Close()

	type AuditLogItem struct {
		ID            int32     `json:"id"`
		ModeratorID   string    `json:"moderator_id"`
		ModeratorName string    `json:"moderator_name"`
		ActionType    string    `json:"action_type"`
		TargetType    string    `json:"target_type"`
		TargetID      string    `json:"target_id"`
		Details       string    `json:"details"`
		CreatedAt     time.Time `json:"created_at"`
	}

	logs := []AuditLogItem{}
	for rows.Next() {
		var item AuditLogItem
		if err := rows.Scan(
			&item.ID,
			&item.ModeratorID,
			&item.ModeratorName,
			&item.ActionType,
			&item.TargetType,
			&item.TargetID,
			&item.Details,
			&item.CreatedAt,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan audit log: " + err.Error()})
			return
		}
		logs = append(logs, item)
	}

	c.JSON(http.StatusOK, logs)
}

// BroadcastNotification sends an announcement notification to all users (admin only)
func (h *AuthHandler) BroadcastNotification(c *gin.Context) {
	roleVal, exists := c.Get("user_role")
	if !exists || !hasAdminAccess(roleVal) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Forbidden: Admin role required"})
		return
	}

	var dto struct {
		Title string `json:"title" binding:"required"`
		Text  string `json:"text" binding:"required"`
	}
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Fetch all user IDs
	rows, err := h.pool.Query(ctx, "SELECT user_id::text FROM profiles")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to query users: " + err.Error()})
		return
	}
	defer rows.Close()

	var userIDs []string
	for rows.Next() {
		var uid string
		if err := rows.Scan(&uid); err == nil {
			userIDs = append(userIDs, uid)
		}
	}

	// Insert global notification for each user
	for _, uid := range userIDs {
		_, _ = h.pool.Exec(ctx, `
			INSERT INTO notifications (user_id, actor_id, notification_type, text)
			VALUES ($1, $2, 'announcement', $3)
		`, uid, nil, "Внимание! ["+dto.Title+"]: "+dto.Text)
	}

	c.JSON(http.StatusOK, gin.H{"message": "Broadcast sent successfully to " + strconv.Itoa(len(userIDs)) + " users"})
}
