package handler

import (
	"fmt"
	"html"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type LegalLang string

const (
	LangRU LegalLang = "ru"
	LangKK LegalLang = "kk"
	LangEN LegalLang = "en"
)

// NormalizeLegalLang parses the lang query parameter into a supported LegalLang ("ru", "kk", "en"), defaulting to "ru".
func NormalizeLegalLang(raw string) LegalLang {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "kk", "kz", "kaz", "qaz":
		return LangKK
	case "en", "eng":
		return LangEN
	default:
		return LangRU
	}
}

// GetPrivacyPage serves the public Privacy Policy page in RU, KK, or EN.
func GetPrivacyPage(c *gin.Context) {
	lang := NormalizeLegalLang(c.Query("lang"))
	pageHTML := renderLegalPage(true, lang)
	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(pageHTML))
}

// GetTermsPage serves the public Terms of Service page in RU, KK, or EN.
func GetTermsPage(c *gin.Context) {
	lang := NormalizeLegalLang(c.Query("lang"))
	pageHTML := renderLegalPage(false, lang)
	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(pageHTML))
}

// AuthHandler wrapper methods for legal pages to allow mounting via authHandler if desired.
func (h *AuthHandler) GetPrivacyPage(c *gin.Context) {
	GetPrivacyPage(c)
}

func (h *AuthHandler) GetTermsPage(c *gin.Context) {
	GetTermsPage(c)
}

