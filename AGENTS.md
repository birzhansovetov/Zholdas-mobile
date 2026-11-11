# Zholdas Mobile — правила для агентов

Главное репо проекта Жолдас: https://github.com/birzhansovetov/Zholdas-mobile (ветка `main`).
Основное направление — **мобильная разработка под iOS и Android**.

---

## 1. Стек

| Часть | Папка | Технологии |
|---|---|---|
| iOS | `Zholdas/` | Swift 5, SwiftUI, Xcode-проект `Zholdas.xcodeproj`, iOS 18.0+, тесты `ZholdasTests`, `ZholdasUITests` |
| Android | `ZholdasAndroid/` | Kotlin 2.3, Jetpack Compose (Material 3), Navigation 3, Retrofit + OkHttp, DataStore, Coil, Firebase Messaging; AGP 9, compileSdk/targetSdk 36, minSdk 24; пакет `com.example.zholdas` |
| Бэкенд | `backend/` | Go 1.25 (Gin), PostgreSQL, sqlc (`db/queries`), миграции `db/migrations` |
| Деплой | `.github/workflows/deploy-heroku.yml` | Heroku, приложение `zholdas-api-de89a64e4196.herokuapp.com` |

Оба приложения ходят в один и тот же бэкенд (`AppConfig.swift` на iOS, `BACKEND_BASE_URL` в `ZholdasAndroid/app/build.gradle.kts`).

---

## 2. Роли

*   **Claude Code — основной агент.** Пишет код для iOS, Android и бэкенда, принимает технические решения, проверяет сборку и тесты.
*   **agy (Antigravity CLI, Google AI Pro) — помощник** для дизайна, UI-текстов (RU/KZ/EN), анализа длинных файлов и второго мнения. Его ответ — совет: Claude Code проверяет его, прежде чем применить. Как вызывать — раздел 5.
*   **Пользователь** утверждает продуктовые решения: какие фичи добавить, переделать или убрать.

---

## 3. Правила работы

1.  **Паритет платформ.** Фича или фикс делается сразу на iOS и Android, если Пользователь не сказал иначе. Тексты, поведение и обращения к API должны совпадать.
2.  **Push в `main` с изменениями в `backend/**` сразу деплоит на Heroku.** Перед таким push — спросить Пользователя.
3.  **Внешние сервисы** (Heroku, база, Firebase, Supabase, App Store / Google Play) — менять только после подтверждения Пользователя.
4.  **Секреты не коммитить:** `.env`, `google-services.json`, ключи подписи. Названия переменных бэкенда — в `backend/.env.example`.
5.  **Mac нет — iOS собирается в облаке.** Swift-код пишем на Windows, собирает и тестирует его GitHub Actions на macOS (`.github/workflows/ios.yml`), сборки с `main` уходят в TestFlight на iPhone Пользователя. Android и бэкенд собираются локально. Подробно — раздел 4.
6.  Перед релизом Android — `ZholdasAndroid/RELEASE_CHECKLIST.md`.

---

## 4. Сборка и тесты (Windows)

**Где работаем:** рабочий клон — `D:\dev\Zholdas-mobile`. Диск C: почти заполнен, поэтому все кэши и временные файлы сборок держим в `D:\dev\cache`. Перед любой сборкой в bash:
```bash
export GRADLE_USER_HOME='D:\dev\cache\gradle' GOCACHE='D:\dev\cache\go-build' GOMODCACHE='D:\dev\cache\go-mod' \
       GOTMPDIR='D:\dev\cache\go-tmp' TMP='D:\dev\cache\tmp' TEMP='D:\dev\cache\tmp' \
       JAVA_TOOL_OPTIONS='-Djava.io.tmpdir=D:\dev\cache\tmp' \
       JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" ANDROID_HOME="/c/Users/Hp/AppData/Local/Android/Sdk"
```

**Android** (проверено 2026-11-10: сборка OK, 108 unit-тестов зелёные; первая сборка ~25 мин из-за скачивания зависимостей):
```bash
cd ZholdasAndroid
./gradlew.bat :app:assembleDebug     # APK → app/build/outputs/apk/debug/app-debug.apk
./gradlew.bat :app:testDebugUnitTest # unit-тесты
```
Без `app/google-services.json` Firebase-плагин просто не подключается — сборка идёт и без него.

**Бэкенд** (проверено 2026-11-10: сборка OK, тесты `middleware` и `service` зелёные):
```bash
cd backend
go build ./...
go test ./internal/middleware/... ./internal/service/...
```
Интеграционные тесты в `internal/handler` на Windows не проходят: адрес базы зашит в `integration_test.go` (`postgres://birzhansovetov@localhost:5432/zholdas`, это настройка с Mac).

