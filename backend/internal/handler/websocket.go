package handler

import (
	"log"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"github.com/birzhansovetov/zholdas-backend/internal/middleware"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// WebSocketChatUpgrader upgrades HTTP requests to WebSocket connection for event chats
func (h *EventHandler) WebSocketChatUpgrader(c *gin.Context) {
	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	tokenStr := c.Query("token")
	if tokenStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Authentication token query param is required"})
		return
	}

	claims, err := middleware.ParseToken(tokenStr, h.jwtSecret)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
		return
	}

	ctx := c.Request.Context()

	var isBanned bool
	userID := claims.Subject
	err = h.pool.QueryRow(ctx, "SELECT is_banned FROM profiles WHERE user_id = $1", userID).Scan(&isBanned)
	if err == nil && isBanned {
		c.JSON(http.StatusForbidden, gin.H{"error": "User is banned"})
		return
	}

	var isMember bool
	err = h.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM events WHERE id = $1 AND creator_id = $2
			UNION ALL
			SELECT 1 FROM event_participants WHERE event_id = $1 AND user_id = $2
		)
	`, int32(eventID), userID).Scan(&isMember)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error checking membership: " + err.Error()})
		return
	}

	if !isMember {
		c.JSON(http.StatusForbidden, gin.H{"error": "Вы не являетесь участником этого события"})
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("[WebSocket Upgrade Error] eventID=%d, userID=%s: %v", eventID, userID, err)
		return
	}

	h.ChatHub.Register(int32(eventID), conn)

	go func(eventID int32, conn *websocket.Conn) {
		defer func() {
			h.ChatHub.Unregister(eventID, conn)
		}()

		for {
			_, _, err := conn.ReadMessage()
			if err != nil {
				break
			}
		}
	}(int32(eventID), conn)
}
