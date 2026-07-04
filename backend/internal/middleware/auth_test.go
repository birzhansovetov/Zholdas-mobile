package middleware

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

const testSecret = "my_secret_key_for_testing"
const testUserID = "11111111-1111-1111-1111-111111111111"

func generateSupabaseTestToken(subject string, secret string) (string, error) {
	claims := &Claims{
		Email: "test@example.com",
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   subject,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

func TestTokenGenerationAndParsing(t *testing.T) {
	tokenStr, err := generateSupabaseTestToken(testUserID, testSecret)
	if err != nil {
		t.Fatalf("Failed to generate token: %v", err)
	}

	claims, err := ParseToken(tokenStr, testSecret)
	if err != nil {
		t.Fatalf("Failed to parse token: %v", err)
	}

	if claims.Subject != testUserID {
		t.Errorf("Expected subject %s, got %s", testUserID, claims.Subject)
	}
}

func TestInvalidTokenSignature(t *testing.T) {
	tokenStr, _ := generateSupabaseTestToken(testUserID, testSecret)

	// Parse with a different secret
	_, err := ParseToken(tokenStr, "different_secret_key")
	if err == nil {
		t.Error("Expected parsing to fail with incorrect secret signature, but it succeeded")
	}
}

func TestExpiredToken(t *testing.T) {
	// Create an already expired token manually
	claims := &Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   testUserID,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(-1 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(time.Now().Add(-2 * time.Minute)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, _ := token.SignedString([]byte(testSecret))

	_, err := ParseToken(tokenStr, testSecret)
	if err == nil {
		t.Error("Expected parsing of expired token to fail, but it succeeded")
	}
}

func TestAuthMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(AuthMiddleware(testSecret, nil))
	r.GET("/test", func(c *gin.Context) {
		userID, exists := c.Get("user_id")
		if !exists {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "user_id not set"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"user_id": userID})
	})

	t.Run("Missing Header", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/test", nil)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusUnauthorized {
			t.Errorf("Expected status 401, got %d", w.Code)
		}
	})

	t.Run("Malformed Header", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/test", nil)
		req.Header.Set("Authorization", "Bearer")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusUnauthorized {
			t.Errorf("Expected status 401, got %d", w.Code)
		}
	})

	t.Run("Invalid Token", func(t *testing.T) {
		req, _ := http.NewRequest("GET", "/test", nil)
		req.Header.Set("Authorization", "Bearer invalidtokenhere")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusUnauthorized {
			t.Errorf("Expected status 401, got %d", w.Code)
		}
	})

	t.Run("Valid Token", func(t *testing.T) {
		tokenStr, _ := generateSupabaseTestToken(testUserID, testSecret)
		req, _ := http.NewRequest("GET", "/test", nil)
		req.Header.Set("Authorization", "Bearer "+tokenStr)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("Expected status 200, got %d. Body: %s", w.Code, w.Body.String())
		}

		var res struct {
			UserID string `json:"user_id"`
		}
		err := json.Unmarshal(w.Body.Bytes(), &res)
		if err != nil {
			t.Fatalf("Failed to decode JSON response: %v", err)
		}
		if res.UserID != testUserID {
			t.Errorf("Expected injected user_id %s, got %s", testUserID, res.UserID)
		}
	})
}
