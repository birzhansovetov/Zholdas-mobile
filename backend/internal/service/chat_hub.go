package service

import (
	"sync"

	"github.com/gorilla/websocket"
)

// Client represents a connected user socket
type Client struct {
	EventID int32
	Conn    *websocket.Conn
}

// ChatHub manages active websocket connections per event chat room
type ChatHub struct {
	mu      sync.RWMutex
	clients map[int32]map[*websocket.Conn]bool
}

// NewChatHub creates a new instance of ChatHub
func NewChatHub() *ChatHub {
	return &ChatHub{
		clients: make(map[int32]map[*websocket.Conn]bool),
	}
}

// Register adds a connection for a specific event
func (h *ChatHub) Register(eventID int32, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if _, exists := h.clients[eventID]; !exists {
		h.clients[eventID] = make(map[*websocket.Conn]bool)
	}
	h.clients[eventID][conn] = true
}

// Unregister removes a connection for a specific event
func (h *ChatHub) Unregister(eventID int32, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if connections, exists := h.clients[eventID]; exists {
		if _, ok := connections[conn]; ok {
			delete(connections, conn)
			_ = conn.Close()
		}
		if len(connections) == 0 {
			delete(h.clients, eventID)
		}
	}
}

// BroadcastMessage sends a message to all connected clients for a specific event
func (h *ChatHub) BroadcastMessage(eventID int32, message interface{}) {
	h.mu.RLock()
	var targets []*websocket.Conn
	if connections, exists := h.clients[eventID]; exists {
		for conn := range connections {
			targets = append(targets, conn)
		}
	}
	h.mu.RUnlock()

	if len(targets) == 0 {
		return
	}

	for _, conn := range targets {
		go func(c *websocket.Conn) {
			err := c.WriteJSON(message)
			if err != nil {
				h.Unregister(eventID, c)
			}
		}(conn)
	}
}
