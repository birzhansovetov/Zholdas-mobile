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

type EventChatContext struct {
	Title             string
	Description       string
	Category          string
	LocationName      string
	StartTime         time.Time
	EndTime           time.Time
	MaxParticipants   int32
	ParticipantsCount int32
	GenderFilter      string
	MinAge            int32
	MaxAge            int32
	ParticipantStatus string
	RecentMessages    []AIChatMessage
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
		return "Привет! Я Жорик, инструктор встреч в Жолдас. Сейчас я в демо-режиме без OPENAI_API_KEY, но после настройки ключа буду подсказывать, что взять, как одеться и как лучше подготовиться к встрече.", nil
	}

	messages := make([]OpenAIMessage, 0, len(history)+2)
	messages = append(messages, OpenAIMessage{
		Role:    "system",
		Content: "Ты - Жорик, дружелюбный, но очень конкретный ИИ-инструктор встреч в мобильном приложении 'Жолдас' для Алматы. Твоя задача - не просто болтать, а помогать людям подготовиться к прогулкам, походам, играм, встречам и городским активностям. Отвечай на языке пользователя, по умолчанию на русском. Давай практичные инструкции: что взять из еды и напитков, как одеться, что взять с собой, как договориться о встрече, что важно для безопасности и комфорта. Если пользователь спрашивает, чем заняться или как организовать встречу, обязательно предложи 3-5 конкретных вариантов игр, активностей или форматов встречи с коротким объяснением, для какой компании они подходят. Затем дай мини-план организации: кто что приносит, где собраться, как начать, сколько времени заложить. Если информации мало, не зависай: дай базовый чеклист и коротко напиши, что стоит уточнить. Не выдумывай точную погоду, цены, расписания или несуществующие события. Если вопрос простой, отвечай коротко; если пользователь просит подготовку, отвечай структурой 'Варианты', 'Еда', 'Одежда', 'С собой', 'План', 'Важно'.",
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
func (ai *AIService) EventChatHelper(ctx context.Context, eventCtx EventChatContext, prompt string) (string, error) {
	if ai.apiKey == "" {
		return mockEventHelperReply(eventCtx), nil
	}

	messages := make([]OpenAIMessage, 0, len(eventCtx.RecentMessages)+2)
	messages = append(messages, OpenAIMessage{
		Role:    "system",
		Content: buildEventHelperSystemPrompt(eventCtx),
	})

	for _, h := range eventCtx.RecentMessages {
		role := normalizeOpenAIRole(h.Role)
		if role == "" {
			continue
		}
		messages = append(messages, OpenAIMessage{Role: role, Content: h.Text})
	}

	messages = append(messages, OpenAIMessage{
		Role:    "user",
		Content: prompt,
	})

	return ai.generateTextOutput(ctx, messages)
}

func buildEventHelperSystemPrompt(eventCtx EventChatContext) string {
	category := strings.ToLower(strings.TrimSpace(eventCtx.Category))
	return fmt.Sprintf(`Ты - Жорик, ИИ-инструктор и координатор конкретной встречи в приложении Жолдас.

Контекст встречи:
- Название: %s
- Категория: %s
- Описание: %s
- Место: %s
- Время: %s - %s
- Участники: %d/%d
- Ограничения: пол=%s, возраст=%s
- Статус пользователя: %s

Твоя задача - давать конкретные действия, а не общие советы. Учитывай категорию, место, время, лимит участников и последние сообщения чата.

Правила ответа:
- Отвечай на языке пользователя, коротко и уверенно.
- Всегда давай применимые действия: кто что делает, что взять, что написать в чат, как начать встречу.
- Если спрашивают "что взять/как подготовиться", отвечай разделами: Еда, Одежда, Вещи, Игры/активности, План, Важно.
- Не используй Markdown-заголовки ### и жирный **.
- Не выдумывай точную погоду, цены и расписания. Если погоды нет в контексте, скажи проверить прогноз перед выходом.
- Если пользователь просит варианты игр/организации, дай 3-5 вариантов с правилами, длительностью, количеством людей и что подготовить.

Категорийные правила:
%s`, eventCtx.Title, category, eventCtx.Description, eventCtx.LocationName, eventCtx.StartTime.Format(time.RFC1123), eventCtx.EndTime.Format(time.RFC1123), eventCtx.ParticipantsCount, eventCtx.MaxParticipants, emptyFallback(eventCtx.GenderFilter, "all"), ageRestrictionText(eventCtx.MinAge, eventCtx.MaxAge), participantStatusText(eventCtx.ParticipantStatus), categoryInstruction(category))
}

func categoryInstruction(category string) string {
	switch category {
	case "networking", "cat_networking":
		return "- Нетворкинг: не предлагай пикник, чипсы или пиво как основу. Фокус на знакомство, вопросы, мини-питчи, обмен контактами, роли модератора и тайминг.\n- Игры: speed networking, 2 правды 1 ложь, карточки-вопросы, мини-презентации по 60 секунд."
	case "hiking", "cat_mountains":
		return "- Горы/поход: вода, перекус, треккинговая обувь, слои одежды, аптечка, power bank, фонарик, темп группы, контроль отстающих, безопасность.\n- Не предлагай тяжелую еду и алкоголь."
	case "walk", "cat_walks":
		return "- Прогулка: удобная обувь, вода, простой маршрут, точки отдыха, фото-задания, разговорные игры, запасной план на дождь."
	case "sports", "cat_sports":
		return "- Спорт: форма, обувь, вода, разминка, правила, деление команд, безопасность, восстановление. Еду только легкий перекус после."
	case "restaurant", "cat_restaurant":
		return "- Ресторан/кафе: бронь, бюджет, аллергии, кто оплачивает, темы разговора, рассадка, игры за столом. Не советуй приносить свою еду."
	case "board_games", "cat_games":
		return "- Игры: ведущий, правила за 2 минуты, выбор игр по числу участников, таймер, запасные простые игры, легкие снеки по желанию."
	case "theater", "cat_theater":
		return "- Театр/кино/культура: билеты, время входа, дресс-код, где встретиться до входа, обсуждение после, опоздания нельзя."
	default:
		return "- Общая встреча: уточни формат, предложи простой план, роли, чеклист вещей и 3 активности для знакомства."
	}
}

func mockEventHelperReply(eventCtx EventChatContext) string {
	switch strings.ToLower(strings.TrimSpace(eventCtx.Category)) {
	case "networking", "cat_networking":
		return "Для этой нетворкинг-встречи лучше сделать так:\n\nЕда\n- Только вода/кофе по желанию, еду не делаем центром встречи.\n\nИгры и знакомство\n- Speed networking: пары меняются каждые 5 минут.\n- 2 правды и 1 ложь: быстро снимает напряжение.\n- Мини-питч 60 секунд: кто ты, чем занимаешься, кого ищешь.\n\nПлан\n- За 30 минут до встречи напишите в чат точку сбора.\n- Назначьте ведущего, который следит за таймингом.\n- В конце обменяйтесь контактами и сделайте общий итог."
	case "hiking", "cat_mountains":
		return "Для похода подготовка такая:\n\nЕда\n- Вода 1-1.5 л на человека, батончики, орехи, фрукты.\n\nОдежда\n- Удобная треккинговая обувь, слои одежды, ветровка/дождевик.\n\nВещи\n- Power bank, аптечка, салфетки, пакет для мусора.\n\nПлан\n- Проверьте прогноз, точку старта и кто идёт медленнее.\n- Договоритесь, что группа не разделяется."
	case "restaurant", "cat_restaurant":
		return "Для встречи в кафе/ресторане:\n\nЕда\n- Еду приносить не нужно. Лучше заранее договориться по бюджету и аллергиям.\n\nПлан\n- Забронируйте стол.\n- Напишите в чат точное место и имя брони.\n- Подготовьте 3 темы для разговора или карточки-вопросы.\n\nВажно\n- Уточните, кто и как оплачивает счёт."
	default:
		return "Сделайте встречу конкретнее:\n\nПлан\n- Напишите в чат точку сбора и время, когда ждать опоздавших.\n- Назначьте одного координатора.\n- Подготовьте 2-3 простые активности для знакомства.\n\nС собой\n- Вода, заряд телефона, удобная одежда по погоде.\n\nВажно\n- За час до начала подтвердите, кто точно идёт."
	}
}

func emptyFallback(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return value
}

func ageRestrictionText(minAge, maxAge int32) string {
	if minAge > 0 && maxAge > 0 {
		return fmt.Sprintf("%d-%d", minAge, maxAge)
	}
	if minAge > 0 {
		return fmt.Sprintf("от %d", minAge)
	}
	if maxAge > 0 {
		return fmt.Sprintf("до %d", maxAge)
	}
	return "любой"
}

func participantStatusText(status string) string {
	switch status {
	case "going":
		return "идёт"
	case "late":
		return "опаздывает"
	case "arrived":
		return "на месте"
	case "not_going":
		return "не сможет прийти"
	default:
		return "неизвестен"
	}
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
