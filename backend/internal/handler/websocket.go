package handler

import (
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"github.com/birzhansovetov/zholdas-backend/internal/middleware"
	"github.com/birzhansovetov/zholdas-backend/internal/service"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = 25 * time.Second
	maxMessageSize = 8192
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

	claims, err := middleware.ParseTokenWithConfig(tokenStr, h.tokenConfig)
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

	client := h.ChatHub.Register(int32(eventID), conn)

	go h.writePump(client)
	go h.readPump(client)
}

func (h *EventHandler) readPump(client *service.Client) {
	defer func() {
		h.ChatHub.Unregister(client)
	}()

	client.Conn.SetReadLimit(maxMessageSize)
	_ = client.Conn.SetReadDeadline(time.Now().Add(pongWait))
	client.Conn.SetPongHandler(func(string) error {
		_ = client.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, _, err := client.Conn.ReadMessage()
		if err != nil {
			break
		}
	}
}

func (h *EventHandler) writePump(client *service.Client) {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		h.ChatHub.Unregister(client)
	}()

	for {
		select {
		case message, ok := <-client.Send:
			_ = client.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = client.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := client.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			_ = client.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := client.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
