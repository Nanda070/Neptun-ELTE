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

---

## В работе / запланировано (честно)

**[ongoing]**

- **Принудительный logout сессии** при провале refresh / silent re-auth — **в коде** (`SessionGuard.forceExpiredLogout`); логин сохраняется, снова экран входа. Следить за краевыми случаями после wipe cookie портала.
- **Переводчик сообщений** (HU → EN/RU для тел писем) — helper + действия в popup есть; считать **in progress**, пока offline / failure не проверены тщательно.
- Бэклог фич **Quick / Medium** — **запланировано**, не заявлено как shipped.
- Полный UI email OTP (`RequestEmailCode` / `CodePrefix`) — известен по HAR; **не** основной путь (сначала TOTP).
- Тонкая настройка учебной недели под текущий календарь семестра — **ещё итерация**.

---

*Владелец / разработчик: **Nanda**. Полное юридическое имя — только в Legal.*
