package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"html"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/birzhansovetov/zholdas-backend/internal/database"
	"github.com/birzhansovetov/zholdas-backend/internal/service"
)

type EventHandler struct {
	pool                *pgxpool.Pool
	queries             *database.Queries
	aiService           *service.AIService
	notificationService *service.NotificationService
	ChatHub             *service.ChatHub
	jwtSecret           string
}

func NewEventHandler(pool *pgxpool.Pool, aiService *service.AIService, notificationService *service.NotificationService) *EventHandler {
	return &EventHandler{
		pool:                pool,
		queries:             database.New(pool),
		aiService:           aiService,
		notificationService: notificationService,
		ChatHub:             service.NewChatHub(),
	}
}

// SetJWTSecret sets the JWT secret key for websocket auth
func (h *EventHandler) SetJWTSecret(secret string) {
	h.jwtSecret = secret
}

func (h *EventHandler) isAIEnabled(ctx context.Context) bool {
	var value string
	err := h.pool.QueryRow(ctx, "SELECT value FROM system_settings WHERE key = 'ai_enabled'").Scan(&value)
	if err != nil {
		log.Printf("[AI Settings] Failed to read ai_enabled, allowing AI by default: %v", err)
		return true
	}

	enabled, err := strconv.ParseBool(strings.TrimSpace(value))
	if err != nil {
		log.Printf("[AI Settings] Invalid ai_enabled value %q, allowing AI by default.", value)
		return true
	}

	return enabled
}

func extractEventAIPrompt(text string) (string, bool) {
	trimmed := strings.TrimSpace(text)
	if trimmed == "" {
		return "", false
	}

	lower := strings.ToLower(trimmed)
	prefixes := []string{"@ai", "@жорик", "@joryk", "@jorik"}
	for _, prefix := range prefixes {
		if lower == prefix {
			return "", true
		}
		if strings.HasPrefix(lower, prefix+" ") || strings.HasPrefix(lower, prefix+"\n") || strings.HasPrefix(lower, prefix+"\t") {
			return strings.TrimSpace(trimmed[len(prefix):]), true
		}
	}

	return "", false
}

type CreateEventDTO struct {
	Title           string    `json:"title" binding:"required"`
	Description     string    `json:"description" binding:"required"`
	Category        string    `json:"category" binding:"required"`
	LocationName    string    `json:"location_name" binding:"required"`
	Longitude       float64   `json:"longitude" binding:"required"`
	Latitude        float64   `json:"latitude" binding:"required"`
	StartTime       time.Time `json:"start_time" binding:"required"`
	EndTime         time.Time `json:"end_time" binding:"required"`
	MaxParticipants int32     `json:"max_participants" binding:"required,gt=0"`
	ImageURL        string    `json:"image_url"`
	Visibility      string    `json:"visibility"`
	GenderFilter    string    `json:"gender_filter"`
	MinAge          int32     `json:"min_age"`
	MaxAge          int32     `json:"max_age"`
}

type UpdateEventDTO struct {
	Title           string    `json:"title" binding:"required"`
	Description     string    `json:"description" binding:"required"`
	Category        string    `json:"category" binding:"required"`
	LocationName    string    `json:"location_name" binding:"required"`
	Longitude       float64   `json:"longitude" binding:"required"`
	Latitude        float64   `json:"latitude" binding:"required"`
	StartTime       time.Time `json:"start_time" binding:"required"`
	EndTime         time.Time `json:"end_time" binding:"required"`
	MaxParticipants int32     `json:"max_participants" binding:"required,gt=0"`
	ImageURL        string    `json:"image_url"`
	Visibility      string    `json:"visibility"`
	GenderFilter    string    `json:"gender_filter"`
	MinAge          int32     `json:"min_age"`
	MaxAge          int32     `json:"max_age"`
}

type MarkArrivedDTO struct {
	Latitude  *float64 `json:"latitude"`
	Longitude *float64 `json:"longitude"`
	Accuracy  *float64 `json:"accuracy"`
}

type UpdateParticipantStatusDTO struct {
	Status string `json:"status" binding:"required"`
}

// CreateEvent creates an event with status 'active' and moderates it asynchronously
func (h *EventHandler) CreateEvent(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	var dto CreateEventDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if dto.EndTime.Before(dto.StartTime) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "End time must be after start time"})
		return
	}

	ctx := c.Request.Context()

	pgStartTime := pgtype.Timestamptz{Time: dto.StartTime, Valid: true}
	pgEndTime := pgtype.Timestamptz{Time: dto.EndTime, Valid: true}

	var createdEvent struct {
		ID              int32     `json:"id"`
		CreatorID       string    `json:"creator_id"`
		Title           string    `json:"title"`
		Description     string    `json:"description"`
		Category        string    `json:"category"`
		LocationName    string    `json:"location_name"`
		Latitude        float64   `json:"latitude"`
		Longitude       float64   `json:"longitude"`
		StartTime       time.Time `json:"start_time"`
		EndTime         time.Time `json:"end_time"`
		MaxParticipants int32     `json:"max_participants"`
		Status          string    `json:"status"`
		ImageURL        *string   `json:"image_url"`
		CreatedAt       time.Time `json:"created_at"`
		Visibility      *string   `json:"visibility"`
		GenderFilter    *string   `json:"gender_filter"`
		MinAge          *int32    `json:"min_age"`
		MaxAge          *int32    `json:"max_age"`
	}

	var imageURLParam *string
	if dto.ImageURL != "" {
		imageURLParam = &dto.ImageURL
	}

	visibilityVal := "public"
	if dto.Visibility != "" {
		visibilityVal = dto.Visibility
	}

	genderFilterVal := "Все"
	if dto.GenderFilter != "" {
		genderFilterVal = dto.GenderFilter
	}

	err := h.pool.QueryRow(ctx, `
		INSERT INTO events (creator_id, title, description, category, location_name, location, start_time, end_time, max_participants, status, image_url, visibility, gender_filter, min_age, max_age)
		VALUES ($1, $2, $3, $4, $5, ST_SetSRID(ST_MakePoint($6::float8, $7::float8), 4326)::geography, $8, $9, $10, $11, $12, $13, $14, $15, $16)
		RETURNING id, creator_id::text, title, description, category, location_name, 
		          (ST_Y(location::geometry))::float8 AS latitude, 
		          (ST_X(location::geometry))::float8 AS longitude, 
		          start_time, end_time, max_participants, status, image_url, created_at,
		          visibility, gender_filter, min_age, max_age
	`, userID, dto.Title, dto.Description, dto.Category, dto.LocationName, dto.Longitude, dto.Latitude, pgStartTime, pgEndTime, dto.MaxParticipants, "active", imageURLParam, visibilityVal, genderFilterVal, dto.MinAge, dto.MaxAge).Scan(
		&createdEvent.ID,
		&createdEvent.CreatorID,
		&createdEvent.Title,
		&createdEvent.Description,
		&createdEvent.Category,
		&createdEvent.LocationName,
		&createdEvent.Latitude,
		&createdEvent.Longitude,
		&createdEvent.StartTime,
		&createdEvent.EndTime,
		&createdEvent.MaxParticipants,
		&createdEvent.Status,
		&createdEvent.ImageURL,
		&createdEvent.CreatedAt,
		&createdEvent.Visibility,
		&createdEvent.GenderFilter,
		&createdEvent.MinAge,
		&createdEvent.MaxAge,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create event: " + err.Error()})
		return
	}

	// 201 Response returned instantly
	c.JSON(http.StatusCreated, createdEvent)

	// Async Content Moderation in Background Goroutine
	go func(eventID int32, creatorID string, title, description string) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		isUnsafe, reason, err := h.aiService.ModerateEvent(ctx, title, description)
		if err != nil {
			log.Printf("[Async Moderation Error] event_id=%d: %v", eventID, err)
			return
		}

		if isUnsafe {
			log.Printf("[Async Moderation Blocked] event_id=%d, reason=%s", eventID, reason)

			// Mark event blocked in DB
			err = h.queries.UpdateEventStatus(context.Background(), database.UpdateEventStatusParams{
				ID:     eventID,
				Status: "blocked",
			})
			if err != nil {
				log.Printf("[Async Moderation Error] Failed to update status in DB: %v", err)
				return
			}

			// Push notification dispatch
			h.notificationService.SendPush(creatorID, "Ваше событие заблокировано: "+reason)
		}
	}(createdEvent.ID, createdEvent.CreatorID, createdEvent.Title, createdEvent.Description)
}

