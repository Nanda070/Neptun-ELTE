# Neptun ELTE — Dev Blog

Короткий дневник разработки **Neptun ELTE** (владелец: **Nanda**).  
Время — **Europe/Budapest (UTC+2)**. Факты по репозиторию и живой работе — не маркетинговый changelog.

> 🇬🇧 [English](DEV_BLOG.md) · 📘 [Техническая](TECHNICAL.ru.md) · [Product README](../README.ru.md)

---

## 2026-09-09

**[2026-09-09, 23:06]**

- Базовая линия Android-релиза **1.0.5+18** ещё под брендом Neptun Mobile.
- До «только ELTE»: в дереве ещё список вузов и старые языковые пакеты.

---

## 2026-09-13 — iOS, языки, хаб ELTE

**[2026-09-13, 00:18]**

- Поднят проект **iOS** (`ios/`, CocoaPods, Automatic Signing / Team).
- Физический iPhone: **`flutter run --release`**, чтобы иконка появилась на домашнем экране (ограничение debug на iOS 14+).
- Bundle ID **`com.nanda070.neptunmobile`** (без `_` — иначе ломается signing); Android остаётся `com.nanda070.neptun_mobile.app`.
- Языки: встроенные **EN / HU** + пакеты **RU / TR** с GitHub.
- Удалены шуточные / неиспользуемые пакеты (Pirate, Chinese, German, Spanish, Romanian, Ukrainian, UAE и т.д.).

**[2026-09-13, 00:29]**

- Расширен путь логина / **2FA** для modern Neptun API (ввод кода после пароля).
- Первые правки входа на iOS; дальше — реальный портальный поток ELTE.

**[2026-09-13, 00:38 – 00:42]**

- Расширены developer / technical docs (EN + RU): запуск iOS, signing, честные оговорки.

**[2026-09-13, 01:45]**

- Продукт сужен до **только ELTE**.
- Хаб: одна кнопка института — без списка вузов и без произвольного URL.
- `universityNameUrlPairs.json` → одна запись: ELTE → **`https://neptun.elte.hu`**.
- Явно **не** путь Óbuda/BME **`/ujhallgato`**.

**[2026-09-13, 01:50]**

- Переименование display / docs: **Neptun ELTE** (целевой репо **Neptun-ELTE**).
- Каталог тем и строки языков под новое имя.
- Android label / iOS display name выровнены.

**[2026-09-13, 02:12]**

- Зафиксирован student-web bridge: после портала Student web попадает на **`hallgatoN.neptun.elte.hu`** (балансировка узлов `1…N`).
- **Не** хардкодить один `hallgato` — узел назначает портал (в live HAR: `hallgato3` / `ELTE_HW3`).

**[2026-09-13, 04:20]**

- Главная правка логина: **`POST https://neptun.elte.hu/api/Account/Authenticate` для ELTE мёртв** (пустой HTTP 400).
- Верный путь как на сайте: портал **Potlap** `Login` → **`Login2FA`** (TOTP) → **`ToNeptunHWeb`** → **`OuterLogin`** JWT на назначенном `hallgatoN`.
- Разделение **неверный пароль** vs **сервер занят** / перегрузка (больше не маскируется под bad password).
- Формат email OTP из HAR задокументирован как **`XXX-XXXXXX`** (префикс 3 цифры + 6); в UI приоритет у **Authenticator TOTP**.
- Устаревшая плашка «с 2FA войти нельзя» **удалена** — на ELTE 2FA обязательна, приложение принимает код.

---

## 2026-09-13 — полировка, UX, docs (та же ночь → утро)

**[2026-09-13, ~04:45]**