func renderLegalPage(isPrivacy bool, lang LegalLang) string {
	var (
		docTitle     string
		brandBadge   string
		switchPath   string
		altPagePath  string
		altPageLabel string
		contentHTML  string
		currentLang  = string(lang)
	)

	if isPrivacy {
		switchPath = "/privacy"
		altPagePath = fmt.Sprintf("/terms?lang=%s", currentLang)
		switch lang {
		case LangKK:
			docTitle = "Құпиялылық саясаты | Жолдас"
			brandBadge = "Жолдас · Құпиялылық саясаты"
			altPageLabel = "Пайдалану шарттарын оқу →"
			contentHTML = privacyContentKK
		case LangEN:
			docTitle = "Privacy Policy | Zholdas"
			brandBadge = "Zholdas · Privacy Policy"
			altPageLabel = "Read Terms of Service →"
			contentHTML = privacyContentEN
		default:
			docTitle = "Политика конфиденциальности | Жолдас"
			brandBadge = "Жолдас · Политика конфиденциальности"
			altPageLabel = "Читать Условия использования →"
			contentHTML = privacyContentRU
		}
	} else {
		switchPath = "/terms"
		altPagePath = fmt.Sprintf("/privacy?lang=%s", currentLang)
		switch lang {
		case LangKK:
			docTitle = "Пайдалану шарттары | Жолдас"
			brandBadge = "Жолдас · Пайдалану шарттары"
			altPageLabel = "Құпиялылық саясатын оқу →"
			contentHTML = termsContentKK
		case LangEN:
			docTitle = "Terms of Service | Zholdas"
			brandBadge = "Zholdas · Terms of Service"
			altPageLabel = "Read Privacy Policy →"
			contentHTML = termsContentEN
		default:
			docTitle = "Условия использования | Жолдас"
			brandBadge = "Жолдас · Условия использования"
			altPageLabel = "Читать Политику конфиденциальности →"
			contentHTML = termsContentRU
		}
	}

	ruActive := ""
	kkActive := ""
	enActive := ""
	switch lang {
	case LangKK:
		kkActive = " active"
	case LangEN:
		enActive = " active"
	default:
		ruActive = " active"
	}

	return fmt.Sprintf(`<!doctype html>
<!-- DRAFT: текст требует утверждения владельцем -->
<html lang="%s">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%s</title>
  <style>
    :root {
      color-scheme: dark;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    body {
      margin: 0;
      min-height: 100vh;
      background: radial-gradient(circle at top, #2e1065, #080414 70%%);
      color: #f3f4f6;
      padding: 32px 16px;
      box-sizing: border-box;
      line-height: 1.65;
    }
    main {
      max-width: 720px;
      margin: 0 auto;
      background: rgba(17, 10, 34, 0.88);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 28px;
      padding: 36px 32px;
      box-shadow: 0 24px 80px rgba(0, 0, 0, 0.45);
    }
    .header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 16px;
      margin-bottom: 24px;
    }
    .pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 8px 16px;
      border-radius: 999px;
      background: rgba(139, 92, 246, 0.18);
      color: #c4b5fd;
      font-weight: 700;
      font-size: 14px;
    }
    .lang-switch {
      display: inline-flex;
      background: rgba(255, 255, 255, 0.08);
      border-radius: 999px;
      padding: 4px;
      gap: 4px;
    }
    .lang-btn {
      padding: 6px 14px;
      border-radius: 999px;
      text-decoration: none;
      font-size: 13px;
      font-weight: 700;
      color: rgba(255, 255, 255, 0.7);
      transition: background 0.15s, color 0.15s;
    }
    .lang-btn.active {
      background: #7c3aed;
      color: #ffffff;
    }
    .lang-btn:hover:not(.active) {
      color: #ffffff;
    }
    h1 {
      margin: 0 0 10px;
      font-size: clamp(26px, 5vw, 36px);
      line-height: 1.25;
      color: #ffffff;
    }
    .meta-tag {
      color: rgba(255, 255, 255, 0.5);
      font-size: 13px;
      margin-bottom: 24px;
    }
    h2 {
      margin: 28px 0 12px;
      font-size: 20px;
      color: #ddd6fe;
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      padding-bottom: 6px;
    }
    p {
      color: rgba(255, 255, 255, 0.82);
      margin: 12px 0;
      font-size: 15px;
    }
    ul, ol {
      color: rgba(255, 255, 255, 0.82);
      padding-left: 22px;
      margin: 10px 0;
      font-size: 15px;
    }
    li {
      margin-bottom: 6px;
    }
    strong {
      color: #ffffff;
    }
    .notice-box {
      margin: 20px 0;
      padding: 16px 20px;
      background: rgba(124, 58, 237, 0.12);
      border: 1px solid rgba(139, 92, 246, 0.28);
      border-radius: 16px;
      font-size: 14px;
    }
    .footer-nav {
      margin-top: 36px;
      padding-top: 20px;
      border-top: 1px solid rgba(255, 255, 255, 0.1);
      display: flex;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 12px;
      font-size: 14px;
    }
    .footer-nav a {
      color: #a78bfa;
      text-decoration: none;
      font-weight: 600;
    }
    .footer-nav a:hover {
      text-decoration: underline;
    }
    @media (max-width: 560px) {
      main {
        padding: 24px 18px;
        border-radius: 20px;
      }
    }
  </style>
</head>
<body>
  <main>
    <div class="header-row">
      <div class="pill">%s</div>
      <nav class="lang-switch" aria-label="Language Selector">
        <a href="%s?lang=ru" class="lang-btn%s">RU</a>
        <a href="%s?lang=kk" class="lang-btn%s">KK</a>
        <a href="%s?lang=en" class="lang-btn%s">EN</a>
      </nav>
    </div>

    %s

    <div class="footer-nav">
      <a href="%s">%s</a>
      <span>© Жолдас (Zholdas)</span>
    </div>
  </main>
</body>
</html>`,
		html.EscapeString(string(lang)),
		html.EscapeString(docTitle),
		html.EscapeString(brandBadge),
		switchPath, ruActive,
		switchPath, kkActive,
		switchPath, enActive,
		contentHTML,
		html.EscapeString(altPagePath),
		html.EscapeString(altPageLabel),
	)
}