**Android на эмуляторе** (AVD `Pixel_8`, Android 35, лежит в `D:\dev\cache\avd`; ускорение WHPX работает):
```bash
export ANDROID_AVD_HOME='D:\dev\cache\avd'
"$ANDROID_HOME/emulator/emulator" -avd Pixel_8 -no-snapshot-save &   # запуск (в фоне)
ADB="$ANDROID_HOME/platform-tools/adb.exe"
"$ADB" wait-for-device
"$ADB" install -r app/build/outputs/apk/debug/app-debug.apk
"$ADB" shell monkey -p com.example.zholdas -c android.intent.category.LAUNCHER 1
"$ADB" exec-out screencap -p > /d/dev/cache/screen.png             # скриншот для проверки
```
Если приложение показывает «Офлайн-режим», проверь прокси эмулятора: `adb shell settings get global http_proxy`. На 2026-11-11 там был `10.0.2.2:8080` (похоже на Burp Suite), из-за него все запросы падали. Убрать: `adb shell settings put global http_proxy :0`.

**iOS — без Mac, через GitHub Actions** (`.github/workflows/ios.yml`, раннер `macos-26`, самый новый Xcode):
*   **Любой push / PR с изменениями в `Zholdas/**`** → сборка под симулятор iPhone, unit- и UI-тесты, скриншот запуска. Результаты — в артефактах запуска: `ios-screenshots`, `ios-test-results` (лог `xcodebuild-test.log`). Ошибки компиляции Swift смотреть в этом логе.
*   **Push в `main`** (или ручной запуск *Run workflow* с галочкой *testflight*) → архив, подпись и загрузка в **TestFlight**. Через 5–20 мин обработки сборка приходит на iPhone в приложение TestFlight.
*   Схема Xcode: `Zholdas/Zholdas.xcodeproj/xcshareddata/xcschemes/Zholdas.xcscheme` (shared, нужна для CI).
*   Подпись: команда Apple `YFQ2H65ZA7` (аккаунт Пользователя), автоматическая подпись через App Store Connect API key — сертификаты и профили создаёт Xcode сам (`-allowProvisioningUpdates`). Номер сборки = время UTC `yyMMddHHmm`, версия — `MARKETING_VERSION` в проекте.
*   **GitHub-секреты** (Settings → Secrets and variables → Actions) — добавляет Пользователь сам: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (полный текст файла `AuthKey_XXXX.p8`). Ключ создаётся в App Store Connect → Users and Access → Integrations → App Store Connect API, роль **Admin** (нужна для облачных сертификатов подписи).
*   В App Store Connect должно существовать приложение с bundle id `app.zholdas.Zholdas`; Пользователь добавлен во внутренние тестеры TestFlight.
*   В DEBUG на симуляторе iOS ходит на `http://localhost:8080`, на устройстве и в TestFlight — на Heroku.

---

## 5. Вызов agy (Antigravity CLI)

*   **Путь**: `C:\Users\Hp\AppData\Local\agy\bin\agy.exe` (добавлен в User PATH; в старых терминалах может быть не виден — тогда по полному пути). Версия на момент настройки: 1.5.3.
*   **Одиночный запрос без интерактива** (`-p` / `--print`; флаги ставить ДО `-p`; stdin закрывать, чтобы не зависал):
    ```bash
    agy --mode plan --print-timeout 180s -p "Твой запрос" </dev/null
    ```
    PowerShell: `& "$env:LOCALAPPDATA\agy\bin\agy.exe" --mode plan --print-timeout 180s -p "Твой запрос"`
*   **Режимы**: `--mode plan` — только чтение, по умолчанию. Правки (`--mode accept-edits`) — только по явной просьбе Пользователя. `--dangerously-skip-permissions` не использовать.
*   **Модель**: `--model gemini-3.8-flash-high` (список — `agy models`). Для сложного анализа — `--effort high`.
*   **Файлы**: agy работает в текущей папке и сам читает файлы — достаточно указать путь в запросе («Прочитай ZholdasAndroid/.../MapScreen.kt и …»). Доп. папки — `--add-dir <path>`.
*   **Структурированный ответ**: `--output-format json` или `--json-schema <схема>`.
*   **Продолжить последний диалог**: `agy -c -p "…"`.
*   Запросы дольше 2 минут — запускать в фоне.