- Исправлен **чёрный экран после успешного 2FA**: сначала закрыть popup 2FA, затем `pushAndRemoveUntil(HomePage)`, чтобы отложенный `pop` не обнулил навигатор.
- Нумерация учебной недели: предпочитать **учебный / лекционный период** (`szorgalmi`, study period, …), а не окна **записи на предметы**, которые начинаются раньше и раздували номер недели (~36). Всё ещё итерация к осмысленным **неделям 1–2** в начале сентября.
- UX: сохраняются только темы **Light / Dark**; баг-репорт / контакты → **[nanda.is-a.dev](https://nanda.is-a.dev)**; при выходе остаётся **логин**, очищаются **пароль** / сессия + cookie jar портала.
- i18n хрома Payments / Contacts; заголовки прямо из API Neptun могут оставаться на венгерском.

**[2026-09-13, ~05:00]**

- Реструктуризация docs в `docs/`:
  - Legal: **`Legal-En/` · `Legal-Ru/` · `Legal-Hu/`** (Privacy, Terms, Cookies).
  - Technical → **`docs/Technical/`**; отдельный **`DEVELOPER.md` удалён** (iOS-шпаргалка — Technical §14).
  - Канон лицензии **LGPL-3.0-only** в `docs/LICENSE` (корневой `LICENSE` зеркалирует).
- Добавлен этот **Dev Blog** (EN + RU).

**[2026-09-13, ~05:15]**

- Баг календаря: modern `GetCalendarEvents` брал **следующий понедельник 23:59** как `endDate` → занятия следующего пн после ложного **~163 ч «szünet»** (и HU-хардкод UI перерыва). Исправлено: **конец воскресенья**, отсев вне окна, перерывы только в тот же день (5 мин–12 ч), локализация EN/HU/RU/TR.

**[2026-09-13, 05:14]**

- Языковые пакеты RU/TR: добавлены **39** ключей, которые были в EN/HU, но отсутствовали в JSON с GitHub (масштаб шрифта, полосы/фильтры/перерывы календаря, перевод почты, секции настроек, заголовки уведомлений, markbook/payment). Недостающие ключи раньше падали в **английский**.
- `Languages/LangExtentions/{Russian,Turkish}.json` bundled как Flutter **assets**; `loadBundledLanguagePacks` мержит в кэш/скачанные пакеты, чтобы устройство не зависело от устаревшего GitHub/cache до push.
- Хардкода английского в UI календаря для TR **не найдено** — заголовки уже через `AppStrings`; причина — устаревшие пакеты.
- Деплой на iPhone Nanda **пропущен** (активен другой `flutter run --release`).

**[2026-09-13, ~05:16]**

- **10-минутный wall-clock сессии:** `SessionGuard.startSessionWallClock()` при входе на `HomePage` → через 10 мин `forceExpiredLogout` (логин сохраняется, snackbar `auth_sessionExpired_PleaseSignIn`, экран входа). Отмена при ручном выходе; перезапуск при повторном логине. **Не** продлевается refresh JWT. Выравнивает UI-logout с короткоживущими access JWT Neptun (~10–15 мин) от **входа в сессию**, а не только от 401.

**[2026-09-13, ~05:20]**

- **Аватар в drawer работает:** в HAR фото уже есть в `/api/UserInfo` как `data.userAvatar.image` (base64 JPEG) и крупнее в `/api/General/GetUserAvatar?imageSizeType=Normal`. Кэш base64 в `DataCache`, drawer — `MemoryImage`, fallback на инициалы. Прежнее «в API нет фото» было ошибкой — пропустили вложенное поле.

**[2026-09-13, ~05:25]**

- **EN chrome деталей предмета:** диалоги тапа по занятию / задаче в календаре имели HU-хардкод (`Tárgykód`, `Típus`, `Tanár`, `Terem`, `Bezárás`, `Terem betöltése…`, Subject/Type/Result задачи). Переведено на `courseDetail_*` + `popup_case4_5_SubjectCode` (EN/HU/RU/TR). Плейсхолдеры приложения локализуются; **контент Neptun** (названия, Előadás/Gyakorlat, аудитории) может остаться на HU.

**[2026-09-13, ~05:30]**

- **Тап-расшифровка кодов аудиторий ELTE:** `LD-0-805` / `LD-0-805-01-11` переключают короткий код ↔ сводку (кампус–этаж–аудитория–**поток**–**группа**; отсутствующие хвосты не выдумываются). Префиксы LD/LE/LK. `DecodableRoomText` в списке, диалоге и popup. Ключи `roomCode_*` в HU/EN + RU/TR JSON.

**[2026-09-13, ~05:35]**

- Расширенный i18n-аудит: тела уведомлений занятий/экзаменов, подпись масштаба шрифта, ошибки почты, 2FA popup, Android updater, API fallback + DEMO — всё через `LanguagePack` (HU/EN + RU/TR JSON). UI декода кода аудитории сохранён.

**[2026-09-13, ~05:40]**

- Добиты остатки Language Pack аудита в `api_coms`: транспортный `ErrorMessage` (неверный URL/HTML, сеть), JSON истечения сессии через `auth_sessionExpired_PleaseSignIn`, превью письма «нажмите чтобы загрузить», пустой ответ Neptun / сетевая ошибка загрузки (`api_error_*`, `mail_preview_TapToLoadBody` HU/EN + RU/TR). Токены статуса оплаты для matching API (`aktív` / `teljesített`) оставлены как ключи протокола (не UI).

---

## В работе / запланировано (честно)

**[ongoing]**

- **Принудительный logout сессии** при провале refresh / silent re-auth — **в коде** (`SessionGuard.forceExpiredLogout`); логин сохраняется, снова экран входа. Следить за краевыми случаями после wipe cookie портала.
- **Переводчик сообщений** (HU → EN/RU для тел писем) — helper + действия в popup есть; считать **in progress**, пока offline / failure не проверены тщательно.
- **Крупные фичи** (студенческий, полный профиль+банк, запись на экзамен/курс) — нужен HAR; не сделаны.
- Полный UI email OTP (`RequestEmailCode` / `CodePrefix`) — известен по HAR; **не** основной путь (сначала TOTP).

---

*Владелец / разработчик: **Nanda**. Полное юридическое имя — только в Legal.*