const privacyContentRU = `
<h1>Политика конфиденциальности</h1>
<div class="meta-tag">Дата вступления в силу: [дата] · Версия: 1.0 (Черновик)</div>

<p>Настоящая Политика конфиденциальности регулирует сбор, использование, хранение и защиту персональной информации пользователей мобильного приложения и платформы <strong>«Жолдас»</strong> (Казахстан), предназначенной для поиска единомышленников, встреч и событий по интересам.</p>

<h2>1. Какие данные мы собираем</h2>
<ul>
  <li><strong>Данные учетной записи и профиля:</strong> адрес электронной почты (email), отображаемое имя (full_name), уникальное имя пользователя (username), фотография профиля (аватар), город проживания, пол, год рождения и описание о себе (био).</li>
  <li><strong>События и участие:</strong> созданные вами события (название, описание, категория, время и место встречи), история участия в мероприятиях, статусы присутствия («иду», «опаздываю», «на месте»), оценки и отзывы.</li>
  <li><strong>Сообщения чатов:</strong> текст сообщений в групповых чатах событий и запросы к встроенному ИИ-помощнику.</li>
  <li><strong>Геопозиция:</strong> запрашивается исключительно с вашего прямого согласия в операционной системе смартфона. Используется строго для показа событий рядом с вами на карте, отметки прибытия на встречу и временной функции трансляции геопозиции («поделиться геопозицией») между участниками активного события. Приложение не собирает геопозицию в фоновом режиме.</li>
  <li><strong>Push-токены устройства:</strong> токены сервисов Apple APNs и Google FCM для доставки важных напоминаний о событиях, обновлениях статусов и сообщениях чата.</li>
  <li><strong>Технические журналы:</strong> IP-адреса, идентификаторы запросов (Request-ID) и системные логи, необходимые для обеспечения безопасности, защиты от спама и мониторинга работоспособности сервиса.</li>
</ul>

<h2>2. Зачем мы обрабатываем данные</h2>
<ul>
  <li>Обеспечение работы сервиса: создание аккаунтов, организация событий, общение участников в чатах.</li>
  <li>Подбор и рекомендации: отображение актуальных событий рядом и персонализированные рекомендации по интересам.</li>
  <li>Безопасность и модерация: предотвращение спама, оскорбительного поведения, расследование жалоб пользователей и защита сообщества.</li>
  <li>Оповещения: напоминания о времени начала запланированных встреч и важные сервисные уведомления.</li>
</ul>

<h2>3. Кому и как передаются данные</h2>
<p>Мы не продаем персональные данные третьим лицам и не передаем их рекламным сетям. Данные обрабатываются исключительно надежными инфраструктурными провайдерами:</p>
<ul>
  <li><strong>Хостинг и база данных:</strong> Supabase Inc. (США/ЕС) и Heroku (США/ЕС) для безопасного хранения базы данных и исполнения серверных API.</li>
  <li><strong>ИИ-помощник («Жорик»):</strong> текст запросов при обращении к помощнику и описание событий обрабатываются моделями OpenAI API исключительно для генерации ответов и рекомендаций.</li>
  <li><strong>Картография и навигация:</strong> OpenFreeMap / MapLibre и ссылки на сторонние карты (2GIS) для прокладки маршрутов.</li>
  <li><strong>Службы уведомлений:</strong> Apple Inc. (APNs) и Google LLC (FCM) для отправки push-уведомлений.</li>
</ul>

<h2>4. Хранение и удаление данных (Удаление аккаунта)</h2>
<div class="notice-box">
  <strong>Как удалить аккаунт:</strong> Вы можете в любой момент самостоятельно удалить свой аккаунт прямо в приложении: перейдите в <strong>«Профиль» → «Удалить аккаунт»</strong> и подтвердите удаление.
</div>
<p>При удалении аккаунта:</p>
<ul>
  <li>Все персональные данные учетной записи (email, имя, фото профиля, город, био, сессии авторизации, push-токены, созданные события) безвозвратно удаляются из активной базы данных.</li>
  <li>Сообщения в групповых чатах событий сохраняются в обезличенном виде: имя отправителя заменяется на <em>«Удалённый пользователь»</em> (deleted_user), аватар и идентификаторы очищаются. Это необходимо для сохранения контекста и целостности переписки остальных участников встречи.</li>
  <li>Данные хранятся до тех пор, пока действует ваша учетная запись, либо до ее удаления модератором за нарушение правил.</li>
</ul>

<h2>5. Права пользователя</h2>
<p>Вы имеете право просматривать и изменять свои данные через настройки профиля, отозвать разрешение на использование геопозиции и отправку push-уведомлений в системных настройках своего телефона, а также полностью удалить свои данные.</p>

<h2>6. Возрастное ограничение (16+)</h2>
<p>Сервис «Жолдас» предназначен строго для лиц в возрасте <strong>16 лет и старше</strong>. Использование сервиса лицами младше 16 лет запрещено.</p>

<h2>7. Контактные данные</h2>
<p>По всем вопросам конфиденциальности и удаления данных обращайтесь по электронной почте: <strong>[контактный email]</strong>.</p>
`

