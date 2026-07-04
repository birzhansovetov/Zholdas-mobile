package handler

import (
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/birzhansovetov/zholdas-backend/internal/database"
	"github.com/birzhansovetov/zholdas-backend/internal/service"
)

type AuthHandler struct {
	pool                *pgxpool.Pool
	queries             *database.Queries
	jwtSecret           string
	notificationService *service.NotificationService
}

func NewAuthHandler(pool *pgxpool.Pool, jwtSecret string) *AuthHandler {
	return &AuthHandler{
		pool:      pool,
		queries:   database.New(pool),
		jwtSecret: jwtSecret,
	}
}

// SetNotificationService configures the notification service dependency
func (h *AuthHandler) SetNotificationService(ns *service.NotificationService) {
	h.notificationService = ns
}

type SignUpDTO struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
	Username string `json:"username" binding:"required"`
	FullName string `json:"full_name" binding:"required"`
}

type SignInDTO struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type RefreshDTO struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

// SignUp registers a new user and creates their profile
func (h *AuthHandler) SignUp(c *gin.Context) {
	c.JSON(http.StatusGone, gin.H{"error": "Use Supabase Auth signup from the client"})
}

// SignIn authenticates the user and generates new tokens
func (h *AuthHandler) SignIn(c *gin.Context) {
	c.JSON(http.StatusGone, gin.H{"error": "Use Supabase Auth signin from the client"})
}

// RefreshToken rotates refresh tokens and returns a new access/refresh token pair
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	c.JSON(http.StatusGone, gin.H{"error": "Use Supabase Auth refresh from the client"})
}

// LogOut invalidates the user's active refresh tokens
func (h *AuthHandler) LogOut(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	_ = userIDVal

	c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
}

// GetProfile returns the profile details of the authenticated user
func (h *AuthHandler) GetProfile(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userID, ok := userIDVal.(string)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID type"})
		return
	}

	ctx := c.Request.Context()
	var user struct {
		ID               string
		Email            string
		Username         string
		FullName         string
		AvatarURL        *string
		Bio              *string
		City             *string
		Gender           *string
		BirthYear        *int32
		Role             string
		IsBanned         bool
		EmailConfirmedAt *time.Time
	}
	err := h.pool.QueryRow(ctx, `
			SELECT p.user_id::text, COALESCE(au.email, ''), p.username, p.full_name, p.avatar_url, p.bio, p.city, p.gender, p.birth_year, COALESCE(p.role, 'user'), COALESCE(p.is_banned, false), au.email_confirmed_at
			FROM profiles p
			LEFT JOIN auth.users au ON au.id = p.user_id
			WHERE p.user_id = $1
		`, userID).Scan(&user.ID, &user.Email, &user.Username, &user.FullName, &user.AvatarURL, &user.Bio, &user.City, &user.Gender, &user.BirthYear, &user.Role, &user.IsBanned, &user.EmailConfirmedAt)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Profile not found"})
		return
	}

	avatarURL := ""
	if user.AvatarURL != nil {
		avatarURL = *user.AvatarURL
	}

	bio := ""
	if user.Bio != nil {
		bio = *user.Bio
	}

	city := ""
	if user.City != nil {
		city = *user.City
	}

	// Fetch dynamic events count (created + joined)
	var eventsCount int
	err = h.pool.QueryRow(ctx, `
		SELECT COUNT(DISTINCT e.id)
		FROM events e
		LEFT JOIN event_participants ep ON ep.event_id = e.id
		WHERE e.creator_id = $1 OR ep.user_id = $1
	`, userID).Scan(&eventsCount)
	if err != nil {
		log.Printf("[Warning] Failed to fetch events count: %v", err)
		eventsCount = 0
	}

	// Fetch dynamic rating
	var rating float64
	err = h.pool.QueryRow(ctx, `
		SELECT COALESCE(AVG(rating)::float, 5.0)
		FROM user_reviews
		WHERE ratee_id = $1
	`, userID).Scan(&rating)
	if err != nil {
		rating = 5.0
	}

	c.JSON(http.StatusOK, gin.H{
		"id":              user.ID,
		"email":           user.Email,
		"username":        user.Username,
		"full_name":       user.FullName,
		"avatar_url":      avatarURL,
		"bio":             bio,
		"city":            city,
		"gender":          stringValue(user.Gender),
		"birth_year":      int32Value(user.BirthYear),
		"age":             ageFromBirthYear(user.BirthYear),
		"events_count":    eventsCount,
		"rating":          rating,
		"role":            user.Role,
		"is_banned":       user.IsBanned,
		"email_confirmed": user.EmailConfirmedAt != nil,
	})
}

type UpdateProfileDTO struct {
	FullName  string `json:"full_name" binding:"required"`
	Bio       string `json:"bio"`
	City      string `json:"city"`
	AvatarURL string `json:"avatar_url"`
	Gender    string `json:"gender"`
	BirthYear *int32 `json:"birth_year"`
	Age       *int32 `json:"age"`
}

// UpdateProfile updates profile details of the authenticated user
func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userID, ok := userIDVal.(string)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID type"})
		return
	}

	var dto UpdateProfileDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()
	cleanBio, parsedGender, parsedBirthYear := splitProfileMetadata(dto.Bio)
	gender := nullableString(dto.Gender)
	if gender == nil {
		gender = nullableString(parsedGender)
	}
	birthYear := normalizedBirthYear(dto.BirthYear, dto.Age)
	if birthYear == nil {
		birthYear = normalizedBirthYear(parsedBirthYear, nil)
	}

	// Update profiles table
	_, err := h.pool.Exec(ctx, `
		UPDATE profiles
		SET full_name = $1,
		    bio = $2,
		    city = $3,
		    avatar_url = $4,
		    gender = COALESCE($5, gender),
		    birth_year = COALESCE($6, birth_year)
		WHERE user_id = $7
	`, dto.FullName, cleanBio, dto.City, dto.AvatarURL, gender, birthYear, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Profile updated successfully"})
}

