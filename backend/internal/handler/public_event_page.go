package handler

import (
	"bytes"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const (
	PageLangRU = "ru"
	PageLangKK = "kk"
	PageLangEN = "en"
)

type PageTexts struct {
	Brand                string
	PrivacyTitle         string
	PrivacyBody          string
	NotFoundTitle        string
	NotFoundBody         string
	ServerErrorTitle     string
	ServerErrorBody      string
	LabelDateTime        string
	LabelLocation        string
	LabelOrganizer       string
	LabelParticipants    string
	BtnRoute             string
	BtnOpenInApp         string
	BtnAppStore          string
	BtnGooglePlay        string
	NoteNoApp            string
	DefaultOrganizerName string
}

var pageTranslations = map[string]PageTexts{
	PageLangRU: {
		Brand:                "Жолдас",
		PrivacyTitle:         "Событие для друзей",
		PrivacyBody:          "Это событие видно только друзьям организатора. Откройте его в приложении Жолдас.",
		NotFoundTitle:        "Событие не найдено или удалено",
		NotFoundBody:         "Возможно, организатор отменил событие или ссылка недействительна.",
		ServerErrorTitle:     "Что-то пошло не так",
		ServerErrorBody:      "Не удалось загрузить событие. Попробуйте обновить страницу позже.",
		LabelDateTime:        "Дата и время",
		LabelLocation:        "Место",
		LabelOrganizer:       "Организатор",
		LabelParticipants:    "Участники",
		BtnRoute:             "Маршрут в 2GIS",
		BtnOpenInApp:         "Открыть в Жолдас",
		BtnAppStore:          "Скачать в App Store",
		BtnGooglePlay:        "Скачать в Google Play",
		NoteNoApp:            "Нет приложения? Установите и откройте ссылку ещё раз",
		DefaultOrganizerName: "Организатор",
	},
	PageLangKK: {
		Brand:                "Жолдас",
		PrivacyTitle:         "Достарға арналған іс-шара",
		PrivacyBody:          "Бұл іс-шара тек ұйымдастырушының достарына көрінеді. Оны Жолдас қосымшасынан ашыңыз.",
		NotFoundTitle:        "Іс-шара табылмады немесе өшірілген",
		NotFoundBody:         "Мүмкін ұйымдастырушы іс-шараны тоқтатқан немесе сілтеме жарамсыз.",
		ServerErrorTitle:     "Бірдеңе дұрыс болмады",
		ServerErrorBody:      "Іс-шараны жүктеу мүмкін болмады. Бетті кейінірек жаңартып көріңіз.",
		LabelDateTime:        "Күні мен уақыты",
		LabelLocation:        "Өтетін орны",
		LabelOrganizer:       "Ұйымдастырушы",
		LabelParticipants:    "Қатысушылар",
		BtnRoute:             "2GIS бағыты",
		BtnOpenInApp:         "Жолдастан ашу",
		BtnAppStore:          "App Store-дан жүктеу",
		BtnGooglePlay:        "Google Play-ден жүктеу",
		NoteNoApp:            "Қосымша жоқ па? Орнатып, сілтемені қайта ашыңыз",
		DefaultOrganizerName: "Ұйымдастырушы",
	},
	PageLangEN: {
		Brand:                "Zholdas",
		PrivacyTitle:         "Friends-only event",
		PrivacyBody:          "This event is only visible to the organizer's friends. Open it in the Zholdas app.",
		NotFoundTitle:        "Event not found or has been deleted",
		NotFoundBody:         "The event might have been cancelled by the organizer or the link is invalid.",
		ServerErrorTitle:     "Something went wrong",
		ServerErrorBody:      "Failed to load the event. Please refresh the page later.",
		LabelDateTime:        "Date and time",
		LabelLocation:        "Location",
		LabelOrganizer:       "Organizer",
		LabelParticipants:    "Participants",
		BtnRoute:             "Route in 2GIS",
		BtnOpenInApp:         "Open in Zholdas",
		BtnAppStore:          "Download on App Store",
		BtnGooglePlay:        "Get it on Google Play",
		NoteNoApp:            "Don't have the app? Install it and open the link again",
		DefaultOrganizerName: "Organizer",
	},
}

func getPageTexts(lang string) PageTexts {
	if t, ok := pageTranslations[lang]; ok {
		return t
	}
	return pageTranslations[PageLangRU]
}

func resolveLanguage(c *gin.Context) string {
	qLang := strings.ToLower(strings.TrimSpace(c.Query("lang")))
	switch qLang {
	case "kk", "kz", "kaz", "qaz":
		return PageLangKK
	case "en", "eng":
		return PageLangEN
	case "ru", "rus":
		return PageLangRU
	}

	accept := strings.ToLower(strings.TrimSpace(c.GetHeader("Accept-Language")))
	if strings.HasPrefix(accept, "kk") {
		return PageLangKK
	}
	if strings.HasPrefix(accept, "en") {
		return PageLangEN
	}
	return PageLangRU
}

func translateCategory(category string, lang string) string {
	trimmed := strings.TrimSpace(category)
	if trimmed == "" {
		return ""
	}
	lower := strings.ToLower(trimmed)

	var catKey string
	switch lower {
	case "mountains", "mountain", "hiking", "hike", "горы", "гора", "поход", "тау":
		catKey = "mountains"
	case "sports", "sport", "спорт":
		catKey = "sports"
	case "walks", "walk", "прогулки", "прогулка", "серуен":
		catKey = "walks"
	case "games", "game", "board_games", "boardgames", "board games", "игры", "игра", "настолки", "ойындар", "ойын":
		catKey = "games"
	case "theater", "theatre", "театр":
		catKey = "theater"
	case "restaurant", "restaurants", "ресторан", "мейрамхана", "кафе":
		catKey = "restaurant"
	case "networking", "нетворкинг":
		catKey = "networking"
	case "other", "другое", "басқа":
		catKey = "other"
	default:
		// Неизвестную категорию показываем как есть
		return trimmed
	}

	switch lang {
	case PageLangKK:
		switch catKey {
		case "mountains":
			return "Тау"
		case "sports":
			return "Спорт"
		case "walks":
			return "Серуен"
		case "games":
			return "Ойындар"
		case "theater":
			return "Театр"
		case "restaurant":
			return "Мейрамхана"
		case "networking":
			return "Нетворкинг"
		case "other":
			return "Басқа"
		}
	case PageLangEN:
		switch catKey {
		case "mountains":
			return "Mountains"
		case "sports":
			return "Sports"
		case "walks":
			return "Walks"
		case "games":
			return "Games"
		case "theater":
			return "Theater"
		case "restaurant":
			return "Restaurant"
		case "networking":
			return "Networking"
		case "other":
			return "Other"
		}
	default: // ru
		switch catKey {
		case "mountains":
			return "Горы"
		case "sports":
			return "Спорт"
		case "walks":
			return "Прогулки"
		case "games":
			return "Игры"
		case "theater":
			return "Театр"
		case "restaurant":
			return "Ресторан"
		case "networking":
			return "Нетворкинг"
		case "other":
			return "Другое"
		}
	}
	return trimmed
}

func translateStatus(status string, lang string) (name string, class string) {
	lower := strings.ToLower(strings.TrimSpace(status))
	switch lower {
	case "active":
		class = "active"
		switch lang {
		case PageLangKK:
			name = "Белсенді"
		case PageLangEN:
			name = "Active"
		default:
			name = "Активно"
		}
	case "cancelled", "canceled":
		class = "cancelled"
		switch lang {
		case PageLangKK:
			name = "Тоқтатылды"
		case PageLangEN:
			name = "Cancelled"
		default:
			name = "Отменено"
		}
	case "finished", "completed":
		class = "finished"
		switch lang {
		case PageLangKK:
			name = "Аяқталды"
		case PageLangEN:
			name = "Finished"
		default:
			name = "Завершено"
		}
	case "blocked":
		class = "cancelled"
		switch lang {
		case PageLangKK:
			name = "Бұғатталды"
		case PageLangEN:
			name = "Blocked"
		default:
			name = "Заблокировано"
		}
	default:
		class = "finished"
		name = status
	}
	return
}

var almatyZone = time.FixedZone("Asia/Almaty", 5*3600)

var ruGenitiveMonths = map[time.Month]string{
	time.January:   "января",
	time.February:  "февраля",
	time.March:     "марта",
	time.April:     "апреля",
	time.May:       "мая",
	time.June:      "июня",
	time.July:      "июля",
	time.August:    "августа",
	time.September: "сентября",
	time.October:   "октября",
	time.November:  "ноября",
	time.December:  "декабря",
}

var kkGenitiveMonths = map[time.Month]string{
	time.January:   "қаңтар",
	time.February:  "ақпан",
	time.March:     "наурыз",
	time.April:     "сәуір",
	time.May:       "мамыр",
	time.June:      "маусым",
	time.July:      "шілде",
	time.August:    "тамыз",
	time.September: "қыркүйек",
	time.October:   "қазан",
	time.November:  "қараша",
	time.December:  "желтоқсан",
}

var enMonths = map[time.Month]string{
	time.January:   "January",
	time.February:  "February",
	time.March:     "March",
	time.April:     "April",
	time.May:       "May",
	time.June:      "June",
	time.July:      "July",
	time.August:    "August",
	time.September: "September",
	time.October:   "October",
	time.November:  "November",
	time.December:  "December",
}

func formatEventDateTime(startUTC, endUTC time.Time, lang string) string {
	start := startUTC.In(almatyZone)
	startHM := start.Format("15:04")

	if endUTC.IsZero() || endUTC.Before(startUTC) {
		switch lang {
		case PageLangKK:
			return fmt.Sprintf("%d %s, %s", start.Day(), kkGenitiveMonths[start.Month()], startHM)
		case PageLangEN:
			return fmt.Sprintf("%s %d, %s", enMonths[start.Month()], start.Day(), startHM)
		default: // ru
			return fmt.Sprintf("%d %s, %s", start.Day(), ruGenitiveMonths[start.Month()], startHM)
		}
	}

	end := endUTC.In(almatyZone)
	endHM := end.Format("15:04")
	sameDay := start.Year() == end.Year() && start.YearDay() == end.YearDay()

	switch lang {
	case PageLangKK:
		if sameDay {
			return fmt.Sprintf("%d %s, %s–%s", start.Day(), kkGenitiveMonths[start.Month()], startHM, endHM)
		}
		return fmt.Sprintf("%d %s, %s – %d %s, %s", start.Day(), kkGenitiveMonths[start.Month()], startHM, end.Day(), kkGenitiveMonths[end.Month()], endHM)
	case PageLangEN:
		if sameDay {
			return fmt.Sprintf("%s %d, %s–%s", enMonths[start.Month()], start.Day(), startHM, endHM)
		}
		return fmt.Sprintf("%s %d, %s – %s %d, %s", enMonths[start.Month()], start.Day(), startHM, enMonths[end.Month()], end.Day(), endHM)
	default: // ru
		if sameDay {
			return fmt.Sprintf("%d %s, %s–%s", start.Day(), ruGenitiveMonths[start.Month()], startHM, endHM)
		}
		return fmt.Sprintf("%d %s, %s – %d %s, %s", start.Day(), ruGenitiveMonths[start.Month()], startHM, end.Day(), ruGenitiveMonths[end.Month()], endHM)
	}
}

func formatParticipants(count, max int32, lang string) string {
	if max <= 0 {
		return strconv.Itoa(int(count))
	}
	switch lang {
	case PageLangKK:
		return fmt.Sprintf("%d / %d", count, max)
	case PageLangEN:
		return fmt.Sprintf("%d of %d", count, max)
	default: // ru
		return fmt.Sprintf("%d из %d", count, max)
	}
}

func formatOrganizerName(fullName, username, defaultName string) string {
	trimmedFull := strings.TrimSpace(fullName)
	if trimmedFull != "" {
		words := strings.Fields(trimmedFull)
		if len(words) > 0 {
			return words[0]
		}
	}
	trimmedUser := strings.TrimSpace(username)
	if trimmedUser != "" {
		return trimmedUser
	}
	return defaultName
}

func makeAppURL(eventID int) template.URL {
	return template.URL(fmt.Sprintf("zholdas://event/%d", eventID))
}

type PublicEventPageData struct {
	Lang                  string
	ID                    int
	CanonicalURL          string
	MetaTitle             string
	MetaDescription       string
	Brand                 string
	SiteName              string
	IsError               bool
	ErrorTitle            string
	ErrorBody             string
	IsPrivate             bool
	Title                 string
	CategoryName          string
	StatusName            string
	StatusClass           string
	FormattedDate         string
	LocationName          string
	RouteURL              string
	OrganizerName         string
	FormattedParticipants string
	Description           string
	AppURL                template.URL
	Texts                 PageTexts
}

const publicEventHTMLTemplate = `<!doctype html>
<html lang="{{.Lang}}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>{{.MetaTitle}}</title>
  <meta name="description" content="{{.MetaDescription}}">
  <meta name="theme-color" content="#f6f3ff" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#07051a" media="(prefers-color-scheme: dark)">
  <link rel="canonical" href="{{.CanonicalURL}}">
  <link rel="icon" type="image/png" sizes="32x32" href="https://www.zholdas.app/assets/favicon-32.png">
  <link rel="apple-touch-icon" href="https://www.zholdas.app/assets/icon-180.png">

  <!-- Open Graph -->
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="{{.SiteName}}">
  <meta property="og:title" content="{{.MetaTitle}}">
  <meta property="og:description" content="{{.MetaDescription}}">
  <meta property="og:url" content="{{.CanonicalURL}}">
  <meta property="og:image" content="https://www.zholdas.app/assets/icon-512.png">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary">
  <meta name="twitter:title" content="{{.MetaTitle}}">
  <meta name="twitter:description" content="{{.MetaDescription}}">
  <meta name="twitter:image" content="https://www.zholdas.app/assets/icon-512.png">

  <!-- Fonts -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">

  <style>
    :root {
      --bg: #f6f3ff;
      --bg-2: #ede7ff;
      --surface: #ffffff;
      --surface-2: #f1ecff;
      --line: rgba(65, 42, 135, 0.12);
      --text: #1b1430;
      --text-2: #584b74;
      --text-3: #82749c;
      --accent: #6a3fe6;
      --accent-deep: #572ec7;
      --accent-glow: rgba(106, 63, 230, 0.22);
      --success: #1fa860;
      --danger: #d92c3f;
      --radius: 22px;
      --shadow: 0 20px 60px rgba(60, 35, 140, 0.12);
      color-scheme: light;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #07051a;
        --bg-2: #0d0a24;
        --surface: #120e2e;
        --surface-2: #1a1540;
        --line: rgba(196, 180, 255, 0.14);
        --text: #f3f0ff;
        --text-2: #b9b0d8;
        --text-3: #8c84ad;
        --accent: #946bfe;
        --accent-deep: #572ec7;
        --accent-glow: rgba(148, 107, 254, 0.35);
        --success: #2ecc80;
        --danger: #ff5a6b;
        --shadow: 0 30px 80px rgba(3, 1, 15, 0.55);
        color-scheme: dark;
      }
    }

    * { box-sizing: border-box; }
    html { -webkit-text-size-adjust: 100%; }
    body {
      margin: 0;
      min-height: 100vh;
      background: radial-gradient(120% 80% at 50% 0%, var(--bg-2) 0%, var(--bg) 65%);
      color: var(--text);
      font: 400 16px/1.55 "Manrope", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
      -webkit-font-smoothing: antialiased;
      display: grid;
      place-items: center;
      padding: 24px 16px;
    }

    .card {
      width: 100%;
      max-width: 560px;
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 28px;
      padding: 32px 28px;
      box-shadow: var(--shadow);
    }
    @media (max-width: 480px) {
      .card {
        padding: 24px 18px;
        border-radius: 24px;
      }
    }

    .card__header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 22px;
    }
    .brand {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      text-decoration: none;
      color: var(--text);
      font-weight: 800;
      font-size: 18px;
    }
    .brand img {
      border-radius: 9px;
      display: block;
    }

    .badges {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      align-items: center;
      margin-bottom: 8px;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      padding: 6px 12px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 700;
      line-height: 1.2;
    }
    .badge--cat {
      background: var(--surface-2);
      color: var(--accent);
      border: 1px solid var(--line);
    }
    .badge--active {
      background: color-mix(in srgb, var(--success) 14%, transparent);
      color: var(--success);
    }
    .badge--cancelled {
      background: color-mix(in srgb, var(--danger) 14%, transparent);
      color: var(--danger);
    }
    .badge--finished {
      background: var(--surface-2);
      color: var(--text-3);
    }

    h1.title {
      margin: 16px 0 12px;
      font-size: clamp(24px, 5.5vw, 32px);
      font-weight: 800;
      line-height: 1.2;
      letter-spacing: -0.02em;
      color: var(--text);
      word-break: break-word;
    }
    .desc {
      margin: 0 0 24px;
      color: var(--text-2);
      font-size: 15px;
      line-height: 1.6;
      white-space: pre-line;
      word-break: break-word;
    }

    .grid {
      display: grid;
      gap: 10px;
      margin: 20px 0 24px;
    }
    .row {
      display: flex;
      align-items: center;
      gap: 14px;
      padding: 13px 16px;
      border-radius: 18px;
      background: var(--surface-2);
      border: 1px solid var(--line);
    }
    .row__icon {
      flex-shrink: 0;
      width: 36px;
      height: 36px;
      border-radius: 11px;
      background: color-mix(in srgb, var(--accent) 12%, var(--surface));
      color: var(--accent);
      display: grid;
      place-items: center;
    }
    .row__icon svg {
      width: 19px;
      height: 19px;
    }
    .row__content {
      flex: 1;
      min-width: 0;
    }
    .row__label {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: var(--text-3);
      margin-bottom: 2px;
    }
    .row__value {
      font-size: 15px;
      font-weight: 700;
      color: var(--text);
      word-break: break-word;
    }
    .btn--route {
      display: inline-block;
      margin-top: 10px;
      padding: 8px 14px;
      border-radius: 12px;
      background: var(--surface);
      border: 1px solid var(--line);
      color: var(--accent);
      font-size: 13px;
      font-weight: 700;
      text-decoration: none;
      white-space: nowrap;
      transition: border-color .15s ease, background .15s ease;
    }
    .btn--route:hover {
      border-color: var(--accent);
    }

    .state-icon {
      width: 56px;
      height: 56px;
      border-radius: 18px;
      background: color-mix(in srgb, var(--accent) 14%, var(--surface-2));
      color: var(--accent);
      display: grid;
      place-items: center;
      margin: 8px 0 18px;
    }
    .state-icon svg {
      width: 28px;
      height: 28px;
    }

    .actions {
      display: flex;
      flex-direction: column;
      gap: 12px;
      margin-top: 24px;
    }
    .btn {
      appearance: none;
      border: 0;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      padding: 16px 24px;
      border-radius: 16px;
      font: 700 16px/1 inherit;
      font-family: inherit;
      text-decoration: none;
      text-align: center;
      transition: transform .15s ease, box-shadow .15s ease, background .15s ease, border-color .15s ease;
      box-sizing: border-box;
    }
    .btn:hover {
      transform: translateY(-1px);
    }
    .btn:active {
      transform: translateY(0);
    }
    .btn--primary {
      background: linear-gradient(135deg, var(--accent), var(--accent-deep));
      color: #fff;
      box-shadow: 0 10px 28px var(--accent-glow);
    }
    .btn--primary:hover {
      box-shadow: 0 14px 34px var(--accent-glow);
    }
    .stores {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
    }
    @media (max-width: 440px) {
      .stores {
        grid-template-columns: 1fr;
      }
    }
    .btn--store {
      background: var(--surface-2);
      border: 1px solid var(--line);
      color: var(--text);
      padding: 13px 16px;
      font-size: 14px;
      font-weight: 600;
      border-radius: 14px;
    }
    .btn--store svg {
      width: 20px;
      height: 20px;
      flex-shrink: 0;
    }
    .btn--highlight {
      border-color: var(--accent);
      background: color-mix(in srgb, var(--accent) 14%, var(--surface-2));
      color: var(--accent);
      font-weight: 700;
      box-shadow: 0 4px 16px var(--accent-glow);
    }
    .note {
      text-align: center;
      color: var(--text-3);
      font-size: 13px;
      line-height: 1.45;
      margin: 4px 0 0;
    }
  </style>
</head>
<body>
  <main class="card">
    <header class="card__header">
      <a href="https://www.zholdas.app" class="brand" aria-label="{{.Texts.Brand}}">
        <img src="https://www.zholdas.app/assets/icon-180.png" width="36" height="36" alt="">
        <span>{{.Texts.Brand}}</span>
      </a>
    </header>

    {{if .IsError}}
      <div class="state-icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>
      </div>
      <h1 class="title">{{.ErrorTitle}}</h1>
      <p class="desc">{{.ErrorBody}}</p>
      <div class="actions">
        <div class="stores">
          <a id="app-store-btn" href="https://apps.apple.com/app/id6801053662" target="_blank" rel="noopener noreferrer" class="btn btn--store">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.63-.77 1.06-1.85.94-2.93-.93.04-2.07.62-2.73 1.39-.58.67-1.09 1.76-.95 2.81 1.04.08 2.11-.53 2.74-1.27z"/></svg>
            <span>{{.Texts.BtnAppStore}}</span>
          </a>
          <a id="play-store-btn" href="https://play.google.com/store/apps/details?id=com.example.zholdas" target="_blank" rel="noopener noreferrer" class="btn btn--store">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M3.25 1.5A1.5 1.5 0 0 0 3 2.75v18.5a1.5 1.5 0 0 0 .25 1.25l.08.08L13.5 12.4v-.4L3.33 1.92l-.08.08z M14.88 13.78l-2.46-2.46 2.46-2.46 3.65 2.08c.73.42.73 1.48 0 1.9l-3.65 2.08z M11.83 10.73L4.81 3.71 14.28 9.1l-2.45 1.63z M11.83 13.27l2.45 1.63-9.47 5.39 7.02-7.02z"/></svg>
            <span>{{.Texts.BtnGooglePlay}}</span>
          </a>
        </div>
      </div>

    {{else if .IsPrivate}}
      <div class="state-icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
      </div>
      <h1 class="title">{{.Texts.PrivacyTitle}}</h1>
      <p class="desc">{{.Texts.PrivacyBody}}</p>
      <div class="actions">
        <a id="open-app-btn" href="{{.AppURL}}" class="btn btn--primary">{{.Texts.BtnOpenInApp}}</a>
        <div class="stores">
          <a id="app-store-btn" href="https://apps.apple.com/app/id6801053662" target="_blank" rel="noopener noreferrer" class="btn btn--store">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.63-.77 1.06-1.85.94-2.93-.93.04-2.07.62-2.73 1.39-.58.67-1.09 1.76-.95 2.81 1.04.08 2.11-.53 2.74-1.27z"/></svg>
            <span>{{.Texts.BtnAppStore}}</span>
          </a>
          <a id="play-store-btn" href="https://play.google.com/store/apps/details?id=com.example.zholdas" target="_blank" rel="noopener noreferrer" class="btn btn--store">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M3.25 1.5A1.5 1.5 0 0 0 3 2.75v18.5a1.5 1.5 0 0 0 .25 1.25l.08.08L13.5 12.4v-.4L3.33 1.92l-.08.08z M14.88 13.78l-2.46-2.46 2.46-2.46 3.65 2.08c.73.42.73 1.48 0 1.9l-3.65 2.08z M11.83 10.73L4.81 3.71 14.28 9.1l-2.45 1.63z M11.83 13.27l2.45 1.63-9.47 5.39 7.02-7.02z"/></svg>
            <span>{{.Texts.BtnGooglePlay}}</span>
          </a>
        </div>
        <p class="note">{{.Texts.NoteNoApp}}</p>
      </div>

    {{else}}
      <div class="badges">
        {{if .CategoryName}}<span class="badge badge--cat">{{.CategoryName}}</span>{{end}}
        {{if .StatusName}}<span class="badge badge--{{.StatusClass}}">{{.StatusName}}</span>{{end}}
      </div>
      <h1 class="title">{{.Title}}</h1>

      <div class="grid">
        <div class="row">
          <div class="row__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
          </div>
          <div class="row__content">
            <div class="row__label">{{.Texts.LabelDateTime}}</div>
            <div class="row__value">{{.FormattedDate}}</div>
          </div>
        </div>

        <div class="row">
          <div class="row__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>
          </div>
          <div class="row__content">
            <div class="row__label">{{.Texts.LabelLocation}}</div>
            <div class="row__value">{{.LocationName}}</div>
            {{if .RouteURL}}
              <a href="{{.RouteURL}}" target="_blank" rel="noopener noreferrer" class="btn--route">{{.Texts.BtnRoute}}</a>
            {{end}}
          </div>
        </div>

        <div class="row">
          <div class="row__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
          </div>
          <div class="row__content">
            <div class="row__label">{{.Texts.LabelOrganizer}}</div>
            <div class="row__value">{{.OrganizerName}}</div>
          </div>
        </div>

        <div class="row">
          <div class="row__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>
          </div>
          <div class="row__content">
            <div class="row__label">{{.Texts.LabelParticipants}}</div>
            <div class="row__value">{{.FormattedParticipants}}</div>
          </div>
        </div>
      </div>

      {{if .Description}}
        <p class="desc">{{.Description}}</p>
      {{end}}

      <div class="actions">
        <a id="open-app-btn" href="{{.AppURL}}" class="btn btn--primary">{{.Texts.BtnOpenInApp}}</a>
        <div class="stores">
          <a id="app-store-btn" href="https://apps.apple.com/app/id6801053662" target="_blank" rel="noopener noreferrer" class="btn btn--store">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.63-.77 1.06-1.85.94-2.93-.93.04-2.07.62-2.73 1.39-.58.67-1.09 1.76-.95 2.81 1.04.08 2.11-.53 2.74-1.27z"/></svg>
            <span>{{.Texts.BtnAppStore}}</span>
          </a>
          <a id="play-store-btn" href="https://play.google.com/store/apps/details?id=com.example.zholdas" target="_blank" rel="noopener noreferrer" class="btn btn--store">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M3.25 1.5A1.5 1.5 0 0 0 3 2.75v18.5a1.5 1.5 0 0 0 .25 1.25l.08.08L13.5 12.4v-.4L3.33 1.92l-.08.08z M14.88 13.78l-2.46-2.46 2.46-2.46 3.65 2.08c.73.42.73 1.48 0 1.9l-3.65 2.08z M11.83 10.73L4.81 3.71 14.28 9.1l-2.45 1.63z M11.83 13.27l2.45 1.63-9.47 5.39 7.02-7.02z"/></svg>
            <span>{{.Texts.BtnGooglePlay}}</span>
          </a>
        </div>
        <p class="note">{{.Texts.NoteNoApp}}</p>
      </div>
    {{end}}
  </main>

  <script>
    (function() {
      var ua = navigator.userAgent || navigator.vendor || window.opera || '';
      var isAndroid = /android/i.test(ua);
      var isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
      var mainBtn = document.getElementById('open-app-btn');
      var appStoreBtn = document.getElementById('app-store-btn');
      var playStoreBtn = document.getElementById('play-store-btn');
      var playUrl = 'https://play.google.com/store/apps/details?id=com.example.zholdas';
      var appStoreUrl = 'https://apps.apple.com/app/id6801053662';
      var eventId = {{.ID}};

      if (isAndroid) {
        if (playStoreBtn) {
          playStoreBtn.classList.add('btn--highlight');
        }
        if (mainBtn && eventId > 0) {
          mainBtn.href = 'intent://event/' + eventId + '#Intent;scheme=zholdas;package=com.example.zholdas;S.browser_fallback_url=' + encodeURIComponent(playUrl) + ';end';
        }
      } else if (isIOS) {
        if (appStoreBtn) {
          appStoreBtn.classList.add('btn--highlight');
        }
        if (mainBtn && eventId > 0) {
          mainBtn.href = 'zholdas://event/' + eventId;
          mainBtn.addEventListener('click', function() {
            var start = Date.now();
            setTimeout(function() {
              if (document.visibilityState === 'visible' && (Date.now() - start < 3500)) {
                window.location.href = appStoreUrl;
              }
            }, 1500);
          });
        }
      } else {
        if (mainBtn) {
          mainBtn.style.display = 'none';
        }
      }
    })();
  </script>
</body>
</html>`

var publicEventTemplate = template.Must(template.New("public_event_page").Parse(publicEventHTMLTemplate))

func renderPublicEvent(c *gin.Context, statusCode int, data PublicEventPageData) {
	var buf bytes.Buffer
	if err := publicEventTemplate.Execute(&buf, data); err != nil {
		log.Printf("[PublicEvent] Template execution error: %v", err)
		c.String(http.StatusInternalServerError, "Internal Server Error")
		return
	}

	c.Header("Content-Type", "text/html; charset=utf-8")
	c.Header("Cache-Control", "public, max-age=60")
	c.Data(statusCode, "text/html; charset=utf-8", buf.Bytes())
}

func renderPublicEventError(c *gin.Context, statusCode int, lang string, eventID int, isDBError bool) {
	texts := getPageTexts(lang)

	title := texts.NotFoundTitle
	body := texts.NotFoundBody
	if isDBError {
		title = texts.ServerErrorTitle
		body = texts.ServerErrorBody
	}

	canonicalURL := "https://www.zholdas.app/"
	if eventID > 0 {
		canonicalURL = fmt.Sprintf("https://www.zholdas.app/e/%d", eventID)
	}

	data := PublicEventPageData{
		Lang:            lang,
		ID:              eventID,
		CanonicalURL:    canonicalURL,
		MetaTitle:       title + " | " + texts.Brand,
		MetaDescription: body,
		Brand:           texts.Brand,
		SiteName:        texts.Brand,
		IsError:         true,
		ErrorTitle:      title,
		ErrorBody:       body,
		Texts:           texts,
	}

	renderPublicEvent(c, statusCode, data)
}