const privacyContentKK = `
<h1>Құпиялылық саясаты</h1>
<div class="meta-tag">Күшіне ену күні: [күні] · Нұсқа: 1.0 (Жоба)</div>

<p>Осы Құпиялылық саясаты <strong>«Жолдас»</strong> мобильді қосымшасы мен сервисін (Қазақстан) пайдаланушылардың дербес деректерін жинау, пайдалану, сақтау және қорғау тәртібін реттейді. Сервис қызығушылықтар бойынша достар табуға, кездесулер мен түрлі шараларды ұйымдастыруға арналған.</p>

<h2>1. Біз қандай деректерді жинаймыз</h2>
<ul>
  <li><strong>Тіркелгі және профиль деректері:</strong> электрондық пошта (email), аты-жөні (full_name), бірегей пайдаланушы аты (username), профиль суреті (аватар), қала, жынысы, туған жылы және өзі туралы қысқаша мәлімет (био).</li>
  <li><strong>Оқиғалар мен қатысу:</strong> сіз ұйымдастырған іс-шаралар (атауы, сипаттамасы, санаты, кездесу орны мен уақыты), қатысу тарихы, қатысу мәртебелері («барамын», «кешігемін», «жеттім»), бағалаулар мен пікірлер.</li>
  <li><strong>Чат хабарламалары:</strong> оқиғалардың жалпы топтық чаттарындағы хабарламалар және ЖИ-көмекшіге қойылған сұраулар.</li>
  <li><strong>Геопозиция (орналасқан жер):</strong> тек сіздің смартфоныңызда берген нақты рұқсатыңызбен ғана жиналады. Жақын маңдағы оқиғаларды картада көрсету, кездесу орнына келгенді белгілеу және белсенді оқиға кезінде қатысушылармен орналасқан жерді бөлісу («геопозициямен бөлісу») функциясы үшін пайдаланылады. Қосымша фондық режимде геолокацияны бақыламайды.</li>
  <li><strong>Құрылғының Push-токендері:</strong> маңызды еске салуларды, хабарламалар мен мәртебе өзгерістерін жедел жеткізу үшін Apple APNs және Google FCM токендері.</li>
  <li><strong>Техникалық журналдар:</strong> қауіпсіздікті қамтамасыз ету, спамнан қорғау және тұрақтылықты бақылау үшін IP-мекенжайлар, сұраныс логтары (Request-ID) мен техникалық мәліметтер.</li>
</ul>

<h2>2. Деректерді өңдеу мақсаттары</h2>
<ul>
  <li>Сервистің толыққанды жұмысын қамтамасыз ету: тіркелу, оқиғалар құру, қатысушылардың қарым-қатынасы.</li>
  <li>Іздеу және ұсынымдар: қасыңыздағы қызықты шараларды көрсету және жеке қызығушылықтарға сай ұсыныстар дайындау.</li>
  <li>Қоғамдастық қауіпсіздігі: спамға, былапыт сөздерге жол бермеу, шағымдарды қарау және қауіпсіз орта қалыптастыру.</li>
  <li>Хабардар ету: жоспарланған кездесулердің басталу уақытын еске салу және чаттағы жаңалықтарды хабарлау.</li>
</ul>

<h2>3. Деректерді үшінші тараптарға беру</h2>
<p>Біз дербес деректерді сатпаймыз және жарнама берушілерге таратпаймыз. Деректер тек сенімді инфрақұрылымдық серіктестер арқылы өңделеді:</p>
<ul>
  <li><strong>Хостинг және дерекқор:</strong> Supabase Inc. және Heroku — деректерді қауіпсіз сақтау және серверлік логиканы орындау үшін.</li>
  <li><strong>ЖИ-көмекші («Жорик»):</strong> көмекшіге жүгінгендегі сұрау мәтіндері жауап пен ұсыным қалыптастыру үшін OpenAI API үлгілері арқылы өңделеді.</li>
  <li><strong>Картография және навигация:</strong> OpenFreeMap / MapLibre және бағыт құру үшін сыртқы навигация қызметтері (2GIS).</li>
  <li><strong>Хабарлама сервистері:</strong> Apple Inc. (APNs) және Google LLC (FCM).</li>
</ul>

<h2>4. Деректерді сақтау және жою (Тіркелгіні жою)</h2>
<div class="notice-box">
  <strong>Тіркелгіні қалай жоюға болады:</strong> Тіркелгіңізді кез келген уақытта қосымша ішінде өзіңіз өшіре аласыз: <strong>«Профиль» → «Тіркелгіні жою»</strong> бөліміне өтіп, жоюды растаңыз.
</div>
<p>Тіркелгі жойылған жағдайда:</p>
<ul>
  <li>Барлық жеке деректер (email, аты-жөні, суреттер, қала, био, сессиялар, push-токендер, жасалған оқиғалар) негізгі дерекқордан біржола жойылады.</li>
  <li>Оқиға чаттарындағы хабарламалар мазмұндық тұтастықты сақтау үшін иесіздендіріледі: жіберушінің аты <em>«Удалённый пользователь»</em> (Жойылған пайдаланушы) деп көрсетіледі, ал жеке идентификаторлар тазартылады.</li>
  <li>Деректер сіз тіркелгіні жойғанға дейін немесе ереже бұзғаны үшін модератор бұғаттағанға дейін сақталады.</li>
</ul>

<h2>5. Пайдаланушы құқықтары</h2>
<p>Сіз өз деректеріңізді қарауға және түзетуге, телефон параметрлерінде геолокация мен push-хабарламаларға берілген рұқсатты қайтарып алуға, сондай-ақ барлық деректеріңізді толық жоюға құқылысыз.</p>

<h2>6. Жас шектеуі (16+)</h2>
<p>«Жолдас» қосымшасы тек <strong>16 жасқа толған және одан асқан</strong> пайдаланушыларға арналған. 16 жасқа толмаған тұлғаларға сервисті пайдалануға тыйым салынады.</p>

<h2>7. Байланыс ақпараты</h2>
<p>Дербес деректерді қорғау және жою мәселелері бойынша мына электрондық поштаға хабарласыңыз: <strong>[контакттік email]</strong>.</p>
`