// UpdateEvent lets the event creator edit the meeting and notifies participants about important changes.
func (h *EventHandler) UpdateEvent(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	eventID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	var dto UpdateEventDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if dto.EndTime.Before(dto.StartTime) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "End time must be after start time"})
		return
	}

	ctx := c.Request.Context()
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	var old struct {
		CreatorID       string
		Title           string
		Description     string
		LocationName    string
		Latitude        float64
		Longitude       float64
		StartTime       time.Time
		EndTime         time.Time
		MaxParticipants int32
	}

	err = tx.QueryRow(ctx, `
		SELECT creator_id::text, title, description, location_name,
		       (ST_Y(location::geometry))::float8 AS latitude,
		       (ST_X(location::geometry))::float8 AS longitude,
		       start_time, end_time, max_participants
		FROM events
		WHERE id = $1
	`, eventID).Scan(
		&old.CreatorID,
		&old.Title,
		&old.Description,
		&old.LocationName,
		&old.Latitude,
		&old.Longitude,
		&old.StartTime,
		&old.EndTime,
		&old.MaxParticipants,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch event"})
		return
	}

	if old.CreatorID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Only the organizer can edit this event"})
		return
	}

	var currentParticipants int32
	if err := tx.QueryRow(ctx, "SELECT COUNT(*)::int FROM event_participants WHERE event_id = $1", eventID).Scan(&currentParticipants); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count participants"})
		return
	}

	if dto.MaxParticipants < currentParticipants {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Max participants cannot be lower than current participants"})
		return
	}

	var imageURLParam *string
	if strings.TrimSpace(dto.ImageURL) != "" {
		imageURLParam = &dto.ImageURL
	}

	visibilityVal := strings.TrimSpace(dto.Visibility)
	if visibilityVal == "" {
		visibilityVal = "public"
	}

	genderFilterVal := strings.TrimSpace(dto.GenderFilter)
	if genderFilterVal == "" {
		genderFilterVal = "all"
	}

	pgStartTime := pgtype.Timestamptz{Time: dto.StartTime, Valid: true}
	pgEndTime := pgtype.Timestamptz{Time: dto.EndTime, Valid: true}

	var updated NearbyEventResponse
	err = tx.QueryRow(ctx, `
		UPDATE events
		SET title = $2,
		    description = $3,
		    category = $4,
		    location_name = $5,
		    location = ST_SetSRID(ST_MakePoint($6::float8, $7::float8), 4326)::geography,
		    start_time = $8,
		    end_time = $9,
		    max_participants = $10,
		    image_url = $11,
		    visibility = $12,
		    gender_filter = $13,
		    min_age = $14,
		    max_age = $15
		WHERE id = $1
		RETURNING id, creator_id::text, title, description, category, location_name,
		          (ST_Y(location::geometry))::float8 AS latitude,
		          (ST_X(location::geometry))::float8 AS longitude,
		          start_time, end_time, max_participants, status, image_url, created_at,
		          0::float8 AS distance_meters,
		          (SELECT COUNT(*) FROM event_participants ep WHERE ep.event_id = events.id)::int AS participants_count,
		          true::bool AS is_joined,
		          COALESCE(visibility, 'public') AS visibility,
		          COALESCE(gender_filter, 'all') AS gender_filter,
		          COALESCE(min_age, 0)::int AS min_age,
		          COALESCE(max_age, 0)::int AS max_age
	`, eventID, dto.Title, dto.Description, dto.Category, dto.LocationName, dto.Longitude, dto.Latitude, pgStartTime, pgEndTime, dto.MaxParticipants, imageURLParam, visibilityVal, genderFilterVal, dto.MinAge, dto.MaxAge).Scan(
		&updated.ID,
		&updated.CreatorID,
		&updated.Title,
		&updated.Description,
		&updated.Category,
		&updated.LocationName,
		&updated.Latitude,
		&updated.Longitude,
		&updated.StartTime,
		&updated.EndTime,
		&updated.MaxParticipants,
		&updated.Status,
		&updated.ImageURL,
		&updated.CreatedAt,
		&updated.DistanceMeters,
		&updated.ParticipantsCont,
		&updated.IsJoined,
		&updated.Visibility,
		&updated.GenderFilter,
		&updated.MinAge,
		&updated.MaxAge,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update event: " + err.Error()})
		return
	}

	var pushParticipantIDs []string
	var pushText string
	changes := eventChangeLabels(old.Description, old.LocationName, old.Latitude, old.Longitude, old.StartTime, old.EndTime, old.MaxParticipants, dto)
	if len(changes) > 0 {
		text := fmt.Sprintf("В событии \"%s\" изменилось: %s.", updated.Title, strings.Join(changes, ", "))
		if _, err := tx.Exec(ctx, `
			INSERT INTO notifications (user_id, actor_id, event_id, notification_type, text)
			SELECT ep.user_id, $2, $1, 'event_update', $3
			FROM event_participants ep
			WHERE ep.event_id = $1 AND ep.user_id <> $2
		`, eventID, userID, text); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to notify participants"})
			return
		}

		rows, err := tx.Query(ctx, `
			SELECT ep.user_id::text
			FROM event_participants ep
			WHERE ep.event_id = $1 AND ep.user_id <> $2
		`, eventID, userID)
		if err == nil {
			for rows.Next() {
				var participantID string
				if scanErr := rows.Scan(&participantID); scanErr == nil {
					pushParticipantIDs = append(pushParticipantIDs, participantID)
				}
			}
			rows.Close()
			pushText = text
		} else {
			log.Printf("[Event Update] Failed to fetch participant push targets for event_id=%d: %v", eventID, err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit update"})
		return
	}

	if h.notificationService != nil && pushText != "" && len(pushParticipantIDs) > 0 {
		go func(ids []string, message string) {
			for _, id := range ids {
				h.notificationService.SendPush(id, message)
			}
		}(pushParticipantIDs, pushText)
	}

	c.JSON(http.StatusOK, updated)
}

