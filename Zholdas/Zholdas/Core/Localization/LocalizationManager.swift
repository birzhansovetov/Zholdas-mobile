import SwiftUI
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @AppStorage("app_language") var currentLanguage: String = "ru" {
        didSet {
            // Force SwiftUI environment and views to update
            objectWillChange.send()
        }
    }
    
    // Translation dictionary: key -> [lang: translation]
    private let translations: [String: [String: String]] = [
        // Tabs
        "tab_map": [
            "ru": "Карта",
            "kk": "Карта",
            "en": "Map"
        ],
        "tab_events": [
            "ru": "События",
            "kk": "Оқиғалар",
            "en": "Events"
        ],
        "tab_chats": [
            "ru": "Чаты",
            "kk": "Чаттар",
            "en": "Chats"
        ],
        "tab_profile": [
            "ru": "Профиль",
            "kk": "Профиль",
            "en": "Profile"
        ],
        "tab_activity": [
            "ru": "Активность",
            "kk": "Хабарлар",
            "en": "Activity"
        ],
        
        // Auth screens
        "auth_welcome": [
            "ru": "Добро пожаловать в Zholdas",
            "kk": "Zholdas қосымшасына қош келдіңіз",
            "en": "Welcome to Zholdas"
        ],
        "auth_signin_title": [
            "ru": "Вход в аккаунт",
            "kk": "Жүйеге кіру",
            "en": "Sign In to Account"
        ],
        "auth_signup_title": [
            "ru": "Регистрация профиля",
            "kk": "Профильді тіркеу",
            "en": "Register Profile"
        ],
        "auth_email": [
            "ru": "Электронная почта",
            "kk": "Электрондық пошта",
            "en": "Email Address"
        ],
        "auth_password": [
            "ru": "Пароль",
            "kk": "Құпия сөз",
            "en": "Password"
        ],
        "auth_signin_btn": [
            "ru": "Войти",
            "kk": "Кіру",
            "en": "Sign In"
        ],
        "auth_signup_btn": [
            "ru": "Зарегистрироваться",
            "kk": "Тіркелу",
            "en": "Register"
        ],
        "auth_no_account": [
            "ru": "Нет аккаунта? Зарегистрироваться",
            "kk": "Аккаунт жоқ па? Тіркелу",
            "en": "No account? Sign Up"
        ],
        "auth_have_account": [
            "ru": "Уже есть аккаунт? Войти",
            "kk": "Аккаунт бар ма? Кіру",
            "en": "Already have an account? Sign In"
        ],
        "auth_fullname": [
            "ru": "Полное имя (ФИО)",
            "kk": "Толық аты-жөні",
            "en": "Full Name"
        ],
        "auth_username": [
            "ru": "Имя пользователя (@username)",
            "kk": "Пайдаланушы аты (@username)",
            "en": "Username (@username)"
        ],
        "auth_birthyear": [
            "ru": "Год рождения",
            "kk": "Туған жылы",
            "en": "Birth Year"
        ],
        "auth_gender": [
            "ru": "Ваш пол",
            "kk": "Жынысыңыз",
            "en": "Your Gender"
        ],
        "auth_gender_male": [
            "ru": "Мужской",
            "kk": "Ер адам",
            "en": "Male"
        ],
        "auth_gender_female": [
            "ru": "Женский",
            "kk": "Әйел адам",
            "en": "Female"
        ],
        "auth_avatar_selection": [
            "ru": "Выберите ваш аватар:",
            "kk": "Аватарыңызды таңдаңыз:",
            "en": "Select your avatar:"
        ],
        "auth_bio": [
            "ru": "О себе (интересы, хобби)",
            "kk": "Өзім туралы (қызығушылықтар)",
            "en": "About me (interests, hobbies)"
        ],
        
        // Profile tab
        "prof_title": [
            "ru": "Профиль пользователя",
            "kk": "Пайдаланушы профилі",
            "en": "User Profile"
        ],
        "prof_friends": [
            "ru": "друзей",
            "kk": "достар",
            "en": "friends"
        ],
        "prof_created": [
            "ru": "событий",
            "kk": "оқиғалар",
            "en": "events"
        ],
        "prof_edit_btn": [
            "ru": "Редакт.",
            "kk": "Өңдеу",
            "en": "Edit"
        ],
        "prof_lang": [
            "ru": "Язык приложения",
            "kk": "Қосымша тілі",
            "en": "App Language"
        ],
        "prof_theme": [
            "ru": "Тема приложения",
            "kk": "Қолданба тақырыбы",
            "en": "App Theme"
        ],
        "theme_system": [
            "ru": "Системная",
            "kk": "Жүйелік",
            "en": "System"
        ],
        "theme_dark": [
            "ru": "Темная",
            "kk": "Қараңғы",
            "en": "Dark"
        ],
        "theme_light": [
            "ru": "Светлая",
            "kk": "Жарық",
            "en": "Light"
        ],
        "prof_notifications": [
            "ru": "Уведомления и заявки",
            "kk": "Хабарландырулар",
            "en": "Notifications"
        ],
        "prof_my_events": [
            "ru": "Мои события",
            "kk": "Менің оқиғаларым",
            "en": "My Events"
        ],
        "prof_friends_list": [
            "ru": "Список друзей",
            "kk": "Достар тізімі",
            "en": "Friends List"
        ],
        "prof_signout": [
            "ru": "Выйти из аккаунта",
            "kk": "Аккаунттан шығу",
            "en": "Sign Out"
        ],
        "prof_about_me": [
            "ru": "О СЕБЕ",
            "kk": "ӨЗІМ ТУРАЛЫ",
            "en": "ABOUT ME"
        ],
        "prof_age": [
            "ru": "Возраст",
            "kk": "Жасы",
            "en": "Age"
        ],
        "prof_gender": [
            "ru": "Пол",
            "kk": "Жынысы",
            "en": "Gender"
        ],
        "prof_loading": [
            "ru": "Загрузка профиля...",
            "kk": "Профиль жүктелуде...",
            "en": "Loading profile..."
        ],
        "prof_events_count": [
            "ru": "Ивентов",
            "kk": "Оқиғалар",
            "en": "Events"
        ],
        "prof_friends_count": [
            "ru": "Друзей",
            "kk": "Достар",
            "en": "Friends"
        ],
        "prof_rating_count": [
            "ru": "Рейтинг",
            "kk": "Рейтинг",
            "en": "Rating"
        ],
        "prof_moderator_panel": [
            "ru": "Панель модератора",
            "kk": "Модератор панелі",
            "en": "Moderator Panel"
        ],
        "prof_admin_panel": [
            "ru": "Админ-панель",
            "kk": "Әкімші панелі",
            "en": "Admin Panel"
        ],
        
        // Events general
        "ev_active": [
            "ru": "Активный",
            "kk": "Белсенді",
            "en": "Active"
        ],
        "ev_finished": [
            "ru": "Завершен",
            "kk": "Аяқталды",
            "en": "Finished"
        ],
        "ev_cancelled": [
            "ru": "Отменен",
            "kk": "Бас тартылды",
            "en": "Cancelled"
        ],
        "ev_details_title": [
            "ru": "Детали встречи",
            "kk": "Кездесу мәліметтері",
            "en": "Meeting Details"
        ],
        "ev_remaining_seats": [
            "ru": "Осталось мест",
            "kk": "Бос орындар",
            "en": "Seats Left"
        ],
        "ev_participants": [
            "ru": "Участников",
            "kk": "Қатысушылар",
            "en": "Participants"
        ],
        "ev_status": [
            "ru": "Статус встречи",
            "kk": "Кездесу мәртебесі",
            "en": "Event Status"
        ],
        "ev_organizer": [
            "ru": "Организатор встречи",
            "kk": "Кездесу ұйымдастырушысы",
            "en": "Event Organizer"
        ],
        "ev_organizer_loading": [
            "ru": "Загрузка профиля",
            "kk": "Профиль жүктелуде",
            "en": "Loading profile"
        ],
        "ev_date_time": [
            "ru": "Дата и время",
            "kk": "Күні мен уақыты",
            "en": "Date & Time"
        ],
        "ev_you_are_organizer": [
            "ru": "Вы являетесь организатором",
            "kk": "Сіз ұйымдастырушысыз",
            "en": "You are the organizer"
        ],
        "ev_rate_participants": [
            "ru": "Оценить участников",
            "kk": "Қатысушыларды бағалау",
            "en": "Rate Participants"
        ],
        "ev_prepare_btn": [
            "ru": "Подготовиться",
            "kk": "Дайындалу",
            "en": "Prepare"
        ],
        "ev_prepare_title": [
            "ru": "Чеклист от Жорика",
            "kk": "Жорик чеклисті",
            "en": "Joryk Checklist"
        ],
        "ev_prepare_loading": [
            "ru": "Жорик собирает чеклист...",
            "kk": "Жорик чеклист дайындап жатыр...",
            "en": "Joryk is preparing your checklist..."
        ],
        "ev_restrictions": [
            "ru": "Ограничения: Все · Возраст 18 – 30 лет",
            "kk": "Шектеулер: Барлығы · Жас 18 – 30 жас",
            "en": "Restrictions: All · Age 18 – 30 years"
        ],
        "ev_location": [
            "ru": "Место проведения",
            "kk": "Өтетін орны",
            "en": "Event Location"
        ],
        "ev_joined_progress": [
            "ru": "Присоединилось участников",
            "kk": "Қосылған қатысушылар",
            "en": "Joined Participants"
        ],
        "ev_view_all_participants": [
            "ru": "Посмотреть всех участников",
            "kk": "Барлық қатысушыларды көру",
            "en": "View All Participants"
        ],
        "ev_how_it_runs": [
            "ru": "Как пройдет встреча",
            "kk": "Кездесу қалай өтеді",
            "en": "How the Event Will Go"
        ],
        "ev_rules": [
            "ru": "1. Уважайте других участников.\n2. Будьте вовремя.\n3. Соблюдайте правила безопасности.",
            "kk": "1. Басқа қатысушыларды құрметтеңіз.\n2. Уақытында келіңіз.\n3. Қауіпсіздік ережелерін сақтаңыз.",
            "en": "1. Respect other participants.\n2. Be on time.\n3. Follow safety guidelines."
        ],
        "ev_join_btn": [
            "ru": "Присоединиться",
            "kk": "Қосылу",
            "en": "Join Event"
        ],
        "ev_leave_btn": [
            "ru": "Покинуть встречу",
            "kk": "Кездесуден шығу",
            "en": "Leave Event"
        ],
        "ev_open_chat_btn": [
            "ru": "Открыть чат встречи",
            "kk": "Кездесу чатын ашу",
            "en": "Open Event Chat"
        ],
        "ev_share_btn": [
            "ru": "Поделиться",
            "kk": "Бөлісу",
            "en": "Share Event"
        ],
        "ev_route_btn": [
            "ru": "Построить маршрут",
            "kk": "Бағытты құру",
            "en": "Get Directions"
        ],
        
        // Create Event screen
        "create_ev_cover": [
            "ru": "Обложка активности",
            "kk": "Мұқаба суреті",
            "en": "Event Cover"
        ],
        "create_ev_select_photo": [
            "ru": "Выбрать фото обложки",
            "kk": "Мұқаба суретін таңдау",
            "en": "Select Cover Photo"
        ],
        "create_ev_title_label": [
            "ru": "Название активности",
            "kk": "Оқиға атауы",
            "en": "Event Title"
        ],
        "create_ev_title_placeholder": [
            "ru": "Например: Поход на Кок-Жайляу",
            "kk": "Мысалы: Көк-Жайлауға жорық",
            "en": "e.g. Hike to Kok-Zhailau"
        ],
        "create_ev_location_label": [
            "ru": "Где встречаемся (Ориентир)",
            "kk": "Кездесетін орын (Бағдар)",
            "en": "Meeting Point (Landmark)"
        ],
        "create_ev_location_placeholder": [
            "ru": "Например: Остановка у эко-поста",
            "kk": "Мысалы: Эко-бекет жанындағы аялдама",
            "en": "e.g. Bus stop at the eco-post"
        ],
        "create_ev_pick_location": [
            "ru": "Выбрать на карте",
            "kk": "Картадан таңдау",
            "en": "Pick on map"
        ],
        "create_ev_pick_location_hint": [
            "ru": "Укажите точку встречи на карте",
            "kk": "Кездесу нүктесін картада белгілеңіз",
            "en": "Mark the meeting point on the map"
        ],
        "create_ev_map_tap_hint": [
            "ru": "Нажмите на карту, чтобы поставить пин в месте встречи.",
            "kk": "Кездесу орнын белгілеу үшін картаны басыңыз.",
            "en": "Tap the map to place the meeting pin."
        ],
        "create_ev_location_selected": [
            "ru": "Точка встречи выбрана",
            "kk": "Кездесу нүктесі таңдалды",
            "en": "Meeting point selected"
        ],
        "create_ev_confirm_location": [
            "ru": "Подтвердить место",
            "kk": "Орынды растау",
            "en": "Confirm location"
        ],
        "create_ev_selected_point_name": [
            "ru": "Выбранная точка на карте",
            "kk": "Картадағы таңдалған нүкте",
            "en": "Selected point on map"
        ],
        "edit_prof_change_avatar": [
            "ru": "Нажмите, чтобы сменить фото",
            "kk": "Фотоны өзгерту үшін басыңыз",
            "en": "Tap to change photo"
        ],
        "create_ev_participants_label": [
            "ru": "Максимальное количество участников",
            "kk": "Қатысушылардың максималды саны",
            "en": "Maximum Participants"
        ],
        "create_ev_people_count": [
            "ru": "человек",
            "kk": "адам",
            "en": "people"
        ],
        "create_ev_date": [
            "ru": "Дата",
            "kk": "Күні",
            "en": "Date"
        ],
        "create_ev_start": [
            "ru": "Начало",
            "kk": "Басталуы",
            "en": "Start Time"
        ],
        "create_ev_end": [
            "ru": "Окончание",
            "kk": "Аяқталуы",
            "en": "End Time"
        ],
        "create_ev_visibility_header": [
            "ru": "КТО МОЖЕТ ВИДЕТЬ ИВЕНТ",
            "kk": "ОҚИҒАНЫ КІМ КӨРЕ АЛАДЫ",
            "en": "WHO CAN SEE THE EVENT"
        ],
        "create_ev_audience_header": [
            "ru": "АУДИТОРИЯ",
            "kk": "АУДИТОРИЯ",
            "en": "AUDIENCE"
        ],
        "create_ev_gender_label": [
            "ru": "Для кого",
            "kk": "Кімге арналған",
            "en": "For whom"
        ],
        "create_ev_gender_men": [
            "ru": "Мужчины",
            "kk": "Ерлер",
            "en": "Men"
        ],
        "create_ev_gender_women": [
            "ru": "Женщины",
            "kk": "Әйелдер",
            "en": "Women"
        ],
        "create_ev_age_range_label": [
            "ru": "Возрастной диапазон (необязательно)",
            "kk": "Жас аралығы (міндетті емес)",
            "en": "Age Range (optional)"
        ],
        "create_ev_years": [
            "ru": "лет",
            "kk": "жас",
            "en": "years"
        ],
        "create_ev_nav_title": [
            "ru": "Новое событие",
            "kk": "Жаңа оқиға",
            "en": "New Event"
        ],
        "create_ev_cancel": [
            "ru": "Отмена",
            "kk": "Бас тарту",
            "en": "Cancel"
        ],
        "create_title": [
            "ru": "Создание события",
            "kk": "Оқиға жасау",
            "en": "Create New Event"
        ],
        "create_ev_name": [
            "ru": "Название события",
            "kk": "Оқиға атауы",
            "en": "Event Title"
        ],
        "create_ev_desc": [
            "ru": "Описание встречи",
            "kk": "Кездесу сипаттамасы",
            "en": "Event Description"
        ],
        "create_ev_category": [
            "ru": "Выберите категорию",
            "kk": "Санатты таңдаңыз",
            "en": "Select Category"
        ],
        "create_ev_max": [
            "ru": "Лимит участников (человек)",
            "kk": "Қатысушылар шегі (адам)",
            "en": "Max Participants"
        ],
        "create_ev_visibility": [
            "ru": "Видимость события",
            "kk": "Оқиғаның көрінуі",
            "en": "Event Visibility"
        ],
        "create_ev_visibility_all": [
            "ru": "Все пользователи",
            "kk": "Барлық пайдаланушылар",
            "en": "All Users"
        ],
        "create_ev_visibility_friends": [
            "ru": "Только друзья",
            "kk": "Тек достар",
            "en": "Friends Only"
        ],
        "create_ev_gender": [
            "ru": "Ограничение по полу",
            "kk": "Жыныс шектеуі",
            "en": "Gender Restriction"
        ],
        "create_ev_gender_all": [
            "ru": "Все",
            "kk": "Барлығы",
            "en": "All"
        ],
        "create_ev_gender_m": [
            "ru": "Только мужчины",
            "kk": "Тек ерлер",
            "en": "Men Only"
        ],
        "create_ev_gender_f": [
            "ru": "Только женщины",
            "kk": "Тек әйелдер",
            "en": "Women Only"
        ],
        "create_ev_age": [
            "ru": "Возрастные ограничения",
            "kk": "Жас шектеулері",
            "en": "Age Limits"
        ],
        "create_ev_age_from": [
            "ru": "Возраст от",
            "kk": "Жас мөлшері",
            "en": "Min Age"
        ],
        "create_ev_age_to": [
            "ru": "до",
            "kk": "дейін",
            "en": "to"
        ],
        "create_ev_address": [
            "ru": "Адрес проведения",
            "kk": "Өтетін мекен-жайы",
            "en": "Address"
        ],
        "create_ev_btn": [
            "ru": "Опубликовать событие",
            "kk": "Оқиғаны жариялау",
            "en": "Publish Event"
        ],
        
        // Chats
        "chat_assistant_title": [
            "ru": "ИИ Помощник Жорик",
            "kk": "Жорик ИИ Көмекшісі",
            "en": "AI Assistant Zhorik"
        ],
        "chat_placeholder": [
            "ru": "Введите сообщение...",
            "kk": "Хабарлама енгізіңіз...",
            "en": "Type a message..."
        ],
        
        // Map screen
        "map_offline_mode": [
            "ru": "Вы работаете в офлайн-режиме. Показаны сохраненные события.",
            "kk": "Сіз оффлайн режимде жұмыс істеп жатырсыз. Сақталған оқиғалар көрсетілген.",
            "en": "You are working in offline mode. Saved events are shown."
        ],
        "map_events_in_city": [
            "ru": "%d встреч в Алматы",
            "kk": "Алматыда %d кездесу",
            "en": "%d events in Almaty"
        ],
        "map_search_placeholder": [
            "ru": "Чем хочешь заняться? (ИИ-поиск)",
            "kk": "Немен айналысқыңыз келеді? (ИИ-іздеу)",
            "en": "What do you want to do? (AI-Search)"
        ],
        "map_ai_recs_title": [
            "ru": "Жолдас AI Рекомендации",
            "kk": "Жолик AI Ұсыныстары",
            "en": "Zholdas AI Recommendations"
        ],
        "map_ai_markers_hint": [
            "ru": "Рекомендованные маркеры подсвечены синим на карте 📍",
            "kk": "Ұсынылған белгілер картада көк түспен ерекшеленген 📍",
            "en": "Recommended markers are highlighted in blue on the map 📍"
        ],
        "map_you_are_here": [
            "ru": "Вы здесь",
            "kk": "Сіз осындасыз",
            "en": "You are here"
        ],
        "map_current_location": [
            "ru": "Ваше местоположение",
            "kk": "Сіздің орналасқан жеріңіз",
            "en": "Your location"
        ],
        "map_location_searching": [
            "ru": "Ищем GPS...",
            "kk": "GPS ізделуде...",
            "en": "Searching GPS..."
        ],
        "map_location_denied": [
            "ru": "GPS выключен",
            "kk": "GPS өшірулі",
            "en": "GPS is off"
        ],
        "map_location_waiting_permission": [
            "ru": "Разрешите доступ к GPS",
            "kk": "GPS рұқсатын беріңіз",
            "en": "Allow GPS access"
        ],
        "map_location_default": [
            "ru": "Алматы по умолчанию",
            "kk": "Әдепкі Алматы",
            "en": "Default Almaty location"
        ],
        "list_events_nearby": [
            "ru": "Всего %d активностей рядом",
            "kk": "Маңайда барлығы %d оқиға бар",
            "en": "Total %d events nearby"
        ],
        "list_no_events_found": [
            "ru": "Событий не найдено",
            "kk": "Оқиғалар табылмады",
            "en": "No events found"
        ],
        "list_no_events_hint": [
            "ru": "Попробуйте сменить категорию или создать новое событие на карте!",
            "kk": "Санатты өзгертіп көріңіз немесе картада жаңа оқиға жасаңыз!",
            "en": "Try changing the category or create a new event on the map!"
        ],
        
        // Category keys
        "cat_all": [
            "ru": "Все",
            "kk": "Барлығы",
            "en": "All"
        ],
        "cat_mountains": [
            "ru": "Горы",
            "kk": "Таулар",
            "en": "Mountains"
        ],
        "cat_theater": [
            "ru": "Театр",
            "kk": "Театр",
            "en": "Theater"
        ],
        "cat_restaurant": [
            "ru": "Ресторан",
            "kk": "Мейрамхана",
            "en": "Restaurant"
        ],
        "cat_sports": [
            "ru": "Спорт",
            "kk": "Спорт",
            "en": "Sports"
        ],
        "cat_walks": [
            "ru": "Прогулки",
            "kk": "Серуен",
            "en": "Walks"
        ],
        "cat_games": [
            "ru": "Игры",
            "kk": "Ойындар",
            "en": "Games"
        ],
        "cat_networking": [
            "ru": "Нетворкинг",
            "kk": "Нетворкинг",
            "en": "Networking"
        ],
        "cat_other": [
            "ru": "Другое",
            "kk": "Басқа",
            "en": "Other"
        ],
        
        // Chat room & sessions
        "chat_readonly_completed": [
            "ru": "Чат завершен. Доступен только для чтения.",
            "kk": "Чат аяқталды. Тек оқу үшін қолжетімді.",
            "en": "Chat is completed. Available in read-only mode."
        ],
        "chat_completed_badge": [
            "ru": "Завершен",
            "kk": "Аяқталды",
            "en": "Completed"
        ],
        "chat_ai_assistant_name": [
            "ru": "Жорик (ИИ-помощник)",
            "kk": "Жолик (ИИ-көмекші)",
            "en": "Zhorik (AI-Assistant)"
        ],
        "chat_ai_assistant_welcome": [
            "ru": "Привет! Я Жорик, твой ИИ-помощник. Задавай мне любые вопросы про Алматы!",
            "kk": "Сәлем! Мен Жоликпін, сенің ИИ-көмекшіңмін. Алматы туралы кез келген сұрақ қой!",
            "en": "Hello! I am Zhorik, your AI-Assistant. Ask me any questions about Almaty!"
        ],
        "chats_count": [
            "ru": "%d чатов",
            "kk": "%d чат",
            "en": "%d chats"
        ],
        "chats_search_placeholder": [
            "ru": "Поиск чатов...",
            "kk": "Чаттарды іздеу...",
            "en": "Search chats..."
        ],
        "chat_prefix_you": [
            "ru": "Вы: ",
            "kk": "Сіз: ",
            "en": "You: "
        ],
        
        // Activity & Notifications
        "act_all_community": [
            "ru": "Все сообщество",
            "kk": "Барлық қоғамдастық",
            "en": "All Community"
        ],
        "act_tab_all": [
            "ru": "Все",
            "kk": "Барлығы",
            "en": "All"
        ],
        "act_tab_friends": [
            "ru": "Друзья",
            "kk": "Достар",
            "en": "Friends"
        ],
        "act_no_friends": [
            "ru": "Нет активности друзей",
            "kk": "Достар белсенділігі жоқ",
            "en": "No activity from friends"
        ],
        "act_no_notifications": [
            "ru": "Нет новых событий",
            "kk": "Жаңа оқиғалар жоқ",
            "en": "No new notifications"
        ],
        "act_no_friends_hint": [
            "ru": "У вас пока нет друзей в приложении, или они пока не проявляли активность.",
            "kk": "Қосымшада әлі достарыңыз жоқ немесе олар әлі белсенділік танытқан жоқ.",
            "en": "You don't have friends in the app yet, or they haven't been active yet."
        ],
        "act_no_notifications_hint": [
            "ru": "Пока тихо. Самое время создать новый ивент или найти компанию!",
            "kk": "Әзірге тыныш. Жаңа оқиға жасау немесе серік табудың дәл уақыты!",
            "en": "Quiet for now. High time to create a new event or find company!"
        ],
        
        // Profile & Settings
        "prof_default_bio": [
            "ru": "Участник сообщества Zholdas. Люблю активный отдых, спорт и новые знакомства!",
            "kk": "Zholdas қауымдастығының мүшесі. Белсенді демалысты, спортты және жаңа таныстарды жақсы көремін!",
            "en": "Member of the Zholdas community. I love active recreation, sports, and new acquaintances!"
        ],
        "prof_menu_and_settings": [
            "ru": "МЕНЮ И НАСТРОЙКИ",
            "kk": "МӘЗІР МЕН БАПТАУЛАР",
            "en": "MENU & SETTINGS"
        ],
        
        // Edit Profile
        "edit_prof_title": [
            "ru": "Редактировать профиль",
            "kk": "Профильді өңдеу",
            "en": "Edit Profile"
        ],
        "edit_prof_name_title": [
            "ru": "ИМЯ",
            "kk": "ЕСІМ",
            "en": "NAME"
        ],
        "edit_prof_name_placeholder": [
            "ru": "Ваше имя",
            "kk": "Сіздің есіміңіз",
            "en": "Your name"
        ],
        "edit_prof_avatar_title": [
            "ru": "ССЫЛКА НА АВАТАР",
            "kk": "АВАТАР СІЛТЕМЕСІ",
            "en": "AVATAR URL"
        ],
        "edit_prof_city_title": [
            "ru": "ГОРОД",
            "kk": "ҚАЛА",
            "en": "CITY"
        ],
        "edit_prof_city_placeholder": [
            "ru": "Выберите город",
            "kk": "Қаланы таңдаңыз",
            "en": "Select city"
        ],
        "edit_prof_bio_placeholder": [
            "ru": "Опишите себя подробнее...",
            "kk": "Өзіңіз туралы толығырақ сипаттаңыз...",
            "en": "Describe yourself in detail..."
        ],
        "edit_prof_saving": [
            "ru": "Сохранение...",
            "kk": "Сақталуда...",
            "en": "Saving..."
        ],
        "edit_prof_preview": [
            "ru": "Предпросмотр",
            "kk": "Алдын ала қарау",
            "en": "Preview"
        ],
        
        // Friends
        "friends_title": [
            "ru": "Контакты",
            "kk": "Контактілер",
            "en": "Contacts"
        ],
        "friends_my_friends": [
            "ru": "Мои друзья",
            "kk": "Достарым",
            "en": "My Friends"
        ],
        "friends_requests": [
            "ru": "Запросы",
            "kk": "Сұраулар",
            "en": "Requests"
        ],
        "friends_empty_title": [
            "ru": "У вас пока нет друзей",
            "kk": "Сізде әлі дос жоқ",
            "en": "You don't have friends yet"
        ],
        "friends_empty_subtitle": [
            "ru": "Присоединяйтесь к событиям и добавляйте участников в друзья, чтобы общаться напрямую!",
            "kk": "Тікелей сөйлесу үшін оқиғаларға қосылыңыз және қатысушыларды дос ретінде қосыңыз!",
            "en": "Join events and add participants as friends to communicate directly!"
        ],
        "friends_empty_requests_title": [
            "ru": "Нет новых запросов",
            "kk": "Жаңа сұраулар жоқ",
            "en": "No new requests"
        ],
        "friends_empty_requests_subtitle": [
            "ru": "Когда кто-то отправит вам запрос в друзья, он появится здесь.",
            "kk": "Біреу сізге дос болуға сұрау жібергенде, ол осында пайда болады.",
            "en": "When someone sends you a friend request, it will appear here."
        ],
        
        // Reports
        "rep_title": [
            "ru": "Пожаловаться",
            "kk": "Шағымдану",
            "en": "Report"
        ],
        "rep_info_text": [
            "ru": "Пожалуйста, укажите причину жалобы. Ваша жалоба будет конфиденциально рассмотрена модератором.",
            "kk": "Шағым жасау себебін көрсетіңіз. Сіздің шағымыңызды модератор құпия түрде қарайды.",
            "en": "Please select the reason for the report. Your report will be confidentially reviewed by a moderator."
        ],
        "rep_details_title": [
            "ru": "ПОДРОБНОСТИ (ОПЦИОНАЛЬНО)",
            "kk": "МӘЛІМЕТТЕР (ҚОСЫМША)",
            "en": "DETAILS (OPTIONAL)"
        ],
        "rep_details_placeholder": [
            "ru": "Опишите ситуацию подробнее...",
            "kk": "Жағдайды толығырақ сипаттаңыз...",
            "en": "Describe the situation in detail..."
        ],
        "rep_submit_btn": [
            "ru": "Отправить жалобу",
            "kk": "Шағымды жіберу",
            "en": "Submit Report"
        ],
        "rep_alert_title": [
            "ru": "Жалоба отправлена",
            "kk": "Шағым жіберілді",
            "en": "Report Submitted"
        ],
        "rep_alert_message": [
            "ru": "Спасибо! Мы рассмотрим вашу жалобу в течение 24 часов.",
            "kk": "Рахмет! Біз сіздің шағымыңызды 24 сағат ішінде қарастырамыз.",
            "en": "Thank you! We will review your report within 24 hours."
        ],
        "rep_reason_spam": [
            "ru": "Спам / Реклама",
            "kk": "Спам / Жарнама",
            "en": "Spam / Ads"
        ],
        "rep_reason_harassment": [
            "ru": "Оскорбление / Преследование",
            "kk": "Қорлау / Қудалау",
            "en": "Harassment / Stalking"
        ],
        "rep_reason_violence": [
            "ru": "Насилие / Угрозы",
            "kk": "Зорлық-зомбылық / Қорқыту",
            "en": "Violence / Threats"
        ],
        "rep_reason_inappropriate": [
            "ru": "Неприемлемый контент",
            "kk": "Қолайсыз контент",
            "en": "Inappropriate Content"
        ],
        "rep_reason_other": [
            "ru": "Другое",
            "kk": "Басқа",
            "en": "Other"
        ],
        
        // Shared buttons
        "btn_cancel": [
            "ru": "Отмена",
            "kk": "Бас тарту",
            "en": "Cancel"
        ],
        "btn_done": [
            "ru": "Готово",
            "kk": "Дайын",
            "en": "Done"
        ],
        "btn_retry": [
            "ru": "Повторить",
            "kk": "Қайталау",
            "en": "Retry"
        ],
        "btn_ok": [
            "ru": "ОК",
            "kk": "ОК",
            "en": "OK"
        ],
        
        // Event Details
        "ev_default_cover_title": [
            "ru": "Жолдас Активность",
            "kk": "Жолдас Оқиғасы",
            "en": "Zholdas Activity"
        ],
        "ev_starts_today": [
            "ru": "Начнется сегодня",
            "kk": "Бүгін басталады",
            "en": "Starts today"
        ],
        "ev_already_started": [
            "ru": "Активность уже началась",
            "kk": "Оқиға басталып кетті",
            "en": "Activity already started"
        ],
        "ev_starts_in_days_format": [
            "ru": "Начнется через %d д",
            "kk": "%d күннен кейін басталады",
            "en": "Starts in %d d"
        ],
        "ev_distance": [
            "ru": "Расстояние",
            "kk": "Қашықтық",
            "en": "Distance"
        ],
        "ev_distance_calculating": [
            "ru": "Расстояние: рассчитывается...",
            "kk": "Қашықтық: есептелуде...",
            "en": "Distance: calculating..."
        ],
        "ev_status_active": [
            "ru": "Активный",
            "kk": "Белсенді",
            "en": "Active"
        ],
        "ev_status_finished": [
            "ru": "Завершено",
            "kk": "Аяқталды",
            "en": "Finished"
        ],
        "ev_participants_empty": [
            "ru": "Список пуст",
            "kk": "Тізім бос",
            "en": "List is empty"
        ],
        "ev_how_it_runs_rule1": [
            "ru": "Приходите за 10-15 минут до начала, чтобы спокойно найти группу.",
            "kk": "Топты оңай табу үшін басталуға 10-15 минут қалғанда келіңіз.",
            "en": "Arrive 10-15 minutes early to easily find the group."
        ],
        "ev_how_it_runs_rule2": [
            "ru": "Все детали и изменения лучше уточнять в общем чате ивента.",
            "kk": "Барлық мәліметтер мен өзгерістерді оқиғаның жалпы чатында нақтылаған дұрыс.",
            "en": "It's best to check all details and changes in the event's general chat."
        ],
        "ev_how_it_runs_rule3": [
            "ru": "После завершения участники смогут оставить отзывы друг другу.",
            "kk": "Аяқталғаннан кейін қатысушылар бір-біріне пікір қалдыра алады.",
            "en": "After completion, participants can leave feedback for each other."
        ],
        "ev_share_prefix": [
            "ru": "Присоединяйся к событию",
            "kk": "Оқиғаға қосыл",
            "en": "Join the event"
        ],
        "ev_share_at": [
            "ru": "в",
            "kk": "мекенжайында:",
            "en": "at"
        ],
        
        // Moderator Dashboard
        "mod_nav_title": [
            "ru": "Панель управления",
            "kk": "Басқару панелі",
            "en": "Admin Panel"
        ],
        "mod_role_moderator": [
            "ru": "Модератор",
            "kk": "Модератор",
            "en": "Moderator"
        ],
        "mod_role_admin": [
            "ru": "Администратор",
            "kk": "Әкімші",
            "en": "Administrator"
        ],
        "mod_announcement": [
            "ru": "Администратор",
            "kk": "Әкімші",
            "en": "Administrator"
        ],
        "mod_moderation": [
            "ru": "Модерация",
            "kk": "Модерация",
            "en": "Moderation"
        ],
        "mod_subtitle": [
            "ru": "Управление пользователями, чатами, ивентами, модерацией, настройками и аналитикой.",
            "kk": "Пайдаланушыларды, чаттарды, оқиғаларды, модерацияны, баптауларды және аналитиканы басқару.",
            "en": "Manage users, chats, events, moderation, settings, and analytics."
        ],
        "mod_tab_moderation": [
            "ru": "Модерация",
            "kk": "Модерация",
            "en": "Moderation"
        ],
        "mod_tab_stats": [
            "ru": "Статистика",
            "kk": "Статистика",
            "en": "Stats"
        ],
        "mod_tab_users": [
            "ru": "Юзеры",
            "kk": "Пайдаланушылар",
            "en": "Users"
        ],
        "mod_tab_events": [
            "ru": "Ивенты",
            "kk": "Оқиғалар",
            "en": "Events"
        ],
        "mod_tab_tools": [
            "ru": "Инструменты",
            "kk": "Құралдар",
            "en": "Tools"
        ],
        "mod_tab_audit": [
            "ru": "Логи",
            "kk": "Логтар",
            "en": "Logs"
        ],
        "mod_audit_title": [
            "ru": "Журнал действий",
            "kk": "Әрекеттер журналы",
            "en": "Audit Log"
        ],
        "mod_audit_empty": [
            "ru": "Действий пока нет",
            "kk": "Әзірге әрекеттер жоқ",
            "en": "No actions yet"
        ],
        "mod_reports_empty_title": [
            "ru": "Жалоб нет",
            "kk": "Шағымдар жоқ",
            "en": "No reports"
        ],
        "mod_reports_empty_desc": [
            "ru": "Все чисто! Участники ведут себя вежливо.",
            "kk": "Бәрі таза! Қатысушылар сыпайы мінез-құлық танытуда.",
            "en": "All clean! Participants are behaving politely."
        ],
        "mod_reporter_label": [
            "ru": "Отправитель:",
            "kk": "Жіберуші:",
            "en": "Reporter:"
        ],
        "mod_reported_label": [
            "ru": "Нарушитель:",
            "kk": "Бұзушы:",
            "en": "Offender:"
        ],
        "mod_event_label": [
            "ru": "Событие:",
            "kk": "Оқиға:",
            "en": "Event:"
        ],
        "mod_btn_dismiss": [
            "ru": "Отклонить",
            "kk": "Бас тарту",
            "en": "Dismiss"
        ],
        "mod_btn_ban": [
            "ru": "Бан",
            "kk": "Бұғаттау",
            "en": "Ban"
        ],
        "mod_btn_unban": [
            "ru": "Разбанить",
            "kk": "Бұғаттан шығару",
            "en": "Unban"
        ],
        "mod_btn_delete_perm": [
            "ru": "Удалить навсегда",
            "kk": "Біржола жою",
            "en": "Delete Permanently"
        ],
        "mod_stats_title": [
            "ru": "Статистика платформы",
            "kk": "Платформа статистикасы",
            "en": "Platform Statistics"
        ],
        "mod_analytics_title": [
            "ru": "MVP Аналитика",
            "kk": "MVP Аналитикасы",
            "en": "MVP Analytics"
        ],
        "mod_users_title": [
            "ru": "Управление пользователями",
            "kk": "Пайдаланушыларды басқару",
            "en": "User Management"
        ],
        "mod_users_search_placeholder": [
            "ru": "Поиск по имени, email или id",
            "kk": "Аты, email немесе id бойынша іздеу",
            "en": "Search by name, email or id"
        ],
        "mod_user_banned_label": [
            "ru": "ЗАБАНЕН",
            "kk": "БҰҒАТТАЛҒАН",
            "en": "BANNED"
        ],
        "mod_user_roles_label": [
            "ru": "Роли:",
            "kk": "Рөлдер:",
            "en": "Roles:"
        ],
        "mod_events_title": [
            "ru": "Управление ивентами",
            "kk": "Оқиғаларды басқару",
            "en": "Event Management"
        ],
        "mod_events_search_placeholder": [
            "ru": "Поиск ивента",
            "kk": "Оқиғаны іздеу",
            "en": "Search event"
        ],
        "mod_events_filter_all": [
            "ru": "Все",
            "kk": "Барлығы",
            "en": "All"
        ],
        "mod_events_filter_active": [
            "ru": "Активные",
            "kk": "Белсенділер",
            "en": "Active"
        ],
        "mod_events_filter_closed": [
            "ru": "Закрытые",
            "kk": "Жабылғандар",
            "en": "Closed"
        ],
        "mod_events_filter_cancelled": [
            "ru": "Отмененные",
            "kk": "Бас тартылғандар",
            "en": "Cancelled"
        ],
        "mod_tools_broadcast_header": [
            "ru": "BROADCAST ВСЕМ ПОЛЬЗОВАТЕЛЯМ",
            "kk": "БАРЛЫҚ ПАЙДАЛАНУШЫЛАРҒА BROADCAST",
            "en": "BROADCAST TO ALL USERS"
        ],
        "mod_tools_broadcast_title_placeholder": [
            "ru": "Заголовок объявления",
            "kk": "Хабарландыру тақырыбы",
            "en": "Announcement title"
        ],
        "mod_tools_broadcast_text_placeholder": [
            "ru": "Текст объявления",
            "kk": "Хабарландыру мәтіні",
            "en": "Announcement text"
        ],
        "mod_tools_broadcast_submit": [
            "ru": "Отправить всем",
            "kk": "Барлығына жіберу",
            "en": "Send to all"
        ],
        "mod_tools_settings_header": [
            "ru": "СИСТЕМНЫЕ НАСТРОЙКИ",
            "kk": "ЖҮЙЕЛІК БАПТАУЛАР",
            "en": "SYSTEM SETTINGS"
        ],
        "mod_tools_settings_save": [
            "ru": "Сохранить настройки",
            "kk": "Баптауларды сақтау",
            "en": "Save Settings"
        ],
        "mod_tools_settings_saved_msg": [
            "ru": "Системные настройки сохранены!",
            "kk": "Жүйелік баптаулар сақталды!",
            "en": "System settings saved!"
        ],
        "mod_ban_sheet_title": [
            "ru": "Блокировка пользователя",
            "kk": "Пайдаланушыны бұғаттау",
            "en": "Ban User"
        ],
        "mod_ban_sheet_reason_placeholder": [
            "ru": "Причина блокировки",
            "kk": "Бұғаттау себебі",
            "en": "Reason for ban"
        ],
        "mod_creator_label": [
            "ru": "Создатель",
            "kk": "Ұйымдастырушы",
            "en": "Creator"
        ],
        "mod_btn_activate": [
            "ru": "Активировать",
            "kk": "Белсендіру",
            "en": "Activate"
        ],
        "mod_btn_cancel": [
            "ru": "Отменить",
            "kk": "Бас тарту",
            "en": "Cancel"
        ],
        "mod_btn_delete": [
            "ru": "Удалить",
            "kk": "Жою",
            "en": "Delete"
        ],
        
        // Login screen
        "login_email_label": [
            "ru": "Электронная почта",
            "kk": "Электрондық пошта",
            "en": "Email Address"
        ],
        "login_password_label": [
            "ru": "Пароль",
            "kk": "Құпия сөз",
            "en": "Password"
        ],
        "login_password_placeholder": [
            "ru": "Введите ваш пароль",
            "kk": "Құпия сөзіңізді енгізіңіз",
            "en": "Enter your password"
        ],
        "login_btn": [
            "ru": "Войти",
            "kk": "Кіру",
            "en": "Sign In"
        ],
        "login_no_account": [
            "ru": "Нет аккаунта?",
            "kk": "Аккаунт жоқ па?",
            "en": "Don't have an account?"
        ],
        "login_register_link": [
            "ru": "Создать аккаунт",
            "kk": "Тіркелу",
            "en": "Create Account"
        ],
        "login_subtitle": [
            "ru": "Найди компанию для прогулок и походов",
            "kk": "Серуендеу мен жорықтарға серік тап",
            "en": "Find company for walks and hikes"
        ],
        
        // Registration screen
        "reg_title": [
            "ru": "Создать аккаунт",
            "kk": "Тіркелу",
            "en": "Create Account"
        ],
        "reg_choose_avatar": [
            "ru": "ВЫБЕРИ АВАТАР",
            "kk": "АВАТАР ТАҢДАҢЫЗ",
            "en": "CHOOSE AVATAR"
        ],
        "reg_name_label": [
            "ru": "ИМЯ *",
            "kk": "ЕСІМ *",
            "en": "NAME *"
        ],
        "reg_name_placeholder": [
            "ru": "Как тебя зовут?",
            "kk": "Есіміңіз кім?",
            "en": "What is your name?"
        ],
        "reg_email_label": [
            "ru": "EMAIL *",
            "kk": "EMAIL *",
            "en": "EMAIL *"
        ],
        "reg_email_placeholder": [
            "ru": "your@email.com",
            "kk": "your@email.com",
            "en": "your@email.com"
        ],
        "reg_password_label": [
            "ru": "ПАРОЛЬ *",
            "kk": "ҚҰПИЯ СӨЗ *",
            "en": "PASSWORD *"
        ],
        "reg_password_placeholder": [
            "ru": "Минимум 6 символов",
            "kk": "Кемінде 6 таңба",
            "en": "Minimum 6 characters"
        ],
        "reg_confirm_password_label": [
            "ru": "ПОДТВЕРДИ ПАРОЛЬ *",
            "kk": "ҚҰПИЯ СӨЗДІ РАСТАУ *",
            "en": "CONFIRM PASSWORD *"
        ],
        "reg_hide": [
            "ru": "Скрыть",
            "kk": "Жасыру",
            "en": "Hide"
        ],
        "reg_show": [
            "ru": "Показать",
            "kk": "Көрсету",
            "en": "Show"
        ],
        "reg_gender_label": [
            "ru": "ПОЛ",
            "kk": "ЖЫНЫСЫ",
            "en": "GENDER"
        ],
        "reg_gender_male": [
            "ru": "Мужской",
            "kk": "Ер",
            "en": "Male"
        ],
        "reg_gender_female": [
            "ru": "Женский",
            "kk": "Әйел",
            "en": "Female"
        ],
        "reg_gender_none": [
            "ru": "Не указывать",
            "kk": "Көрсетпеу",
            "en": "Prefer not to say"
        ],
        "reg_birth_year_label": [
            "ru": "ВОЗРАСТ",
            "kk": "ЖАСЫ",
            "en": "AGE"
        ],
        "reg_birth_year_placeholder": [
            "ru": "Выберите возраст",
            "kk": "Жасыңызды таңдаңыз",
            "en": "Choose age"
        ],
        "reg_age_suffix": [
            "ru": "лет",
            "kk": "жас",
            "en": "years old"
        ],
        "reg_bio_label": [
            "ru": "О СЕБЕ",
            "kk": "ӨЗІМ ТУРАЛЫ",
            "en": "ABOUT ME"
        ],
        "reg_bio_placeholder": [
            "ru": "Пара слов о тебе...",
            "kk": "Өзіңіз туралы бірнеше сөз...",
            "en": "A few words about you..."
        ],
        "reg_preview_name": [
            "ru": "Твое имя",
            "kk": "Сіздің есіміңіз",
            "en": "Your Name"
        ],
        "reg_err_mismatch": [
            "ru": "Пароли не совпадают",
            "kk": "Құпия сөздер сәйкес келмейді",
            "en": "Passwords do not match"
        ],
        "reg_err_short": [
            "ru": "Пароль должен быть не менее 6 символов",
            "kk": "Құпия сөз кемінде 6 таңбадан тұруы керек",
            "en": "Password must be at least 6 characters"
        ],
        "reg_already_have_account": [
            "ru": "Уже есть аккаунт?",
            "kk": "Аккаунтыңыз бар ма?",
            "en": "Already have an account?"
        ],
        "reg_login_link": [
            "ru": "Войти",
            "kk": "Кіру",
            "en": "Sign In"
        ],
        "reg_back": [
            "ru": "Назад",
            "kk": "Артқа",
            "en": "Back"
        ]
    ]
    
    func localizedString(for key: String) -> String {
        guard let langDict = translations[key] else {
            return key
        }
        return langDict[currentLanguage] ?? langDict["ru"] ?? key
    }
}

// String extension for SwiftUI views usage
extension String {
    var localized: String {
        LocalizationManager.shared.localizedString(for: self)
    }
}