const privacyContentEN = `
<h1>Privacy Policy</h1>
<div class="meta-tag">Effective Date: [дата] · Version: 1.0 (Draft)</div>

<p>This Privacy Policy outlines how the <strong>Zholdas</strong> platform and mobile application (Kazakhstan) collect, use, store, and safeguard your personal information. Zholdas is an interest-based community designed to help people discover local events, meet friends, and share hobbies.</p>

<h2>1. Information We Collect</h2>
<ul>
  <li><strong>Account & Profile Information:</strong> Email address, full name, unique username, profile picture (avatar), city, gender, birth year, and biography/interests (bio).</li>
  <li><strong>Events & Participation:</strong> Events created by you (title, description, category, location, and meeting time), participation history, arrival statuses ("going", "late", "arrived"), ratings, and reviews.</li>
  <li><strong>Chat Messages:</strong> Messages sent within group event chats and queries directed to the built-in AI companion.</li>
  <li><strong>Geolocation Data:</strong> Collected only with your explicit permission granted via your device OS settings. It is used strictly to display nearby events on the map, verify arrival at the event location, and power the temporary live location sharing feature among participants of an active event. We do not track your location in the background.</li>
  <li><strong>Device Push Tokens:</strong> Apple APNs and Google FCM tokens used to deliver reminders, status updates, and chat notifications.</li>
  <li><strong>Technical Logs:</strong> IP addresses, request IDs, and system logs collected for security maintenance, anti-spam safeguards, and uptime monitoring.</li>
</ul>

<h2>2. How and Why We Use Your Information</h2>
<ul>
  <li>Core service delivery: user authentication, event organization, and attendee communication.</li>
  <li>Discovery & Recommendations: finding events near you and offering relevant suggestions based on stated interests.</li>
  <li>Trust & Community Safety: content moderation, spam prevention, investigating user reports, and protecting member safety.</li>
  <li>Timely Notifications: reminders before upcoming meetings and direct notifications about event updates.</li>
</ul>

<h2>3. Third-Party Sharing</h2>
<p>We do not sell personal data or monetize it through advertising networks. Information is processed exclusively by reliable infrastructure providers:</p>
<ul>
  <li><strong>Cloud Infrastructure & Database:</strong> Supabase Inc. (US/EU) and Heroku (US/EU) for database storage and server-side logic.</li>
  <li><strong>AI Assistant ("Zhorik"):</strong> Prompts submitted to the companion and event summaries are processed by OpenAI API models strictly to generate suggestions and replies.</li>
  <li><strong>Maps & Navigation:</strong> OpenFreeMap / MapLibre and external navigation shortcuts (2GIS) for route planning.</li>
  <li><strong>Push Notification Gateways:</strong> Apple Inc. (APNs) and Google LLC (FCM).</li>
</ul>

<h2>4. Data Retention & Account Deletion</h2>
<div class="notice-box">
  <strong>How to Delete Your Account:</strong> You can delete your account at any time directly within the app: go to <strong>Profile → Delete Account</strong> and confirm your choice.
</div>
<p>When an account is deleted:</p>
<ul>
  <li>All personal profile information (email, name, photos, city, bio, active sessions, push tokens, and created events) is permanently removed from the active database.</li>
  <li>Messages sent in event group chats are retained in an anonymized form: the sender name is displayed as <em>"Удалённый пользователь"</em> (Deleted User), with personal IDs and avatars wiped. This preserves conversation context and continuity for the remaining participants.</li>
  <li>Data is retained as long as your account remains active or until administrative removal due to community rule violations.</li>
</ul>

<h2>5. Your Rights</h2>
<p>You have the right to access and update your profile information, revoke location and push notification permissions at any time through your mobile device settings, and request the complete deletion of your account.</p>

<h2>6. Age Requirement (16+)</h2>
<p>The Zholdas service is strictly intended for individuals aged <strong>16 and older</strong>. Individuals under the age of 16 are not permitted to use the service or register an account.</p>

<h2>7. Contact Us</h2>
<p>For inquiries regarding privacy, data protection, or account deletion, please contact us at: <strong>[контактный email]</strong>.</p>
`

