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

type TokenConfig struct {
	Secret   string
	Issuer   string
	Audience string
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
	return ParseTokenWithConfig(tokenStr, TokenConfig{Secret: secret})
}

// ParseTokenWithConfig validates signature, lifetime, subject and, when set,
// the exact Supabase issuer and audience. Pinning the issuer also prevents a
// token from directing the backend to an attacker-controlled JWKS endpoint.
func ParseTokenWithConfig(tokenStr string, config TokenConfig) (*Claims, error) {
	unverified := &Claims{}
	_, _, err := jwt.NewParser().ParseUnverified(tokenStr, unverified)
	if err != nil {
		return nil, fmt.Errorf("parse token claims: %w", err)
	}
	if config.Issuer != "" && unverified.Issuer != config.Issuer {
		return nil, errors.New("invalid issuer")
	}

	claims := &Claims{}
	options := []jwt.ParserOption{
		jwt.WithValidMethods([]string{
			jwt.SigningMethodHS256.Alg(),
			jwt.SigningMethodRS256.Alg(),
			jwt.SigningMethodES256.Alg(),
		}),
	}
	if config.Issuer != "" {
		options = append(options, jwt.WithIssuer(config.Issuer))
	}
	if config.Audience != "" {
		options = append(options, jwt.WithAudience(config.Audience))
	}

	token, err := jwt.ParseWithClaims(tokenStr, claims, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); ok {
			return []byte(config.Secret), nil
		}

		if _, ok := token.Method.(*jwt.SigningMethodRSA); ok {
			return publicKeyForToken(config.Issuer, unverified.Issuer, token)
		}
		if _, ok := token.Method.(*jwt.SigningMethodECDSA); ok {
			return publicKeyForToken(config.Issuer, unverified.Issuer, token)
		}

		return nil, fmt.Errorf("unexpected signing method: %s", token.Method.Alg())
	}, options...)

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

func publicKeyForToken(expectedIssuer, tokenIssuer string, token *jwt.Token) (interface{}, error) {
	kid, _ := token.Header["kid"].(string)
	if kid == "" {
		return nil, errors.New("missing key id")
	}

	issuer := tokenIssuer
	if expectedIssuer != "" {
		issuer = expectedIssuer
	}
	if issuer == "" {
		return nil, errors.New("missing issuer")
	}

	keys, err := jwksForIssuer(issuer)
	if err != nil {
		return nil, err
	}

	key, ok := keys[kid]
	if !ok {
		jwksCacheMu.Lock()
		delete(jwksCache, issuer)
		jwksCacheMu.Unlock()

		keys, err = jwksForIssuer(issuer)
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
	return AuthMiddlewareWithConfig(TokenConfig{Secret: jwtSecret}, pool)
}

func AuthMiddlewareWithConfig(tokenConfig TokenConfig, pool *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			AbortWithError(c, http.StatusUnauthorized, "AUTH_HEADER_MISSING", "Authorization header is required")
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || strings.TrimSpace(parts[1]) == "" {
			AbortWithError(c, http.StatusUnauthorized, "AUTH_HEADER_INVALID", "Authorization header format must be Bearer <token>")
			return
		}

		tokenStr := parts[1]
		claims, err := ParseTokenWithConfig(tokenStr, tokenConfig)
		if err != nil {
			log.Printf("request_id=%s auth_token_validation_failed=%v", RequestID(c), err)
			AbortWithError(c, http.StatusUnauthorized, "AUTH_TOKEN_INVALID", "Invalid or expired access token")
			return
		}

		userID := claims.Subject

		// Ensure a local profile row exists for the Supabase Auth user.
		if pool != nil {
			_, err = pool.Exec(c.Request.Context(), `
				INSERT INTO profiles (user_id, username, full_name)
				VALUES ($1, 'user_' || replace($1::text, '-', ''), COALESCE($2, 'Пользователь'))
				ON CONFLICT (user_id) DO NOTHING
			`, userID, claims.Email)
			if err != nil {
				log.Printf("request_id=%s profile_initialization_failed user_id=%s error=%v", RequestID(c), userID, err)
				AbortWithError(c, http.StatusServiceUnavailable, "PROFILE_INITIALIZATION_FAILED", "User profile is temporarily unavailable")
				return
			}
		}

		// Perform database check to see if user is banned or get their role.
		var isBanned bool
		var role = "user"
		if pool != nil {
			err = pool.QueryRow(c.Request.Context(), "SELECT is_banned, role FROM profiles WHERE user_id = $1", userID).Scan(&isBanned, &role)
			if err != nil {
				log.Printf("request_id=%s profile_lookup_failed user_id=%s error=%v", RequestID(c), userID, err)
				AbortWithError(c, http.StatusServiceUnavailable, "PROFILE_LOOKUP_FAILED", "User profile is temporarily unavailable")
				return
			}
		}

		if isBanned {
			AbortWithError(c, http.StatusForbidden, "USER_BANNED", "User is banned")
			return
		}

		c.Set("user_id", userID)
		c.Set("user_role", role)
		c.Next()
	}
}
