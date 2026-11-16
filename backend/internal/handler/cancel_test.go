package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestCancelEvent_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := &EventHandler{}

	r := gin.New()
	r.POST("/events/:id/cancel", h.CancelEvent)

	req := httptest.NewRequest(http.MethodPost, "/events/1/cancel", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401 Unauthorized, got %d", w.Code)
	}

	var body map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse json response: %v", err)
	}
	if body["error"] != "Unauthorized" {
		t.Errorf("expected error 'Unauthorized', got %q", body["error"])
	}
}

func TestCancelEvent_InvalidEventID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := &EventHandler{}

	r := gin.New()
	r.POST("/events/:id/cancel", func(c *gin.Context) {
		c.Set("user_id", "test-user-uuid")
		h.CancelEvent(c)
	})

	invalidIDs := []string{"abc", "0", "-1", "xyz123", "3.14"}
	for _, id := range invalidIDs {
		t.Run("id_"+id, func(t *testing.T) {
			w := httptest.NewRecorder()
			req := httptest.NewRequest(http.MethodPost, "/events/"+id+"/cancel", nil)
			r.ServeHTTP(w, req)

			if w.Code != http.StatusBadRequest {
				t.Fatalf("expected status 400 Bad Request for id %q, got %d", id, w.Code)
			}

			var body map[string]string
			if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
				t.Fatalf("failed to parse json response: %v", err)
			}
			if body["error"] != "Invalid event ID" {
				t.Errorf("expected error 'Invalid event ID', got %q", body["error"])
			}
		})
	}
}

func TestCancelEvent_NoDatabaseFailsClosed(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := &EventHandler{} // pool is nil

	r := gin.New()
	r.POST("/events/:id/cancel", func(c *gin.Context) {
		c.Set("user_id", "test-user-uuid")
		h.CancelEvent(c)
	})

	req := httptest.NewRequest(http.MethodPost, "/events/42/cancel", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected status 500 Internal Server Error when pool is nil, got %d", w.Code)
	}

	var body map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse json response: %v", err)
	}
	if body["error"] != "Database unavailable" {
		t.Errorf("expected error 'Database unavailable', got %q", body["error"])
	}
}