const termsContentRU = `
<h1>Условия использования</h1>
<div class="meta-tag">Дата вступления в силу: [дата] · Версия: 1.0 (Черновик)</div>

<p>Добро пожаловать в <strong>«Жолдас»</strong>. Настоящие Условия использования (далее — «Условия») регулируют использование мобильного приложения и сопутствующих сервисов. Регистрация или использование сервиса означает ваше полное и безоговорочное согласие с настоящими Условиями.</p>

<h2>1. О сервисе</h2>
<p>«Жолдас» — это информационная платформа, которая помогает жителям и гостям Казахстана находить события, организовывать совместный досуг и знакомиться с единомышленниками по интересам (спорт, настольные игры, прогулки, культурные мероприятия и др.).</p>

<h2>2. Правила поведения и сообщества</h2>
<p>Каждый участник сообщества «Жолдас» обязан соблюдать культуру уважительного и безопасного общения. Категорически запрещено:</p>
<ul>
  <li>Публиковать оскорбления, угрозы, клевету, разжигать ненависть или дискриминацию по расовому, национальному, религиозному, половому или социальному признакам;</li>
  <li>Распространять материалы порнографического, экстремистского характера, пропагандировать насилие, употребление наркотических средств, оружия или любую иную незаконную деятельность;</li>
  <li>Заниматься спамом, навязчивой рекламой товаров и услуг, финансовыми пирамидами и сбором персональных данных других лиц;</li>
  <li>Выдавать себя за другое лицо или вводить участников в заблуждение относительно своего возраста, намерений или личности.</li>
</ul>

<h2>3. Жалобы, модерация и удаление контента</h2>
<ul>
  <li>В приложении действует система подачи жалоб (на подозрительные профили, события и сообщения в чатах).</li>
  <li>Администрация сервиса применяет как автоматические алгоритмы проверки контента, так и ручную модерацию.</li>
  <li>Администрация оставляет за собой право в одностороннем порядке заблокировать или удалить любой контент, а также временно или бессрочно заблокировать аккаунт нарушителя без предварительного уведомления.</li>
  <li>При получении множественных подтвержденных жалоб событие или пользователь могут быть автоматически ограничены в доступе.</li>
</ul>

<h2>4. Ответственность за офлайн-встречи (Безопасность)</h2>
<div class="notice-box">
  <strong>Важно:</strong> «Жолдас» является исключительно онлайн-инструментом для поиска мероприятий. Вся ответственность за проведение, участие и безопасность офлайн-встреч в реальной жизни лежит непосредственно на самих участниках.
</div>
<p><strong>Советы по безопасности при реальных встречах:</strong></p>
<ul>
  <li>Назначайте первые встречи только в публичных, хорошо освещенных и многолюдных местах (кафе, парки, спортивные площадки, коворкинги);</li>
  <li>Обязательно сообщайте близким или друзьям, куда, с кем и до какого времени вы отправляетесь;</li>
  <li>Никогда не передавайте малознакомым людям деньги, банковские карты, личные документы или конфиденциальные данные;</li>
  <li>Доверяйте своей интуиции: если поведение организатора или участников вызывает подозрение или дискомфорт, немедленно прекратите общение и покиньте встречу.</li>
</ul>

<h2>5. Возрастное ограничение (16+)</h2>
<p>Сервис доступен только для лиц, достигших <strong>16 лет</strong>. Регистрируясь в приложении, вы подтверждаете, что вам исполнилось 16 лет.</p>

<h2>6. Изменение условий</h2>
<p>Мы оставляем за собой право вносить изменения в настоящие Условия. Обновленная версия публикуется на этой странице. Продолжение использования приложения после внесения изменений означает ваше согласие с новой редакцией.</p>

<h2>7. Контакты</h2>
<p>Если у вас есть вопросы, предложения или претензии относительно работы сервиса, пожалуйста, свяжитесь с нами: <strong>[контактный email]</strong>.</p>
`

