package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type client struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

type AIRateLimiter struct {
	mu      sync.RWMutex
	clients map[string]*client
	r       rate.Limit
	b       int
}

// NewAIRateLimiter initializes the rate limiter.
// Recover 1 token every 2 minutes (rate.Every(2 * time.Minute)) with a burst of 3.
func NewAIRateLimiter() *AIRateLimiter {
	i := &AIRateLimiter{
		clients: make(map[string]*client),
		r:       rate.Every(2 * time.Minute),
		b:       3,
	}

	go i.cleanupClients()

	return i
}

func (i *AIRateLimiter) GetLimiter(userID string) *rate.Limiter {
	i.mu.Lock()
	defer i.mu.Unlock()

	c, exists := i.clients[userID]
	if !exists {
		limiter := rate.NewLimiter(i.r, i.b)
		i.clients[userID] = &client{limiter: limiter, lastSeen: time.Now()}
		return limiter
	}

	c.lastSeen = time.Now()
	return c.limiter
}

func (i *AIRateLimiter) cleanupClients() {
	for {
		time.Sleep(1 * time.Hour)

		i.mu.Lock()
		for userID, c := range i.clients {
			if time.Since(c.lastSeen) > 1*time.Hour {
				delete(i.clients, userID)
			}
		}
		i.mu.Unlock()
	}
}

func RateLimitMiddleware(limiter *AIRateLimiter) gin.HandlerFunc {
	return func(c *gin.Context) {
		userIDVal, exists := c.Get("user_id")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User ID not found in context"})
			c.Abort()
			return
		}

		userID, ok := userIDVal.(string)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
			c.Abort()
			return
		}

		lim := limiter.GetLimiter(userID)
		if !lim.Allow() {
			c.JSON(http.StatusTooManyRequests, gin.H{"error": "Rate limit exceeded. Allowed 3 requests burst, restoring 1 request every 2 minutes."})
			c.Abort()
			return
		}

		c.Next()
	}
}