func eventChangeLabels(oldDescription, oldLocationName string, oldLatitude, oldLongitude float64, oldStartTime, oldEndTime time.Time, oldMaxParticipants int32, dto UpdateEventDTO) []string {
	var changes []string

	if strings.TrimSpace(oldLocationName) != strings.TrimSpace(dto.LocationName) ||
		absFloat(oldLatitude-dto.Latitude) > 0.00001 ||
		absFloat(oldLongitude-dto.Longitude) > 0.00001 {
		changes = append(changes, "место")
	}

	if !oldStartTime.Equal(dto.StartTime) || !oldEndTime.Equal(dto.EndTime) {
		changes = append(changes, "время")
	}

	if strings.TrimSpace(oldDescription) != strings.TrimSpace(dto.Description) {
		changes = append(changes, "описание")
	}

	if oldMaxParticipants != dto.MaxParticipants {
		changes = append(changes, "лимит участников")
	}

	return changes
}

func absFloat(value float64) float64 {
	if value < 0 {
		return -value
	}
	return value
}

func normalizeParticipantStatus(status string) string {
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "going", "иду", "go":
		return "going"
	case "late", "опаздываю":
		return "late"
	case "arrived", "на месте", "here":
		return "arrived"
	case "not_going", "not-going", "cant_go", "cannot_go", "не смогу":
		return "not_going"
	default:
		return ""
	}
}

func participantStatusLabel(status string) string {
	switch status {
	case "going":
		return "иду"
	case "late":
		return "опаздываю"
	case "arrived":
		return "на месте"
	case "not_going":
		return "не смогу"
	default:
		return status
	}
}

type NearbyEventResponse struct {
	ID               int32     `json:"id"`
	CreatorID        string    `json:"creator_id"`
	Title            string    `json:"title"`
	Description      string    `json:"description"`
	Category         string    `json:"category"`
	LocationName     string    `json:"location_name"`
	Latitude         float64   `json:"latitude"`
	Longitude        float64   `json:"longitude"`
	StartTime        time.Time `json:"start_time"`
	EndTime          time.Time `json:"end_time"`
	MaxParticipants  int32     `json:"max_participants"`
	Status           string    `json:"status"`
	ImageURL         *string   `json:"image_url"`
	CreatedAt        time.Time `json:"created_at"`
	DistanceMeters   float64   `json:"distance_meters"`
	ParticipantsCont int32     `json:"participants_count"`
	IsJoined         bool      `json:"is_joined"`
	Visibility       string    `json:"visibility"`
	GenderFilter     string    `json:"gender_filter"`
	MinAge           int32     `json:"min_age"`
	MaxAge           int32     `json:"max_age"`
}

// GetPublicEventPage renders a lightweight public page for shared event links.
func (h *EventHandler) GetPublicEventPage(c *gin.Context) {
	eventID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "Invalid event id")
		return
	}

	ctx := c.Request.Context()
	var (
		title           string
		description     string
		category        string
		locationName    string
		latitude        float64
		longitude       float64
		startTime       time.Time
		endTime         time.Time
		maxParticipants int32
		status          string
		organizerName   string
	)

	err = h.pool.QueryRow(ctx, `
		SELECT e.title, e.description, e.category, e.location_name,
		       (ST_Y(e.location::geometry))::float8 AS latitude,
		       (ST_X(e.location::geometry))::float8 AS longitude,
		       e.start_time, e.end_time, e.max_participants, e.status,
		       COALESCE(NULLIF(p.full_name, ''), NULLIF(p.username, ''), 'Организатор') AS organizer_name
		FROM events e
		LEFT JOIN profiles p ON p.user_id = e.creator_id
		WHERE e.id = $1
	`, eventID).Scan(
		&title,
		&description,
		&category,
		&locationName,
		&latitude,
		&longitude,
		&startTime,
		&endTime,
		&maxParticipants,
		&status,
		&organizerName,
	)
	if err != nil {
		c.String(http.StatusNotFound, "Event not found")
		return
	}

	routeURL := fmt.Sprintf("https://2gis.kz/geo/%f,%f", longitude, latitude)
	appURL := fmt.Sprintf("zholdas://events/%d", eventID)
	page := fmt.Sprintf(`<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%s | Zholdas</title>
  <style>
    :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: radial-gradient(circle at top, #4c1d95, #080414 58%%); color: white; }
    main { width: min(92vw, 560px); padding: 32px; border: 1px solid rgba(255,255,255,.12); border-radius: 28px; background: rgba(17, 10, 34, .78); box-shadow: 0 24px 80px rgba(0,0,0,.42); }
    .pill { display: inline-flex; gap: 8px; align-items: center; padding: 8px 12px; border-radius: 999px; background: rgba(139, 92, 246, .18); color: #c4b5fd; font-weight: 700; font-size: 14px; }
    h1 { margin: 22px 0 10px; font-size: clamp(32px, 8vw, 52px); line-height: 1; }
    p { color: rgba(255,255,255,.72); line-height: 1.55; }
    .grid { display: grid; gap: 12px; margin: 24px 0; }
    .row { padding: 16px; border-radius: 18px; background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.08); }
    .label { color: rgba(255,255,255,.48); font-size: 13px; letter-spacing: .06em; text-transform: uppercase; }
    .value { margin-top: 4px; font-weight: 750; }
    .actions { display: grid; gap: 12px; grid-template-columns: 1fr 1fr; }
    a { text-decoration: none; text-align: center; color: white; font-weight: 800; padding: 15px 18px; border-radius: 18px; background: linear-gradient(135deg, #a78bfa, #6d28d9); }
    a.secondary { background: rgba(255,255,255,.09); }
    @media (max-width: 520px) { main { padding: 24px; } .actions { grid-template-columns: 1fr; } }
  </style>
</head>
<body>
  <main>
    <div class="pill">Жолдас · %s · %s</div>
    <h1>%s</h1>
    <p>%s</p>
    <div class="grid">
      <div class="row"><div class="label">Организатор</div><div class="value">%s</div></div>
      <div class="row"><div class="label">Место</div><div class="value">%s</div></div>
      <div class="row"><div class="label">Дата и время</div><div class="value">%s - %s</div></div>
      <div class="row"><div class="label">Участников</div><div class="value">До %d человек</div></div>
    </div>
    <div class="actions">
      <a href="%s">Открыть в приложении</a>
      <a class="secondary" href="%s">Маршрут в 2GIS</a>
    </div>
  </main>
</body>
</html>`,
		html.EscapeString(title),
		html.EscapeString(category),
		html.EscapeString(status),
		html.EscapeString(title),
		html.EscapeString(description),
		html.EscapeString(organizerName),
		html.EscapeString(locationName),
		html.EscapeString(startTime.Format("02.01.2006 15:04")),
		html.EscapeString(endTime.Format("15:04")),
		maxParticipants,
		html.EscapeString(appURL),
		html.EscapeString(routeURL),
	)

	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(page))
}