const termsContentKK = `
<h1>Пайдалану шарттары</h1>
<div class="meta-tag">Күшіне ену күні: [күні] · Нұсқа: 1.0 (Жоба)</div>

<p><strong>«Жолдас»</strong> қосымшасына қош келдіңіз. Осы Пайдалану шарттары (бұдан әрі — «Шарттар») қосымша мен оған қатысты сервистерді пайдалану ережелерін белгілейді. Қосымшаға тіркелу немесе оны қолдану осы Шарттармен толық келіскеніңізді білдіреді.</p>

<h2>1. Сервис туралы</h2>
<p>«Жолдас» — Қазақстан қалаларында қызығушылықтары бір адамдарды табуға, бос уақытты бірге өткізуге және түрлі шараларды (спорт, үстел ойындары, серуендеу, мәдени кездесулер) ұйымдастыруға арналған ақпараттық платформа.</p>

<h2>2. Қоғамдастық ережелері мен мінез-құлық</h2>
<p>Сервистің әрбір пайдаланушысы мәдениетті әрі сыйластықпен қарым-қатынас жасауға міндетті. Мынадай әрекеттерге қатаң тыйым салынады:</p>
<ul>
  <li>Басқа пайдаланушыларды балағаттау, қорлау, қорқыту, нәсілдік, ұлттық, діни немесе жыныстық белгілері бойынша кемсіту;</li>
  <li>Порнографиялық, экстремистік сипаттағы контентті, зорлық-зомбылықты, есірткіні, қару-жарақты немесе өзге де заңсыз әрекеттерді насихаттау;</li>
  <li>Спам тарату, тауарлар мен қызметтерді рұқсатсыз жарнамалау, қаржылық алаяқтық жасау және өзгелердің деректерін жинау;</li>
  <li>Өзін басқа біреу ретінде көрсету, жасын немесе жеке басын жасырып, адамдарды алдау.</li>
</ul>

<h2>3. Шағымдар, модерация және контентті жою</h2>
<ul>
  <li>Қосымшада күмәнді профильдерге, оқиғаларға немесе чат хабарламаларына шағым жіберу мүмкіндігі бар.</li>
  <li>Сервис әкімшілігі автоматты сүзгілер мен қолмен модерациялау жүйесін қолданады.</li>
  <li>Әкімшілік ережені бұзған кез келген контентті жоюға, сондай-ақ заң бұзған пайдаланушының тіркелгісін алдын ала ескертусіз уақытша немесе біржола бұғаттауға құқылы.</li>
  <li>Шағымдар саны көп болған жағдайда оқиға немесе пайдаланушы автоматты түрде бұғатталуы мүмкін.</li>
</ul>

<h2>4. Офлайн-кездесулер үшін жауапкершілік (Қауіпсіздік)</h2>
<div class="notice-box">
  <strong>Маңызды:</strong> «Жолдас» — тек оқиғаларды табуға арналған онлайн-құрал. Нақты өмірдегі кездесулерді өткізу, оған қатысу және жеке қауіпсіздік үшін жауапкершілік толықтай қатысушылардың өз мойнында.
</div>
<p><strong>Нақты өмірде кездесу кезіндегі қауіпсіздік кеңестері:</strong></p>
<ul>
  <li>Алғашқы кездесулерді тек адамдар көп жүретін, жарық қоғамдық орындарда (дәмханалар, саябақтар, коворкингтер, спорт алаңдары) өткізіңіз;</li>
  <li>Кездесуге бара жатқаныңыз туралы жақындарыңызға немесе достарыңызға алдын ала хабарлап, баратын орныңыз бен уақытыңызды айтыңыз;</li>
  <li>Бейтаныс адамдарға ақша бермеңіз, банк карталары мен құжаттарыңызды сеніп тапсырмаңыз;</li>
  <li>Егер кездесуде өзіңізді жайсыз сезінсеңіз немесе күмәнді жағдай туындаса, кездесуді дереу тоқтатып, қауіпсіз жерге кетіңіз.</li>
</ul>

<h2>5. Жас шектеуі (16+)</h2>
<p>Сервисті тек <strong>16 жасқа толған</strong> адамдар ғана пайдалана алады. Тіркеле отырып, сіз жасыңыздың 16-ға толғанын растайсыз.</p>

<h2>6. Шарттардың өзгеруі</h2>
<p>Біз осы Шарттарды кез келген уақытта жаңартуға құқылымыз. Жаңа нұсқа осы бетте жарияланады. Өзгерістер енгізілгеннен кейін қосымшаны пайдалануды жалғастыру жаңа шарттармен келіскеніңізді білдіреді.</p>

<h2>7. Байланыс</h2>
<p>Шарттар немесе сервистің жұмысы туралы сұрақтарыңыз болса, мына электрондық поштаға хабарласыңыз: <strong>[контакттік email]</strong>.</p>
`

