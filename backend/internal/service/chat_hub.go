package service

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

const (
	sendBufferSize = 256
)

// Client represents a connected user socket
type Client struct {
	Hub     *ChatHub
	EventID int32
	Conn    *websocket.Conn
	Send    chan []byte
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
