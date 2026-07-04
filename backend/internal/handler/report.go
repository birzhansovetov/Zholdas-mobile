package handler

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

type CreateReportDTO struct {
	ReportedUserID *string `json:"reported_user_id"`
	EventID        *int32  `json:"event_id"`
	MessageID      *int32  `json:"message_id"`
	Reason         string  `json:"reason" binding:"required"`
	Description    string  `json:"description"`
}

// CreateReport handles submitting reports on users, events, or messages
func (h *AuthHandler) CreateReport(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	reporterID := userIDVal.(string)

	var dto CreateReportDTO
	if err := c.ShouldBindJSON(&dto); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if dto.ReportedUserID == nil && dto.EventID == nil && dto.MessageID == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "At least one target (reported_user_id, event_id, or message_id) must be specified"})
		return
	}

	ctx := c.Request.Context()

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	// 1. Insert report
	_, err = tx.Exec(ctx, `
		INSERT INTO reports (reporter_id, reported_user_id, event_id, message_id, reason, description)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, reporterID, dto.ReportedUserID, dto.EventID, dto.MessageID, dto.Reason, dto.Description)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save report: " + err.Error()})
		return
	}

	// 2. Commit first before doing post-report checks to make sure DB state is committed
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit report transaction"})
		return
	}

	// 3. Post-report auto moderation check:
	// If it's an event report, count reports on this event. If >= 3, block it!
	if dto.EventID != nil {
		var reportsCount int
		err = h.pool.QueryRow(ctx, `
			SELECT COUNT(DISTINCT reporter_id)
			FROM reports
			WHERE event_id = $1
		`, *dto.EventID).Scan(&reportsCount)
		if err != nil {
			log.Printf("[Warning] Failed to count event reports: %v", err)
		} else if reportsCount >= 3 {
			log.Printf("[Auto Moderation Block] Event ID %d has reached %d reports. Blocking it.", *dto.EventID, reportsCount)

			// Get event creator ID and title for notification
			var creatorID string
			var title string
			err = h.pool.QueryRow(ctx, "SELECT creator_id::text, title FROM events WHERE id = $1", *dto.EventID).Scan(&creatorID, &title)
			if err == nil {
				// Mark event as blocked in DB
				_, err = h.pool.Exec(ctx, "UPDATE events SET status = 'blocked' WHERE id = $1", *dto.EventID)
				if err != nil {
					log.Printf("[Error] Failed to update event status to blocked: %v", err)
				} else {
					// Create push notification for block
					msgText := "Ваше событие '" + title + "' заблокировано из-за жалоб участников."
					_, err = h.pool.Exec(ctx, `
						INSERT INTO notifications (user_id, actor_id, notification_type, text)
						VALUES ($1, $2, 'event_block', $3)
					`, creatorID, reporterID, msgText)
					if err != nil {
						log.Printf("[Warning] Failed to insert event block notification: %v", err)
					}

					if h.notificationService != nil {
						h.notificationService.SendPush(creatorID, msgText)
					}
				}
			}
		}
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Report submitted successfully"})
}
