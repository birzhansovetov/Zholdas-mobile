package handler_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gorilla/websocket"

	"github.com/birzhansovetov/zholdas-backend/internal/database"
	"github.com/birzhansovetov/zholdas-backend/internal/handler"
	"github.com/birzhansovetov/zholdas-backend/internal/middleware"
	"github.com/birzhansovetov/zholdas-backend/internal/service"
)

const testDBURL = "postgres://birzhansovetov@localhost:5432/zholdas?sslmode=disable"
const testJWTSecret = "test_jwt_secret_key_12345"

func setupTestDB(t *testing.T) *pgxpool.Pool {
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, testDBURL)
	if err != nil {
		t.Fatalf("Failed to connect to test DB: %v", err)
	}

	// Run migrations (pointing to db/migrations sibling folder)
	err = runTestMigrations(ctx, pool)
	if err != nil {
		t.Fatalf("Failed to run migrations: %v", err)
	}

	// Truncate tables to ensure fresh tests
	_, err = pool.Exec(ctx, "TRUNCATE TABLE user_sessions, events, profiles, users CASCADE;")
	if err != nil {
		t.Fatalf("Failed to truncate tables: %v", err)
	}

	return pool
}

func runTestMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	_, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version INT PRIMARY KEY,
			applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		);
	`)
	if err != nil {
		return err
	}

	// Go up one level to look for db/migrations since test runs inside internal/handler
	migrationsDir := "../../db/migrations"
	files, err := os.ReadDir(migrationsDir)
	if err != nil {
		return err
	}

	var sqlFiles []string
	for _, f := range files {
		if !f.IsDir() && strings.HasSuffix(f.Name(), ".up.sql") {
			sqlFiles = append(sqlFiles, f.Name())
		}
	}
	sort.Strings(sqlFiles)

	for _, fileName := range sqlFiles {
		parts := strings.Split(fileName, "_")
		if len(parts) < 2 {
			continue
		}
		version, err := strconv.Atoi(parts[0])
		if err != nil {
			continue
		}

		var exists bool
		err = pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version=$1)", version).Scan(&exists)
		if err != nil {
			return err
		}

		if exists {
			continue
		}

		filePath := filepath.Join(migrationsDir, fileName)
		content, err := os.ReadFile(filePath)
		if err != nil {
			return err
		}

		tx, err := pool.Begin(ctx)
		if err != nil {
			return err
		}

		_, err = tx.Exec(ctx, string(content))
		if err != nil {
			tx.Rollback(ctx)
			return err
		}

		_, err = tx.Exec(ctx, "INSERT INTO schema_migrations (version) VALUES ($1)", version)
		if err != nil {
			tx.Rollback(ctx)
			return err
		}

		err = tx.Commit(ctx)
		if err != nil {
			return err
		}
	}
	return nil
}

func TestE2EFlow(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	aiService := service.NewAIService("") // uses mock moderation
	notificationService := service.NewNotificationService()

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)
	eventHandler := handler.NewEventHandler(pool, aiService, notificationService)

	// Build Router
	r := gin.Default()

	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)
	r.POST("/auth/refresh", authHandler.RefreshToken)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.POST("/auth/logout", authHandler.LogOut)
		protected.POST("/events", eventHandler.CreateEvent)
		protected.GET("/events/nearby", eventHandler.GetNearbyEvents)

		aiRecLimiter := middleware.NewAIRateLimiter()
		protected.GET("/events/recommendations", middleware.RateLimitMiddleware(aiRecLimiter), eventHandler.GetAIRecommendations)
		aiChatLimiter := middleware.NewAIRateLimiter()
		protected.POST("/ai/chat", middleware.RateLimitMiddleware(aiChatLimiter), eventHandler.ChatWithAI)
	}

	// 1. Sign Up User
	signUpBody := `{"email":"user@zholdas.kz","password":"password123","username":"user1","full_name":"Zholdas User"}`
	req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signUpBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("Expected 201 Created for signup, got: %d, body: %s", w.Code, w.Body.String())
	}

	// 2. Sign In
	signInBody := `{"email":"user@zholdas.kz","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signInBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for signin, got: %d", w.Code)
	}

	var tokenRes handler.TokenResponse
	if err := json.Unmarshal(w.Body.Bytes(), &tokenRes); err != nil {
		t.Fatalf("Failed to parse token response: %v", err)
	}

	if tokenRes.AccessToken == "" || tokenRes.RefreshToken == "" {
		t.Fatalf("Expected non-empty tokens")
	}

	// 3. Token Refresh Rotation
	refreshBody := map[string]string{"refresh_token": tokenRes.RefreshToken}
	refreshJSON, _ := json.Marshal(refreshBody)
	req, _ = http.NewRequest("POST", "/auth/refresh", bytes.NewReader(refreshJSON))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for refresh, got: %d", w.Code)
	}

	var rotatedTokens handler.TokenResponse
	if err := json.Unmarshal(w.Body.Bytes(), &rotatedTokens); err != nil {
		t.Fatalf("Failed to parse rotated tokens: %v", err)
	}

	// Verify old refresh token is deleted (trying to refresh with old one should fail)
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("POST", "/auth/refresh", bytes.NewReader(refreshJSON))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("Expected 401 Unauthorized for used refresh token, got: %d", w.Code)
	}

	// 4. Create Event (Active)
	startTime := time.Now().Add(1 * time.Hour).Format(time.RFC3339)
	endTime := time.Now().Add(2 * time.Hour).Format(time.RFC3339)
	eventBody := `{
		"title": "Football Match",
		"description": "Weekly friendly match in Almaty",
		"category": "sports",
		"location_name": "Almaty Stadium",
		"longitude": 76.9286,
		"latitude": 43.2389,
		"start_time": "` + startTime + `",
		"end_time": "` + endTime + `",
		"max_participants": 12
	}`

	req, _ = http.NewRequest("POST", "/events", bytes.NewBufferString(eventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+rotatedTokens.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("Expected 201 Created for event creation, got: %d, body: %s", w.Code, w.Body.String())
	}

	// 5. Create Event (Unsafe -> will trigger async moderation block)
	unsafeEventBody := `{
		"title": "Illegal Drugs Gathering",
		"description": "Unlawful activity containing word bomb",
		"category": "misc",
		"location_name": "Dark Alley",
		"longitude": 76.9200,
		"latitude": 43.2300,
		"start_time": "` + startTime + `",
		"end_time": "` + endTime + `",
		"max_participants": 50
	}`

	req, _ = http.NewRequest("POST", "/events", bytes.NewBufferString(unsafeEventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+rotatedTokens.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("Expected 201 Created for unsafe event, got: %d", w.Code)
	}

	// Wait briefly for goroutine moderation to execute and update the status in DB
	time.Sleep(150 * time.Millisecond)

	// 6. Test Spatial GetNearbyEvents
	// Location matches Almaty (Football Match)
	q := url.Values{}
	q.Set("latitude", "43.2389")
	q.Set("longitude", "76.9286")
	q.Set("radius_meters", "1000") // 1km radius

	req, _ = http.NewRequest("GET", "/events/nearby?"+q.Encode(), nil)
	req.Header.Set("Authorization", "Bearer "+rotatedTokens.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for nearby events, got: %d, body: %s", w.Code, w.Body.String())
	}

	var eventsList []database.GetNearbyEventsRow
	if err := json.Unmarshal(w.Body.Bytes(), &eventsList); err != nil {
		t.Fatalf("Failed to parse events list: %v", err)
	}

	// It should find 1 event ("Football Match")
	// The unsafe event ("Illegal Drugs Gathering") must be blocked and filtered out!
	if len(eventsList) != 1 {
		t.Errorf("Expected 1 nearby event (Football Match), got: %d. Unsafe events should be blocked and excluded.", len(eventsList))
	} else if eventsList[0].Title != "Football Match" {
		t.Errorf("Expected Football Match event, got: %s", eventsList[0].Title)
	}

	// 7. Verify AI Recommendation Rate Limiting
	// Let's call recommendations endpoint 4 times in a row
	recQ := url.Values{}
	recQ.Set("q", "Рекомендуй мне спорт")
	recQ.Set("latitude", "43.2389")
	recQ.Set("longitude", "76.9286")

	for i := 1; i <= 4; i++ {
		req, _ = http.NewRequest("GET", "/events/recommendations?"+recQ.Encode(), nil)
		req.Header.Set("Authorization", "Bearer "+rotatedTokens.AccessToken)
		w = httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if i <= 3 {
			if w.Code != http.StatusOK {
				t.Fatalf("Expected 200 OK on call %d of rate limiter, got: %d, body: %s", i, w.Code, w.Body.String())
			}
		} else {
			// 4th call exceeds burst = 3 limit
			if w.Code != http.StatusTooManyRequests {
				t.Fatalf("Expected 429 Too Many Requests on 4th call, got: %d, body: %s", w.Code, w.Body.String())
			}
		}
	}

	// 7.5. Verify AI Chat Assistant Endpoint (Mock mode)
	chatBody := `{"message":"Привет! Какая погода на Шымбулаке?","history":[{"role":"user","text":"Привет"},{"role":"model","text":"Здравствуйте!"}]}`
	req, _ = http.NewRequest("POST", "/ai/chat", bytes.NewBufferString(chatBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+rotatedTokens.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for AI chat request, got: %d, body: %s", w.Code, w.Body.String())
	}

	var chatRes handler.AIChatResponse
	if err := json.Unmarshal(w.Body.Bytes(), &chatRes); err != nil {
		t.Fatalf("Failed to parse AI chat response: %v", err)
	}
	if !strings.Contains(chatRes.Reply, "Жорик") && !strings.Contains(chatRes.Reply, "демонстрационном") {
		t.Fatalf("Expected mock AI chat reply containing Жорик, got: %s", chatRes.Reply)
	}

	// 8. Log Out
	req, _ = http.NewRequest("POST", "/auth/logout", nil)
	req.Header.Set("Authorization", "Bearer "+rotatedTokens.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for logout, got: %d", w.Code)
	}

	// Refresh token should no longer work
	refreshBody = map[string]string{"refresh_token": rotatedTokens.RefreshToken}
	refreshJSON, _ = json.Marshal(refreshBody)
	req, _ = http.NewRequest("POST", "/auth/refresh", bytes.NewReader(refreshJSON))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("Expected 401 Unauthorized after logging out, got: %d", w.Code)
	}
}

func TestEventChats(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	aiService := service.NewAIService("")
	notificationService := service.NewNotificationService()

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)
	eventHandler := handler.NewEventHandler(pool, aiService, notificationService)

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.POST("/events", eventHandler.CreateEvent)
		protected.POST("/events/:id/join", eventHandler.JoinEvent)
		protected.GET("/chats", eventHandler.GetChatSessions)
		protected.GET("/events/:id/messages", eventHandler.GetEventMessages)
		protected.POST("/events/:id/messages", eventHandler.SendEventMessage)
	}

	// 1. Sign Up 3 Users
	users := []struct {
		Email    string
		Password string
		Username string
		FullName string
	}{
		{"creator@zholdas.kz", "password123", "creator", "Event Creator"},
		{"participant@zholdas.kz", "password123", "participant", "Event Participant"},
		{"outsider@zholdas.kz", "password123", "outsider", "Event Outsider"},
	}

	tokens := make([]string, len(users))

	for i, u := range users {
		signUpBody, _ := json.Marshal(map[string]string{
			"email":     u.Email,
			"password":  u.Password,
			"username":  u.Username,
			"full_name": u.FullName,
		})
		req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBuffer(signUpBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code != http.StatusCreated {
			t.Fatalf("Failed to sign up user %s: %d", u.Username, w.Code)
		}

		signInBody, _ := json.Marshal(map[string]string{
			"email":    u.Email,
			"password": u.Password,
		})
		req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBuffer(signInBody))
		req.Header.Set("Content-Type", "application/json")
		w = httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Fatalf("Failed to sign in user %s: %d", u.Username, w.Code)
		}

		var tokenRes handler.TokenResponse
		_ = json.Unmarshal(w.Body.Bytes(), &tokenRes)
		tokens[i] = tokenRes.AccessToken
	}

	creatorToken := tokens[0]
	participantToken := tokens[1]
	outsiderToken := tokens[2]

	// 2. Creator creates event
	startTime := time.Now().Add(1 * time.Hour).Format(time.RFC3339)
	endTime := time.Now().Add(2 * time.Hour).Format(time.RFC3339)
	eventBody := `{
		"title": "Board Games Night",
		"description": "Playing Catan in Almaty",
		"category": "boardgames",
		"location_name": "Game Club",
		"longitude": 76.9286,
		"latitude": 43.2389,
		"start_time": "` + startTime + `",
		"end_time": "` + endTime + `",
		"max_participants": 5
	}`
	req, _ := http.NewRequest("POST", "/events", bytes.NewBufferString(eventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+creatorToken)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to create event: %d, body: %s", w.Code, w.Body.String())
	}

	var eventObj struct {
		ID int32 `json:"id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &eventObj)
	eventIDStr := strconv.Itoa(int(eventObj.ID))

	// 3. Outsider tries to access event messages (should get 403)
	req, _ = http.NewRequest("GET", "/events/"+eventIDStr+"/messages", nil)
	req.Header.Set("Authorization", "Bearer "+outsiderToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusForbidden {
		t.Errorf("Expected 403 Forbidden for outsider GET messages, got: %d", w.Code)
	}

	// 4. Outsider tries to send event message (should get 403)
	msgBody, _ := json.Marshal(map[string]string{"text": "Spam message"})
	req, _ = http.NewRequest("POST", "/events/"+eventIDStr+"/messages", bytes.NewBuffer(msgBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+outsiderToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusForbidden {
		t.Errorf("Expected 403 Forbidden for outsider POST message, got: %d", w.Code)
	}

	// 5. Participant joins event
	req, _ = http.NewRequest("POST", "/events/"+eventIDStr+"/join", nil)
	req.Header.Set("Authorization", "Bearer "+participantToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to join event: %d", w.Code)
	}

	// 6. Participant sends message
	msgText := "Hello, when does it start?"
	msgBody, _ = json.Marshal(map[string]string{"text": msgText})
	req, _ = http.NewRequest("POST", "/events/"+eventIDStr+"/messages", bytes.NewBuffer(msgBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+participantToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Expected 201 Created for message sending, got: %d, body: %s", w.Code, w.Body.String())
	}

	var sendRes handler.EventMessageResponse
	_ = json.Unmarshal(w.Body.Bytes(), &sendRes)
	if sendRes.Text != msgText {
		t.Errorf("Expected sent message text %q, got %q", msgText, sendRes.Text)
	}

	// 7. Creator gets messages list
	req, _ = http.NewRequest("GET", "/events/"+eventIDStr+"/messages", nil)
	req.Header.Set("Authorization", "Bearer "+creatorToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for creator GET messages, got: %d", w.Code)
	}

	var messagesList []handler.EventMessageResponse
	_ = json.Unmarshal(w.Body.Bytes(), &messagesList)
	if len(messagesList) != 1 {
		t.Errorf("Expected 1 message, got: %d", len(messagesList))
	} else {
		if messagesList[0].Text != msgText {
			t.Errorf("Expected message text %q, got %q", msgText, messagesList[0].Text)
		}
		if messagesList[0].SenderUsername != "participant" {
			t.Errorf("Expected sender username 'participant', got %q", messagesList[0].SenderUsername)
		}
	}

	// 8. Creator sends reply message
	replyText := "Hi! Starting at 7 PM."
	replyBody, _ := json.Marshal(map[string]string{"text": replyText})
	req, _ = http.NewRequest("POST", "/events/"+eventIDStr+"/messages", bytes.NewBuffer(replyBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+creatorToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Expected 201 Created for reply, got: %d", w.Code)
	}

	// 9. Participant retrieves both messages
	req, _ = http.NewRequest("GET", "/events/"+eventIDStr+"/messages", nil)
	req.Header.Set("Authorization", "Bearer "+participantToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for participant GET messages, got: %d", w.Code)
	}
	_ = json.Unmarshal(w.Body.Bytes(), &messagesList)
	if len(messagesList) != 2 {
		t.Errorf("Expected 2 messages, got: %d", len(messagesList))
	}

	// 10. Check GetChatSessions for Creator (chats list)
	req, _ = http.NewRequest("GET", "/chats", nil)
	req.Header.Set("Authorization", "Bearer "+creatorToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK for creator GET chats, got: %d", w.Code)
	}

	var chatSessions []handler.ChatSessionResponse
	_ = json.Unmarshal(w.Body.Bytes(), &chatSessions)
	if len(chatSessions) != 1 {
		t.Errorf("Expected 1 chat session, got: %d", len(chatSessions))
	} else {
		s := chatSessions[0]
		if s.LastMessage != replyText {
			t.Errorf("Expected last message %q, got %q", replyText, s.LastMessage)
		}
		if s.LastMessageSender != "Event Creator" {
			t.Errorf("Expected last message sender 'Event Creator', got %q", s.LastMessageSender)
		}
	}
}

func TestProfileUpdate(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	aiService := service.NewAIService("")
	notificationService := service.NewNotificationService()

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)
	eventHandler := handler.NewEventHandler(pool, aiService, notificationService)

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.GET("/auth/me", authHandler.GetProfile)
		protected.PUT("/auth/profile", authHandler.UpdateProfile)
		protected.POST("/events", eventHandler.CreateEvent)
	}

	// 1. Sign Up
	signUpBody := `{"email":"test_profile@zholdas.kz","password":"password123","username":"profile_test","full_name":"Initial Name"}`
	req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signUpBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to sign up: %d", w.Code)
	}

	// 2. Sign In
	signInBody := `{"email":"test_profile@zholdas.kz","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signInBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to sign in: %d", w.Code)
	}

	var tokenRes handler.TokenResponse
	_ = json.Unmarshal(w.Body.Bytes(), &tokenRes)
	token := tokenRes.AccessToken

	// 3. Get Profile (Initial state)
	req, _ = http.NewRequest("GET", "/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to fetch initial profile: %d", w.Code)
	}

	var profileRes map[string]interface{}
	_ = json.Unmarshal(w.Body.Bytes(), &profileRes)
	if profileRes["full_name"] != "Initial Name" {
		t.Errorf("Expected initial name 'Initial Name', got %v", profileRes["full_name"])
	}
	if profileRes["bio"] != "" {
		t.Errorf("Expected initial empty bio, got %v", profileRes["bio"])
	}
	if int(profileRes["events_count"].(float64)) != 0 {
		t.Errorf("Expected initial events count 0, got %v", profileRes["events_count"])
	}

	// 4. Update Profile
	updateBody := `{"full_name":"New Updated Name","bio":"This is a test bio.","city":"Almaty","avatar_url":"https://example.com/avatar.jpg"}`
	req, _ = http.NewRequest("PUT", "/auth/profile", bytes.NewBufferString(updateBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to update profile: %d, body: %s", w.Code, w.Body.String())
	}

	// 5. Get Profile (Updated state)
	req, _ = http.NewRequest("GET", "/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to fetch updated profile: %d", w.Code)
	}

	_ = json.Unmarshal(w.Body.Bytes(), &profileRes)
	if profileRes["full_name"] != "New Updated Name" {
		t.Errorf("Expected updated name 'New Updated Name', got %v", profileRes["full_name"])
	}
	if profileRes["bio"] != "This is a test bio." {
		t.Errorf("Expected updated bio, got %v", profileRes["bio"])
	}
	if profileRes["city"] != "Almaty" {
		t.Errorf("Expected updated city 'Almaty', got %v", profileRes["city"])
	}
	if profileRes["avatar_url"] != "https://example.com/avatar.jpg" {
		t.Errorf("Expected updated avatar url, got %v", profileRes["avatar_url"])
	}
	if int(profileRes["events_count"].(float64)) != 0 {
		t.Errorf("Expected events count 0, got %v", profileRes["events_count"])
	}

	// 6. Create event to increment events_count
	startTime := time.Now().Add(1 * time.Hour).Format(time.RFC3339)
	endTime := time.Now().Add(2 * time.Hour).Format(time.RFC3339)
	eventBody := `{
		"title": "Profile Event Test",
		"description": "Verification test event",
		"category": "sports",
		"location_name": "Almaty",
		"longitude": 76.9,
		"latitude": 43.2,
		"start_time": "` + startTime + `",
		"end_time": "` + endTime + `",
		"max_participants": 10
	}`
	req, _ = http.NewRequest("POST", "/events", bytes.NewBufferString(eventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to create event for profile test: %d, body: %s", w.Code, w.Body.String())
	}

	// 7. Get Profile again and verify events_count is 1
	req, _ = http.NewRequest("GET", "/auth/me", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to fetch profile: %d", w.Code)
	}

	_ = json.Unmarshal(w.Body.Bytes(), &profileRes)
	if int(profileRes["events_count"].(float64)) != 1 {
		t.Errorf("Expected updated events count 1, got %v", profileRes["events_count"])
	}
}

