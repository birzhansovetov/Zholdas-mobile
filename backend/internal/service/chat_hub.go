package service

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = 25 * time.Second
	maxMessageSize = 8192
	sendBufferSize = 256
)

// Client represents a connected user socket
type Client struct {
	Hub     *ChatHub
	EventID int32
	Conn    *websocket.Conn
	Send    chan []byte
}

// ReadPump pumps messages from the websocket connection to the hub.
func (c *Client) ReadPump() {
	defer func() {
		c.Hub.Unregister(c)
	}()

	c.Conn.SetReadLimit(maxMessageSize)
	_ = c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		_ = c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, _, err := c.Conn.ReadMessage()
		if err != nil {
			break
		}
	}
}

// WritePump pumps messages from the hub to the websocket connection.
func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Hub.Unregister(c)
	}()

	for {
		select {
		case message, ok := <-c.Send:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// ChatHub manages active websocket connections per event chat room
type ChatHub struct {
	mu      sync.RWMutex
	clients map[int32]map[*Client]bool
}

// NewChatHub creates a new instance of ChatHub
func NewChatHub() *ChatHub {
	return &ChatHub{
		clients: make(map[int32]map[*Client]bool),
	}
}

// Register adds a connection for a specific event and returns a new Client
func (h *ChatHub) Register(eventID int32, conn *websocket.Conn) *Client {
	client := &Client{
		Hub:     h,
		EventID: eventID,
		Conn:    conn,
		Send:    make(chan []byte, sendBufferSize),
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	if _, exists := h.clients[eventID]; !exists {
		h.clients[eventID] = make(map[*Client]bool)
	}
	h.clients[eventID][client] = true

	return client
}

// Unregister removes a connection for a specific event and cleans up its resources
func (h *ChatHub) Unregister(client *Client) {
	if client == nil {
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	if connections, exists := h.clients[client.EventID]; exists {
		if _, ok := connections[client]; ok {
			delete(connections, client)
			close(client.Send)
			_ = client.Conn.Close()
		}
		if len(connections) == 0 {
			delete(h.clients, client.EventID)
		}
	}
}

// UnregisterConn removes a connection for a specific event by websocket.Conn (backward compatibility)
func (h *ChatHub) UnregisterConn(eventID int32, conn *websocket.Conn) {
	if conn == nil {
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	if connections, exists := h.clients[eventID]; exists {
		for client := range connections {
			if client.Conn == conn {
				delete(connections, client)
				close(client.Send)
				_ = client.Conn.Close()
				break
			}
		}
		if len(connections) == 0 {
			delete(h.clients, eventID)
		}
	}
}

// BroadcastMessage sends a message to all connected clients for a specific event
func (h *ChatHub) BroadcastMessage(eventID int32, message interface{}) {
	var data []byte
	var err error
	switch v := message.(type) {
	case []byte:
		data = v
	case string:
		data = []byte(v)
	default:
		data, err = json.Marshal(v)
		if err != nil {
			log.Printf("[ChatHub] Failed to marshal broadcast message: %v", err)
			return
		}
	}

	h.mu.RLock()
	var slowClients []*Client
	if connections, exists := h.clients[eventID]; exists {
		for client := range connections {
			select {
			case client.Send <- data:
			default:
				slowClients = append(slowClients, client)
			}
		}
	}
	h.mu.RUnlock()

	for _, client := range slowClients {
		log.Printf("[ChatHub] Client buffer full, disconnecting slow client for eventID=%d", eventID)
		h.Unregister(client)
	}
}
