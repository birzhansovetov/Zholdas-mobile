package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type AIService struct {
	apiKey string
}

func NewAIService(apiKey string) *AIService {
	return &AIService{apiKey: apiKey}
}

type AIRecommendation struct {
	Answer             string  `json:"answer"`
	RecommendedCardIDs []int32 `json:"recommended_card_ids"`
}

type ModerationResult struct {
	IsUnsafe bool   `json:"is_unsafe"`
	Reason   string `json:"reason"`
}

type AIChatMessage struct {
	Role string `json:"role"` // "user", "assistant", or legacy "model"
	Text string `json:"text"`
}

type OpenAIMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type OpenAIChatRequest struct {
	Model          string                 `json:"model"`
	Messages       []OpenAIMessage        `json:"messages"`
	Temperature    float64                `json:"temperature,omitempty"`
	MaxTokens      int                    `json:"max_tokens,omitempty"`
	ResponseFormat map[string]interface{} `json:"response_format,omitempty"`
}

const openAIModel = "gpt-4o-mini"

// ModerateEvent checks the title and description for unsafe content.
// It will query the OpenAI API if an API key is present; otherwise, it uses mock rules.
func (ai *AIService) ModerateEvent(ctx context.Context, title, description string) (bool, string, error) {
	if ai.apiKey == "" {
		// Mock local rules if no OpenAI key is provided
		lowerTitle := strings.ToLower(title)
		lowerDesc := strings.ToLower(description)
		unsafeWords := []string{"bomb", "weapons", "terror", "drugs", "suicide", "illegal"}

		for _, word := range unsafeWords {
			if strings.Contains(lowerTitle, word) || strings.Contains(lowerDesc, word) {
				return true, fmt.Sprintf("content contains forbidden keyword: '%s'", word), nil
			}
		}
		return false, "", nil
	}

	prompt := fmt.Sprintf(`Moderate this event.
Title: %s
Description: %s

Return only valid JSON in this exact shape:
{"is_unsafe": false, "reason": ""}`, title, description)

	resultJSON, err := ai.generateStructuredOutput(ctx, prompt)
	if err != nil {
		return false, "", err
	}

	var res ModerationResult
	if err := json.Unmarshal([]byte(resultJSON), &res); err != nil {
		return false, "", fmt.Errorf("failed to parse moderation result: %w", err)
	}

	return res.IsUnsafe, res.Reason, nil
}

// GetRecommendations requests recommendations for events based on a user query and list of options.
func (ai *AIService) GetRecommendations(ctx context.Context, userQuery string, eventsJSON string) (*AIRecommendation, error) {
	if ai.apiKey == "" {
		// Mock local recommendation
		return &AIRecommendation{
			Answer:             "This is a mock recommendation. Please set OPENAI_API_KEY to get real AI suggestions.",
			RecommendedCardIDs: []int32{1},
		}, nil
	}

	prompt := fmt.Sprintf(`Ты локальный гид приложения Жолдас.
Твоя задача — рекомендовать только реально существующие ID событий из переданного списка. Не выдумывай новые ID.

Запрос пользователя: %q
Список событий: %s

Return only valid JSON in this exact shape:
{"answer":"короткий дружелюбный ответ","recommended_card_ids":[1,2]}`, userQuery, eventsJSON)

	resultJSON, err := ai.generateStructuredOutput(ctx, prompt)
	if err != nil {
		return nil, err
	}

	var rec AIRecommendation
	if err := json.Unmarshal([]byte(resultJSON), &rec); err != nil {
		return nil, fmt.Errorf("failed to parse recommendation result: %w", err)
	}

	return &rec, nil
}

func (ai *AIService) generateStructuredOutput(ctx context.Context, prompt string) (string, error) {
	return ai.generateOpenAIOutput(ctx, []OpenAIMessage{
		{
			Role:    "system",
			Content: "You are a strict JSON API. Return only valid JSON. Do not wrap the JSON in markdown.",
		},
		{
			Role:    "user",
			Content: prompt,
		},
	}, map[string]interface{}{"type": "json_object"})
}

