package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/birzhansovetov/zholdas-backend/internal/config"
	"github.com/birzhansovetov/zholdas-backend/internal/handler"
	"github.com/birzhansovetov/zholdas-backend/internal/middleware"
	"github.com/birzhansovetov/zholdas-backend/internal/service"
)

func main() {
	cfg := config.LoadConfig()

	log.Printf("Starting Zholdas Backend on port %s...", cfg.Port)

	// 1. Initialize PostgreSQL Connection Pool
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pool, err := newDBPool(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer pool.Close()

	// Ping database to confirm connection
	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("Database ping failed: %v", err)
	}
	log.Println("Connected to database successfully.")

	// Keep mobile app tables isolated from the existing web public schema.
	_, err = pool.Exec(ctx, "CREATE SCHEMA IF NOT EXISTS mobile;")
	if err != nil {
		log.Fatalf("Failed to create mobile schema: %v", err)
	}

	// 2. Run Database Migrations
	if cfg.RunMigrations {
		if err := runMigrations(context.Background(), pool); err != nil {
			log.Fatalf("Migration run failed: %v", err)
		}
	} else {
		log.Println("Skipping database migrations because RUN_MIGRATIONS=false.")
	}
	if err := ensureOperationalSchema(context.Background(), pool); err != nil {
		log.Fatalf("Failed to ensure operational schema: %v", err)
	}
	if err := ensureAdminRole(context.Background(), pool, cfg.AdminEmail); err != nil {
		log.Fatalf("Failed to ensure admin role: %v", err)
	}

	// 3. Initialize Services
	aiService := service.NewAIService(cfg.OpenAIAPIKey)
	notificationService := service.NewNotificationService()
	notificationService.SetPool(pool)

	// 4. Initialize Handlers
	authHandler := handler.NewAuthHandler(pool, cfg.JWTSecret)
	authHandler.SetNotificationService(notificationService)
	eventHandler := handler.NewEventHandler(pool, aiService, notificationService)
	eventHandler.SetJWTSecret(cfg.JWTSecret)

	// 5. Setup Gin Router
	router := gin.Default()

	// CORS Middleware
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	})

	// Static uploads directory
	router.Static("/uploads", "./uploads")

	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	router.GET("/events/:id", eventHandler.GetPublicEventPage)

	// WebSocket Route (JWT validation is handled inside query parameters)
	router.GET("/events/:id/ws", eventHandler.WebSocketChatUpgrader)

	// Public Routes
	authRoutes := router.Group("/auth")
	{
		authRoutes.POST("/signup", authHandler.SignUp)
		authRoutes.POST("/register", authHandler.SignUp)
		authRoutes.POST("/signin", authHandler.SignIn)
		authRoutes.POST("/refresh", authHandler.RefreshToken)
	}

	// Protected Routes (JWT Auth)
	protectedRoutes := router.Group("/")
	protectedRoutes.Use(middleware.AuthMiddleware(cfg.JWTSecret, pool))
	{
		protectedRoutes.POST("/auth/logout", authHandler.LogOut)
		protectedRoutes.GET("/auth/me", authHandler.GetProfile)
		protectedRoutes.PUT("/auth/profile", authHandler.UpdateProfile)
		protectedRoutes.POST("/upload", authHandler.UploadImage)
		protectedRoutes.POST("/auth/device-token", authHandler.RegisterDeviceToken)
		protectedRoutes.GET("/users/:id", authHandler.GetUserProfileByID)
		protectedRoutes.GET("/users/:id/reviews", authHandler.GetUserReviews)
		protectedRoutes.POST("/reports", authHandler.CreateReport)
		protectedRoutes.POST("/events", eventHandler.CreateEvent)

		// Moderation routes
		protectedRoutes.GET("/moderation/reports", authHandler.GetReports)
		protectedRoutes.POST("/moderation/users/:id/ban", authHandler.BanUser)
		protectedRoutes.POST("/moderation/users/:id/unban", authHandler.UnbanUser)
		protectedRoutes.POST("/moderation/reports/:id/close", authHandler.CloseReport)
		protectedRoutes.GET("/moderation/users", authHandler.GetModerationUsers)
		protectedRoutes.POST("/moderation/users/:id/role", authHandler.UpdateUserRole)
		protectedRoutes.POST("/moderation/users/:id/delete", authHandler.DeleteUserPermanently)
		protectedRoutes.GET("/moderation/events", authHandler.GetModerationEvents)
		protectedRoutes.POST("/moderation/events/:id/status", authHandler.UpdateEventStatus)
		protectedRoutes.GET("/moderation/stats", authHandler.GetModerationStats)
		protectedRoutes.GET("/moderation/audit-logs", authHandler.GetModerationAuditLogs)
		protectedRoutes.GET("/moderation/settings", authHandler.GetSystemSettings)
		protectedRoutes.PUT("/moderation/settings", authHandler.UpdateSystemSettings)
		protectedRoutes.POST("/moderation/broadcast", authHandler.BroadcastNotification)

		// Block routes
		protectedRoutes.POST("/users/:id/block", authHandler.BlockUser)
		protectedRoutes.POST("/users/:id/unblock", authHandler.UnblockUser)
		protectedRoutes.GET("/events/nearby", eventHandler.GetNearbyEvents)
		protectedRoutes.POST("/events/:id/join", eventHandler.JoinEvent)
		protectedRoutes.POST("/events/:id/leave", eventHandler.LeaveEvent)
		protectedRoutes.POST("/events/:id/arrive", eventHandler.MarkArrived)
		protectedRoutes.GET("/events/:id/participants", eventHandler.GetEventParticipants)
		protectedRoutes.POST("/events/:id/live-location", eventHandler.UpdateEventLiveLocation)
		protectedRoutes.GET("/events/:id/live-locations", eventHandler.GetEventLiveLocations)
		protectedRoutes.DELETE("/events/:id/live-location", eventHandler.DeleteEventLiveLocation)
		protectedRoutes.POST("/events/:id/rate", authHandler.RateParticipant)

		// Chat Room Routes
		protectedRoutes.GET("/chats", eventHandler.GetChatSessions)
		protectedRoutes.GET("/events/:id/messages", eventHandler.GetEventMessages)
		protectedRoutes.POST("/events/:id/messages", eventHandler.SendEventMessage)

		// Notifications Routes
		protectedRoutes.GET("/notifications", eventHandler.GetNotifications)
		protectedRoutes.POST("/notifications/read", eventHandler.MarkNotificationsRead)

		// Friends Routes
		protectedRoutes.POST("/friends/request/:id", authHandler.SendFriendRequest)
		protectedRoutes.POST("/friends/accept/:id", authHandler.AcceptFriendRequest)
		protectedRoutes.POST("/friends/reject/:id", authHandler.RejectFriendRequest)
		protectedRoutes.GET("/friends", authHandler.GetFriends)
		protectedRoutes.GET("/friends/requests", authHandler.GetFriendRequests)
		protectedRoutes.GET("/friends/status/:id", authHandler.GetFriendshipStatus)

		// AI Recommendation & Chat Routes (Protected + Rate Limited)
		aiRecLimiter := middleware.NewAIRateLimiter()
		protectedRoutes.GET("/events/recommendations", middleware.RateLimitMiddleware(aiRecLimiter), eventHandler.GetAIRecommendations)
		aiChatLimiter := middleware.NewAIRateLimiter()
		protectedRoutes.POST("/ai/chat", middleware.RateLimitMiddleware(aiChatLimiter), eventHandler.ChatWithAI)
	}

	// Background task: Auto-finish events whose end_time has passed
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			ctx := context.Background()
			res, err := pool.Exec(ctx, `
				UPDATE events 
				SET status = 'finished' 
				WHERE status = 'active' AND end_time <= NOW()
			`)
			if err != nil {
				log.Printf("[Background Job] Error auto-finishing events: %v", err)
			} else {
				if rows := res.RowsAffected(); rows > 0 {
					log.Printf("[Background Job] Auto-finished %d events.", rows)
				}
			}
		}
	}()

	// Background task: notify participants before upcoming events.
	go func() {
		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()
		for {
			sendEventReminders(context.Background(), pool, notificationService)
			<-ticker.C
		}
	}()

	// Start HTTP Server
	serverAddr := fmt.Sprintf(":%s", cfg.Port)
	if err := router.Run(serverAddr); err != nil {
		log.Fatalf("Failed to run server: %v", err)
	}
}

