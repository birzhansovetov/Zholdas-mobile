package config

import (
	"os"
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
	os.Unsetenv("OPENAI_API_KEY")
	os.Unsetenv("ADMIN_EMAIL")

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

	if cfg.OpenAIAPIKey != "" {
		t.Errorf("Expected default OpenAIAPIKey empty, got '%s'", cfg.OpenAIAPIKey)
	}

	if cfg.AdminEmail != "" {
		t.Errorf("Expected default AdminEmail empty, got '%s'", cfg.AdminEmail)
	}
}

func TestLoadConfig_Overrides(t *testing.T) {
	withoutDotEnv(t)

	// Set custom environment variables
	os.Setenv("PORT", "9090")
	os.Setenv("DATABASE_URL", "postgres://test_user@localhost:5432/test_db")
	os.Setenv("JWT_SECRET", "custom_secret_key")
	os.Setenv("OPENAI_API_KEY", "openai_key_123")
	os.Setenv("ADMIN_EMAIL", "owner@example.com")

	// Ensure they clean up after test
	defer func() {
		os.Unsetenv("PORT")
		os.Unsetenv("DATABASE_URL")
		os.Unsetenv("JWT_SECRET")
		os.Unsetenv("OPENAI_API_KEY")
		os.Unsetenv("ADMIN_EMAIL")
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

	if cfg.OpenAIAPIKey != "openai_key_123" {
		t.Errorf("Expected OpenAIAPIKey 'openai_key_123', got '%s'", cfg.OpenAIAPIKey)
	}

	if cfg.AdminEmail != "owner@example.com" {
		t.Errorf("Expected AdminEmail 'owner@example.com', got '%s'", cfg.AdminEmail)
	}
}