// GetNearbyEvents queries PostgreSQL + PostGIS for close-by events
func (h *EventHandler) GetNearbyEvents(c *gin.Context) {
	latStr := c.Query("latitude")
	lonStr := c.Query("longitude")
	radiusStr := c.DefaultQuery("radius_meters", "5000")
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	if latStr == "" || lonStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "latitude and longitude queries are required"})
		return
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid latitude query"})
		return
	}

	lon, err := strconv.ParseFloat(lonStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid longitude query"})
		return
	}

	radius, err := strconv.ParseFloat(radiusStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid radius_meters query"})
		return
	}

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		limit = 20
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		offset = 0
	}

	userIDVal, exists := c.Get("user_id")
	var userID string
	if exists {
		userID = userIDVal.(string)
	}

	ctx := c.Request.Context()

	query := `
		SELECT e.id, e.creator_id::text, e.title, e.description, e.category, e.location_name,
		       (ST_Y(e.location::geometry))::float8 AS latitude,
		       (ST_X(e.location::geometry))::float8 AS longitude,
		       e.start_time, e.end_time, e.max_participants, e.status, e.image_url, e.created_at,
		       ST_Distance(e.location, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography)::float8 AS distance_meters,
		       (SELECT COUNT(*) FROM event_participants ep WHERE ep.event_id = e.id)::int AS participants_count,
		       EXISTS(SELECT 1 FROM event_participants ep WHERE ep.event_id = e.id AND ep.user_id = $6)::bool AS is_joined,
		       COALESCE(e.visibility, 'public') AS visibility,
		       COALESCE(e.gender_filter, 'all') AS gender_filter,
		       COALESCE(e.min_age, 0)::int AS min_age,
		       COALESCE(e.max_age, 0)::int AS max_age
		FROM events e
		WHERE e.status = 'active'
		  AND ST_DWithin(e.location, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography, $3::float8)
		ORDER BY distance_meters ASC
		LIMIT $4 OFFSET $5;
	`

	rows, err := h.pool.Query(ctx, query, lon, lat, radius, limit, offset, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch events: " + err.Error()})
		return
	}
	defer rows.Close()

	var responseList []NearbyEventResponse = []NearbyEventResponse{}
	for rows.Next() {
		var item NearbyEventResponse
		err := rows.Scan(
			&item.ID,
			&item.CreatorID,
			&item.Title,
			&item.Description,
			&item.Category,
			&item.LocationName,
			&item.Latitude,
			&item.Longitude,
			&item.StartTime,
			&item.EndTime,
			&item.MaxParticipants,
			&item.Status,
			&item.ImageURL,
			&item.CreatedAt,
			&item.DistanceMeters,
			&item.ParticipantsCont,
			&item.IsJoined,
			&item.Visibility,
			&item.GenderFilter,
			&item.MinAge,
			&item.MaxAge,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan event row: " + err.Error()})
			return
		}
		responseList = append(responseList, item)
	}

	c.JSON(http.StatusOK, responseList)
}

// GetAIRecommendations matches nearby events based on structured LLM outputs (Rate Limited)
func (h *EventHandler) GetAIRecommendations(c *gin.Context) {
	ctx := c.Request.Context()
	if !h.isAIEnabled(ctx) {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "AI features are temporarily disabled"})
		return
	}

	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "q query parameter is required"})
		return
	}

	latStr := c.Query("latitude")
	lonStr := c.Query("longitude")
	radiusStr := c.DefaultQuery("radius_meters", "10000")

	if latStr == "" || lonStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "latitude and longitude queries are required"})
		return
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid latitude query"})
		return
	}

	lon, err := strconv.ParseFloat(lonStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid longitude query"})
		return
	}

	radius, err := strconv.ParseFloat(radiusStr, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid radius_meters query"})
		return
	}

	// Get candidate events (max 100) nearby to supply to AI
	rows, err := h.pool.Query(ctx, `
		SELECT id, creator_id::text, title, description, category, location_name,
		       (ST_Y(location::geometry))::float8 AS latitude,
		       (ST_X(location::geometry))::float8 AS longitude,
		       ST_Distance(location, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography)::float8 AS distance_meters
		FROM events
		WHERE status = 'active'
		  AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography, $3::float8)
		ORDER BY distance_meters ASC
		LIMIT 100
	`, lon, lat, radius)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve candidate events: " + err.Error()})
		return
	}
	defer rows.Close()

	var events []gin.H
	for rows.Next() {
		var item NearbyEventResponse
		if err := rows.Scan(&item.ID, &item.CreatorID, &item.Title, &item.Description, &item.Category, &item.LocationName, &item.Latitude, &item.Longitude, &item.DistanceMeters); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan candidate event: " + err.Error()})
			return
		}
		events = append(events, gin.H{
			"id":              item.ID,
			"creator_id":      item.CreatorID,
			"title":           item.Title,
			"description":     item.Description,
			"category":        item.Category,
			"location_name":   item.LocationName,
			"latitude":        item.Latitude,
			"longitude":       item.Longitude,
			"distance_meters": item.DistanceMeters,
		})
	}

	if len(events) == 0 {
		c.JSON(http.StatusOK, gin.H{
			"answer":               "Поблизости нет активных событий.",
			"recommended_card_ids": []int32{},
		})
		return
	}

	eventsJSONBytes, err := json.Marshal(events)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to serialize events list"})
		return
	}

	// Call structured AI recommendations service
	recommendation, err := h.aiService.GetRecommendations(ctx, query, string(eventsJSONBytes))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "AI recommendation error: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, recommendation)
}

// ParticipantResponse represents a participant profile details
type ParticipantResponse struct {
	ID                string     `json:"id"`
	Username          string     `json:"username"`
	FullName          string     `json:"full_name"`
	AvatarURL         string     `json:"avatar_url"`
	ParticipantStatus string     `json:"participant_status"`
	ArrivedAt         *time.Time `json:"arrived_at,omitempty"`
}