// Chat calls the OpenAI API to get a response from Joryk, Almaty AI Assistant.
func (ai *AIService) Chat(ctx context.Context, message string, history []AIChatMessage) (string, error) {
	if ai.apiKey == "" {
		return "Привет! Я Жорик, твой ИИ-помощник в Алматы. Сейчас я запущен в демонстрационном режиме без API-ключа, но когда разработчик укажет OPENAI_API_KEY, мы сможем пообщаться по-настоящему! ⛰️🍎", nil
	}

	messages := make([]OpenAIMessage, 0, len(history)+2)
	messages = append(messages, OpenAIMessage{
		Role:    "system",
		Content: "Ты — Жорик, дружелюбный ИИ-помощник в мобильном приложении 'Жолдас' для поиска компании и событий в городе Алматы. Помогай пользователям находить интересные места (Кок-Тобе, Медеу, БАО, Шымбулак, пешеходная улица Панфилова и др.), предлагай идеи для совместных активностей, подсказывай, как правильно организовать встречу. Отвечай кратко (до 3-4 предложений), дружелюбно, на языке пользователя (по умолчанию на русском), используй эмодзи для живости. Не выдумывай несуществующие события.",
	})

	for _, h := range history {
		role := normalizeOpenAIRole(h.Role)
		if role == "" {
			continue
		}
		messages = append(messages, OpenAIMessage{
			Role:    role,
			Content: h.Text,
		})
	}

	messages = append(messages, OpenAIMessage{
		Role:    "user",
		Content: message,
	})

	return ai.generateTextOutput(ctx, messages)
}

func (ai *AIService) generateTextOutput(ctx context.Context, messages []OpenAIMessage) (string, error) {
	return ai.generateOpenAIOutput(ctx, messages, nil)
}

// EventChatHelper calls OpenAI to answer a query inside a specific event chat context.
func (ai *AIService) EventChatHelper(ctx context.Context, eventTitle, eventDesc, prompt string) (string, error) {
	if ai.apiKey == "" {
		return "Привет! Я Жорик, ИИ-помощник этого события. Сейчас я запущен в демонстрационном режиме, но когда разработчик настроит OPENAI_API_KEY, я смогу отвечать на все ваши вопросы в чате! ⛰️🍎", nil
	}

	messages := []OpenAIMessage{
		{
			Role:    "system",
			Content: fmt.Sprintf("Ты — Жорик, дружелюбный ИИ-помощник участников встречи '%s' в Алматы. Описание события: '%s'. Отвечай на вопросы участников дружелюбно, кратко (1-3 предложения), помогай им спланировать встречу, отвечай на вопросы о правилах игр, еде, локации или погоде.", eventTitle, eventDesc),
		},
		{
			Role:    "user",
			Content: prompt,
		},
	}

	return ai.generateTextOutput(ctx, messages)
}

func (ai *AIService) generateOpenAIOutput(ctx context.Context, messages []OpenAIMessage, responseFormat map[string]interface{}) (string, error) {
	reqPayload := OpenAIChatRequest{
		Model:          openAIModel,
		Messages:       messages,
		Temperature:    0.4,
		MaxTokens:      700,
		ResponseFormat: responseFormat,
	}

	bodyBytes, err := json.Marshal(reqPayload)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", "https://api.openai.com/v1/chat/completions", bytes.NewBuffer(bodyBytes))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+ai.apiKey)

	client := &http.Client{Timeout: 20 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		var errBuf bytes.Buffer
		errBuf.ReadFrom(resp.Body)
		return "", fmt.Errorf("openai API returned status %d: %s", resp.StatusCode, errBuf.String())
	}

	var openAIResp struct {
		Choices []struct {
			Message OpenAIMessage `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&openAIResp); err != nil {
		return "", err
	}

	if len(openAIResp.Choices) == 0 || strings.TrimSpace(openAIResp.Choices[0].Message.Content) == "" {
		return "", fmt.Errorf("openai API returned empty response")
	}

	return strings.TrimSpace(openAIResp.Choices[0].Message.Content), nil
}

func normalizeOpenAIRole(role string) string {
	switch strings.ToLower(strings.TrimSpace(role)) {
	case "user":
		return "user"
	case "assistant", "model":
		return "assistant"
	default:
		return ""
	}
}

// NotificationService logs or dispatches Push Notifications
type NotificationService struct {
	pool *pgxpool.Pool
}

func NewNotificationService() *NotificationService {
	return &NotificationService{}
}

func (n *NotificationService) SetPool(pool *pgxpool.Pool) {
	n.pool = pool
}

func (n *NotificationService) SendPush(userID string, message string) {
	log.Printf("[PUSH TO USER %s]: %s", userID, message)

	if n.pool == nil {
		return
	}

	// Query user device tokens
	rows, err := n.pool.Query(context.Background(), "SELECT device_token, platform FROM user_device_tokens WHERE user_id = $1", userID)
	if err != nil {
		log.Printf("[Push Error] Failed to query device tokens for user %s: %v", userID, err)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var token, platform string
		if err := rows.Scan(&token, &platform); err == nil {
			log.Printf("[APNs Dispatch] Sending remote push to deviceToken=%s platform=%s payload=%q", token, platform, message)
		}
	}
}
