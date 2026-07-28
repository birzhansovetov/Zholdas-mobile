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

type AIActionCard struct {
	Title  string `json:"title"`
	Body   string `json:"body"`
	Action string `json:"action"`
}

type AIChatStructuredReply struct {
	Mode             string         `json:"mode"`
	Summary          string         `json:"summary"`
	Choices          []string       `json:"choices"`
	Actions          []AIActionCard `json:"actions"`
	Checklist        []AIActionCard `json:"checklist"`
	RiskWarnings     []string       `json:"risk_warnings"`
	ModeratorPrompts []AIActionCard `json:"moderator_prompts"`
	FollowUpQuestion string         `json:"follow_up_question"`
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
	structured, err := ai.ChatStructured(ctx, message, history)
	if err != nil {
		return "", err
	}
	return FormatStructuredReply(structured), nil
}

func (ai *AIService) ChatStructured(ctx context.Context, message string, history []AIChatMessage) (*AIChatStructuredReply, error) {
	if ai.apiKey == "" {
		return &AIChatStructuredReply{
			Mode:    "general",
			Summary: "Я Жорик, инструктор встреч в Жолдас. Сейчас работаю в демо-режиме, но могу помочь собрать формат встречи.",
			Choices: []string{
				"Активный формат: прогулка, спорт, горы, квест.",
				"Спокойный формат: кафе, настолки, разговорная прогулка.",
				"Организация: роли, тайминг, что написать участникам.",
			},
			Actions: []AIActionCard{
				{Title: "Выберите темп", Body: "Активный или спокойный формат.", Action: "Напишите: активный или спокойный."},
				{Title: "Уточните компанию", Body: "Сколько людей будет и насколько они знакомы.", Action: "Напишите количество участников."},
			},
			RiskWarnings: []string{
				"Сначала уточните темп, бюджет и размер компании, иначе план получится слишком общим.",
			},
			ModeratorPrompts: []AIActionCard{
				{Title: "Вопрос в чат", Body: "Кто хочет активный формат, а кто спокойный?", Action: "Отправить участникам."},
			},
			FollowUpQuestion: "Хочешь активный отдых или спокойный формат?",
		}, nil
	}

	messages := make([]OpenAIMessage, 0, len(history)+2)
	messages = append(messages, OpenAIMessage{
		Role:    "system",
		Content: "Ты - Жорик, живой и конкретный ИИ-инструктор встреч в мобильном приложении 'Жолдас'. Ты помогаешь выбрать формат отдыха, подготовиться к встрече, придумать игры и организовать людей. Отвечай на языке пользователя, по умолчанию на русском. Не используй Markdown: никаких **, ###, таблиц и декоративных звездочек. Если запрос общий, предложи выбор: активный отдых или спокойный формат, маленькая или большая компания, бюджетно или с заведением. Давай 4-6 разных вариантов. Для каждого варианта укажи кому подойдет, что подготовить, сколько времени займет и как начать. Если пользователь просит еду, одежду или подготовку, отвечай практично: что взять, что не брать, как одеться, кто за что отвечает. Не выдумывай точную погоду, цены, расписания или несуществующие события.",
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
		Content: structuredReplyPrompt(message),
	})

	resultJSON, err := ai.generateOpenAIOutput(ctx, messages, map[string]interface{}{"type": "json_object"})
	if err != nil {
		return nil, err
	}

	var reply AIChatStructuredReply
	if err := json.Unmarshal([]byte(resultJSON), &reply); err != nil {
		return nil, fmt.Errorf("failed to parse AI chat structured reply: %w", err)
	}

	return normalizeStructuredReply(&reply), nil
}

func (ai *AIService) generateTextOutput(ctx context.Context, messages []OpenAIMessage) (string, error) {
	return ai.generateOpenAIOutput(ctx, messages, nil)
}

// EventChatHelper calls OpenAI to answer a query inside a specific event chat context.
func (ai *AIService) EventChatHelper(ctx context.Context, eventCtx EventChatContext, prompt string) (string, error) {
	structured, err := ai.EventChatHelperStructured(ctx, eventCtx, prompt)
	if err != nil {
		return "", err
	}
	return FormatStructuredReply(structured), nil
}

func (ai *AIService) EventChatHelperStructured(ctx context.Context, eventCtx EventChatContext, prompt string) (*AIChatStructuredReply, error) {
	if ai.apiKey == "" {
		return mockEventHelperStructuredReply(eventCtx), nil
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
		Content: structuredReplyPrompt(prompt),
	})

	resultJSON, err := ai.generateOpenAIOutput(ctx, messages, map[string]interface{}{"type": "json_object"})
	if err != nil {
		return nil, err
	}

	var reply AIChatStructuredReply
	if err := json.Unmarshal([]byte(resultJSON), &reply); err != nil {
		return nil, fmt.Errorf("failed to parse event AI structured reply: %w", err)
	}

	return normalizeStructuredReply(&reply), nil
}