func TestNotificationsFlow(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	aiService := service.NewAIService("")
	notificationService := service.NewNotificationService()

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)
	eventHandler := handler.NewEventHandler(pool, aiService, notificationService)

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.POST("/events", eventHandler.CreateEvent)
		protected.POST("/events/:id/join", eventHandler.JoinEvent)
		protected.POST("/events/:id/leave", eventHandler.LeaveEvent)
		protected.GET("/notifications", eventHandler.GetNotifications)
		protected.POST("/notifications/read", eventHandler.MarkNotificationsRead)
	}

	// 1. Sign Up User A & B
	users := []struct {
		Email    string
		Password string
		Username string
		FullName string
	}{
		{"notify_a@zholdas.kz", "password123", "notify_a", "User A Creator"},
		{"notify_b@zholdas.kz", "password123", "notify_b", "User B Participant"},
	}

	tokens := make([]string, 2)
	for i, u := range users {
		signUpBody, _ := json.Marshal(map[string]string{
			"email":     u.Email,
			"password":  u.Password,
			"username":  u.Username,
			"full_name": u.FullName,
		})
		req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBuffer(signUpBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		signInBody, _ := json.Marshal(map[string]string{
			"email":    u.Email,
			"password": u.Password,
		})
		req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBuffer(signInBody))
		req.Header.Set("Content-Type", "application/json")
		w = httptest.NewRecorder()
		r.ServeHTTP(w, req)

		var tokenRes handler.TokenResponse
		_ = json.Unmarshal(w.Body.Bytes(), &tokenRes)
		tokens[i] = tokenRes.AccessToken
	}

	tokenA := tokens[0]
	tokenB := tokens[1]

	// 2. User A creates event
	startTime := time.Now().Add(1 * time.Hour).Format(time.RFC3339)
	endTime := time.Now().Add(2 * time.Hour).Format(time.RFC3339)
	eventBody := `{
		"title": "Party Night",
		"description": "Party in Almaty",
		"category": "misc",
		"location_name": "My House",
		"longitude": 76.9,
		"latitude": 43.2,
		"start_time": "` + startTime + `",
		"end_time": "` + endTime + `",
		"max_participants": 5
	}`
	req, _ := http.NewRequest("POST", "/events", bytes.NewBufferString(eventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to create event: %d", w.Code)
	}

	var eventObj struct {
		ID int32 `json:"id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &eventObj)
	eventIDStr := strconv.Itoa(int(eventObj.ID))

	// 3. User A checks notifications (should be 0)
	req, _ = http.NewRequest("GET", "/notifications", nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to fetch A's notifications: %d", w.Code)
	}
	var notificationsList []handler.NotificationResponse
	_ = json.Unmarshal(w.Body.Bytes(), &notificationsList)
	if len(notificationsList) != 0 {
		t.Errorf("Expected 0 notifications, got: %d", len(notificationsList))
	}

	// 4. User B joins the event
	req, _ = http.NewRequest("POST", "/events/"+eventIDStr+"/join", nil)
	req.Header.Set("Authorization", "Bearer "+tokenB)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to join event: %d", w.Code)
	}

	// 5. User A checks notifications (should have 1 join notification)
	req, _ = http.NewRequest("GET", "/notifications", nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	_ = json.Unmarshal(w.Body.Bytes(), &notificationsList)
	if len(notificationsList) != 1 {
		t.Errorf("Expected 1 notification after join, got: %d", len(notificationsList))
	} else {
		n := notificationsList[0]
		if n.NotificationType != "join" {
			t.Errorf("Expected join notification type, got: %s", n.NotificationType)
		}
		if n.ActorName != "User B Participant" {
			t.Errorf("Expected actor name 'User B Participant', got: %s", n.ActorName)
		}
		if n.EventTitle != "Party Night" {
			t.Errorf("Expected event title 'Party Night', got: %s", n.EventTitle)
		}
		if n.IsRead {
			t.Errorf("Expected notification to be unread")
		}
	}

	// 6. User B leaves the event
	req, _ = http.NewRequest("POST", "/events/"+eventIDStr+"/leave", nil)
	req.Header.Set("Authorization", "Bearer "+tokenB)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to leave event: %d", w.Code)
	}

	// 7. User A checks notifications (should have 2 notifications, latest should be leave)
	req, _ = http.NewRequest("GET", "/notifications", nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	_ = json.Unmarshal(w.Body.Bytes(), &notificationsList)
	if len(notificationsList) != 2 {
		t.Errorf("Expected 2 notifications after leave, got: %d", len(notificationsList))
	} else {
		n := notificationsList[0] // sorted by created_at DESC
		if n.NotificationType != "leave" {
			t.Errorf("Expected latest leave notification type, got: %s", n.NotificationType)
		}
		if n.IsRead {
			t.Errorf("Expected latest notification to be unread")
		}
	}

	// 8. User A marks notifications as read
	req, _ = http.NewRequest("POST", "/notifications/read", nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to mark notifications as read: %d", w.Code)
	}

	// 9. User A verifies notifications are read
	req, _ = http.NewRequest("GET", "/notifications", nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	_ = json.Unmarshal(w.Body.Bytes(), &notificationsList)
	for _, n := range notificationsList {
		if !n.IsRead {
			t.Errorf("Expected notification to be read after calling read endpoint")
		}
	}
}

func TestFriendsFlow(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.POST("/friends/request/:id", authHandler.SendFriendRequest)
		protected.POST("/friends/accept/:id", authHandler.AcceptFriendRequest)
		protected.POST("/friends/reject/:id", authHandler.RejectFriendRequest)
		protected.GET("/friends", authHandler.GetFriends)
		protected.GET("/friends/requests", authHandler.GetFriendRequests)
		protected.GET("/friends/status/:id", authHandler.GetFriendshipStatus)
	}

	// 1. Create two users
	signupBodyA := `{"email":"usera@test.com","password":"password123","username":"usera","full_name":"User A"}`
	req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupBodyA))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to signup A: %d", w.Code)
	}
	var resA struct {
		UserID int32 `json:"user_id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &resA)

	signupBodyB := `{"email":"userb@test.com","password":"password123","username":"userb","full_name":"User B"}`
	req, _ = http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupBodyB))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to signup B: %d", w.Code)
	}
	var resB struct {
		UserID int32 `json:"user_id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &resB)

	// Sign in User A
	signinBodyA := `{"email":"usera@test.com","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinBodyA))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var tokensA struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &tokensA)
	tokenA := tokensA.AccessToken

	// Sign in User B
	signinBodyB := `{"email":"userb@test.com","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinBodyB))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var tokensB struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &tokensB)
	tokenB := tokensB.AccessToken

	idAStr := strconv.Itoa(int(resA.UserID))
	idBStr := strconv.Itoa(int(resB.UserID))

	// 2. Check initial friendship status from A to B (should be "none")
	req, _ = http.NewRequest("GET", "/friends/status/"+idBStr, nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to check status: %d", w.Code)
	}
	var statusObj struct {
		Status string `json:"status"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &statusObj)
	if statusObj.Status != "none" {
		t.Errorf("Expected status 'none', got '%s'", statusObj.Status)
	}

	// 3. User A sends friend request to User B
	req, _ = http.NewRequest("POST", "/friends/request/"+idBStr, nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to send friend request: %d - %s", w.Code, w.Body.String())
	}

	// 4. Verify A's status with B is "pending_sent"
	req, _ = http.NewRequest("GET", "/friends/status/"+idBStr, nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	_ = json.Unmarshal(w.Body.Bytes(), &statusObj)
	if statusObj.Status != "pending_sent" {
		t.Errorf("Expected status 'pending_sent', got '%s'", statusObj.Status)
	}

	// 5. Verify B's status with A is "pending_received"
	req, _ = http.NewRequest("GET", "/friends/status/"+idAStr, nil)
	req.Header.Set("Authorization", "Bearer "+tokenB)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	_ = json.Unmarshal(w.Body.Bytes(), &statusObj)
	if statusObj.Status != "pending_received" {
		t.Errorf("Expected status 'pending_received', got '%s'", statusObj.Status)
	}

	// 6. User B fetches incoming requests (should have User A)
	req, _ = http.NewRequest("GET", "/friends/requests", nil)
	req.Header.Set("Authorization", "Bearer "+tokenB)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to fetch requests: %d", w.Code)
	}
	var reqList []struct {
		ID int32 `json:"id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &reqList)
	if len(reqList) != 1 || reqList[0].ID != resA.UserID {
		t.Errorf("Expected incoming request from User A (%d), got: %v", resA.UserID, reqList)
	}

	// 7. User B accepts User A's friend request
	req, _ = http.NewRequest("POST", "/friends/accept/"+idAStr, nil)
	req.Header.Set("Authorization", "Bearer "+tokenB)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to accept friend request: %d - %s", w.Code, w.Body.String())
	}

	// 8. Verify status is "accepted" for both
	req, _ = http.NewRequest("GET", "/friends/status/"+idBStr, nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	_ = json.Unmarshal(w.Body.Bytes(), &statusObj)
	if statusObj.Status != "accepted" {
		t.Errorf("Expected status 'accepted', got '%s'", statusObj.Status)
	}

	// 9. Fetch friends lists
	req, _ = http.NewRequest("GET", "/friends", nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var friendsA []struct {
		ID int32 `json:"id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &friendsA)
	if len(friendsA) != 1 || friendsA[0].ID != resB.UserID {
		t.Errorf("Expected friend User B (%d) in A's friends list, got: %v", resB.UserID, friendsA)
	}

	// 10. User A rejects/unfriends User B
	req, _ = http.NewRequest("POST", "/friends/reject/"+idBStr, nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to reject friendship: %d", w.Code)
	}

	// 11. Verify status is back to "none"
	req, _ = http.NewRequest("GET", "/friends/status/"+idBStr, nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	_ = json.Unmarshal(w.Body.Bytes(), &statusObj)
	if statusObj.Status != "none" {
		t.Errorf("Expected status 'none' after unfriending, got '%s'", statusObj.Status)
	}
}

func TestReviewsFlow(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)
	eventHandler := handler.NewEventHandler(pool, service.NewAIService(""), service.NewNotificationService())

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)
	r.GET("/users/:id", authHandler.GetUserProfileByID)
	r.GET("/users/:id/reviews", authHandler.GetUserReviews)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.POST("/events", eventHandler.CreateEvent)
		protected.POST("/events/:id/join", eventHandler.JoinEvent)
		protected.POST("/events/:id/rate", authHandler.RateParticipant)
	}

	// 1. Create two users
	signupBodyA := `{"email":"usera@test.com","password":"password123","username":"usera","full_name":"User A"}`
	req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupBodyA))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var resA struct {
		UserID int32 `json:"user_id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &resA)

	signupBodyB := `{"email":"userb@test.com","password":"password123","username":"userb","full_name":"User B"}`
	req, _ = http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupBodyB))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var resB struct {
		UserID int32 `json:"user_id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &resB)

	// Sign in User A
	signinBodyA := `{"email":"usera@test.com","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinBodyA))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var tokensA struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &tokensA)
	tokenA := tokensA.AccessToken

	// Sign in User B
	signinBodyB := `{"email":"userb@test.com","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinBodyB))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var tokensB struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &tokensB)
	tokenB := tokensB.AccessToken

	// 2. User A creates an event that has already completed
	pastStart := time.Now().Add(-2 * time.Hour).Format(time.RFC3339)
	pastEnd := time.Now().Add(-1 * time.Hour).Format(time.RFC3339)

	eventBody := `{
		"title": "Old Completed Event",
		"description": "This event is already finished",
		"category": "sports",
		"location_name": "Completed stadium",
		"longitude": 76.9,
		"latitude": 43.2,
		"start_time": "` + pastStart + `",
		"end_time": "` + pastEnd + `",
		"max_participants": 5
	}`
	req, _ = http.NewRequest("POST", "/events", bytes.NewBufferString(eventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to create event: %d - %s", w.Code, w.Body.String())
	}

	var eventObj struct {
		ID int32 `json:"id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &eventObj)
	eventIDStr := strconv.Itoa(int(eventObj.ID))

	// 3. User B joins the event
	req, _ = http.NewRequest("POST", "/events/"+eventIDStr+"/join", nil)
	req.Header.Set("Authorization", "Bearer "+tokenB)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("User B failed to join: %d", w.Code)
	}

	// 4. User A rates User B (rating 5, comment "Great guy")
	rateBody := `{"ratee_id":` + strconv.Itoa(int(resB.UserID)) + `,"rating":5,"comment":"Great guy!"}`
	req, _ = http.NewRequest("POST", "/events/"+eventIDStr+"/rate", bytes.NewBufferString(rateBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to rate user: %d - %s", w.Code, w.Body.String())
	}

	// 5. Verify User B's profile rating (should be 5.0 now)
	req, _ = http.NewRequest("GET", "/users/"+strconv.Itoa(int(resB.UserID)), nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to get profile: %d", w.Code)
	}
	var profileObj struct {
		Rating float64 `json:"rating"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &profileObj)
	if profileObj.Rating != 5.0 {
		t.Errorf("Expected rating 5.0, got %f", profileObj.Rating)
	}

	// 6. Fetch reviews for User B (should contain 1 review from User A)
	req, _ = http.NewRequest("GET", "/users/"+strconv.Itoa(int(resB.UserID))+"/reviews", nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to fetch reviews: %d", w.Code)
	}
	var reviewsList []handler.UserReviewResponse
	_ = json.Unmarshal(w.Body.Bytes(), &reviewsList)
	if len(reviewsList) != 1 {
		t.Fatalf("Expected 1 review, got %d", len(reviewsList))
	}

	review := reviewsList[0]
	if review.Rating != 5 {
		t.Errorf("Expected rating 5, got %d", review.Rating)
	}
	if review.Comment != "Great guy!" {
		t.Errorf("Expected comment 'Great guy!', got '%s'", review.Comment)
	}
	if review.EvaluatorName != "User A" {
		t.Errorf("Expected evaluator name 'User A', got '%s'", review.EvaluatorName)
	}
}

func TestReportsFlow(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)
	eventHandler := handler.NewEventHandler(pool, service.NewAIService(""), service.NewNotificationService())

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.POST("/events", eventHandler.CreateEvent)
		protected.POST("/reports", authHandler.CreateReport)
	}

	// 1. Create four users: Creator, Reporter 1, Reporter 2, Reporter 3
	usersTokens := make([]string, 4)
	usersIDs := make([]int32, 4)
	for i := 0; i < 4; i++ {
		email := fmt.Sprintf("reporter%d@test.com", i)
		signupBody := fmt.Sprintf(`{"email":"%s","password":"password123","username":"rep%d","full_name":"Reporter %d"}`, email, i, i)
		req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		var signupRes struct {
			UserID int32 `json:"user_id"`
		}
		_ = json.Unmarshal(w.Body.Bytes(), &signupRes)
		usersIDs[i] = signupRes.UserID

		signinBody := fmt.Sprintf(`{"email":"%s","password":"password123"}`, email)
		req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinBody))
		req.Header.Set("Content-Type", "application/json")
		w = httptest.NewRecorder()
		r.ServeHTTP(w, req)

		var signinRes struct {
			AccessToken string `json:"access_token"`
		}
		_ = json.Unmarshal(w.Body.Bytes(), &signinRes)
		usersTokens[i] = signinRes.AccessToken
	}

	// 2. Creator (User 0) creates an event
	eventBody := `{
		"title": "Bad Spammy Event",
		"description": "Buy Bitcoins now!",
		"category": "boardgames",
		"location_name": "Spam Palace",
		"longitude": 76.9,
		"latitude": 43.2,
		"start_time": "` + time.Now().Add(1*time.Hour).Format(time.RFC3339) + `",
		"end_time": "` + time.Now().Add(3*time.Hour).Format(time.RFC3339) + `",
		"max_participants": 10
	}`
	req, _ := http.NewRequest("POST", "/events", bytes.NewBufferString(eventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+usersTokens[0])
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	var eventObj struct {
		ID int32 `json:"id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &eventObj)
	eventIDStr := strconv.Itoa(int(eventObj.ID))

	// 3. User 1 sends a report on User 0 (reported_user_id)
	reportUserBody := fmt.Sprintf(`{"reported_user_id":%d,"reason":"harassment","description":"He insulted me"}`, usersIDs[0])
	req, _ = http.NewRequest("POST", "/reports", bytes.NewBufferString(reportUserBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+usersTokens[1])
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to create user report: %d - %s", w.Code, w.Body.String())
	}

	// Check check-constraint by sending invalid target (all nil)
	invalidReportBody := `{"reason":"other","description":"None"}`
	req, _ = http.NewRequest("POST", "/reports", bytes.NewBufferString(invalidReportBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+usersTokens[1])
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected 400 Bad Request for report without target, got %d", w.Code)
	}

	// 4. Send 2 reports on the event (event is still active)
	for i := 1; i <= 2; i++ {
		reportEventBody := `{"event_id":` + eventIDStr + `,"reason":"spam","description":"bitcoin spam"}`
		req, _ = http.NewRequest("POST", "/reports", bytes.NewBufferString(reportEventBody))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+usersTokens[i])
		w = httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code != http.StatusCreated {
			t.Fatalf("Reporter %d failed to report event: %d", i, w.Code)
		}
	}

	// Verify event status is still 'active' (less than 3 reports)
	var status string
	err := pool.QueryRow(context.Background(), "SELECT status FROM events WHERE id = $1", eventObj.ID).Scan(&status)
	if err != nil {
		t.Fatalf("Failed to query event status: %v", err)
	}
	if status != "active" {
		t.Errorf("Expected event status to be 'active', got '%s'", status)
	}

	// 5. Send 3rd report on the event (should trigger auto blocking)
	reportEventBody3 := `{"event_id":` + eventIDStr + `,"reason":"spam","description":"bitcoin spam"}`
	req, _ = http.NewRequest("POST", "/reports", bytes.NewBufferString(reportEventBody3))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+usersTokens[3])
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Reporter 3 failed to report event: %d", w.Code)
	}

	// Verify event status changed to 'blocked'
	err = pool.QueryRow(context.Background(), "SELECT status FROM events WHERE id = $1", eventObj.ID).Scan(&status)
	if err != nil {
		t.Fatalf("Failed to query event status after 3rd report: %v", err)
	}
	if status != "blocked" {
		t.Errorf("Expected event status to be 'blocked' after 3 reports, got '%s'", status)
	}
}

func TestModerationAndBlocksFlow(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.GET("/moderation/reports", authHandler.GetReports)
		protected.POST("/moderation/users/:id/ban", authHandler.BanUser)
		protected.POST("/moderation/users/:id/unban", authHandler.UnbanUser)
		protected.POST("/moderation/reports/:id/close", authHandler.CloseReport)
		protected.POST("/users/:id/block", authHandler.BlockUser)
		protected.POST("/users/:id/unblock", authHandler.UnblockUser)
		protected.POST("/friends/request/:id", authHandler.SendFriendRequest)
		protected.POST("/reports", authHandler.CreateReport)
	}

	// 1. Create Moderator (User A) and standard users (User B, User C)
	usersTokens := make([]string, 3)
	usersIDs := make([]int32, 3)
	emails := []string{"mod@test.com", "userb@test.com", "userc@test.com"}
	for i := 0; i < 3; i++ {
		signupBody := fmt.Sprintf(`{"email":"%s","password":"password123","username":"user%d","full_name":"User %d"}`, emails[i], i, i)
		req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		var signupRes struct {
			UserID int32 `json:"user_id"`
		}
		_ = json.Unmarshal(w.Body.Bytes(), &signupRes)
		usersIDs[i] = signupRes.UserID

		signinBody := fmt.Sprintf(`{"email":"%s","password":"password123"}`, emails[i])
		req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinBody))
		req.Header.Set("Content-Type", "application/json")
		w = httptest.NewRecorder()
		r.ServeHTTP(w, req)

		var signinRes struct {
			AccessToken string `json:"access_token"`
		}
		_ = json.Unmarshal(w.Body.Bytes(), &signinRes)
		usersTokens[i] = signinRes.AccessToken
	}

	// Make User A a moderator in the database
	_, err := pool.Exec(context.Background(), "UPDATE profiles SET role = 'moderator' WHERE user_id = $1", usersIDs[0])
	if err != nil {
		t.Fatalf("Failed to set moderator role: %v", err)
	}

	// 2. User B blocks User C
	req, _ := http.NewRequest("POST", fmt.Sprintf("/users/%d/block", usersIDs[2]), nil)
	req.Header.Set("Authorization", "Bearer "+usersTokens[1])
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Failed to block user: %d - %s", w.Code, w.Body.String())
	}

	// User B tries to send a friend request to User C (should return 403 Forbidden due to block relationship)
	req, _ = http.NewRequest("POST", fmt.Sprintf("/friends/request/%d", usersIDs[2]), nil)
	req.Header.Set("Authorization", "Bearer "+usersTokens[1])
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusForbidden {
		t.Errorf("Expected 403 Forbidden on friend request between blocked users, got %d", w.Code)
	}

	// 3. User B files a report on User C
	reportEventBody := fmt.Sprintf(`{"reported_user_id":%d,"reason":"harassment","description":"Spamming user"}`, usersIDs[2])
	req, _ = http.NewRequest("POST", "/reports", bytes.NewBufferString(reportEventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+usersTokens[1])
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to file report: %d", w.Code)
	}

	// 4. Moderator A fetches reports
	req, _ = http.NewRequest("GET", "/moderation/reports", nil)
	req.Header.Set("Authorization", "Bearer "+usersTokens[0])
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Moderator failed to get reports: %d - %s", w.Code, w.Body.String())
	}
	var reportsList []handler.ReportResponse
	_ = json.Unmarshal(w.Body.Bytes(), &reportsList)
	if len(reportsList) == 0 {
		t.Fatalf("Expected at least one report, got 0")
	}
	reportID := reportsList[0].ID

	// 5. Moderator A bans User C
	banBody := `{"reason":"Spamming and harassment"}`
	req, _ = http.NewRequest("POST", fmt.Sprintf("/moderation/users/%d/ban", usersIDs[2]), bytes.NewBufferString(banBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+usersTokens[0])
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Moderator failed to ban user: %d - %s", w.Code, w.Body.String())
	}

	// Verify User C is banned in profiles table
	var isBanned bool
	var banReason string
	err = pool.QueryRow(context.Background(), "SELECT is_banned, ban_reason FROM profiles WHERE user_id = $1", usersIDs[2]).Scan(&isBanned, &banReason)
	if err != nil {
		t.Fatalf("Failed to query profile ban status: %v", err)
	}
	if !isBanned {
		t.Errorf("Expected is_banned to be true, got false")
	}
	if banReason != "Spamming and harassment" {
		t.Errorf("Expected ban reason 'Spamming and harassment', got '%s'", banReason)
	}

	// 6. Banned User C tries to send a report (should get 403 Forbidden due to ban)
	req, _ = http.NewRequest("POST", "/reports", bytes.NewBufferString(reportEventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+usersTokens[2])
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusForbidden {
		t.Errorf("Expected banned user request to fail with 403 Forbidden, got %d", w.Code)
	}

	// 7. Moderator A closes/resolves the report
	req, _ = http.NewRequest("POST", fmt.Sprintf("/moderation/reports/%d/close", reportID), nil)
	req.Header.Set("Authorization", "Bearer "+usersTokens[0])
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Moderator failed to close report: %d", w.Code)
	}

	// 8. Moderator A unbans User C
	req, _ = http.NewRequest("POST", fmt.Sprintf("/moderation/users/%d/unban", usersIDs[2]), nil)
	req.Header.Set("Authorization", "Bearer "+usersTokens[0])
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Moderator failed to unban user: %d", w.Code)
	}

	// Verify User C is unbanned
	err = pool.QueryRow(context.Background(), "SELECT is_banned FROM profiles WHERE user_id = $1", usersIDs[2]).Scan(&isBanned)
	if err != nil {
		t.Fatalf("Failed to query profile ban status after unban: %v", err)
	}
	if isBanned {
		t.Errorf("Expected is_banned to be false after unban, got true")
	}
}

func TestEventAIChatFlow(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	// 1. Setup system AI user (needed by database trigger or foreign keys)
	_, err := pool.Exec(context.Background(), `
		INSERT INTO users (id, email, password_hash) 
		VALUES (0, 'ai@zholdas.app', 'disabled') 
		ON CONFLICT (id) DO NOTHING;
		INSERT INTO profiles (user_id, username, full_name, role) 
		VALUES (0, 'ai', 'Жорик (ИИ)', 'user') 
		ON CONFLICT (user_id) DO NOTHING;
	`)
	if err != nil {
		t.Fatalf("Failed to seed system AI user: %v", err)
	}

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)
	// Create AIService with empty API key to trigger mock mode
	aiService := service.NewAIService("")
	eventHandler := handler.NewEventHandler(pool, aiService, service.NewNotificationService())

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.POST("/events", eventHandler.CreateEvent)
		protected.POST("/events/:id/messages", eventHandler.SendEventMessage)
		protected.GET("/events/:id/messages", eventHandler.GetEventMessages)
	}

	// 2. Signup & Signin User A
	signupBody := `{"email":"usera@test.com","password":"password123","username":"usera","full_name":"User A"}`
	req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Signup failed: %d", w.Code)
	}

	signinBody := `{"email":"usera@test.com","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Signin failed: %d", w.Code)
	}

	var signinRes struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &signinRes)
	token := signinRes.AccessToken

	// 3. User A creates an Event
	eventBody := `{"title":"Настолки","description":"Играем в мафию и бункер","latitude":43.238, "longitude":76.945, "location_name":"Клуб","max_participants":10,"start_time":"2026-06-30T19:00:00Z", "end_time":"2026-06-30T22:00:00Z", "category":"games"}`
	req, _ = http.NewRequest("POST", "/events", bytes.NewBufferString(eventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("CreateEvent failed: %d - %s", w.Code, w.Body.String())
	}
	var eventObj struct {
		ID int32 `json:"id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &eventObj)

	// 4. Send Message with prefix "@ai"
	msgBody := `{"text":"@ai посоветуй правила для настолки"}`
	req, _ = http.NewRequest("POST", fmt.Sprintf("/events/%d/messages", eventObj.ID), bytes.NewBufferString(msgBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("SendMessage failed: %d", w.Code)
	}

	// Wait for the async goroutine to execute
	time.Sleep(150 * time.Millisecond)

	// 5. Fetch messages and verify AI companion replied
	req, _ = http.NewRequest("GET", fmt.Sprintf("/events/%d/messages", eventObj.ID), nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("GetEventMessages failed: %d", w.Code)
	}

	var messagesList []handler.EventMessageResponse
	_ = json.Unmarshal(w.Body.Bytes(), &messagesList)
	if len(messagesList) < 2 {
		t.Fatalf("Expected at least 2 messages in chat history (user prompt + AI response), got %d", len(messagesList))
	}

	// The second message should be from the AI system sender (sender_id is empty)
	aiMsg := messagesList[1]
	if aiMsg.SenderID != "" {
		t.Errorf("Expected sender ID to be empty for AI, got %s", aiMsg.SenderID)
	}
	if aiMsg.SenderName != "Жорик (ИИ)" {
		t.Errorf("Expected sender name to be 'Жорик (ИИ)', got '%s'", aiMsg.SenderName)
	}
	if !strings.Contains(aiMsg.Text, "Жорик") {
		t.Errorf("Expected AI message to contain 'Жорик', got '%s'", aiMsg.Text)
	}
}

func TestImageUploadFlow(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.POST("/upload", authHandler.UploadImage)
	}

	// 1. Signup & Signin User A
	signupBody := `{"email":"usera_upload@test.com","password":"password123","username":"usera_upload","full_name":"User Upload"}`
	req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Signup failed: %d", w.Code)
	}

	signinBody := `{"email":"usera_upload@test.com","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("Signin failed: %d", w.Code)
	}

	var signinRes struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &signinRes)
	token := signinRes.AccessToken

	// 2. Prepare multipart form file
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)

	part, err := writer.CreateFormFile("file", "test_avatar.jpg")
	if err != nil {
		t.Fatalf("Failed to create form file: %v", err)
	}

	dummyImageContent := []byte("fake-image-bytes-jpeg-structure")
	_, err = part.Write(dummyImageContent)
	if err != nil {
		t.Fatalf("Failed to write dummy image data: %v", err)
	}

	_ = writer.Close()

	// 3. Send upload request
	req, _ = http.NewRequest("POST", "/upload", &body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+token)

	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Upload failed: %d - %s", w.Code, w.Body.String())
	}

	var uploadRes struct {
		URL string `json:"url"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &uploadRes)

	if !strings.HasPrefix(uploadRes.URL, "/uploads/") {
		t.Errorf("Expected URL to start with '/uploads/', got '%s'", uploadRes.URL)
	}
	if !strings.HasSuffix(uploadRes.URL, ".jpg") {
		t.Errorf("Expected URL to end with '.jpg', got '%s'", uploadRes.URL)
	}

	// Verify local file exists
	localFilePath := filepath.Join(".", uploadRes.URL)
	if _, err := os.Stat(localFilePath); os.IsNotExist(err) {
		t.Errorf("Uploaded file does not exist on disk at '%s'", localFilePath)
	} else {
		// Clean up file
		_ = os.Remove(localFilePath)
	}
}

func TestWebSocketChatFlow(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	aiService := service.NewAIService("")
	notificationService := service.NewNotificationService()
	eventHandler := handler.NewEventHandler(pool, aiService, notificationService)
	eventHandler.SetJWTSecret(testJWTSecret)

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)

	// WebSocket unprotected upgrade route
	r.GET("/events/:id/ws", eventHandler.WebSocketChatUpgrader)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.POST("/events", eventHandler.CreateEvent)
		protected.POST("/events/:id/join", eventHandler.JoinEvent)
		protected.POST("/events/:id/messages", eventHandler.SendEventMessage)
	}

	// 1. Signup & Signin User A (Creator)
	signupA := `{"email":"usera_ws@test.com","password":"password123","username":"usera_ws","full_name":"User A WS"}`
	req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupA))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Signup A failed: %d", w.Code)
	}

	signinA := `{"email":"usera_ws@test.com","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinA))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var signResA struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &signResA)

	// 2. Signup & Signin User B (Participant)
	signupB := `{"email":"userb_ws@test.com","password":"password123","username":"userb_ws","full_name":"User B WS"}`
	req, _ = http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupB))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Signup B failed: %d", w.Code)
	}

	signinB := `{"email":"userb_ws@test.com","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinB))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var signResB struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &signResB)

	// 3. User A creates an event
	startTime := time.Now().Add(1 * time.Hour).Format(time.RFC3339)
	endTime := time.Now().Add(2 * time.Hour).Format(time.RFC3339)
	eventBody := fmt.Sprintf(`{"title":"WS Hike","description":"Hike to WS","category":"hiking","location_name":"WS Peak","latitude":43.0,"longitude":76.0,"start_time":"%s","end_time":"%s","max_participants":10}`, startTime, endTime)

	req, _ = http.NewRequest("POST", "/events", bytes.NewBufferString(eventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+signResA.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("CreateEvent failed: %d - %s", w.Code, w.Body.String())
	}
	var createdEvent struct {
		ID int32 `json:"id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &createdEvent)

	// 4. User B joins the event
	req, _ = http.NewRequest("POST", fmt.Sprintf("/events/%d/join", createdEvent.ID), nil)
	req.Header.Set("Authorization", "Bearer "+signResB.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("JoinEvent failed: %d - %s", w.Code, w.Body.String())
	}

	// 5. Start a real HTTP server for WebSocket connection testing
	ts := httptest.NewServer(r)
	defer ts.Close()

	// 6. User B connects to WebSocket
	wsURL := strings.Replace(ts.URL, "http", "ws", 1) + fmt.Sprintf("/events/%d/ws?token=%s", createdEvent.ID, signResB.AccessToken)
	wsConn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to establish WebSocket connection: %v", err)
	}
	defer wsConn.Close()

	// 7. User A sends a chat message via POST
	chatMsgBody := `{"text":"Hello from User A via WS test"}`
	req, _ = http.NewRequest("POST", fmt.Sprintf("/events/%d/messages", createdEvent.ID), bytes.NewBufferString(chatMsgBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+signResA.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Failed to send chat message: %d", w.Code)
	}

	// 8. User B receives the message in WebSocket in real-time
	var receivedMsg handler.EventMessageResponse
	err = wsConn.SetReadDeadline(time.Now().Add(2 * time.Second))
	if err != nil {
		t.Fatalf("Failed to set read deadline: %v", err)
	}

	err = wsConn.ReadJSON(&receivedMsg)
	if err != nil {
		t.Fatalf("Failed to read WebSocket message: %v", err)
	}

	if receivedMsg.Text != "Hello from User A via WS test" {
		t.Errorf("Expected message text 'Hello from User A via WS test', got '%s'", receivedMsg.Text)
	}
	if receivedMsg.SenderName != "User A WS" {
		t.Errorf("Expected sender name 'User A WS', got '%s'", receivedMsg.SenderName)
	}
}