// JoinEvent adds the current user as a participant to the event
func (h *EventHandler) JoinEvent(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	ctx := c.Request.Context()

	// Start transaction
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	var maxParticipants int32
	var currentParticipants int32
	var status string
	err = tx.QueryRow(ctx, `
		SELECT max_participants, status, 
		       (SELECT COUNT(*) FROM event_participants WHERE event_id = id)::int
		FROM events
		WHERE id = $1
	`, eventID).Scan(&maxParticipants, &status, &currentParticipants)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
		return
	}

	if status != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Event is not active"})
		return
	}

	if currentParticipants >= maxParticipants {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Event is full"})
		return
	}

	res, err := tx.Exec(ctx, `
		INSERT INTO event_participants (event_id, user_id, participant_status)
		VALUES ($1, $2, 'going')
		ON CONFLICT (event_id, user_id) DO NOTHING
	`, eventID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to join event"})
		return
	}

	rowsAffected := res.RowsAffected()
	if rowsAffected > 0 {
		var eventTitle string
		var creatorID string
		err = tx.QueryRow(ctx, "SELECT title, creator_id::text FROM events WHERE id = $1", eventID).Scan(&eventTitle, &creatorID)
		if err == nil && creatorID != userID {
			var actorName string
			err = tx.QueryRow(ctx, "SELECT full_name FROM profiles WHERE user_id = $1", userID).Scan(&actorName)
			if err == nil {
				_, _ = tx.Exec(ctx, `
					INSERT INTO notifications (user_id, actor_id, event_id, notification_type, text)
					VALUES ($1, $2, $3, $4, $5)
				`, creatorID, userID, eventID, "join", fmt.Sprintf("%s присоединился к вашему событию %s", actorName, eventTitle))
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Successfully joined the event"})
}

// LeaveEvent removes the current user from the event participants list
func (h *EventHandler) LeaveEvent(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	ctx := c.Request.Context()

	// Start transaction so we delete and insert notifications atomically
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	var eventTitle string
	var creatorID string
	err = tx.QueryRow(ctx, "SELECT title, creator_id::text FROM events WHERE id = $1", eventID).Scan(&eventTitle, &creatorID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
		return
	}

	var actorName string
	err = tx.QueryRow(ctx, "SELECT full_name FROM profiles WHERE user_id = $1", userID).Scan(&actorName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch profile info"})
		return
	}

	res, err := tx.Exec(ctx, `
		DELETE FROM event_participants
		WHERE event_id = $1 AND user_id = $2
	`, eventID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to leave event"})
		return
	}

	rowsAffected := res.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "You are not a participant of this event"})
		return
	}

	// Insert notification if participant leaving is not the creator
	if creatorID != userID {
		_, _ = tx.Exec(ctx, `
			INSERT INTO notifications (user_id, actor_id, event_id, notification_type, text)
			VALUES ($1, $2, $3, $4, $5)
		`, creatorID, userID, eventID, "leave", fmt.Sprintf("%s покинул ваше событие %s", actorName, eventTitle))
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Successfully left the event"})
}

// UpdateParticipantStatus lets a participant quickly say if they are going, late, arrived, or cannot come.
func (h *EventHandler) UpdateParticipantStatus(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	var dto UpdateParticipantStatusDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Status is required"})
		return
	}

	status := normalizeParticipantStatus(dto.Status)
	if status == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Unsupported participant status"})
		return
	}
	if status == "arrived" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Use the arrival endpoint with GPS to mark arrival"})
		return
	}

	ctx := c.Request.Context()
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	var eventTitle string
	var creatorID string
	var eventStatus string
	err = tx.QueryRow(ctx, `
		SELECT title, creator_id::text, status
		FROM events
		WHERE id = $1
	`, eventID).Scan(&eventTitle, &creatorID, &eventStatus)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
		return
	}
	if eventStatus != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Event is not active"})
		return
	}

	var res pgconn.CommandTag
	if creatorID == userID {
		res, err = tx.Exec(ctx, `
			INSERT INTO event_participants (event_id, user_id, participant_status, arrived_at)
			VALUES ($1, $2, $3, CASE WHEN $3 = 'arrived' THEN NOW() ELSE NULL END)
			ON CONFLICT (event_id, user_id) DO UPDATE
			SET participant_status = EXCLUDED.participant_status,
			    arrived_at = CASE
			        WHEN EXCLUDED.participant_status = 'arrived' THEN COALESCE(event_participants.arrived_at, NOW())
			        WHEN EXCLUDED.participant_status = 'going' THEN NULL
			        ELSE event_participants.arrived_at
			    END
		`, eventID, userID, status)
	} else {
		res, err = tx.Exec(ctx, `
			UPDATE event_participants
			SET participant_status = $3,
			    arrived_at = CASE
			        WHEN $3 = 'arrived' THEN COALESCE(arrived_at, NOW())
			        WHEN $3 = 'going' THEN NULL
			        ELSE arrived_at
			    END
			WHERE event_id = $1 AND user_id = $2
		`, eventID, userID, status)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update participant status"})
		return
	}
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusForbidden, gin.H{"error": "Join the event before changing status"})
		return
	}

	var arrivedAt pgtype.Timestamptz
	_ = tx.QueryRow(ctx, `
		SELECT arrived_at
		FROM event_participants
		WHERE event_id = $1 AND user_id = $2
	`, eventID, userID).Scan(&arrivedAt)

	var arrivedAtValue *time.Time
	if arrivedAt.Valid {
		arrivedAtValue = &arrivedAt.Time
	}

	if creatorID != userID && (status == "late" || status == "not_going" || status == "arrived") {
		var actorName string
		err = tx.QueryRow(ctx, "SELECT full_name FROM profiles WHERE user_id = $1", userID).Scan(&actorName)
		if err == nil {
			text := fmt.Sprintf("%s: %s — %s", eventTitle, actorName, participantStatusLabel(status))
			_, _ = tx.Exec(ctx, `
				INSERT INTO notifications (user_id, actor_id, event_id, notification_type, text)
				VALUES ($1, $2, $3, $4, $5)
			`, creatorID, userID, eventID, "participant_status", text)
			if h.notificationService != nil {
				go h.notificationService.SendPush(creatorID, text)
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":            "Participant status updated",
		"participant_status": status,
		"arrived_at":         arrivedAtValue,
	})
}

// MarkArrived marks the current participant as arrived at the event location.
func (h *EventHandler) MarkArrived(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	var dto MarkArrivedDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Location is required to mark arrival"})
		return
	}
	if dto.Latitude == nil || dto.Longitude == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Location is required to mark arrival"})
		return
	}
	if *dto.Latitude < -90 || *dto.Latitude > 90 || *dto.Longitude < -180 || *dto.Longitude > 180 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid coordinates"})
		return
	}

	ctx := c.Request.Context()
	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	var eventTitle string
	var creatorID string
	var status string
	var distanceMeters float64
	err = tx.QueryRow(ctx, `
		SELECT title,
		       creator_id::text,
		       status,
		       ST_Distance(location, ST_SetSRID(ST_MakePoint($2::float8, $3::float8), 4326)::geography)::float8
		FROM events
		WHERE id = $1
	`, eventID, *dto.Longitude, *dto.Latitude).Scan(&eventTitle, &creatorID, &status, &distanceMeters)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
		return
	}
	if status != "active" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Event is not active"})
		return
	}
	if distanceMeters > 200 {
		c.JSON(http.StatusForbidden, gin.H{
			"error":           fmt.Sprintf("Вы слишком далеко от места встречи: %.0f м. Подойдите ближе, чтобы отметиться.", distanceMeters),
			"distance_meters": distanceMeters,
		})
		return
	}

	var res pgconn.CommandTag
	if creatorID == userID {
		res, err = tx.Exec(ctx, `
			INSERT INTO event_participants (event_id, user_id, arrived_at, participant_status)
			VALUES ($1, $2, NOW(), 'arrived')
			ON CONFLICT (event_id, user_id) DO UPDATE
			SET arrived_at = COALESCE(event_participants.arrived_at, NOW()),
			    participant_status = 'arrived'
		`, eventID, userID)
	} else {
		res, err = tx.Exec(ctx, `
			UPDATE event_participants
			SET arrived_at = COALESCE(arrived_at, NOW()),
			    participant_status = 'arrived'
			WHERE event_id = $1 AND user_id = $2
		`, eventID, userID)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark arrival"})
		return
	}
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusForbidden, gin.H{"error": "Join the event before marking arrival"})
		return
	}

	var arrivedAt time.Time
	_ = tx.QueryRow(ctx, `
		SELECT arrived_at
		FROM event_participants
		WHERE event_id = $1 AND user_id = $2
	`, eventID, userID).Scan(&arrivedAt)

	if creatorID != userID {
		var actorName string
		err = tx.QueryRow(ctx, "SELECT full_name FROM profiles WHERE user_id = $1", userID).Scan(&actorName)
		if err == nil {
			text := fmt.Sprintf("%s уже на месте: %s", actorName, eventTitle)
			_, _ = tx.Exec(ctx, `
				INSERT INTO notifications (user_id, actor_id, event_id, notification_type, text)
				VALUES ($1, $2, $3, $4, $5)
			`, creatorID, userID, eventID, "arrival", text)
			if h.notificationService != nil {
				h.notificationService.SendPush(creatorID, text)
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":         "Arrival marked",
		"arrived_at":      arrivedAt,
		"distance_meters": distanceMeters,
	})
}

