package handler

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type RateParticipantDTO struct {
	RateeID string `json:"ratee_id" binding:"required"`
	Rating  int    `json:"rating" binding:"required,min=1,max=5"`
	Comment string `json:"comment"`
}

type UserReviewResponse struct {
	ID                 int32     `json:"id"`
	EvaluatorName      string    `json:"evaluator_name"`
	EvaluatorAvatarURL string    `json:"evaluator_avatar_url"`
	Rating             int       `json:"rating"`
	Comment            string    `json:"comment"`
	CreatedAt          time.Time `json:"created_at"`
}

// RateParticipant submits a review for another participant of a completed event
func (h *AuthHandler) RateParticipant(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	currentUserID := userIDVal.(string)

	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	var dto RateParticipantDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if currentUserID == dto.RateeID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot rate yourself"})
		return
	}

	ctx := c.Request.Context()

	// 1. Verify event exists and has ended
	var endTime time.Time
	var creatorID string
	err = h.pool.QueryRow(ctx, "SELECT end_time, creator_id::text FROM events WHERE id = $1", eventID).Scan(&endTime, &creatorID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
		return
	}

	if time.Now().Before(endTime) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Event has not ended yet. Rating is only allowed after completion."})
		return
	}

	// 2. Verify evaluator (current user) is participant or creator
	var isEvaluatorParticipant bool
	if currentUserID == creatorID {
		isEvaluatorParticipant = true
	} else {
		err = h.pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM event_participants WHERE event_id = $1 AND user_id = $2)", eventID, currentUserID).Scan(&isEvaluatorParticipant)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check evaluator participation status"})
			return
		}
	}

	if !isEvaluatorParticipant {
		c.JSON(http.StatusForbidden, gin.H{"error": "You are not a participant or organizer of this event"})
		return
	}

	// 3. Verify ratee (target user) is participant or creator
	var isRateeParticipant bool
	if dto.RateeID == creatorID {
		isRateeParticipant = true
	} else {
		err = h.pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM event_participants WHERE event_id = $1 AND user_id = $2)", eventID, dto.RateeID).Scan(&isRateeParticipant)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check target user participation status"})
			return
		}
	}

	if !isRateeParticipant {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Target user is not a participant or organizer of this event"})
		return
	}

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	// 4. Insert the review
	_, err = tx.Exec(ctx, `
		INSERT INTO user_reviews (evaluator_id, ratee_id, event_id, rating, comment)
		VALUES ($1, $2, $3, $4, $5)
	`, currentUserID, dto.RateeID, eventID, dto.Rating, dto.Comment)
	if err != nil {
		// Unique key violation or other constraint
		c.JSON(http.StatusBadRequest, gin.H{"error": "You have already rated this participant for this event"})
		return
	}

	// 5. Create notification for target user
	var evaluatorName string
	_ = tx.QueryRow(ctx, "SELECT full_name FROM profiles WHERE user_id = $1", currentUserID).Scan(&evaluatorName)
	if evaluatorName == "" {
		evaluatorName = "Пользователь"
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO notifications (user_id, actor_id, notification_type, text)
		VALUES ($1, $2, 'user_rate', $3)
	`, dto.RateeID, currentUserID, fmt.Sprintf("%s оценил вас на %d звезд за событие!", evaluatorName, dto.Rating))
	if err != nil {
		log.Printf("[Warning] Failed to create notification for rating: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Rating submitted successfully"})
}

// GetUserReviews returns all reviews submitted for a user
func (h *AuthHandler) GetUserReviews(c *gin.Context) {
	targetUserID := c.Param("id")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	ctx := c.Request.Context()

	rows, err := h.pool.Query(ctx, `
		SELECT r.id, p.full_name, p.avatar_url, r.rating, r.comment, r.created_at
		FROM user_reviews r
		JOIN profiles p ON p.user_id = r.evaluator_id
		WHERE r.ratee_id = $1
		ORDER BY r.created_at DESC
	`, targetUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to query reviews: " + err.Error()})
		return
	}
	defer rows.Close()

	reviews := []UserReviewResponse{}
	for rows.Next() {
		var id int32
		var evaluatorName string
		var avatarURL, comment *string
		var rating int
		var createdAt time.Time

		err = rows.Scan(&id, &evaluatorName, &avatarURL, &rating, &comment, &createdAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan review row"})
			return
		}

		responseItem := UserReviewResponse{
			ID:            id,
			EvaluatorName: evaluatorName,
			Rating:        rating,
			CreatedAt:     createdAt,
		}

		if avatarURL != nil {
			responseItem.EvaluatorAvatarURL = *avatarURL
		} else {
			responseItem.EvaluatorAvatarURL = ""
		}

		if comment != nil {
			responseItem.Comment = *comment
		} else {
			responseItem.Comment = ""
		}

		reviews = append(reviews, responseItem)
	}

	c.JSON(http.StatusOK, reviews)
}