const termsContentEN = `
<h1>Terms of Service</h1>
<div class="meta-tag">Effective Date: [дата] · Version: 1.0 (Draft)</div>

<p>Welcome to <strong>Zholdas</strong>. These Terms of Service ("Terms") govern your use of the Zholdas mobile application and related services. By registering or using the platform, you agree to be bound by these Terms.</p>

<h2>1. About the Service</h2>
<p>Zholdas is an informational platform helping individuals in Kazakhstan discover activities, organize leisure time, and connect with people who share common interests (sports, board games, outdoor walks, arts, and community meetups).</p>

<h2>2. Code of Conduct & Community Guidelines</h2>
<p>All members of the Zholdas community are expected to maintain respectful, civil, and lawful behavior. Strictly prohibited behaviors include:</p>
<ul>
  <li>Harassment, insults, threats, defamation, hate speech, or discrimination based on race, ethnicity, religion, gender, or sexual orientation;</li>
  <li>Publishing sexually explicit, pornographic, or extremist content, advocating violence, illegal narcotics, firearms, or criminal activities;</li>
  <li>Distributing unsolicited spam, commercial promotion, fraudulent investment schemes, or harvesting personal data of other members;</li>
  <li>Impersonating another person or misrepresenting your identity, age, or intentions.</li>
</ul>

<h2>3. User Reports, Moderation & Content Removal</h2>
<ul>
  <li>Users can report suspicious profiles, inappropriate events, or abusive chat messages directly in the app.</li>
  <li>Our team uses automated filtering combined with human moderation to safeguard the community.</li>
  <li>We reserve the right to remove any content and suspend or terminate accounts violating these Terms without prior warning.</li>
  <li>Events receiving multiple verified reports may be automatically blocked to prevent harm.</li>
</ul>

<h2>4. Responsibility for In-Person Gatherings (Safety Notice)</h2>
<div class="notice-box">
  <strong>Important Safety Notice:</strong> Zholdas is solely an online medium for discovering events. All participation, organization, and safety precautions regarding real-world in-person gatherings remain the sole responsibility of the participants.
</div>
<p><strong>Safety Recommendations for Real-Life Meetups:</strong></p>
<ul>
  <li>Always schedule first meetings in busy, well-lit, public venues (cafes, public parks, coworking spaces, athletic grounds);</li>
  <li>Inform trusted friends or family members about where you are going, who you are meeting, and when you plan to return;</li>
  <li>Never lend money, share banking credentials, or surrender identification documents to strangers;</li>
  <li>Trust your intuition: if a situation or individual feels unsafe or uncomfortable, leave immediately.</li>
</ul>

<h2>5. Age Requirement (16+)</h2>
<p>You must be at least <strong>16 years of age</strong> to use Zholdas. By registering, you warrant and represent that you meet this age threshold.</p>

<h2>6. Changes to Terms</h2>
<p>We may revise these Terms periodically. Updated versions will be published on this page. Your continued use of the service following modifications constitutes acceptance of the amended Terms.</p>

<h2>7. Contact Us</h2>
<p>If you have any questions or concerns regarding these Terms, please reach out via email at: <strong>[контактный email]</strong>.</p>
`