// GetEventParticipants lists all users participating in the event
func (h *EventHandler) GetEventParticipants(c *gin.Context) {
	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	ctx := c.Request.Context()

	rows, err := h.pool.Query(ctx, `
		SELECT p.user_id::text,
		       p.username,
		       p.full_name,
		       COALESCE(p.avatar_url, '') AS avatar_url,
		       COALESCE(ep.participant_status, 'going') AS participant_status,
		       ep.arrived_at
		FROM event_participants ep
		JOIN profiles p ON p.user_id = ep.user_id
		WHERE ep.event_id = $1
		ORDER BY
			CASE COALESCE(ep.participant_status, 'going')
				WHEN 'arrived' THEN 1
				WHEN 'going' THEN 2
				WHEN 'late' THEN 3
				WHEN 'not_going' THEN 4
				ELSE 5
			END,
			ep.joined_at ASC
	`, eventID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch participants: " + err.Error()})
		return
	}
	defer rows.Close()

	var participants []ParticipantResponse = []ParticipantResponse{}
	for rows.Next() {
		var p ParticipantResponse
		var arrivedAt pgtype.Timestamptz
		err := rows.Scan(&p.ID, &p.Username, &p.FullName, &p.AvatarURL, &p.ParticipantStatus, &arrivedAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan participant row: " + err.Error()})
			return
		}
		if arrivedAt.Valid {
			p.ArrivedAt = &arrivedAt.Time
		}
		participants = append(participants, p)
	}

	c.JSON(http.StatusOK, participants)
}

type UpdateLiveLocationDTO struct {
	Latitude  float64  `json:"latitude"`
	Longitude float64  `json:"longitude"`
	Accuracy  *float64 `json:"accuracy"`
}

type EventLiveLocationResponse struct {
	UserID    string    `json:"user_id"`
	Username  string    `json:"username"`
	FullName  string    `json:"full_name"`
	AvatarURL string    `json:"avatar_url"`
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	Accuracy  *float64  `json:"accuracy"`
	UpdatedAt time.Time `json:"updated_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

func (h *EventHandler) canUseEventLiveLocation(ctx context.Context, eventID int, userID string) (bool, error) {
	var allowed bool
	err := h.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1
			FROM events e
			WHERE e.id = $1
			  AND e.status = 'active'
			  AND NOW() BETWEEN e.start_time - INTERVAL '1 hour' AND e.end_time + INTERVAL '15 minutes'
			  AND (
				e.creator_id = $2::uuid
				OR EXISTS (
					SELECT 1
					FROM event_participants ep
					WHERE ep.event_id = e.id AND ep.user_id = $2::uuid
				)
			  )
		)
	`, eventID, userID).Scan(&allowed)
	return allowed, err
}

// UpdateEventLiveLocation shares the current user's temporary location for one event.
func (h *EventHandler) UpdateEventLiveLocation(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	eventID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	var dto UpdateLiveLocationDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if dto.Latitude < -90 || dto.Latitude > 90 || dto.Longitude < -180 || dto.Longitude > 180 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid coordinates"})
		return
	}

	ctx := c.Request.Context()
	allowed, err := h.canUseEventLiveLocation(ctx, eventID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check event access"})
		return
	}
	if !allowed {
		c.JSON(http.StatusForbidden, gin.H{"error": "Live location is available only to participants during active events"})
		return
	}

	var expiresAt time.Time
	err = h.pool.QueryRow(ctx, `
		INSERT INTO event_live_locations (event_id, user_id, latitude, longitude, accuracy, updated_at, expires_at)
		VALUES ($1, $2, $3, $4, $5, NOW(), NOW() + INTERVAL '5 minutes')
		ON CONFLICT (event_id, user_id) DO UPDATE
		SET latitude = EXCLUDED.latitude,
		    longitude = EXCLUDED.longitude,
		    accuracy = EXCLUDED.accuracy,
		    updated_at = NOW(),
		    expires_at = NOW() + INTERVAL '5 minutes'
		RETURNING expires_at
	`, eventID, userID, dto.Latitude, dto.Longitude, dto.Accuracy).Scan(&expiresAt)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update live location"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":    "Live location updated",
		"expires_at": expiresAt,
	})
}

// GetEventLiveLocations returns non-expired live locations for event participants.
func (h *EventHandler) GetEventLiveLocations(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	eventID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	ctx := c.Request.Context()
	allowed, err := h.canUseEventLiveLocation(ctx, eventID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check event access"})
		return
	}
	if !allowed {
		c.JSON(http.StatusForbidden, gin.H{"error": "Live location is available only to participants during active events"})
		return
	}

	_, _ = h.pool.Exec(ctx, "DELETE FROM event_live_locations WHERE expires_at < NOW()")

	rows, err := h.pool.Query(ctx, `
		SELECT l.user_id::text,
		       p.username,
		       p.full_name,
		       COALESCE(p.avatar_url, '') AS avatar_url,
		       l.latitude,
		       l.longitude,
		       l.accuracy,
		       l.updated_at,
		       l.expires_at
		FROM event_live_locations l
		JOIN profiles p ON p.user_id = l.user_id
		WHERE l.event_id = $1
		  AND l.expires_at > NOW()
		ORDER BY l.updated_at DESC
	`, eventID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch live locations"})
		return
	}
	defer rows.Close()

	locations := []EventLiveLocationResponse{}
	for rows.Next() {
		var loc EventLiveLocationResponse
		if err := rows.Scan(
			&loc.UserID,
			&loc.Username,
			&loc.FullName,
			&loc.AvatarURL,
			&loc.Latitude,
			&loc.Longitude,
			&loc.Accuracy,
			&loc.UpdatedAt,
			&loc.ExpiresAt,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan live location"})
			return
		}
		locations = append(locations, loc)
	}

	c.JSON(http.StatusOK, locations)
}