func ensureOperationalSchema(ctx context.Context, pool *pgxpool.Pool) error {
	statements := []string{
		`ALTER TABLE event_participants ADD COLUMN IF NOT EXISTS arrived_at TIMESTAMP WITH TIME ZONE`,
		`CREATE TABLE IF NOT EXISTS event_reminders (
			id SERIAL PRIMARY KEY,
			event_id INT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
			user_id uuid NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
			reminder_type VARCHAR(20) NOT NULL,
			sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
			UNIQUE(event_id, user_id, reminder_type)
		)`,
		`CREATE INDEX IF NOT EXISTS idx_event_participants_arrived ON event_participants(event_id, arrived_at)`,
		`CREATE INDEX IF NOT EXISTS idx_event_reminders_event_user ON event_reminders(event_id, user_id)`,
	}

	for _, statement := range statements {
		if _, err := pool.Exec(ctx, statement); err != nil {
			return err
		}
	}
	return nil
}

func sendEventReminders(ctx context.Context, pool *pgxpool.Pool, notificationService *service.NotificationService) {
	windows := []struct {
		kind  string
		label string
		from  time.Duration
		to    time.Duration
	}{
		{kind: "60m", label: "через 1 час", from: 55 * time.Minute, to: 65 * time.Minute},
		{kind: "15m", label: "через 15 минут", from: 10 * time.Minute, to: 20 * time.Minute},
	}

	for _, window := range windows {
		rows, err := pool.Query(ctx, `
			WITH event_users AS (
				SELECT e.id AS event_id, e.creator_id AS user_id
				FROM events e
				UNION
				SELECT ep.event_id, ep.user_id
				FROM event_participants ep
			)
			SELECT e.id, e.title, e.location_name, eu.user_id::text
			FROM events e
			JOIN event_users eu ON eu.event_id = e.id
			WHERE e.status = 'active'
			  AND e.start_time > NOW() + ($1::int * interval '1 second')
			  AND e.start_time <= NOW() + ($2::int * interval '1 second')
			  AND NOT EXISTS (
			      SELECT 1
			      FROM event_reminders er
			      WHERE er.event_id = e.id
			        AND er.user_id = eu.user_id
			        AND er.reminder_type = $3
			  )
		`, int(window.from.Seconds()), int(window.to.Seconds()), window.kind)
		if err != nil {
			log.Printf("[Reminder Job] Failed to fetch %s reminders: %v", window.kind, err)
			continue
		}

		type reminder struct {
			eventID      int
			title        string
			locationName string
			userID       string
		}

		reminders := []reminder{}
		for rows.Next() {
			var item reminder
			if err := rows.Scan(&item.eventID, &item.title, &item.locationName, &item.userID); err != nil {
				log.Printf("[Reminder Job] Failed to scan reminder: %v", err)
				continue
			}
			reminders = append(reminders, item)
		}
		rows.Close()

		for _, item := range reminders {
			text := fmt.Sprintf("Напоминание: встреча \"%s\" начнется %s. Место: %s. Проверь маршрут и что нужно взять.", item.title, window.label, item.locationName)
			_, err := pool.Exec(ctx, `
				INSERT INTO event_reminders (event_id, user_id, reminder_type)
				VALUES ($1, $2, $3)
				ON CONFLICT (event_id, user_id, reminder_type) DO NOTHING
			`, item.eventID, item.userID, window.kind)
			if err != nil {
				log.Printf("[Reminder Job] Failed to save %s reminder for user %s event %d: %v", window.kind, item.userID, item.eventID, err)
				continue
			}

			_, _ = pool.Exec(ctx, `
				INSERT INTO notifications (user_id, actor_id, event_id, notification_type, text)
				VALUES ($1, $1, $2, $3, $4)
			`, item.userID, item.eventID, "event_reminder", text)

			if notificationService != nil {
				notificationService.SendPush(item.userID, text)
			}
		}
	}
}

