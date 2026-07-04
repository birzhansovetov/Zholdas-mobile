package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestAIRateLimiter_Allow(t *testing.T) {
	limiter := NewAIRateLimiter()
	userID := "11111111-1111-1111-1111-111111111111"

	lim := limiter.GetLimiter(userID)

	// Consume 3 burst tokens
	if !lim.Allow() {
		t.Error("Expected 1st request to be allowed")
	}
	if !lim.Allow() {
		t.Error("Expected 2nd request to be allowed")
	}
	if !lim.Allow() {
		t.Error("Expected 3rd request to be allowed")
	}

	// 4th request must be rate limited
	if lim.Allow() {
		t.Error("Expected 4th request to be rate limited, but it was allowed")
	}
}

func TestRateLimitMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	limiter := NewAIRateLimiter()

	r := gin.New()
	// Set user_id mock injector for test
	r.Use(func(c *gin.Context) {
		if c.Request.Header.Get("X-No-User") == "true" {
			c.Next()
			return
		}
		c.Set("user_id", "11111111-1111-1111-1111-111111111111")
		c.Next()
	})
	r.Use(RateLimitMiddleware(limiter))
	r.GET("/ai", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	t.Run("Missing User Context", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/ai", nil)
		req.Header.Set("X-No-User", "true")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusUnauthorized {
			t.Errorf("Expected status 401, got %d", w.Code)
		}
	})

	t.Run("Allows up to burst of 3", func(t *testing.T) {
		// Fresh limiter for clean test
		lim := NewAIRateLimiter()
		app := gin.New()
		app.Use(func(c *gin.Context) {
			c.Set("user_id", "22222222-2222-2222-2222-222222222222")
			c.Next()
		})
		app.Use(RateLimitMiddleware(lim))
		app.GET("/ai", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"status": "ok"})
		})

		for i := 1; i <= 3; i++ {
			req, _ := http.NewRequest("GET", "/ai", nil)
			w := httptest.NewRecorder()
			app.ServeHTTP(w, req)

			if w.Code != http.StatusOK {
				t.Errorf("Request %d: expected status 200, got %d", i, w.Code)
			}
		}

		// 4th request must be blocked (429)
		req, _ := http.NewRequest("GET", "/ai", nil)
		w := httptest.NewRecorder()
		app.ServeHTTP(w, req)

		if w.Code != http.StatusTooManyRequests {
			t.Errorf("Request 4: expected status 429, got %d", w.Code)
		}
	})
}