// DeleteEventLiveLocation stops sharing the current user's live location for an event.
func (h *EventHandler) DeleteEventLiveLocation(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	eventID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	_, err = h.pool.Exec(c.Request.Context(), `
		DELETE FROM event_live_locations
		WHERE event_id = $1 AND user_id = $2
	`, eventID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to stop live location"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Live location stopped"})
}

type AIChatRequest struct {
	Message string                  `json:"message" binding:"required"`
	History []service.AIChatMessage `json:"history"`
}

type AIChatResponse struct {
	Reply string `json:"reply"`
}

// ChatWithAI generates conversational replies using the configured AI provider.
func (h *EventHandler) ChatWithAI(c *gin.Context) {
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	ctx := c.Request.Context()
	if !h.isAIEnabled(ctx) {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "AI features are temporarily disabled"})
		return
	}

	var dto AIChatRequest
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	reply, err := h.aiService.Chat(ctx, dto.Message, dto.History)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "AI error: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, AIChatResponse{Reply: reply})
}

type ChatSessionResponse struct {
	ID                int32     `json:"id"`
	Title             string    `json:"title"`
	Category          string    `json:"category"`
	LastMessage       string    `json:"last_message"`
	LastMessageSender string    `json:"last_message_sender"`
	LastMessageTime   time.Time `json:"last_message_time"`
	IsCompleted       bool      `json:"is_completed"`
}

type EventMessageResponse struct {
	ID              int32     `json:"id"`
	EventID         int32     `json:"event_id"`
	SenderID        string    `json:"sender_id"`
	SenderName      string    `json:"sender_name"`
	SenderUsername  string    `json:"sender_username"`
	SenderAvatarURL string    `json:"sender_avatar_url"`
	Text            string    `json:"text"`
	CreatedAt       time.Time `json:"created_at"`
}

type SendMessageDTO struct {
	Text string `json:"text" binding:"required"`
}

type NotificationResponse struct {
	ID               int32     `json:"id"`
	UserID           string    `json:"user_id"`
	ActorID          *string   `json:"actor_id"`
	ActorName        string    `json:"actor_name"`
	ActorAvatarURL   string    `json:"actor_avatar_url"`
	EventID          int32     `json:"event_id"`
	EventTitle       string    `json:"event_title"`
	NotificationType string    `json:"notification_type"`
	Text             string    `json:"text"`
	IsRead           bool      `json:"is_read"`
	CreatedAt        time.Time `json:"created_at"`
}

// GetChatSessions returns events the user created or joined, with the last message of each.
func (h *EventHandler) GetChatSessions(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)
	ctx := c.Request.Context()

	// Query events and lateral join the last message
	rows, err := h.pool.Query(ctx, `
		SELECT 
			e.id, 
			e.title, 
			e.category, 
			COALESCE(m.text, 'Будьте первыми! Напишите в чат') AS last_message,
			COALESCE(p.full_name, '') AS last_message_sender,
			COALESCE(m.created_at, e.created_at) AS last_message_time,
			(e.end_time < CURRENT_TIMESTAMP) AS is_completed
		FROM events e
		LEFT JOIN LATERAL (
			SELECT em.text, em.created_at, em.sender_id
			FROM event_messages em
			WHERE em.event_id = e.id
			ORDER BY em.created_at DESC
			LIMIT 1
		) m ON true
		LEFT JOIN profiles p ON p.user_id = m.sender_id
		WHERE e.creator_id = $1 
		   OR EXISTS (
			   SELECT 1 
			   FROM event_participants ep 
			   WHERE ep.event_id = e.id AND ep.user_id = $1
		   )
		ORDER BY last_message_time DESC;
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch chat sessions: " + err.Error()})
		return
	}
	defer rows.Close()

	sessions := []ChatSessionResponse{}
	for rows.Next() {
		var s ChatSessionResponse
		var lastMessageTime pgtype.Timestamptz
		err := rows.Scan(&s.ID, &s.Title, &s.Category, &s.LastMessage, &s.LastMessageSender, &lastMessageTime, &s.IsCompleted)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan chat session: " + err.Error()})
			return
		}
		s.LastMessageTime = lastMessageTime.Time
		sessions = append(sessions, s)
	}

	c.JSON(http.StatusOK, sessions)
}

// GetEventMessages retrieves the chat message history for an event (restricted to participants/creator).
func (h *EventHandler) GetEventMessages(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	ctx := c.Request.Context()

	// 1. Check if the user is the creator or a participant
	var isMember bool
	err = h.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM events WHERE id = $1 AND creator_id = $2
			UNION ALL
			SELECT 1 FROM event_participants WHERE event_id = $1 AND user_id = $2
		)
	`, eventID, userID).Scan(&isMember)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error checking membership: " + err.Error()})
		return
	}

	if !isMember {
		c.JSON(http.StatusForbidden, gin.H{"error": "Вы не являетесь участником этого события"})
		return
	}

	// 2. Fetch messages in chronological order
	rows, err := h.pool.Query(ctx, `
		SELECT 
			em.id, 
			em.event_id, 
			COALESCE(em.sender_id::text, ''), 
			COALESCE(p.full_name, 'Жорик (ИИ)') AS sender_name, 
			COALESCE(p.username, 'ai_helper') AS sender_username, 
			COALESCE(p.avatar_url, '') AS sender_avatar_url, 
			em.text, 
			em.created_at
		FROM event_messages em
		LEFT JOIN profiles p ON p.user_id = em.sender_id
		WHERE em.event_id = $1
		ORDER BY em.created_at ASC;
	`, eventID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch event messages: " + err.Error()})
		return
	}
	defer rows.Close()

	messages := []EventMessageResponse{}
	for rows.Next() {
		var m EventMessageResponse
		var createdAt pgtype.Timestamptz
		err := rows.Scan(&m.ID, &m.EventID, &m.SenderID, &m.SenderName, &m.SenderUsername, &m.SenderAvatarURL, &m.Text, &createdAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan event message: " + err.Error()})
			return
		}
		m.CreatedAt = createdAt.Time
		messages = append(messages, m)
	}

	c.JSON(http.StatusOK, messages)
}