func newDBPool(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	poolConfig, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, err
	}
	if poolConfig.ConnConfig.RuntimeParams == nil {
		poolConfig.ConnConfig.RuntimeParams = map[string]string{}
	}
	poolConfig.ConnConfig.RuntimeParams["search_path"] = "mobile,public"
	poolConfig.ConnConfig.StatementCacheCapacity = 0
	poolConfig.ConnConfig.DescriptionCacheCapacity = 0
	poolConfig.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol
	return pgxpool.NewWithConfig(ctx, poolConfig)
}

func ensureAdminRole(ctx context.Context, pool *pgxpool.Pool, adminEmail string) error {
	adminEmail = strings.TrimSpace(adminEmail)
	if adminEmail == "" {
		return nil
	}

	tag, err := pool.Exec(ctx, `
		UPDATE profiles p
		SET role = 'admin'
		FROM auth.users au
		WHERE p.user_id = au.id
			AND lower(au.email) = lower($1)
	`, adminEmail)
	if err != nil {
		return err
	}

	if tag.RowsAffected() == 0 {
		log.Printf("ADMIN_EMAIL=%s did not match an existing Supabase Auth profile yet.", adminEmail)
		return nil
	}

	log.Printf("Ensured admin role for ADMIN_EMAIL=%s.", adminEmail)
	return nil
}

func runMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	// Create schema_migrations tracking table
	_, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version INT PRIMARY KEY,
			applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
		);
	`)
	if err != nil {
		return fmt.Errorf("failed to create migration tracking table: %w", err)
	}

	migrationsDir := "db/migrations"
	files, err := os.ReadDir(migrationsDir)
	if err != nil {
		return fmt.Errorf("failed to read migrations directory: %w", err)
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

		// Check if migration has already been applied
		var exists bool
		err = pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version=$1)", version).Scan(&exists)
		if err != nil {
			return fmt.Errorf("failed to check migration status for version %d: %w", version, err)
		}

		if exists {
			continue
		}

		filePath := filepath.Join(migrationsDir, fileName)
		content, err := os.ReadFile(filePath)
		if err != nil {
			return fmt.Errorf("failed to read migration file %s: %w", fileName, err)
		}

		log.Printf("Applying migration: %s", fileName)

		tx, err := pool.Begin(ctx)
		if err != nil {
			return fmt.Errorf("failed to start transaction for migration %s: %w", fileName, err)
		}

		_, err = tx.Exec(ctx, string(content))
		if err != nil {
			tx.Rollback(ctx)
			return fmt.Errorf("failed to execute migration %s: %w", fileName, err)
		}

		_, err = tx.Exec(ctx, "INSERT INTO schema_migrations (version) VALUES ($1)", version)
		if err != nil {
			tx.Rollback(ctx)
			return fmt.Errorf("failed to insert migration version %d: %w", version, err)
		}

		if err := tx.Commit(ctx); err != nil {
			return fmt.Errorf("failed to commit migration %s: %w", fileName, err)
		}
		log.Printf("Migration %s applied successfully", fileName)
	}
	return nil
}