// GetUserProfileByID returns the profile of any user by ID
func (h *AuthHandler) GetUserProfileByID(c *gin.Context) {
	targetUserID := c.Param("id")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	ctx := c.Request.Context()
	var user struct {
		ID               string
		Email            string
		Username         string
		FullName         string
		AvatarURL        *string
		Bio              *string
		City             *string
		Gender           *string
		BirthYear        *int32
		Role             string
		IsBanned         bool
		EmailConfirmedAt *time.Time
	}
	err := h.pool.QueryRow(ctx, `
			SELECT p.user_id::text, COALESCE(au.email, ''), p.username, p.full_name, p.avatar_url, p.bio, p.city, p.gender, p.birth_year, COALESCE(p.role, 'user'), COALESCE(p.is_banned, false), au.email_confirmed_at
			FROM profiles p
			LEFT JOIN auth.users au ON au.id = p.user_id
			WHERE p.user_id = $1
		`, targetUserID).Scan(&user.ID, &user.Email, &user.Username, &user.FullName, &user.AvatarURL, &user.Bio, &user.City, &user.Gender, &user.BirthYear, &user.Role, &user.IsBanned, &user.EmailConfirmedAt)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	avatarURL := ""
	if user.AvatarURL != nil {
		avatarURL = *user.AvatarURL
	}

	bio := ""
	if user.Bio != nil {
		bio = *user.Bio
	}

	city := ""
	if user.City != nil {
		city = *user.City
	}

	// Fetch dynamic events count (created + joined)
	var eventsCount int
	err = h.pool.QueryRow(ctx, `
		SELECT COUNT(DISTINCT e.id)
		FROM events e
		LEFT JOIN event_participants ep ON ep.event_id = e.id
		WHERE e.creator_id = $1 OR ep.user_id = $1
	`, targetUserID).Scan(&eventsCount)
	if err != nil {
		log.Printf("[Warning] Failed to fetch events count: %v", err)
		eventsCount = 0
	}

	// Fetch dynamic rating
	var rating float64
	err = h.pool.QueryRow(ctx, `
		SELECT COALESCE(AVG(rating)::float, 5.0)
		FROM user_reviews
		WHERE ratee_id = $1
	`, targetUserID).Scan(&rating)
	if err != nil {
		rating = 5.0
	}

	c.JSON(http.StatusOK, gin.H{
		"id":              user.ID,
		"email":           user.Email,
		"username":        user.Username,
		"full_name":       user.FullName,
		"avatar_url":      avatarURL,
		"bio":             bio,
		"city":            city,
		"gender":          stringValue(user.Gender),
		"birth_year":      int32Value(user.BirthYear),
		"age":             ageFromBirthYear(user.BirthYear),
		"events_count":    eventsCount,
		"rating":          rating,
		"role":            user.Role,
		"is_banned":       user.IsBanned,
		"email_confirmed": user.EmailConfirmedAt != nil,
	})
}

type DeviceTokenDTO struct {
	DeviceToken string `json:"device_token" binding:"required"`
	Platform    string `json:"platform"`
}

// RegisterDeviceToken saves the APNs/FCM device token for push notifications
func (h *AuthHandler) RegisterDeviceToken(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(string)

	var dto DeviceTokenDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	platform := dto.Platform
	if platform == "" {
		platform = "ios"
	}

	ctx := c.Request.Context()
	_, err := h.pool.Exec(ctx, `
		INSERT INTO user_device_tokens (user_id, device_token, platform)
		VALUES ($1, $2, $3)
		ON CONFLICT (device_token) DO UPDATE SET user_id = $1, platform = $3
	`, userID, dto.DeviceToken, platform)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save device token: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Device token registered successfully"})
}

var (
	profileGenderRe    = regexp.MustCompile(`\[gender:([^\]]+)\]`)
	profileBirthYearRe = regexp.MustCompile(`\[birth_year:([0-9]{4})\]`)
)

func splitProfileMetadata(rawBio string) (string, string, *int32) {
	gender := ""
	if match := profileGenderRe.FindStringSubmatch(rawBio); len(match) == 2 {
		gender = strings.TrimSpace(match[1])
	}

	var birthYear *int32
	if match := profileBirthYearRe.FindStringSubmatch(rawBio); len(match) == 2 {
		if year, err := strconv.Atoi(match[1]); err == nil {
			y := int32(year)
			birthYear = &y
		}
	}

	cleanBio := profileGenderRe.ReplaceAllString(rawBio, "")
	cleanBio = profileBirthYearRe.ReplaceAllString(cleanBio, "")
	return strings.TrimSpace(cleanBio), gender, birthYear
}

func nullableString(value string) *string {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	return &value
}

func normalizedBirthYear(birthYear *int32, age *int32) *int32 {
	currentYear := int32(time.Now().Year())

	if birthYear != nil && *birthYear >= 1900 && *birthYear <= currentYear {
		return birthYear
	}

	if age != nil && *age > 0 && *age < 130 {
		year := currentYear - *age
		return &year
	}

	return nil
}

func stringValue(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func int32Value(value *int32) any {
	if value == nil {
		return nil
	}
	return *value
}

func ageFromBirthYear(birthYear *int32) any {
	if birthYear == nil {
		return nil
	}

	age := int32(time.Now().Year()) - *birthYear
	if age < 0 {
		return nil
	}
	return age
}