// SendEventMessage appends a new message to the event chat (restricted to participants/creator).
func (h *EventHandler) SendEventMessage(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	var dto SendMessageDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// 1. Check if the user is the creator or a participant
	var isMember bool
	err = h.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM events WHERE id = $1 AND creator_id = $2
			UNION ALL
			SELECT 1 FROM event_participants WHERE event_id = $1 AND user_id = $2
		)
	`, eventID, userID).Scan(&isMember)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error checking membership: " + err.Error()})
		return
	}

	if !isMember {
		c.JSON(http.StatusForbidden, gin.H{"error": "Вы не являетесь участником этого события"})
		return
	}

	// 2. Insert the message
	var msgID int32
	var createdAt pgtype.Timestamptz
	err = h.pool.QueryRow(ctx, `
		INSERT INTO event_messages (event_id, sender_id, text)
		VALUES ($1, $2, $3)
		RETURNING id, created_at;
	`, eventID, userID, dto.Text).Scan(&msgID, &createdAt)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send message: " + err.Error()})
		return
	}

	// 3. Get sender profile info for the response
	var senderName, senderUsername, senderAvatarURL string
	err = h.pool.QueryRow(ctx, `
		SELECT full_name, username, COALESCE(avatar_url, '')
		FROM profiles
		WHERE user_id = $1;
	`, userID).Scan(&senderName, &senderUsername, &senderAvatarURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch sender profile: " + err.Error()})
		return
	}

	response := EventMessageResponse{
		ID:              msgID,
		EventID:         int32(eventID),
		SenderID:        userID,
		SenderName:      senderName,
		SenderUsername:  senderUsername,
		SenderAvatarURL: senderAvatarURL,
		Text:            dto.Text,
		CreatedAt:       createdAt.Time,
	}

	// Broadcast user message to all websocket clients
	h.ChatHub.BroadcastMessage(int32(eventID), response)

	// Asynchronously trigger AI helper if message mentions Жорик.
	if prompt, isAIRequest := extractEventAIPrompt(dto.Text); isAIRequest && h.isAIEnabled(ctx) {
		if prompt != "" {
			go func(eID int32, requesterID string, userPrompt string) {
				// 1. Fetch event context
				var eventCtx service.EventChatContext
				ctx := context.Background()
				err := h.pool.QueryRow(ctx, `
					SELECT e.title,
					       e.description,
					       e.category,
					       e.location_name,
					       e.start_time,
					       e.end_time,
					       e.max_participants,
					       (SELECT COUNT(*) FROM event_participants ep WHERE ep.event_id = e.id)::int,
					       COALESCE(e.gender_filter, 'all'),
					       COALESCE(e.min_age, 0),
					       COALESCE(e.max_age, 0),
					       COALESCE(ep.participant_status, CASE WHEN e.creator_id = $2 THEN 'going' ELSE '' END)
					FROM events e
					LEFT JOIN event_participants ep ON ep.event_id = e.id AND ep.user_id = $2
					WHERE e.id = $1
				`, eID, requesterID).Scan(
					&eventCtx.Title,
					&eventCtx.Description,
					&eventCtx.Category,
					&eventCtx.LocationName,
					&eventCtx.StartTime,
					&eventCtx.EndTime,
					&eventCtx.MaxParticipants,
					&eventCtx.ParticipantsCount,
					&eventCtx.GenderFilter,
					&eventCtx.MinAge,
					&eventCtx.MaxAge,
					&eventCtx.ParticipantStatus,
				)
				if err != nil {
					log.Printf("[Event AI] Failed to query event context for ID %d: %v", eID, err)
					return
				}

				rows, err := h.pool.Query(ctx, `
					SELECT CASE WHEN sender_id IS NULL THEN 'assistant' ELSE 'user' END AS role,
					       text
					FROM event_messages
					WHERE event_id = $1
					ORDER BY created_at DESC
					LIMIT 8
				`, eID)
				if err == nil {
					defer rows.Close()
					reversed := []service.AIChatMessage{}
					for rows.Next() {
						var msg service.AIChatMessage
						if scanErr := rows.Scan(&msg.Role, &msg.Text); scanErr == nil {
							reversed = append(reversed, msg)
						}
					}
					for i := len(reversed) - 1; i >= 0; i-- {
						eventCtx.RecentMessages = append(eventCtx.RecentMessages, reversed[i])
					}
				} else {
					log.Printf("[Event AI] Failed to query recent chat context for ID %d: %v", eID, err)
				}

				// 2. Call AI provider
				reply, err := h.aiService.EventChatHelper(ctx, eventCtx, userPrompt)
				if err != nil {
					log.Printf("[Event AI] AI request failed: %v", err)
					reply = "Извините, не удалось связаться с Жориком. Пожалуйста, повторите запрос позже."
				}

				// 3. Save AI reply in database (NULL sender_id represents the system AI user)
				var aiMsgID int32
				var aiCreatedAt pgtype.Timestamptz
				err = h.pool.QueryRow(ctx, `
					INSERT INTO event_messages (event_id, sender_id, text)
					VALUES ($1, NULL, $2)
					RETURNING id, created_at
				`, eID, reply).Scan(&aiMsgID, &aiCreatedAt)
				if err != nil {
					log.Printf("[Event AI] Failed to save AI response: %v", err)
					return
				}

				// Broadcast AI message via WebSockets
				aiResponse := EventMessageResponse{
					ID:              aiMsgID,
					EventID:         eID,
					SenderID:        "",
					SenderName:      "Жорик (ИИ)",
					SenderUsername:  "ai_helper",
					SenderAvatarURL: "",
					Text:            reply,
					CreatedAt:       aiCreatedAt.Time,
				}
				h.ChatHub.BroadcastMessage(eID, aiResponse)
			}(int32(eventID), userID, prompt)
		}
	}

	c.JSON(http.StatusCreated, response)
}

// GetNotifications returns notifications list for the authenticated user.
func (h *EventHandler) GetNotifications(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)
	ctx := c.Request.Context()

	rows, err := h.pool.Query(ctx, `
		SELECT 
			n.id, 
			n.user_id::text, 
			n.actor_id::text AS actor_id, 
			COALESCE(p.full_name, '') AS actor_name, 
			COALESCE(p.avatar_url, '') AS actor_avatar_url, 
			COALESCE(n.event_id, 0) AS event_id, 
			COALESCE(e.title, '') AS event_title, 
			n.notification_type, 
			n.text, 
			n.is_read, 
			n.created_at
		FROM notifications n
		LEFT JOIN profiles p ON p.user_id = n.actor_id
		LEFT JOIN events e ON e.id = n.event_id
		WHERE n.user_id = $1
		ORDER BY n.created_at DESC;
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch notifications: " + err.Error()})
		return
	}
	defer rows.Close()

	notifications := []NotificationResponse{}
	for rows.Next() {
		var n NotificationResponse
		var createdAt pgtype.Timestamptz
		err := rows.Scan(
			&n.ID,
			&n.UserID,
			&n.ActorID,
			&n.ActorName,
			&n.ActorAvatarURL,
			&n.EventID,
			&n.EventTitle,
			&n.NotificationType,
			&n.Text,
			&n.IsRead,
			&createdAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan notification: " + err.Error()})
			return
		}
		n.CreatedAt = createdAt.Time
		notifications = append(notifications, n)
	}

	c.JSON(http.StatusOK, notifications)
}

// MarkNotificationsRead marks all notifications for the authenticated user as read.
func (h *EventHandler) MarkNotificationsRead(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)
	ctx := c.Request.Context()

	_, err := h.pool.Exec(ctx, `
		UPDATE notifications
		SET is_read = TRUE
		WHERE user_id = $1
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark notifications as read: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notifications marked as read"})
}