func structuredReplyPrompt(userMessage string) string {
	return fmt.Sprintf(`Запрос пользователя: %s

Верни только JSON в таком виде:
{
  "mode": "planning|checklist|ideas|route|weather|general",
  "summary": "1-2 живых предложения без markdown",
  "choices": ["вариант 1", "вариант 2", "вариант 3"],
  "actions": [{"title":"коротко","body":"конкретная польза","action":"что нажать/написать/сделать"}],
  "checklist": [{"title":"еда","body":"что взять или почему не нужно","action":"кто отвечает"}],
  "risk_warnings": ["короткий риск или ограничение"],
  "moderator_prompts": [{"title":"сообщение в чат","body":"готовый текст для участников","action":"когда отправить"}],
  "follow_up_question": "один короткий вопрос"
}

Требования:
- Никаких Markdown символов: **, ###, таблицы, декоративные звездочки.
- Если запрос общий, обязательно предложи выбор активный/спокойный.
- choices: 3-6 вариантов.
- actions: 2-5 конкретных действий.
- checklist: 0-6 пунктов, только если уместно.
- risk_warnings: 0-4 риска по месту, времени, погоде, безопасности, группе или бюджету.
- moderator_prompts: 1-3 готовых сообщения, которые организатор может отправить в чат.
- follow_up_question обязателен.`, userMessage)
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
- Если запрос широкий, предложи пользователю выбрать: активный или спокойный формат, короткая или длинная встреча, бюджетно или с заведением.
- Давай 4-6 живых вариантов вместо одного общего совета. У каждого варианта укажи кому подойдет, что подготовить и как начать.
- Если спрашивают "что взять/как подготовиться", отвечай разделами: Еда, Одежда, Вещи, Игры/активности, План, Важно.
- Всегда оцени риски встречи: позднее время, неясная точка, дальняя дорога, сложность маршрута, погода, безопасность и состав группы.
- Всегда предлагай 1-3 готовых сообщения для чата, чтобы организатор мог сразу написать участникам.
- Если встреча скоро, напоминай подтвердить участников, точку сбора и запасной план.
- Не используй Markdown: никаких **, ###, таблиц и декоративных звездочек.
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

func FormatStructuredReply(reply *AIChatStructuredReply) string {
	if reply == nil {
		return ""
	}

	sections := []string{}
	if summary := cleanAIText(reply.Summary); summary != "" {
		sections = append(sections, summary)
	}

	if len(reply.Choices) > 0 {
		lines := []string{"Варианты"}
		for i, choice := range reply.Choices {
			if text := cleanAIText(choice); text != "" {
				lines = append(lines, fmt.Sprintf("%d. %s", i+1, text))
			}
		}
		if len(lines) > 1 {
			sections = append(sections, strings.Join(lines, "\n"))
		}
	}

	if len(reply.Actions) > 0 {
		lines := []string{"Что сделать"}
		for _, action := range reply.Actions {
			title := cleanAIText(action.Title)
			body := cleanAIText(action.Body)
			nextAction := cleanAIText(action.Action)
			line := "- " + title
			if body != "" {
				line += ": " + body
			}
			if nextAction != "" {
				line += ". " + nextAction
			}
			if strings.TrimSpace(line) != "-" {
				lines = append(lines, line)
			}
		}
		if len(lines) > 1 {
			sections = append(sections, strings.Join(lines, "\n"))
		}
	}

	if len(reply.Checklist) > 0 {
		lines := []string{"Чеклист"}
		for _, item := range reply.Checklist {
			title := cleanAIText(item.Title)
			body := cleanAIText(item.Body)
			nextAction := cleanAIText(item.Action)
			line := "- " + title
			if body != "" {
				line += ": " + body
			}
			if nextAction != "" {
				line += ". " + nextAction
			}
			if strings.TrimSpace(line) != "-" {
				lines = append(lines, line)
			}
		}
		if len(lines) > 1 {
			sections = append(sections, strings.Join(lines, "\n"))
		}
	}

	if len(reply.RiskWarnings) > 0 {
		lines := []string{"Важно"}
		for _, warning := range reply.RiskWarnings {
			if text := cleanAIText(warning); text != "" {
				lines = append(lines, "- "+text)
			}
		}
		if len(lines) > 1 {
			sections = append(sections, strings.Join(lines, "\n"))
		}
	}

	if len(reply.ModeratorPrompts) > 0 {
		lines := []string{"Можно написать в чат"}
		for _, item := range reply.ModeratorPrompts {
			title := cleanAIText(item.Title)
			body := cleanAIText(item.Body)
			nextAction := cleanAIText(item.Action)
			line := "- " + title
			if body != "" {
				line += ": " + body
			}
			if nextAction != "" {
				line += ". " + nextAction
			}
			if strings.TrimSpace(line) != "-" {
				lines = append(lines, line)
			}
		}
		if len(lines) > 1 {
			sections = append(sections, strings.Join(lines, "\n"))
		}
	}

	if question := cleanAIText(reply.FollowUpQuestion); question != "" {
		sections = append(sections, "Вопрос\n"+question)
	}

	if len(sections) == 0 {
		return "Жорик пока не смог собрать нормальный ответ. Попробуйте спросить чуть конкретнее."
	}

	return strings.Join(sections, "\n\n")
}

func normalizeStructuredReply(reply *AIChatStructuredReply) *AIChatStructuredReply {
	reply.Mode = cleanAIText(reply.Mode)
	reply.Summary = cleanAIText(reply.Summary)
	reply.FollowUpQuestion = cleanAIText(reply.FollowUpQuestion)
	reply.Choices = cleanStringSlice(reply.Choices, 6)
	reply.Actions = cleanActionCards(reply.Actions, 5)
	reply.Checklist = cleanActionCards(reply.Checklist, 6)
	reply.RiskWarnings = cleanStringSlice(reply.RiskWarnings, 4)
	reply.ModeratorPrompts = cleanActionCards(reply.ModeratorPrompts, 3)
	if reply.Mode == "" {
		reply.Mode = "general"
	}
	return reply
}

func cleanStringSlice(values []string, limit int) []string {
	cleaned := make([]string, 0, len(values))
	for _, value := range values {
		text := cleanAIText(value)
		if text == "" {
			continue
		}
		cleaned = append(cleaned, text)
		if len(cleaned) >= limit {
			break
		}
	}
	return cleaned
}

func cleanActionCards(cards []AIActionCard, limit int) []AIActionCard {
	cleaned := make([]AIActionCard, 0, len(cards))
	for _, card := range cards {
		item := AIActionCard{
			Title:  cleanAIText(card.Title),
			Body:   cleanAIText(card.Body),
			Action: cleanAIText(card.Action),
		}
		if item.Title == "" && item.Body == "" && item.Action == "" {
			continue
		}
		cleaned = append(cleaned, item)
		if len(cleaned) >= limit {
			break
		}
	}
	return cleaned
}

func cleanAIText(text string) string {
	replacer := strings.NewReplacer(
		"###", "",
		"##", "",
		"**", "",
		"__", "",
		"`", "",
	)
	return strings.TrimSpace(replacer.Replace(text))
}

func mockEventHelperStructuredReply(eventCtx EventChatContext) *AIChatStructuredReply {
	switch strings.ToLower(strings.TrimSpace(eventCtx.Category)) {
	case "networking", "cat_networking":
		return &AIChatStructuredReply{
			Mode:    "planning",
			Summary: "Жорик предлагает сделать эту встречу не про еду, а про быстрые знакомства и понятный тайминг.",
			Choices: []string{
				"Speed networking: пары меняются каждые 5 минут.",
				"Мини-питч 60 секунд: кто ты, чем занимаешься, кого ищешь.",
				"Карточки-вопросы: каждый отвечает на один вопрос и передает ход дальше.",
			},
			Actions: []AIActionCard{
				{Title: "Назначьте ведущего", Body: "Он следит за временем и сменой пар.", Action: "Напишите в чат, кто берет роль ведущего."},
				{Title: "Соберите ожидания", Body: "Пусть каждый напишет, с кем хочет познакомиться.", Action: "Отправьте вопрос в чат за час до встречи."},
			},
			Checklist: []AIActionCard{
				{Title: "Еда", Body: "Достаточно воды или кофе по желанию, еду не делаем центром встречи.", Action: "Уточните, есть ли рядом кафе."},
				{Title: "Вещи", Body: "Телефон, заряд, заметки или QR-код контактов.", Action: "Подготовьте контакты заранее."},
			},
			RiskWarnings: []string{
				"Если люди не знакомы, нужен ведущий и понятный порядок знакомства.",
				"Не ставьте еду в центр встречи: для нетворкинга важнее структура общения.",
			},
			ModeratorPrompts: []AIActionCard{
				{Title: "Старт", Body: "Давайте начнем с короткого круга: имя, чем занимаюсь, с кем хочу познакомиться.", Action: "Отправить за 10 минут до начала."},
				{Title: "Пары", Body: "После круга делимся на пары по 5 минут и меняемся.", Action: "Отправить на месте."},
			},
			FollowUpQuestion: "Хочешь деловой нетворкинг или более легкий формат знакомства?",
		}
	case "hiking", "cat_mountains":
		return &AIChatStructuredReply{
			Mode:    "checklist",
			Summary: "Жорик предлагает готовиться как к походу: безопасность, вода и темп группы важнее всего.",
			Actions: []AIActionCard{
				{Title: "Проверьте маршрут", Body: "Точка старта, сложность и время возвращения должны быть понятны всем.", Action: "Закрепите маршрут в чате."},
				{Title: "Не разделяйтесь", Body: "Назначьте ведущего впереди и человека, который идет последним.", Action: "Распределите роли перед стартом."},
			},
			Checklist: []AIActionCard{
				{Title: "Еда", Body: "Вода 1-1.5 л, батончики, орехи, фрукты.", Action: "Тяжелую еду не берите."},
				{Title: "Одежда", Body: "Треккинговая обувь, слои одежды, ветровка или дождевик.", Action: "Проверьте прогноз перед выходом."},
				{Title: "Вещи", Body: "Power bank, аптечка, салфетки, пакет для мусора.", Action: "Пусть аптечка будет минимум у одного участника."},
			},
			RiskWarnings: []string{
				"Не выходите без понятного маршрута и времени возвращения.",
				"Если погода меняется, нужен запасной короткий маршрут.",
			},
			ModeratorPrompts: []AIActionCard{
				{Title: "Проверка готовности", Body: "Вода, обувь, power bank и теплая вещь у всех есть?", Action: "Отправить за день."},
				{Title: "Темп", Body: "Идем группой, не разделяемся, ждем отстающих на контрольных точках.", Action: "Отправить перед стартом."},
			},
			FollowUpQuestion: "Маршрут будет легкий прогулочный или полноценный подъем?",
		}
	case "restaurant", "cat_restaurant":
		return &AIChatStructuredReply{
			Mode:    "planning",
			Summary: "Для кафе или ресторана лучше заранее убрать неопределенность: бронь, бюджет и формат разговора.",
			Actions: []AIActionCard{
				{Title: "Забронируйте стол", Body: "Так участники не будут ждать место.", Action: "Напишите имя брони в чат."},
				{Title: "Уточните бюджет", Body: "Это снижает неловкость при заказе.", Action: "Спросите комфортный диапазон."},
			},
			Checklist: []AIActionCard{
				{Title: "Еда", Body: "Свою еду приносить не нужно.", Action: "Лучше уточнить аллергии и ограничения."},
				{Title: "Игры", Body: "Подойдут короткие вопросы для знакомства или мини-викторина.", Action: "Подготовьте 10 вопросов."},
			},
			RiskWarnings: []string{
				"Без брони группа может не поместиться.",
				"Бюджет лучше согласовать заранее, чтобы не было неловкости.",
			},
			ModeratorPrompts: []AIActionCard{
				{Title: "Бронь", Body: "Стол забронирован на имя организатора, приходим за 10 минут.", Action: "Отправить после брони."},
				{Title: "Бюджет", Body: "Напишите комфортный бюджет и ограничения по еде.", Action: "Отправить заранее."},
			},
			FollowUpQuestion: "Это будет спокойный ужин или знакомство с активными разговорами?",
		}
	default:
		return &AIChatStructuredReply{
			Mode:    "planning",
			Summary: "Жорик предлагает сначала выбрать темп встречи, а потом собрать простой план без лишней суеты.",
			Choices: []string{
				"Активный формат: прогулка, мини-квест или спорт.",
				"Спокойный формат: кафе, настолки или разговорная прогулка.",
				"Смешанный формат: короткая активность и затем чай/кофе.",
			},
			Actions: []AIActionCard{
				{Title: "Зафиксируйте точку", Body: "Все должны понимать, где именно встречаетесь.", Action: "Отправьте точку и ориентир в чат."},
				{Title: "Назначьте координатора", Body: "Один человек отвечает за старт и опоздавших.", Action: "Выберите координатора."},
			},
			Checklist: []AIActionCard{
				{Title: "С собой", Body: "Вода, заряд телефона, одежда по погоде.", Action: "Проверьте прогноз перед выходом."},
				{Title: "Активности", Body: "2-3 простые игры для знакомства.", Action: "Выберите одну до встречи."},
			},
			RiskWarnings: []string{
				"Если место указано общо, добавьте точный ориентир.",
				"Если группа большая, нужен один координатор.",
			},
			ModeratorPrompts: []AIActionCard{
				{Title: "Подтверждение", Body: "Кто точно идет и кто может опоздать?", Action: "Отправить за день."},
				{Title: "Точка сбора", Body: "Собираемся у ориентира, после старта пишем в чат, если кто-то задерживается.", Action: "Отправить за час."},
			},
			FollowUpQuestion: "Ты хочешь активный или спокойный формат?",
		}
	}
}

func mockEventHelperReply(eventCtx EventChatContext) string {
	return FormatStructuredReply(mockEventHelperStructuredReply(eventCtx))
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
