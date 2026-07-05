package config

import (
	"bufio"
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