func TestDeviceTokenAndPushFlow(t *testing.T) {
	gin.SetMode(gin.TestMode)
	pool := setupTestDB(t)
	defer pool.Close()

	aiService := service.NewAIService("")
	notificationService := service.NewNotificationService()
	notificationService.SetPool(pool)

	authHandler := handler.NewAuthHandler(pool, testJWTSecret)
	authHandler.SetNotificationService(notificationService)
	eventHandler := handler.NewEventHandler(pool, aiService, notificationService)

	r := gin.Default()
	r.POST("/auth/signup", authHandler.SignUp)
	r.POST("/auth/signin", authHandler.SignIn)

	protected := r.Group("/")
	protected.Use(middleware.AuthMiddleware(testJWTSecret, pool))
	{
		protected.POST("/auth/device-token", authHandler.RegisterDeviceToken)
		protected.POST("/events", eventHandler.CreateEvent)
		protected.POST("/reports", authHandler.CreateReport)
	}

	// 1. Signup & Signin User
	signupBody := `{"email":"pushtest@test.com","password":"password123","username":"pushtest","full_name":"Push Test User"}`
	req, _ := http.NewRequest("POST", "/auth/signup", bytes.NewBufferString(signupBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("Signup failed: %d", w.Code)
	}

	signinBody := `{"email":"pushtest@test.com","password":"password123"}`
	req, _ = http.NewRequest("POST", "/auth/signin", bytes.NewBufferString(signinBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var signRes struct {
		AccessToken string `json:"access_token"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &signRes)

	// 2. Register Device Token
	deviceTokenBody := `{"device_token":"MOCK_APNS_DEVICE_TOKEN_HEX_STRING_12345","platform":"ios"}`
	req, _ = http.NewRequest("POST", "/auth/device-token", bytes.NewBufferString(deviceTokenBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+signRes.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("RegisterDeviceToken failed: %d - %s", w.Code, w.Body.String())
	}

	// Verify token is in database
	var count int
	err := pool.QueryRow(context.Background(), `
		SELECT COUNT(1) FROM user_device_tokens 
		WHERE device_token = 'MOCK_APNS_DEVICE_TOKEN_HEX_STRING_12345'
	`).Scan(&count)
	if err != nil {
		t.Fatalf("Failed to query DB for token: %v", err)
	}
	if count != 1 {
		t.Errorf("Expected exactly 1 device token in DB, got %d", count)
	}

	// 3. User creates an event
	startTime := time.Now().Add(1 * time.Hour).Format(time.RFC3339)
	endTime := time.Now().Add(2 * time.Hour).Format(time.RFC3339)
	eventBody := fmt.Sprintf(`{"title":"Push Event","description":"Testing push","category":"hiking","location_name":"Peak","latitude":43.0,"longitude":76.0,"start_time":"%s","end_time":"%s","max_participants":10}`, startTime, endTime)
	req, _ = http.NewRequest("POST", "/events", bytes.NewBufferString(eventBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+signRes.AccessToken)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var createdEvent struct {
		ID int32 `json:"id"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &createdEvent)

	// 4. Send 3 reports to trigger auto-moderation block, which fires SendPush to event creator
	for i := 1; i <= 3; i++ {
		reportMockBody := fmt.Sprintf(`{"reported_user_id":null,"event_id":%d,"message_id":null,"reason":"spam","description":"spam text"}`, createdEvent.ID)
		req, _ = http.NewRequest("POST", "/reports", bytes.NewBufferString(reportMockBody))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+signRes.AccessToken)
		w = httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code != http.StatusCreated {
			t.Fatalf("CreateReport %d failed: %d", i, w.Code)
		}
	}
}
