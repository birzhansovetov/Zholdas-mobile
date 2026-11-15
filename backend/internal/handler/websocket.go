package handler

import (
	"context"
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

// checkChatAccess checks whether the user is banned and whether they are the creator or a participant of the event.
func (h *EventHandler) checkChatAccess(ctx context.Context, userID string, eventID int32) (int, string) {
	if h.pool == nil {
		// Never grant chat access without a database check.
		return http.StatusInternalServerError, "Database unavailable"
	}

	var isBanned bool
	err := h.pool.QueryRow(ctx, "SELECT is_banned FROM profiles WHERE user_id = $1", userID).Scan(&isBanned)
	if err == nil && isBanned {
		return http.StatusForbidden, "User is banned"
	}

	var isMember bool
	err = h.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM events WHERE id = $1 AND creator_id = $2
			UNION ALL
			SELECT 1 FROM event_participants WHERE event_id = $1 AND user_id = $2
		)
	`, eventID, userID).Scan(&isMember)
	if err != nil {
		return http.StatusInternalServerError, "Database error checking membership: " + err.Error()
	}

	if !isMember {
		return http.StatusForbidden, "Вы не являетесь участником этого события"
	}

	return 0, ""
}

// CreateWebSocketTicket issues a short-lived one-time ticket for event WebSocket chat.
func (h *EventHandler) CreateWebSocketTicket(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID, ok := userIDVal.(string)
	if !ok || userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	ctx := c.Request.Context()
	if status, errMsg := h.checkChatAccess(ctx, userID, int32(eventID)); status != 0 {
		c.JSON(status, gin.H{"error": errMsg})
		return
	}

	key := DeriveWSTicketKey(h.tokenConfig.Secret)
	ticket, err := IssueWSTicket(userID, int32(eventID), key, time.Now())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create ticket"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"ticket":     ticket,
		"expires_in": WSTicketExpiresInSeconds,
	})
}

// WebSocketChatUpgrader upgrades HTTP requests to WebSocket connection for event chats
func (h *EventHandler) WebSocketChatUpgrader(c *gin.Context) {
	eventIDStr := c.Param("id")
	eventID, err := strconv.Atoi(eventIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
		return
	}

	ticketStr := c.Query("ticket")
	tokenStr := c.Query("token")

	if ticketStr == "" && tokenStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Authentication ticket or token query param is required"})
		return
	}

	var userID string
	if ticketStr != "" {
		key := DeriveWSTicketKey(h.tokenConfig.Secret)
		claims, err := ValidateWSTicket(ticketStr, int32(eventID), key, time.Now(), h.getTicketStore())
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired ticket"})
			return
		}
		userID = claims.Subject
	} else {
		// deprecated: remove after clients move to ws-ticket
		claims, err := middleware.ParseTokenWithConfig(tokenStr, h.tokenConfig)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
			return
		}
		userID = claims.Subject
	}

	ctx := c.Request.Context()
	if status, errMsg := h.checkChatAccess(ctx, userID, int32(eventID)); status != 0 {
		c.JSON(status, gin.H{"error": errMsg})
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
