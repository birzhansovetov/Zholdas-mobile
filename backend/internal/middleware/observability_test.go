package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestRequestIDMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.Use(RequestIDMiddleware())
	router.GET("/health", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	t.Run("preserves safe request ID", func(t *testing.T) {
		request := httptest.NewRequest(http.MethodGet, "/health", nil)
		request.Header.Set(requestIDHeader, "client-request_123")
		response := httptest.NewRecorder()
		router.ServeHTTP(response, request)
		if got := response.Header().Get(requestIDHeader); got != "client-request_123" {
			t.Fatalf("unexpected request ID %q", got)
		}
	})

	t.Run("replaces unsafe request ID", func(t *testing.T) {
		request := httptest.NewRequest(http.MethodGet, "/health", nil)
		request.Header.Set(requestIDHeader, "unsafe\nvalue")
		response := httptest.NewRecorder()
		router.ServeHTTP(response, request)
		if got := response.Header().Get(requestIDHeader); got == "" || got == "unsafe\nvalue" {
			t.Fatalf("expected generated request ID, got %q", got)
		}
	})
}
