package middleware

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Claims struct {
	Email string `json:"email"`
	jwt.RegisteredClaims
}

type jwksResponse struct {
	Keys []jwk `json:"keys"`
}

type jwk struct {
	Kid string `json:"kid"`
	Kty string `json:"kty"`
	Alg string `json:"alg"`
	Use string `json:"use"`
	N   string `json:"n"`
	E   string `json:"e"`
	Crv string `json:"crv"`
	X   string `json:"x"`
	Y   string `json:"y"`
}

type jwksCacheEntry struct {
	keys      map[string]interface{}
	expiresAt time.Time
}

var (
	jwksCacheMu sync.Mutex
	jwksCache   = map[string]jwksCacheEntry{}
)

// ParseToken parses and validates a Supabase JWT. The user UUID is in the
// standard "sub" claim, which maps to auth.users.id.
func ParseToken(tokenStr string, secret string) (*Claims, error) {
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenStr, claims, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); ok {
			return []byte(secret), nil
		}

		if _, ok := token.Method.(*jwt.SigningMethodRSA); ok {
			return publicKeyForToken(tokenStr, token)
		}
		if _, ok := token.Method.(*jwt.SigningMethodECDSA); ok {
			return publicKeyForToken(tokenStr, token)
		}

		return nil, fmt.Errorf("unexpected signing method: %s", token.Method.Alg())
	})

	if err != nil {
		return nil, err
	}

	if !token.Valid {
		return nil, errors.New("invalid token")
	}
	if claims.Subject == "" {
		return nil, errors.New("missing subject")
	}

	return claims, nil
}

func publicKeyForToken(tokenStr string, token *jwt.Token) (interface{}, error) {
	kid, _ := token.Header["kid"].(string)
	if kid == "" {
		return nil, errors.New("missing key id")
	}

	unverified := &Claims{}
	_, _, err := jwt.NewParser().ParseUnverified(tokenStr, unverified)
	if err != nil {
		return nil, fmt.Errorf("parse unverified token: %w", err)
	}
	if unverified.Issuer == "" {
		return nil, errors.New("missing issuer")
	}

	keys, err := jwksForIssuer(unverified.Issuer)
	if err != nil {
		return nil, err
	}

	key, ok := keys[kid]
	if !ok {
		jwksCacheMu.Lock()
		delete(jwksCache, unverified.Issuer)
		jwksCacheMu.Unlock()

		keys, err = jwksForIssuer(unverified.Issuer)
		if err != nil {
			return nil, err
		}
		key, ok = keys[kid]
		if !ok {
			return nil, fmt.Errorf("jwks key not found: %s", kid)
		}
	}

	return key, nil
}

func jwksForIssuer(issuer string) (map[string]interface{}, error) {
	jwksCacheMu.Lock()
	entry, ok := jwksCache[issuer]
	if ok && time.Now().Before(entry.expiresAt) {
		keys := entry.keys
		jwksCacheMu.Unlock()
		return keys, nil
	}
	jwksCacheMu.Unlock()

	jwksURL := strings.TrimRight(issuer, "/") + "/.well-known/jwks.json"
	req, err := http.NewRequest(http.MethodGet, jwksURL, nil)
	if err != nil {
		return nil, err
	}

	client := &http.Client{Timeout: 5 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch jwks: %w", err)
	}
	defer res.Body.Close()

	if res.StatusCode < 200 || res.StatusCode > 299 {
		return nil, fmt.Errorf("fetch jwks: status %d", res.StatusCode)
	}

	var jwks jwksResponse
	if err := json.NewDecoder(res.Body).Decode(&jwks); err != nil {
		return nil, fmt.Errorf("decode jwks: %w", err)
	}

	keys := make(map[string]interface{}, len(jwks.Keys))
	for _, key := range jwks.Keys {
		publicKey, err := key.publicKey()
		if err != nil {
			return nil, err
		}
		keys[key.Kid] = publicKey
	}

	jwksCacheMu.Lock()
	jwksCache[issuer] = jwksCacheEntry{
		keys:      keys,
		expiresAt: time.Now().Add(10 * time.Minute),
	}
	jwksCacheMu.Unlock()

	return keys, nil
}

func (key jwk) publicKey() (interface{}, error) {
	switch key.Kty {
	case "RSA":
		return key.rsaPublicKey()
	case "EC":
		return key.ecdsaPublicKey()
	default:
		return nil, fmt.Errorf("unsupported jwk key type: %s", key.Kty)
	}
}

func (key jwk) rsaPublicKey() (*rsa.PublicKey, error) {
	nBytes, err := decodeJWKBase64(key.N)
	if err != nil {
		return nil, fmt.Errorf("decode rsa modulus: %w", err)
	}
	eBytes, err := decodeJWKBase64(key.E)
	if err != nil {
		return nil, fmt.Errorf("decode rsa exponent: %w", err)
	}

	exponent := big.NewInt(0).SetBytes(eBytes).Int64()
	if exponent == 0 {
		return nil, errors.New("invalid rsa exponent")
	}

	return &rsa.PublicKey{
		N: big.NewInt(0).SetBytes(nBytes),
		E: int(exponent),
	}, nil
}

func (key jwk) ecdsaPublicKey() (*ecdsa.PublicKey, error) {
	xBytes, err := decodeJWKBase64(key.X)
	if err != nil {
		return nil, fmt.Errorf("decode ec x: %w", err)
	}
	yBytes, err := decodeJWKBase64(key.Y)
	if err != nil {
		return nil, fmt.Errorf("decode ec y: %w", err)
	}

	var curve elliptic.Curve
	switch key.Crv {
	case "P-256":
		curve = elliptic.P256()
	case "P-384":
		curve = elliptic.P384()
	case "P-521":
		curve = elliptic.P521()
	default:
		return nil, fmt.Errorf("unsupported ec curve: %s", key.Crv)
	}

	return &ecdsa.PublicKey{
		Curve: curve,
		X:     big.NewInt(0).SetBytes(xBytes),
		Y:     big.NewInt(0).SetBytes(yBytes),
	}, nil
}

func decodeJWKBase64(value string) ([]byte, error) {
	return base64.RawURLEncoding.DecodeString(value)
}

// AuthMiddleware intercepts requests and validates access tokens
func AuthMiddleware(jwtSecret string, pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
			c.Abort()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header format must be Bearer <token>"})
			c.Abort()
			return
		}

		tokenStr := parts[1]
		claims, err := ParseToken(tokenStr, jwtSecret)
		if err != nil {
			log.Printf("auth token validation failed: %v", err)
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired access token"})
			c.Abort()
			return
		}

		userID := claims.Subject

		// Ensure a local profile row exists for the Supabase Auth user.
		if pool != nil {
			_, _ = pool.Exec(c.Request.Context(), `
				INSERT INTO profiles (user_id, username, full_name)
				VALUES ($1, 'user_' || replace($1::text, '-', ''), COALESCE($2, 'Пользователь'))
				ON CONFLICT (user_id) DO NOTHING
			`, userID, claims.Email)
		}

		// Perform database check to see if user is banned or get their role.
		var isBanned bool
		var role = "user"
		if pool != nil {
			err = pool.QueryRow(c.Request.Context(), "SELECT is_banned, role FROM profiles WHERE user_id = $1", userID).Scan(&isBanned, &role)
			if err != nil {
				isBanned = false
				role = "user"
			}
		}

		if isBanned {
			c.JSON(http.StatusForbidden, gin.H{"error": "User is banned"})
			c.Abort()
			return
		}

		c.Set("user_id", userID)
		c.Set("user_role", role)
		c.Next()
	}
}
