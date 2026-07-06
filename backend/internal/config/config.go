package config

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

type Config struct {
	Port          string
	DatabaseURL   string
	JWTSecret     string
	OpenAIAPIKey  string
	AdminEmail    string
	RunMigrations bool
}

func loadDotEnv() {
	file, err := os.Open(".env")
	if err != nil {
		return // Ignore if file is missing
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			key := strings.TrimSpace(parts[0])
			val := strings.TrimSpace(parts[1])
			val = strings.Trim(val, `"'`)
			os.Setenv(key, val)
		}
	}
}

func LoadConfig() *Config {
	loadDotEnv()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://birzhansovetov@localhost:5432/zholdas?sslmode=disable"
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "zholdas_secret_key_change_me"
	}

	openAIAPIKey := os.Getenv("OPENAI_API_KEY")
	adminEmail := os.Getenv("ADMIN_EMAIL")
	runMigrations := parseBoolEnv(os.Getenv("RUN_MIGRATIONS"), true)

	return &Config{
		Port:          port,
		DatabaseURL:   dbURL,
		JWTSecret:     jwtSecret,
		OpenAIAPIKey:  openAIAPIKey,
		AdminEmail:    adminEmail,
		RunMigrations: runMigrations,
	}
}

func (c *Config) ValidateForRuntime() []string {
	var warnings []string

	if strings.TrimSpace(c.DatabaseURL) == "" {
		warnings = append(warnings, "DATABASE_URL is empty; database connection will fail")
	}

	if isProductionRuntime() && strings.TrimSpace(os.Getenv("DATABASE_URL")) == "" {
		warnings = append(warnings, "DATABASE_URL is not set in production runtime")
	}

	if strings.TrimSpace(c.JWTSecret) == "" || c.JWTSecret == "zholdas_secret_key_change_me" {
		warnings = append(warnings, "JWT_SECRET is using the local default; set the Supabase JWT secret in production")
	}

	if strings.TrimSpace(c.OpenAIAPIKey) == "" {
		warnings = append(warnings, "OPENAI_API_KEY is empty; AI features may fail")
	}

	if strings.TrimSpace(c.AdminEmail) == "" {
		warnings = append(warnings, "ADMIN_EMAIL is empty; admin role will not be auto-assigned")
	}

	return warnings
}

func (c *Config) Summary() string {
	return fmt.Sprintf(
		"port=%s run_migrations=%t admin_email_set=%t openai_key_set=%t",
		c.Port,
		c.RunMigrations,
		strings.TrimSpace(c.AdminEmail) != "",
		strings.TrimSpace(c.OpenAIAPIKey) != "",
	)
}

func isProductionRuntime() bool {
	return strings.TrimSpace(os.Getenv("RENDER")) != "" ||
		strings.EqualFold(strings.TrimSpace(os.Getenv("APP_ENV")), "production") ||
		strings.EqualFold(strings.TrimSpace(os.Getenv("GIN_MODE")), "release")
}

func parseBoolEnv(value string, fallback bool) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "":
		return fallback
	case "1", "true", "yes", "y", "on":
		return true
	case "0", "false", "no", "n", "off":
		return false
	default:
		return fallback
	}
}
