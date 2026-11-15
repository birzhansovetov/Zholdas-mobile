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
        "ev_reminder_title": [
            "ru": "Напоминание",
            "kk": "Ескерту",
            "en": "Reminder"
        ],
        "ev_reminder_placeholder": [
            "ru": "Напоминание появится в приложении перед началом события",
            "kk": "Ескерту оқиға басталар алдында қосымшада пайда болады",
            "en": "A reminder will appear in the app before the event starts"
        ],
        "ev_live_location_title": [
            "ru": "Локация участников",
            "kk": "Қатысушылар локациясы",
            "en": "Participant Locations"
        ],
        "ev_live_location_hint": [
            "ru": "Включите, чтобы участники этой встречи видели вас на карте.",
            "kk": "Осы кездесудің қатысушылары сізді картадан көруі үшін қосыңыз.",
            "en": "Turn on sharing so this event's participants can see you on the map."
        ],
        "ev_live_location_empty": [
            "ru": "Пока никто не делится локацией.",
            "kk": "Әзірге ешкім локациясын бөліспеді.",
            "en": "No one is sharing location yet."
        ],
        "ev_live_location_count": [
            "ru": "На карте участников: %d",
            "kk": "Картадағы қатысушылар: %d",
            "en": "Participants on map: %d"
        ],
        "ev_live_location_you": [
            "ru": "Вы",
            "kk": "Сіз",
            "en": "You"
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
        "btn_close": [
            "ru": "Закрыть",
            "kk": "Жабу",
            "en": "Close"
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
        "mod_stats_users": [
            "ru": "Пользователи",
            "kk": "Пайдаланушылар",
            "en": "Users"
        ],
        "mod_stats_events": [
            "ru": "Ивенты",
            "kk": "Оқиғалар",
            "en": "Events"
        ],
        "mod_stats_active": [
            "ru": "Активные",
            "kk": "Белсенді",
            "en": "Active"
        ],
        "mod_stats_messages": [
            "ru": "Сообщения",
            "kk": "Хабарламалар",
            "en": "Messages"
        ],
        "mod_stats_reports": [
            "ru": "Жалобы",
            "kk": "Шағымдар",
            "en": "Reports"
        ],
        "mod_stats_bans": [
            "ru": "Баны",
            "kk": "Бұғаттар",
            "en": "Bans"
        ],
        "mod_analytics_title": [
            "ru": "MVP Аналитика",
            "kk": "MVP Аналитикасы",
            "en": "MVP Analytics"
        ],
        "mod_anal_reg_today": [
            "ru": "Регистрации сегодня",
            "kk": "Бүгінгі тіркелулер",
            "en": "Registrations today"
        ],
        "mod_anal_reg_7d": [
            "ru": "Регистрации за 7 дней",
            "kk": "7 күндегі тіркелулер",
            "en": "Registrations 7d"
        ],
        "mod_anal_reg_30d": [
            "ru": "Регистрации за 30 дней",
            "kk": "30 күндегі тіркелулер",
            "en": "Registrations 30d"
        ],
        "mod_anal_ev_7d": [
            "ru": "Ивенты за 7 дней",
            "kk": "7 күндегі оқиғалар",
            "en": "Events 7d"
        ],
        "mod_anal_ev_30d": [
            "ru": "Ивенты за 30 дней",
            "kk": "30 күндегі оқиғалар",
            "en": "Events 30d"
        ],
        "mod_anal_joins_7d": [
            "ru": "Участия за 7 дней",
            "kk": "7 күндегі қатысулар",
            "en": "Joins 7d"
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
        "reg_step_user_info": [
            "ru": "Данные",
            "kk": "Деректер",
            "en": "Info"
        ],
        "reg_step_interests": [
            "ru": "Интересы",
            "kk": "Қызығушылық",
            "en": "Interests"
        ],
        "reg_step_email": [
            "ru": "Почта",
            "kk": "Пошта",
            "en": "Email"
        ],
        "reg_next": [
            "ru": "Далее",
            "kk": "Келесі",
            "en": "Next"
        ],
        "reg_send_code": [
            "ru": "Отправить код",
            "kk": "Код жіберу",
            "en": "Send code"
        ],
        "reg_verify_code": [
            "ru": "Подтвердить код",
            "kk": "Кодты растау",
            "en": "Verify code"
        ],
        "reg_interests_title": [
            "ru": "Выбери интересы",
            "kk": "Қызығушылықтарды таңдаңыз",
            "en": "Choose interests"
        ],
        "reg_interests_subtitle": [
            "ru": "Так Жолдас будет точнее подбирать встречи.",
            "kk": "Осылай Жолдас кездесулерді дәлірек ұсынады.",
            "en": "This helps Zholdas recommend better events."
        ],
        "reg_check_email_title": [
            "ru": "Проверь почту",
            "kk": "Поштаны тексеріңіз",
            "en": "Check your email"
        ],
        "reg_check_email_subtitle": [
            "ru": "Код отправлен на",
            "kk": "Код жіберілді:",
            "en": "Code sent to"
        ],
        "reg_email_code_label": [
            "ru": "КОД ИЗ ПОЧТЫ",
            "kk": "ПОШТАДАҒЫ КОД",
            "en": "EMAIL CODE"
        ],
        "reg_email_code_placeholder": [
            "ru": "Введите 6-значный код",
            "kk": "6 таңбалы кодты енгізіңіз",
            "en": "Enter 6-digit code"
        ],
        "reg_resend_code": [
            "ru": "Отправить код еще раз",
            "kk": "Кодты қайта жіберу",
            "en": "Resend code"
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
        ],
        
        // Errors & System
        "error_invalid_credentials": [
            "ru": "Неверная почта или пароль",
            "kk": "Қате электрондық пошта немесе құпия сөз",
            "en": "Invalid email or password"
        ],
        "error_email_not_confirmed": [
            "ru": "Подтвердите email перед входом",
            "kk": "Кіру алдында email-ді растаңыз",
            "en": "Please confirm your email before signing in"
        ],
        "error_user_already_exists": [
            "ru": "Пользователь с такой почтой уже зарегистрирован",
            "kk": "Бұл поштасы бар пайдаланушы тіркеліп қойған",
            "en": "A user with this email is already registered"
        ],
        "error_weak_password": [
            "ru": "Слишком простой пароль",
            "kk": "Құпия сөз тым қарапайым",
            "en": "Password is too weak"
        ],
        "error_rate_limit": [
            "ru": "Слишком много попыток, попробуйте позже",
            "kk": "Тым көп әрекет жасалды, кейінірек қайталап көріңіз",
            "en": "Too many attempts, please try again later"
        ],
        "error_forbidden": [
            "ru": "Недостаточно прав",
            "kk": "Құқықтар жеткіліксіз",
            "en": "Permission denied"
        ],
        "error_not_found": [
            "ru": "Не найдено",
            "kk": "Табылмады",
            "en": "Not found"
        ],
        "error_server_unavailable": [
            "ru": "Сервер временно недоступен",
            "kk": "Сервер уақытша қолжетімсіз",
            "en": "Server is temporarily unavailable"
        ],
        "error_network": [
            "ru": "Нет соединения с сервером. Проверьте интернет",
            "kk": "Сервермен байланыс жоқ. Интернетті тексеріңіз",
            "en": "No connection to the server. Check your internet"
        ],
        "error_decoding": [
            "ru": "Сервер вернул неожиданные данные. Попробуйте позже",
            "kk": "Сервер күтпеген деректерді қайтарды. Кейінірек қайталап көріңіз",
            "en": "The server returned unexpected data. Please try again later"
        ],
        "error_generic": [
            "ru": "Произошла ошибка. Попробуйте позже",
            "kk": "Қате орын алды. Кейінірек қайталап көріңіз",
            "en": "An error occurred. Please try again later"
        ],
        "session_expired": [
            "ru": "Сессия истекла. Войдите заново",
            "kk": "Сессия аяқталды. Қайта кіріңіз",
            "en": "Session expired. Please sign in again"
        ],
        "chat_system_sender": [
            "ru": "Система",
            "kk": "Жүйе",
            "en": "System"
        ],
        "chat_send_error_prefix": [
            "ru": "⚠️ Ошибка отправки: ",
            "kk": "⚠️ Жіберу қатесі: ",
            "en": "⚠️ Failed to send: "
        ],
        "prof_gender_male": [
            "ru": "Мужчина",
            "kk": "Ер адам",
            "en": "Male"
        ],
        "prof_gender_female": [
            "ru": "Женщина",
            "kk": "Әйел адам",
            "en": "Female"
        ],
        "alert_error_title": [
            "ru": "Ошибка",
            "kk": "Қате",
            "en": "Error"
        ],
        "ev_leave_confirm_title": [
            "ru": "Покинуть событие?",
            "kk": "Оқиғадан шығу керек пе?",
            "en": "Leave Event?"
        ],
        "ev_leave_confirm_message": [
            "ru": "Вы уверены, что хотите покинуть это событие?",
            "kk": "Бұл оқиғадан шыққыңыз келетініне сенімдісіз бе?",
            "en": "Are you sure you want to leave this event?"
        ],
        "prof_signout_confirm_title": [
            "ru": "Выйти из аккаунта?",
            "kk": "Аккаунттан шығу керек пе?",
            "en": "Sign Out?"
        ],
        "prof_signout_confirm_message": [
            "ru": "Вы уверены, что хотите выйти из своего аккаунта?",
            "kk": "Аккаунтыңыздан шыққыңыз келетініне сенімдісіз бе?",
            "en": "Are you sure you want to sign out?"
        ],
        "user_block_btn": [
            "ru": "Заблокировать пользователя",
            "kk": "Пайдаланушыны бұғаттау",
            "en": "Block User"
        ],
        "user_block_confirm_title": [
            "ru": "Заблокировать пользователя?",
            "kk": "Пайдаланушыны бұғаттау керек пе?",
            "en": "Block User?"
        ],
        "user_block_confirm_message": [
            "ru": "Этот пользователь больше не сможет взаимодействовать с вами.",
            "kk": "Бұл пайдаланушы бұдан былай сізбен байланыса алмайды.",
            "en": "This user will no longer be able to interact with you."
        ],
        "friends_unfriend_confirm_title": [
            "ru": "Удалить из друзей?",
            "kk": "Достардан өшіру керек пе?",
            "en": "Remove Friend?"
        ],
        "friends_unfriend_confirm_message": [
            "ru": "Удалить %@ из списка друзей?",
            "kk": "%@ достар тізімінен өшірілсін бе?",
            "en": "Remove %@ from friends list?"
        ],
        "friends_unfriend_confirm_generic": [
            "ru": "Вы уверены, что хотите удалить этого пользователя из друзей?",
            "kk": "Бұл пайдаланушыны достардан өшіргіңіз келетініне сенімдісіз бе?",
            "en": "Are you sure you want to remove this user from friends?"
        ],
        "friends_unfriend_btn": [
            "ru": "Удалить",
            "kk": "Өшіру",
            "en": "Remove"
        ],
        
        // chat_ texts
        "chat_empty_title": [
            "ru": "Здесь пока пусто",
            "kk": "Мұнда әзірге бос",
            "en": "It's empty here yet"
        ],
        "chat_empty_subtitle": [
            "ru": "Напишите первое сообщение, чтобы начать общение!",
            "kk": "Сөйлесуді бастау үшін алғашқы хабарламаны жазыңыз!",
            "en": "Send the first message to start chatting!"
        ],
        "chat_photo_load_error": [
            "ru": "Ошибка загрузки фото",
            "kk": "Фотоны жүктеу қатесі",
            "en": "Failed to load photo"
        ],
        "chat_invalid_photo_url": [
            "ru": "Некорректная ссылка на фото",
            "kk": "Фотоға жарамсыз сілтеме",
            "en": "Invalid photo link"
        ],
        "chat_ask_joryk_placeholder": [
            "ru": "Спросите Жорика...",
            "kk": "Жоликтен сұраңыз...",
            "en": "Ask Zhorik..."
        ],
        "chat_suggestion_active": [
            "ru": "Активный отдых",
            "kk": "Белсенді демалыс",
            "en": "Active recreation"
        ],
        "chat_suggestion_active_prompt": [
            "ru": "Предложи активный отдых: 5 вариантов, что подготовить, сколько займет и как собрать людей.",
            "kk": "Белсенді демалыс ұсын: 5 нұсқа, нені дайындау керек, қанша уақыт алады және адамдарды қалай жинау керек.",
            "en": "Suggest active recreation: 5 options, what to prepare, how long it takes, and how to gather people."
        ],
        "chat_suggestion_calm": [
            "ru": "Спокойный формат",
            "kk": "Тыныш формат",
            "en": "Calm format"
        ],
        "chat_suggestion_calm_prompt": [
            "ru": "Предложи спокойный формат встречи: 5 вариантов, без перегруза, с планом и вопросами для общения.",
            "kk": "Кездесудің тыныш форматын ұсын: 5 нұсқа, артық жүктемесіз, жоспармен және араласуға арналған сұрақтармен.",
            "en": "Suggest a calm meeting format: 5 options, no overwhelm, with a plan and conversation questions."
        ],
        "chat_suggestion_budget": [
            "ru": "Бюджетно",
            "kk": "Үнемді",
            "en": "Budget-friendly"
        ],
        "chat_suggestion_budget_prompt": [
            "ru": "Предложи бюджетный формат встречи: варианты без больших трат, что подготовить и как распределить роли.",
            "kk": "Кездесудің үнемді форматын ұсын: үлкен шығынсыз нұсқалар, нені дайындау керек және рөлдерді қалай бөлу керек.",
            "en": "Suggest a budget meeting format: low-cost options, what to prepare, and how to distribute roles."
        ],
        "chat_suggestion_venue": [
            "ru": "С заведением",
            "kk": "Орынмен бірге",
            "en": "At a venue"
        ],
        "chat_suggestion_venue_prompt": [
            "ru": "Предложи формат встречи с кафе или заведением: как выбрать место, бюджет, бронь и темы для общения.",
            "kk": "Дәмхана немесе орынмен кездесу форматын ұсын: орынды қалай таңдау керек, бюджет, брондау және араласу тақырыптары.",
            "en": "Suggest a meeting format with a cafe or venue: how to choose a place, budget, booking, and conversation topics."
        ],
        "chat_suggestion_what_to_bring": [
            "ru": "Что взять",
            "kk": "Не алу керек",
            "en": "What to bring"
        ],
        "chat_suggestion_what_to_bring_prompt": [
            "ru": "Составь короткий список что взять с собой: еда, напитки, одежда, вещи и что лучше не брать.",
            "kk": "Өзіңмен бірге не алу керектігі туралы қысқа тізім жаса: тамақ, сусындар, киім, заттар және нені алмаған дұрыс.",
            "en": "Make a short checklist of what to bring: food, drinks, clothing, items, and what not to bring."
        ],
        "chat_suggestion_games_prompt": [
            "ru": "Предложи 5 игр или активностей для этой встречи: правила, время, количество людей и реквизит.",
            "kk": "Осы кездесу үшін 5 ойын немесе белсенділік ұсын: ережелер, уақыт, адам саны және қажетті заттар.",
            "en": "Suggest 5 games or activities for this meeting: rules, duration, group size, and props."
        ],
        "chat_suggestion_route": [
            "ru": "Маршрут",
            "kk": "Бағыт",
            "en": "Route"
        ],
        "chat_suggestion_route_prompt": [
            "ru": "Помоги организовать маршрут: точка сбора, как дойти, запасной план и что написать участникам.",
            "kk": "Бағытты ұйымдастыруға көмектес: жиналу нүктесі, қалай жету керек, қосалқы жоспар және қатысушыларға не жазу керек.",
            "en": "Help organize a route: meeting point, directions, backup plan, and what to post to participants."
        ],
        "chat_suggestion_plan": [
            "ru": "План",
            "kk": "Жоспар",
            "en": "Plan"
        ],
        "chat_suggestion_plan_prompt": [
            "ru": "Сделай план организации встречи по шагам: до начала, на месте, после встречи.",
            "kk": "Кездесуді ұйымдастыру жоспарын қадам бойынша жаса: басталғанға дейін, орнында, кездесуден кейін.",
            "en": "Make a step-by-step meeting plan: before start, on-site, after the meeting."
        ],
        "chat_suggestion_more_active": [
            "ru": "Активнее",
            "kk": "Белсендірек",
            "en": "More active"
        ],
        "chat_suggestion_more_active_prompt": [
            "ru": "Сделай вариант активнее: больше движения, 3 сценария, что подготовить и как безопасно провести.",
            "kk": "Нұсқаны белсендірек ет: көбірек қимыл, 3 сценарий, нені дайындау керек және қалай қауіпсіз өткізу керек.",
            "en": "Make it more active: more movement, 3 scenarios, what to prepare, and how to conduct safely."
        ],
        "chat_suggestion_calmer": [
            "ru": "Спокойнее",
            "kk": "Тынышырақ",
            "en": "Calmer"
        ],
        "chat_suggestion_calmer_prompt": [
            "ru": "Сделай спокойнее: меньше движения, уютный формат, вопросы для общения и простой план.",
            "kk": "Тынышырақ ет: азырақ қозғалыс, жайлы формат, сөйлесуге арналған сұрақтар және қарапайым жоспар.",
            "en": "Make it calmer: less movement, cozy format, conversation questions, and a simple plan."
        ],
        "chat_suggestion_cheaper": [
            "ru": "Дешевле",
            "kk": "Арзанырақ",
            "en": "Cheaper"
        ],
        "chat_suggestion_cheaper_prompt": [
            "ru": "Сделай бюджетный план без лишних трат: что взять, где сэкономить и как распределить роли.",
            "kk": "Артық шығынсыз үнемді жоспар жаса: не алу керек, қайдан үнемдеуге болады және рөлдерді қалай бөлу керек.",
            "en": "Make a budget plan without extra spending: what to bring, where to save, and how to distribute roles."
        ],
        "chat_suggestion_final_plan": [
            "ru": "Финальный план",
            "kk": "Қорытынды жоспар",
            "en": "Final plan"
        ],
        "chat_suggestion_final_plan_prompt": [
            "ru": "Собери финальный план встречи по шагам: до начала, на месте, после встречи и что написать в чат.",
            "kk": "Кездесудің қорытынды жоспарын қадам бойынша жина: басталғанға дейін, орнында, кездесуден кейін және чатқа не жазу керек.",
            "en": "Put together a final step-by-step meeting plan: before start, on-site, after the meeting, and what to post in chat."
        ],
        "chat_joryk_answer": [
            "ru": "Ответ Жорика",
            "kk": "Жоликтің жауабы",
            "en": "Zhorik's answer"
        ],
        "chat_joryk_details": [
            "ru": "Детали",
            "kk": "Мәліметтер",
            "en": "Details"
        ],
        "chat_error_prefix": [
            "ru": "⚠️ Ошибка: ",
            "kk": "⚠️ Қате: ",
            "en": "⚠️ Error: "
        ],
        "chat_photo_send_error_prefix": [
            "ru": "⚠️ Ошибка отправки фото: ",
            "kk": "⚠️ Фото жіберу қатесі: ",
            "en": "⚠️ Failed to send photo: "
        ],
        "chat_ai_active": [
            "ru": "Активен",
            "kk": "Белсенді",
            "en": "Active"
        ],
        "chat_time_yesterday": [
            "ru": "Вчера",
            "kk": "Кеше",
            "en": "Yesterday"
        ],
        
        // map_ / ev_list_ texts
        "map_filters": [
            "ru": "Фильтры",
            "kk": "Сүзгілер",
            "en": "Filters"
        ],
        "map_distance_km": [
            "ru": "%d км",
            "kk": "%d км",
            "en": "%d km"
        ],
        "map_filter_distance": [
            "ru": "Дистанция",
            "kk": "Қашықтық",
            "en": "Distance"
        ],
        "map_filter_only_today": [
            "ru": "Только сегодня",
            "kk": "Тек бүгін",
            "en": "Today only"
        ],
        "map_filter_near_me": [
            "ru": "Рядом со мной",
            "kk": "Маған жақын",
            "en": "Near me"
        ],
        "map_location_permission_denied": [
            "ru": "Доступ к геолокации выключен",
            "kk": "Геолокацияға рұқсат өшірілген",
            "en": "Location access is turned off"
        ],
        "map_location_inaccurate": [
            "ru": "GPS слишком неточный",
            "kk": "GPS тым дәл емес",
            "en": "GPS is too inaccurate"
        ],
        "map_location_failed": [
            "ru": "Не удалось получить GPS",
            "kk": "GPS алу мүмкін болмады",
            "en": "Failed to get GPS"
        ],
        "map_ai_invalid_query": [
            "ru": "Некорректный текст запроса",
            "kk": "Сұраныс мәтіні қате",
            "en": "Invalid query text"
        ],
        "map_ai_recommendations_error": [
            "ru": "Ошибка ИИ-рекомендаций: %@",
            "kk": "ИИ-ұсыныстар қатесі: %@",
            "en": "AI recommendations error: %@"
        ],
        "ev_list_filters_prefix": [
            "ru": "Фильтры: %@",
            "kk": "Сүзгілер: %@",
            "en": "Filters: %@"
        ],
        "ev_list_filter_distance": [
            "ru": "Дистанция",
            "kk": "Қашықтық",
            "en": "Distance"
        ],
        "ev_list_distance_km": [
            "ru": "%d км",
            "kk": "%d км",
            "en": "%d km"
        ],
        "ev_list_filter_age_format": [
            "ru": "%d лет",
            "kk": "%d жас",
            "en": "%d y.o."
        ],
        "ev_list_filter_today": [
            "ru": "сегодня",
            "kk": "бүгін",
            "en": "today"
        ],
        "ev_list_filter_nearby": [
            "ru": "рядом",
            "kk": "маңайда",
            "en": "nearby"
        ],
        "ev_list_filter_only_today": [
            "ru": "Только сегодня",
            "kk": "Тек бүгін",
            "en": "Today only"
        ],
        "ev_list_filter_near_me": [
            "ru": "Рядом со мной",
            "kk": "Маған жақын",
            "en": "Near me"
        ],
        "ev_list_load_error": [
            "ru": "Не удалось загрузить события: %@",
            "kk": "Оқиғаларды жүктеу мүмкін болмады: %@",
            "en": "Failed to load events: %@"
        ],
        "ev_list_offline_mode": [
            "ru": "Показываем сохраненные события (офлайн-режим)",
            "kk": "Сақталған оқиғалар көрсетілуде (офлайн-режим)",
            "en": "Showing saved events (offline mode)"
        ],
        "ev_list_create_error": [
            "ru": "Ошибка при создании события: %@",
            "kk": "Оқиғаны жасау қатесі: %@",
            "en": "Failed to create event: %@"
        ],
        "ev_list_update_error": [
            "ru": "Ошибка при обновлении события: %@",
            "kk": "Оқиғаны жаңарту қатесі: %@",
            "en": "Failed to update event: %@"
        ],
        "ev_list_join_error": [
            "ru": "Не удалось присоединиться: %@",
            "kk": "Қосылу мүмкін болмады: %@",
            "en": "Failed to join: %@"
        ],
        "ev_list_leave_error": [
            "ru": "Не удалось отменить участие: %@",
            "kk": "Қатысудан бас тарту мүмкін болмады: %@",
            "en": "Failed to leave: %@"
        ],
        "ev_list_arrive_error": [
            "ru": "Не удалось отметить прибытие: %@",
            "kk": "Келуді белгілеу мүмкін болмады: %@",
            "en": "Failed to mark arrival: %@"
        ],
        "ev_list_status_update_error": [
            "ru": "Не удалось обновить статус: %@",
            "kk": "Мәртебені жаңарту мүмкін болмады: %@",
            "en": "Failed to update status: %@"
        ],
        "ev_list_location_update_error": [
            "ru": "Не удалось обновить локацию: %@",
            "kk": "Локацияны жаңарту мүмкін болмады: %@",
            "en": "Failed to update location: %@"
        ],
        "ev_list_live_locations_error": [
            "ru": "Не удалось загрузить локации участников: %@",
            "kk": "Қатысушылардың локацияларын жүктеу мүмкін болмады: %@",
            "en": "Failed to load participant locations: %@"
        ],
        
        // ev_ texts
        "ev_weather_forecast": [
            "ru": "Прогноз",
            "kk": "Ауа райы болжамы",
            "en": "Forecast"
        ],
        "ev_weather_clear": [
            "ru": "Ясно",
            "kk": "Ашық",
            "en": "Clear"
        ],
        "ev_weather_partly_cloudy": [
            "ru": "Переменная облачность",
            "kk": "Ауыспалы бұлтты",
            "en": "Partly cloudy"
        ],
        "ev_weather_fog": [
            "ru": "Туман",
            "kk": "Тұман",
            "en": "Fog"
        ],
        "ev_weather_rain": [
            "ru": "Дождь",
            "kk": "Жаңбыр",
            "en": "Rain"
        ],
        "ev_weather_snow": [
            "ru": "Снег",
            "kk": "Қар",
            "en": "Snow"
        ],
        "ev_weather_thunderstorm": [
            "ru": "Гроза",
            "kk": "Найзағай",
            "en": "Thunderstorm"
        ],
        "ev_weather_feels_like": [
            "ru": "ощущается %d°C",
            "kk": "сезілуі %d°C",
            "en": "feels like %d°C"
        ],
        "ev_weather_precipitation": [
            "ru": "осадки %.1f мм",
            "kk": "жауын-шашын %.1f мм",
            "en": "precipitation %.1f mm"
        ],
        "ev_weather_wind": [
            "ru": "ветер %d км/ч",
            "kk": "жел %d км/сағ",
            "en": "wind %d km/h"
        ],
        "ev_distance_km_format": [
            "ru": "%.1f км",
            "kk": "%.1f км",
            "en": "%.1f km"
        ],
        "ev_weather_title": [
            "ru": "Погода для встречи",
            "kk": "Кездесу ауа райы",
            "en": "Event weather"
        ],
        "ev_weather_loading": [
            "ru": "Загружаем прогноз...",
            "kk": "Ауа райы болжамы жүктелуде...",
            "en": "Loading forecast..."
        ],
        "ev_weather_unavailable": [
            "ru": "Прогноз пока недоступен",
            "kk": "Ауа райы болжамы әзірге қолжетімсіз",
            "en": "Forecast unavailable yet"
        ],
        "ev_edit_event_btn": [
            "ru": "Редактировать встречу",
            "kk": "Кездесуді өңдеу",
            "en": "Edit Event"
        ],
        "ev_i_am_here": [
            "ru": "Я на месте",
            "kk": "Мен жеттім",
            "en": "I'm here"
        ],
        "ev_you_are_here": [
            "ru": "Вы на месте",
            "kk": "Сіз осындасыз",
            "en": "You are here"
        ],
        "ev_gps_checking": [
            "ru": "Проверяем GPS...",
            "kk": "GPS тексерілуде...",
            "en": "Checking GPS..."
        ],
        "ev_my_status": [
            "ru": "Мой статус",
            "kk": "Менің мәртебем",
            "en": "My Status"
        ],
        "ev_my_status_hint": [
            "ru": "Покажите организатору и участникам, что с вами.",
            "kk": "Ұйымдастырушы мен қатысушыларға жағдайыңызды көрсетіңіз.",
            "en": "Show the organizer and participants your status."
        ],
        "ev_status_going": [
            "ru": "Иду",
            "kk": "Барамын",
            "en": "Going"
        ],
        "ev_status_late": [
            "ru": "Опаздываю",
            "kk": "Кешігемін",
            "en": "I'll be late"
        ],
        "ev_status_arrived": [
            "ru": "На месте",
            "kk": "Осында",
            "en": "Arrived"
        ],
        "ev_status_cant_go": [
            "ru": "Не смогу",
            "kk": "Бара алмаймын",
            "en": "Can't make it"
        ],
        "ev_arrival_gps_error": [
            "ru": "Не удалось получить GPS. Проверьте доступ к геолокации.",
            "kk": "GPS алу мүмкін болмады. Геолокация рұқсатын тексеріңіз.",
            "en": "Failed to get GPS. Check location permissions."
        ],
        "ev_participant_status_late": [
            "ru": "Опаздывает",
            "kk": "Кешігеді",
            "en": "Late"
        ],
        "ev_participant_status_cant_go": [
            "ru": "Не сможет",
            "kk": "Келе алмайды",
            "en": "Can't make it"
        ],
        "ev_participant_status_going": [
            "ru": "Идёт",
            "kk": "Бара жатыр",
            "en": "Going"
        ],
        "edit_ev_name": [
            "ru": "Название",
            "kk": "Атауы",
            "en": "Title"
        ],
        "edit_ev_desc": [
            "ru": "Описание",
            "kk": "Сипаттама",
            "en": "Description"
        ],
        "edit_ev_category": [
            "ru": "Категория",
            "kk": "Санаты",
            "en": "Category"
        ],
        "edit_ev_location": [
            "ru": "Место встречи",
            "kk": "Кездесу орны",
            "en": "Meeting place"
        ],
        "edit_ev_location_placeholder": [
            "ru": "Название места",
            "kk": "Орын атауы",
            "en": "Location name"
        ],
        "edit_ev_latitude": [
            "ru": "Широта",
            "kk": "Ендік",
            "en": "Latitude"
        ],
        "edit_ev_longitude": [
            "ru": "Долгота",
            "kk": "Бойлық",
            "en": "Longitude"
        ],
        "edit_ev_max_participants": [
            "ru": "Лимит участников",
            "kk": "Қатысушылар лимиті",
            "en": "Participant limit"
        ],
        "edit_ev_restrictions": [
            "ru": "Ограничения",
            "kk": "Шектеулер",
            "en": "Restrictions"
        ],
        "edit_ev_no_limit": [
            "ru": "без лимита",
            "kk": "шектеусіз",
            "en": "no limit"
        ],
        "edit_ev_age_from_format": [
            "ru": "Возраст от: %@",
            "kk": "Жас шамасы (бастап): %@",
            "en": "Min age: %@"
        ],
        "edit_ev_age_to_format": [
            "ru": "Возраст до: %@",
            "kk": "Жас шамасы (дейін): %@",
            "en": "Max age: %@"
        ],
        "edit_ev_save_btn": [
            "ru": "Сохранить изменения",
            "kk": "Өзгерістерді сақтау",
            "en": "Save changes"
        ],
        "edit_ev_nav_title": [
            "ru": "Редактировать",
            "kk": "Өңдеу",
            "en": "Edit"
        ],
        "edit_ev_err_title": [
            "ru": "Введите название",
            "kk": "Атауын енгізіңіз",
            "en": "Enter title"
        ],
        "edit_ev_err_desc": [
            "ru": "Введите описание",
            "kk": "Сипаттамасын енгізіңіз",
            "en": "Enter description"
        ],
        "edit_ev_err_location": [
            "ru": "Введите место встречи",
            "kk": "Кездесу орнын енгізіңіз",
            "en": "Enter meeting place"
        ],
        "edit_ev_err_coordinates": [
            "ru": "Проверьте координаты",
            "kk": "Координаталарды тексеріңіз",
            "en": "Check coordinates"
        ],
        "edit_ev_err_end_after_start": [
            "ru": "Окончание должно быть позже начала",
            "kk": "Аяқталуы басталуынан кеш болуы керек",
            "en": "End must be after start"
        ],
        "edit_ev_err_save_failed": [
            "ru": "Не удалось сохранить событие",
            "kk": "Оқиғаны сақтау мүмкін болмады",
            "en": "Failed to save event"
        ],
        
        // profile_ / mod_ / rate_ texts
        "user_detail_load_error": [
            "ru": "Не удалось загрузить пользователя",
            "kk": "Пайдаланушыны жүктеу мүмкін болмады",
            "en": "Failed to load user"
        ],
        "user_detail_reviews_title": [
            "ru": "Отзывы участников",
            "kk": "Қатысушылар пікірлері",
            "en": "Participant Reviews"
        ],
        "user_detail_its_you": [
            "ru": "Это вы",
            "kk": "Бұл сіз",
            "en": "This is you"
        ],
        "user_detail_add_friend": [
            "ru": "Добавить в друзья",
            "kk": "Досқа қосу",
            "en": "Add to Friends"
        ],
        "user_detail_cancel_request": [
            "ru": "Отменить запрос",
            "kk": "Сұрауды бас тарту",
            "en": "Cancel Request"
        ],
        "user_detail_sent_request": [
            "ru": "Отправил вам запрос в друзья",
            "kk": "Сізге достық сұранысын жіберді",
            "en": "Sent you a friend request"
        ],
        "user_detail_reject": [
            "ru": "Отклонить",
            "kk": "Қабылдамау",
            "en": "Decline"
        ],
        "user_detail_accept": [
            "ru": "Принять",
            "kk": "Қабылдау",
            "en": "Accept"
        ],
        "user_detail_friends_status": [
            "ru": "Вы друзья",
            "kk": "Сіздер доссыздар",
            "en": "You are friends"
        ],
        "user_detail_unfriend": [
            "ru": "Удалить из друзей",
            "kk": "Достардан жою",
            "en": "Remove from Friends"
        ],
        "rate_subtitle": [
            "ru": "Поделитесь впечатлениями о других участниках события",
            "kk": "Оқиғаның басқа қатысушылары туралы әсеріңізбен бөлісіңіз",
            "en": "Share your impressions about other event participants"
        ],
        "rate_no_participants_title": [
            "ru": "Нет других участников",
            "kk": "Басқа қатысушылар жоқ",
            "en": "No other participants"
        ],
        "rate_no_participants_desc": [
            "ru": "Вы были единственным участником этого события.",
            "kk": "Сіз бұл оқиғаның жалғыз қатысушысы болдыңыз.",
            "en": "You were the only participant in this event."
        ],
        "rate_rated_badge": [
            "ru": "Оценено",
            "kk": "Бағаланды",
            "en": "Rated"
        ],
        "rate_rate_btn": [
            "ru": "Оценить",
            "kk": "Бағалау",
            "en": "Rate"
        ],
        "rate_sheet_title": [
            "ru": "Оценка участника",
            "kk": "Қатысушыны бағалау",
            "en": "Rate Participant"
        ],
        "rate_star_1": [
            "ru": "Ужасно 😟",
            "kk": "Өте нашар 😟",
            "en": "Terrible 😟"
        ],
        "rate_star_2": [
            "ru": "Плохо 🙁",
            "kk": "Нашар 🙁",
            "en": "Bad 🙁"
        ],
        "rate_star_3": [
            "ru": "Нормально 😐",
            "kk": "Қалыпты 😐",
            "en": "Okay 😐"
        ],
        "rate_star_4": [
            "ru": "Хорошо 🙂",
            "kk": "Жақсы 🙂",
            "en": "Good 🙂"
        ],
        "rate_star_5": [
            "ru": "Отлично! 🤩",
            "kk": "Керемет! 🤩",
            "en": "Excellent! 🤩"
        ],
        "rate_comment_label": [
            "ru": "ОТЗЫВ (НЕОБЯЗАТЕЛЬНО)",
            "kk": "ПІКІР (МІНДЕТТІ ЕМЕС)",
            "en": "REVIEW (OPTIONAL)"
        ],
        "rate_comment_placeholder": [
            "ru": "Напишите пару слов о вашем впечатлении...",
            "kk": "Әсеріңіз туралы бірнеше сөз жазыңыз...",
            "en": "Write a few words about your impression..."
        ],
        "rate_submit_btn": [
            "ru": "Отправить оценку",
            "kk": "Бағаны жіберу",
            "en": "Submit Rating"
        ],
        "my_events_created": [
            "ru": "Созданные",
            "kk": "Жасалғандар",
            "en": "Created"
        ],
        "my_events_participation": [
            "ru": "Участие",
            "kk": "Қатысу",
            "en": "Participation"
        ],
        "my_events_empty": [
            "ru": "Нет таких событий",
            "kk": "Мұндай оқиғалар жоқ",
            "en": "No such events"
        ],
        "events_filter": [
            "ru": "Фильтр",
            "kk": "Сүзгі",
            "en": "Filter"
        ],
        "profile_load_error": [
            "ru": "Не удалось загрузить профиль",
            "kk": "Профильді жүктеу мүмкін болмады",
            "en": "Failed to load profile"
        ],
        "profile_email_confirmed": [
            "ru": "Email подтвержден",
            "kk": "Email расталды",
            "en": "Email confirmed"
        ],
        "profile_email_unconfirmed": [
            "ru": "Подтвердите email",
            "kk": "Email-ді растаңыз",
            "en": "Confirm email"
        ],
        "profile_resend_email": [
            "ru": "Отправить письмо еще раз",
            "kk": "Хатты қайта жіберу",
            "en": "Resend email"
        ],
        "mod_user_email_not_confirmed": [
            "ru": "Email не подтвержден",
            "kk": "Email расталмаған",
            "en": "Email unconfirmed"
        ],
        "mod_user_signin_prefix": [
            "ru": "Вход: %@",
            "kk": "Кіру: %@",
            "en": "Sign-in: %@"
        ],
        "mod_user_reports_sent": [
            "ru": "Репорты",
            "kk": "Репорттар",
            "en": "Reports"
        ],
        "mod_ban_reason_format": [
            "ru": "Причина: %@",
            "kk": "Себебі: %@",
            "en": "Reason: %@"
        ],
        "mod_tools_ai_helper": [
            "ru": "AI помощник",
            "kk": "ЖИ көмекшісі",
            "en": "AI assistant"
        ],
        "mod_tools_default_city": [
            "ru": "Город по умолчанию",
            "kk": "Әдепкі қала",
            "en": "Default city"
        ],
        "mod_tools_ai_rate_limit": [
            "ru": "Лимит ИИ / 10 мин",
            "kk": "ЖИ лимиті / 10 мин",
            "en": "AI limit / 10 min"
        ],
        "mod_msg_report_dismissed": [
            "ru": "Жалоба успешно отклонена/закрыта",
            "kk": "Шағым сәтті қабылданбады/жабылды",
            "en": "Report successfully dismissed/closed"
        ],
        "mod_msg_user_banned": [
            "ru": "Пользователь заблокирован",
            "kk": "Пайдаланушы бұғатталды",
            "en": "User banned"
        ],
        "mod_msg_user_unbanned": [
            "ru": "Пользователь успешно разблокирован",
            "kk": "Пайдаланушы бұғаттан сәтті шығарылды",
            "en": "User successfully unbanned"
        ],
        "mod_msg_user_deleted": [
            "ru": "Пользователь удален навсегда",
            "kk": "Пайдаланушы біржола жойылды",
            "en": "User deleted permanently"
        ],
        "mod_msg_role_updated": [
            "ru": "Роль пользователя обновлена на %@",
            "kk": "Пайдаланушы рөлі келесіге жаңартылды: %@",
            "en": "User role updated to %@"
        ],
        "mod_msg_event_deleted": [
            "ru": "Событие удалено",
            "kk": "Оқиға жойылды",
            "en": "Event deleted"
        ],
        "mod_msg_event_status_updated": [
            "ru": "Статус события обновлен на %@",
            "kk": "Оқиға мәртебесі келесіге жаңартылды: %@",
            "en": "Event status updated to %@"
        ],
        "mod_msg_broadcast_sent": [
            "ru": "Объявление успешно отправлено всем пользователям!",
            "kk": "Хабарландыру барлық пайдаланушыларға сәтті жіберілді!",
            "en": "Announcement successfully sent to all users!"
        ],
        "mod_err_ai_rate_limit": [
            "ru": "Лимит ИИ должен быть положительным числом",
            "kk": "ЖИ лимиті оң сан болуы керек",
            "en": "AI limit must be a positive number"
        ],
        "mod_err_default_city": [
            "ru": "Город по умолчанию не должен быть пустым",
            "kk": "Әдепкі қала бос болмауы керек",
            "en": "Default city cannot be empty"
        ],
        "mod_events_age_up_to": [
            "ru": "до %d",
            "kk": "%d дейін",
            "en": "up to %d"
        ],
        "mod_audit_action_ban": [
            "ru": "Блокировка пользователя",
            "kk": "Пайдаланушыны бұғаттау",
            "en": "User ban"
        ],
        "mod_audit_action_unban": [
            "ru": "Разблокировка пользователя",
            "kk": "Пайдаланушыны бұғаттан шығару",
            "en": "User unban"
        ],
        "mod_audit_action_update_role": [
            "ru": "Изменение роли",
            "kk": "Рөлді өзгерту",
            "en": "Role change"
        ],
        "mod_audit_action_close_report": [
            "ru": "Жалоба закрыта",
            "kk": "Шағым жабылды",
            "en": "Report closed"
        ],
        "mod_audit_action_delete_event": [
            "ru": "Ивент удален",
            "kk": "Оқиға жойылды",
            "en": "Event deleted"
        ],
        "mod_audit_action_delete_profile": [
            "ru": "Профиль удален",
            "kk": "Профиль жойылды",
            "en": "Profile deleted"
        ],
        "mod_audit_action_update_event_status": [
            "ru": "Статус ивента изменен",
            "kk": "Оқиға мәртебесі өзгертілді",
            "en": "Event status updated"
        ],
        "mod_reason_spam": [
            "ru": "СПАМ",
            "kk": "СПАМ",
            "en": "SPAM"
        ],
        "mod_reason_abuse": [
            "ru": "ОСКОРБЛЕНИЯ",
            "kk": "ҚОРЛАУ",
            "en": "ABUSE"
        ],
        "mod_reason_inappropriate": [
            "ru": "НЕПРИЕМЛЕМЫЙ КОНТЕНТ",
            "kk": "ҚОЛАЙСЫЗ КОНТЕНТ",
            "en": "INAPPROPRIATE CONTENT"
        ],
        "mod_reason_default": [
            "ru": "ЖАЛОБА",
            "kk": "ШАҒЫМ",
            "en": "REPORT"
        ],
        
        // auth_ texts
        "auth_reset_password_title": [
            "ru": "Сброс пароля",
            "kk": "Құпия сөзді қайта орнату",
            "en": "Reset Password"
        ],
        "auth_reset_password_subtitle": [
            "ru": "Введите email аккаунта. Мы отправим ссылку для создания нового пароля.",
            "kk": "Аккаунттың email-ін енгізіңіз. Біз жаңа құпия сөз жасау сілтемесін жібереміз.",
            "en": "Enter your account email. We will send a link to create a new password."
        ],
        "forgot_btn": [
            "ru": "Отправить ссылку",
            "kk": "Сілтемені жіберу",
            "en": "Send Link"
        ],
        "auth_back_to_login": [
            "ru": "Вернуться ко входу",
            "kk": "Кіруге оралу",
            "en": "Back to Sign In"
        ],
        "auth_new_password_title": [
            "ru": "Новый пароль",
            "kk": "Жаңа құпия сөз",
            "en": "New Password"
        ],
        "auth_new_password_subtitle": [
            "ru": "Придумайте новый пароль для аккаунта.",
            "kk": "Аккаунт үшін жаңа құпия сөз ойлап табыңыз.",
            "en": "Create a new password for your account."
        ],
        "auth_repeat_password": [
            "ru": "Повторите пароль",
            "kk": "Құпия сөзді қайталаңыз",
            "en": "Repeat password"
        ],
        "auth_repeat_password_placeholder": [
            "ru": "Введите пароль еще раз",
            "kk": "Құпия сөзді қайта енгізіңіз",
            "en": "Enter password again"
        ],
        "auth_err_password_min_length": [
            "ru": "Пароль должен быть минимум 6 символов",
            "kk": "Құпия сөз кемінде 6 таңбадан тұруы керек",
            "en": "Password must be at least 6 characters"
        ],
        "auth_save_password_btn": [
            "ru": "Сохранить пароль",
            "kk": "Құпия сөзді сақтау",
            "en": "Save Password"
        ],
        "login_forgot_password": [
            "ru": "Забыли пароль?",
            "kk": "Құпия сөзді ұмыттыңыз ба?",
            "en": "Forgot password?"
        ],
        "auth_err_save_tokens": [
            "ru": "Не удалось сохранить токены безопасности",
            "kk": "Қауіпсіздік токендерін сақтау мүмкін болмады",
            "en": "Failed to save security tokens"
        ],
        "auth_signup_success_verify": [
            "ru": "Аккаунт создан. Введите код из письма для подтверждения email.",
            "kk": "Аккаунт жасалды. Email-ді растау үшін хаттағы кодты енгізіңіз.",
            "en": "Account created. Enter the code from the email to verify your email address."
        ],
        "auth_reset_email_sent": [
            "ru": "Письмо для сброса пароля отправлено. Проверьте почту.",
            "kk": "Құпия сөзді қалпына келтіру хаты жіберілді. Поштаңызды тексеріңіз.",
            "en": "Password reset email sent. Please check your inbox."
        ],
        "auth_resend_confirmation_sent": [
            "ru": "Письмо подтверждения отправлено еще раз. Проверьте почту.",
            "kk": "Растау хаты қайта жіберілді. Поштаңызды тексеріңіз.",
            "en": "Confirmation email sent again. Please check your inbox."
        ],
        "auth_reset_link_invalid_or_expired": [
            "ru": "Неверная или устаревшая ссылка для сброса пароля",
            "kk": "Құпия сөзді қалпына келтіру сілтемесі қате немесе мерзімі өткен",
            "en": "Password reset link is invalid or expired"
        ],
        "auth_reset_link_invalid": [
            "ru": "Ссылка для сброса пароля недействительна",
            "kk": "Құпия сөзді қалпына келтіру сілтемесі жарамсыз",
            "en": "Password reset link is invalid"
        ],
        "auth_password_updated_success": [
            "ru": "Пароль обновлен. Теперь можно войти с новым паролем.",
            "kk": "Құпия сөз жаңартылды. Енді жаңа құпия сөзбен кіруге болады.",
            "en": "Password updated. You can now sign in with your new password."
        ],
        "auth_err_load_profile_format": [
            "ru": "Не удалось загрузить профиль: %@",
            "kk": "Профильді жүктеу мүмкін болмады: %@",
            "en": "Failed to load profile: %@"
        ],
        "auth_err_update_profile_format": [
            "ru": "Не удалось обновить профиль: %@",
            "kk": "Профильді жаңарту мүмкін болмады: %@",
            "en": "Failed to update profile: %@"
        ],
        "profile_delete_account": [
            "ru": "Удалить аккаунт",
            "kk": "Аккаунтты жою",
            "en": "Delete Account"
        ],
        "profile_delete_account_title": [
            "ru": "Удалить аккаунт?",
            "kk": "Аккаунтты жою керек пе?",
            "en": "Delete Account?"
        ],
        "profile_delete_account_message": [
            "ru": "Будут удалены ваш профиль, фото, созданные вами события, участие и друзья. Сообщения в чатах останутся от имени «Удалённый пользователь». Это действие нельзя отменить.",
            "kk": "Сіздің профиліңіз, фотоларыңыз, жасаған іс-шараларыңыз, қатысуларыңыз бен достарыңыз жойылады. Чаттардағы хабарламалар «Жойылған пайдаланушы» атынан қалады. Бұл әрекетті қайтару мүмкін емес.",
            "en": "Your profile, photos, created events, participation, and friends will be deleted. Chat messages will remain under \"Deleted User\". This action cannot be undone."
        ],
        "profile_delete_account_confirm": [
            "ru": "Удалить",
            "kk": "Жою",
            "en": "Delete"
        ],
        "profile_delete_account_error": [
            "ru": "Не удалось удалить аккаунт. Попробуйте ещё раз",
            "kk": "Аккаунтты жою мүмкін болмады. Қайталап көріңіз",
            "en": "Failed to delete account. Please try again"
        ],
        "profile_privacy_policy": [
            "ru": "Политика конфиденциальности",
            "kk": "Құпиялық саясаты",
            "en": "Privacy Policy"
        ],
        "profile_terms": [
            "ru": "Условия использования",
            "kk": "Пайдалану шарттары",
            "en": "Terms of Service"
        ],
        "reg_terms_prefix": [
            "ru": "Я принимаю ",
            "kk": "Мен қабылдаймын: ",
            "en": "I accept the "
        ],
        "reg_terms_link": [
            "ru": "Условия использования",
            "kk": "Пайдалану шарттары",
            "en": "Terms of Service"
        ],
        "reg_terms_and": [
            "ru": " и ",
            "kk": " және ",
            "en": " and "
        ],
        "reg_privacy_link": [
            "ru": "Политику конфиденциальности",
            "kk": "Құпиялық саясаты",
            "en": "Privacy Policy"
        ],
        "reg_terms_required": [
            "ru": "Чтобы продолжить, примите условия и политику",
            "kk": "Жалғастыру үшін шарттар мен саясатты қабылдаңыз",
            "en": "Please accept the terms and privacy policy to continue"
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
