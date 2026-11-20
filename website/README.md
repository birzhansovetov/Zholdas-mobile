# zholdas.app — сайт-презентация

Статический сайт без сборки: `index.html`, `styles.css`, `i18n.js` (тексты KZ/EN), `main.js` (переключение языка и форма листа ожидания).

* Русские тексты — прямо в `index.html`, казахские и английские — в `i18n.js` по тем же ключам `data-i18n`.
* Форма шлёт `POST /waitlist` на бэкенд (Heroku). Адреса лежат в таблице `waitlist`.
* Ссылки на политику и условия ведут на `/privacy` и `/terms` бэкенда.
* `sw.js` удаляет service worker, который остался от старой веб-версии.

Локальный просмотр: `python -m http.server 4173` в этой папке → http://localhost:4173

Деплой: Vercel, Root Directory = `website`, Framework = Other, без команды сборки.
