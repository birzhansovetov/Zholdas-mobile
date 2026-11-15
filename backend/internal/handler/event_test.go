package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestParseEventID(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantID  int32
		wantErr bool
	}{
		{"valid standard id", "1", 1, false},
		{"valid large id", "123456", 123456, false},
		{"zero id", "0", 0, true},
		{"negative id", "-5", 0, true},
		{"alphanumeric", "12a", 0, true},
		{"string letters", "abc", 0, true},
		{"empty string", "", 0, true},
		{"whitespace", "   ", 0, true},
		{"float number", "12.34", 0, true},
		{"symbols", "#!?", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseEventID(tt.input)
			if (err != nil) != tt.wantErr {
				t.Fatalf("parseEventID(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
			}
			if got != tt.wantID {
				t.Errorf("parseEventID(%q) = %d, want %d", tt.input, got, tt.wantID)
			}
		})
	}
}

func TestGetEventDetails_InvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)

	h := &EventHandler{}

	r := gin.New()
	r.GET("/events/:id/details", h.GetEventDetails)

	invalidIDs := []string{"abc", "0", "-1", "xyz123", "3.14"}

	for _, id := range invalidIDs {
		t.Run("id_"+id, func(t *testing.T) {
			w := httptest.NewRecorder()
			req, _ := http.NewRequest(http.MethodGet, "/events/"+id+"/details", nil)
			r.ServeHTTP(w, req)

			if w.Code != http.StatusBadRequest {
				t.Errorf("expected 400 Bad Request for id %q, got %d", id, w.Code)
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
