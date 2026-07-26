package config

import (
	"os"
	"strings"
	"testing"
)

func withoutDotEnv(t *testing.T) {
	t.Helper()
	originalDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("failed to get working directory: %v", err)
	}
	if err := os.Chdir(t.TempDir()); err != nil {
		t.Fatalf("failed to chdir to temp dir: %v", err)
	}
	t.Cleanup(func() {
		if err := os.Chdir(originalDir); err != nil {
			t.Fatalf("failed to restore working directory: %v", err)
		}
	})
}

func TestLoadConfig_Defaults(t *testing.T) {
	withoutDotEnv(t)

	// Clear environments to test defaults
	os.Unsetenv("PORT")
	os.Unsetenv("DATABASE_URL")
	os.Unsetenv("JWT_SECRET")
	os.Unsetenv("JWT_ISSUER")
	os.Unsetenv("JWT_AUDIENCE")
	os.Unsetenv("TRUSTED_PROXIES")
	os.Unsetenv("OPENAI_API_KEY")
	os.Unsetenv("ADMIN_EMAIL")
	os.Unsetenv("RUN_MIGRATIONS")

	cfg := LoadConfig()

	if cfg.Port != "8080" {
		t.Errorf("Expected default Port '8080', got '%s'", cfg.Port)
	}

	expectedDB := "postgres://birzhansovetov@localhost:5432/zholdas?sslmode=disable"
	if cfg.DatabaseURL != expectedDB {
		t.Errorf("Expected default DatabaseURL '%s', got '%s'", expectedDB, cfg.DatabaseURL)
	}

	if cfg.JWTSecret != "zholdas_secret_key_change_me" {
		t.Errorf("Expected default JWTSecret 'zholdas_secret_key_change_me', got '%s'", cfg.JWTSecret)
	}
	if cfg.JWTIssuer != "https://wqjaolhmpxanjvadxngn.supabase.co/auth/v1" {
		t.Errorf("Unexpected default JWT issuer: %s", cfg.JWTIssuer)
	}
	if cfg.JWTAudience != "authenticated" {
		t.Errorf("Unexpected default JWT audience: %s", cfg.JWTAudience)
	}

	if cfg.OpenAIAPIKey != "" {
		t.Errorf("Expected default OpenAIAPIKey empty, got '%s'", cfg.OpenAIAPIKey)
	}

	if cfg.AdminEmail != "" {
		t.Errorf("Expected default AdminEmail empty, got '%s'", cfg.AdminEmail)
	}

	if !cfg.RunMigrations {
		t.Error("Expected default RunMigrations true")
	}
}

func TestLoadConfig_Overrides(t *testing.T) {
	withoutDotEnv(t)

	// Set custom environment variables
	os.Setenv("PORT", "9090")
	os.Setenv("DATABASE_URL", "postgres://test_user@localhost:5432/test_db")
	os.Setenv("JWT_SECRET", "custom_secret_key")
	os.Setenv("JWT_ISSUER", "https://custom.supabase.co/auth/v1/")
	os.Setenv("JWT_AUDIENCE", "custom-audience")
	os.Setenv("TRUSTED_PROXIES", "10.0.0.0/8, 192.168.0.0/16")
	os.Setenv("OPENAI_API_KEY", "openai_key_123")
	os.Setenv("ADMIN_EMAIL", "owner@example.com")
	os.Setenv("RUN_MIGRATIONS", "false")

	// Ensure they clean up after test
	defer func() {
		os.Unsetenv("PORT")
		os.Unsetenv("DATABASE_URL")
		os.Unsetenv("JWT_SECRET")
		os.Unsetenv("JWT_ISSUER")
		os.Unsetenv("JWT_AUDIENCE")
		os.Unsetenv("TRUSTED_PROXIES")
		os.Unsetenv("OPENAI_API_KEY")
		os.Unsetenv("ADMIN_EMAIL")
		os.Unsetenv("RUN_MIGRATIONS")
	}()

	cfg := LoadConfig()

	if cfg.Port != "9090" {
		t.Errorf("Expected Port '9090', got '%s'", cfg.Port)
	}

	expectedDB := "postgres://test_user@localhost:5432/test_db"
	if cfg.DatabaseURL != expectedDB {
		t.Errorf("Expected DatabaseURL '%s', got '%s'", expectedDB, cfg.DatabaseURL)
	}

	if cfg.JWTSecret != "custom_secret_key" {
		t.Errorf("Expected JWTSecret 'custom_secret_key', got '%s'", cfg.JWTSecret)
	}
	if cfg.JWTIssuer != "https://custom.supabase.co/auth/v1" {
		t.Errorf("Unexpected JWT issuer: %s", cfg.JWTIssuer)
	}
	if cfg.JWTAudience != "custom-audience" {
		t.Errorf("Unexpected JWT audience: %s", cfg.JWTAudience)
	}
	if len(cfg.TrustedProxies) != 2 {
		t.Errorf("Expected two trusted proxies, got %d", len(cfg.TrustedProxies))
	}

	if cfg.OpenAIAPIKey != "openai_key_123" {
		t.Errorf("Expected OpenAIAPIKey 'openai_key_123', got '%s'", cfg.OpenAIAPIKey)
	}

	if cfg.AdminEmail != "owner@example.com" {
		t.Errorf("Expected AdminEmail 'owner@example.com', got '%s'", cfg.AdminEmail)
	}

	if cfg.RunMigrations {
		t.Error("Expected RunMigrations false")
	}
}

func TestValidateForRuntime_Warnings(t *testing.T) {
	cfg := &Config{
		Port:          "8080",
		DatabaseURL:   "",
		JWTSecret:     "zholdas_secret_key_change_me",
		OpenAIAPIKey:  "",
		AdminEmail:    "",
		RunMigrations: false,
	}

	warnings := cfg.ValidateForRuntime()
	if len(warnings) == 0 {
		t.Fatal("Expected warnings for incomplete config")
	}
}

func TestSummary_HidesSecrets(t *testing.T) {
	cfg := &Config{
		Port:          "8080",
		DatabaseURL:   "postgres://user:password@example.com/db",
		JWTSecret:     "jwt_secret",
		OpenAIAPIKey:  "sk-secret",
		AdminEmail:    "owner@example.com",
		RunMigrations: false,
	}

	summary := cfg.Summary()
	if strings.Contains(summary, "sk-secret") || strings.Contains(summary, "jwt_secret") || strings.Contains(summary, "password") {
		t.Fatalf("Summary leaked a secret: %s", summary)
	}
}
