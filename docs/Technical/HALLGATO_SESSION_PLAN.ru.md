# Поддержка сессии hallgato — план (дизайн)

**Статус:** **ядро v1** + **фикс кэша почты** + **UI недели календаря** отгружены в **1.5.6** (16 сентября 2026). **Фоновый keep-alive** + **сохранение пароля** в Настройках отгружены в **1.5.7** (оба default OFF). Portal/HWEB, проактивный `GetNewTokens` на cold start, парсинг JWT `exp` и live-test matrix — **будущее / исследование**.  
**Владелец:** Nanda.  
**Каноническая пара:** [HALLGATO_SESSION_PLAN.md](HALLGATO_SESSION_PLAN.md) (EN).

> Факты о текущей отгрузке: [TECHNICAL.ru.md — восстановление сессии и wall-clock](TECHNICAL.ru.md#session-recovery-and-wall-clock), [§ Auth, 2FA, tokens](TECHNICAL.ru.md#9-auth-2fa-tokens).

---

## Цель

Сократить число полных входов (**пароль + TOTP**), оставаясь в JWT-сессии **hallgato** при обычном использовании приложения.

- **Полный вход** = пароль ELTE portal + интерактивный 6-значный TOTP (на ELTE **нет** «запомнить устройство» — подтверждено пользователем).
- **Поддержка сессии** = обновление access (и при необходимости refresh) через существующий hallgato API, без имитации активности портала.

---

## Поведение в отгрузке — ядро v1 (1.5.6)

| Механизм | Поведение |
|----------|-----------|
| **Конец сессии** | **Ручной logout** или **мёртвый refresh** (`GetNewTokens` 401/403 / пустые токены). **Нет** клиентского 10-мин wall-clock (enforce `SESSION_StartedAtMs` снят). |
| **Проактивный refresh на foreground** | Каждые **3 мин 30 с** в `AppLifecycleState.resumed` → `SessionGuard.runForegroundTokenMaintenance()` → `POST /api/Account/GetNewTokens`. Пауза в фоне. Интервал: `SessionGuard.foregroundTokenMaintenanceInterval`. |
| **Реактивный refresh** | **401/403** на **GET** → `ensureValidSession()` → `tryTokenRefresh()` → ELTE `trySilentReauth()` (**false**) → `forceExpiredLogout`. Общий lock `_isRefreshingToken` с foreground maintenance. |
| **Grace после входа** | ~45 с после `markParticipantSessionStarted` — реактивный путь не форсирует logout, если access ещё есть. |
| **Cold start** | `isColdStartSessionUsable()`: только `HasLogin` + непустой access (без wall-clock stamp). |
| **Фон / убийство процесса** | Периодических вызовов hallgato нет. Виджеты: только кэш, **без JWT**. |
| **JWT `exp`** | Клиент **не** декодирует `exp`; ~10–15 мин access — **наблюдение**. |

---

## Целевое поведение — приложение открыто (foreground)

### Интервал

Пока приложение в **`AppLifecycleState.resumed`**, проактивная поддержка каждые **3 мин 30 с** — **`SessionGuard.foregroundTokenMaintenanceInterval`** в `lib/API/api_coms.dart` (отгружено **1.5.6**).

### Основной механизм

**`POST {hallgatoBase}/api/Account/GetNewTokens`**

- **Authorization:** `Bearer <refresh JWT>` (как в `tryTokenRefresh()` в `lib/API/api_coms.dart`).
- **Тело:** `{}`.
- **Не** фейковая «активность» портала или опрос HWEB — только существующий REST refresh.

### Обоснование

- Access JWT живёт наблюдаемо **~10–15 минут** на hallgato Neptun.
- Обновлять **до** истечения access, чтобы активное использование не упиралось в первый упавший GET + 401.
- Использовать сохранённый refresh; сохранять новые `accessToken` / `refreshToken` из ответа (как при успехе `tryTokenRefresh()` сегодня).

### Правила lifecycle

| Состояние | Таймер поддержки |
|-----------|------------------|
| `resumed` | Запуск / возобновление периодического maintenance |
| `inactive`, `paused`, `detached`, `hidden` | Пауза / отмена — **без** проактивного `GetNewTokens` |
| Процесс убит | Maintenance нет (см. cold start) |

**Точка интеграции:** `HomePage` `WidgetsBindingObserver` — запуск/остановка maintenance `Timer` при `resumed` vs фоне (wall-clock снят в **1.5.6**).

### Ошибки (foreground)

| Исход | Планируемый UX |
|-------|----------------|
| `GetNewTokens` **200** с токенами | Продолжить; сбросить расписание maintenance |
| **401/403** или пустые токены | Refresh мёртв → `SessionGuard.forceExpiredLogout` (логин + кэш сохраняются) → вход + TOTP |
| Сеть / timeout | **Не** logout сразу; повтор на следующем тике; GET 401 path остаётся запасным |
| Параллельный refresh | Уважать `_isRefreshingToken` / lock в `_APIRequest` — maintenance не должен конфликтовать с реактивным refresh |

---

## Целевое поведение — закрыто / долгий фон

- **По умолчанию (ядро v1):** **нет** периодических запросов, пока isolate Flutter не работает. Действует только foreground **3–4 мин** `GetNewTokens` (см. выше).
- Долгий фон при настройках по умолчанию: refresh на сервере может протухнуть; при возврате может понадобиться полный вход — **допустимо**; keep-alive не гарантируется без опционального фонового maintenance (ниже).
- **Опционально:** пользователь может включить фоновый keep-alive в Настройках — см. [Опциональный фоновый keep-alive (Настройки, по умолчанию ВЫКЛ)](#опциональный-фоновый-keep-alive-настройки-по-умолчанию-выкл).

### Cold start (отгружено)

Wall-clock снят; токены в `flutter_secure_storage` (`DataCache`).

| Ситуация | Ожидаемый поток |
|----------|-----------------|
| **Access ещё валиден** (токен есть; GET принимаются) | `Splitter` / `startup_page.dart` → Home; обычные GET с Bearer access |
| **Access истёк, refresh жив** | Опционально `GetNewTokens` при старте **или** первый GET 401 → `ensureValidSession()` → Home без TOTP |
| **Refresh мёртв или нет** | Wipe auth существующими путями → экран входа → **пароль + TOTP** |
| **Нет `HasLogin` / токенов** | Экран входа |

**Cold start (отгружено):** ветка wall-clock **убрана** из `isColdStartSessionUsable()` в **1.5.6**.

**Виджеты:** без изменений — только кэш календаря; **без JWT** в расширениях.

---

## Опциональный фоновый keep-alive (Настройки, по умолчанию ВЫКЛ)

**Статус:** **отгружено** (опциональный уровень, **по умолчанию ВЫКЛ**) — `SETTING_BackgroundHallgatoKeepAlive`, `lib/Misc/hallgato_background_keepalive.dart`, Настройки → Поведение.

### Управление пользователем

- **Переключатель в Настройках** — «Поддерживать сессию в фоне» (`settings_backgroundHallgatoKeepAlive` в `language.dart` EN/HU/RU).
- **Выкл** (default): как в [Целевое поведение — закрыто / долгий фон](#целевое-поведение--закрыто--долгий-фон) — только foreground maintenance.
- **Вкл:** best-effort поддержка hallgato, пока приложение **не** в `AppLifecycleState.resumed`.

### Механизмы платформ (отгружено — TECHNICAL § Session recovery)

| Платформа | Отгрузка | Заметки |
|-----------|----------|---------|
| **Android** | [`workmanager`](https://pub.dev/packages/workmanager) | Период **15 мин** минимум; сеть + не низкий заряд; Doze/OEM могут откладывать. |
| **iOS** | [`background_fetch`](https://pub.dev/packages/background_fetch) | `UIBackgroundModes` = `fetch`; **15+ мин**, система откладывает; force-quit / выкл. Background Refresh — без гарантий. |

**Ограничение — батарея:** **консервативные** интервалы в фоне (не те же 3–4 мин, что на foreground). Один путь `GetNewTokens` с foreground maintenance; **без** агрессивного polling и параллельных таймеров. Честно: **ОС может откладывать или пропускать** задачи; фоновый maintenance — **best-effort**, не SLA.

### Поведение при включении

- **`POST …/api/Account/GetNewTokens`** (как основной foreground-механизм), когда срабатывает фоновая задача и auth не заблокирован.
- Уважать lock refresh (`_isRefreshingToken`); пропускать тик при foreground refresh.
- **401/403** в фоне: **без headless UI** — лог и отложить до foreground GET / proactive refresh или login + TOTP.
- **Сеть:** повтор на следующем запуске по расписанию ОС; не спамить ELTE.

### Риски и политика магазинов

| Тема | Заметки |
|------|---------|
| **Батарея** | Opt-in; консервативный график; в подзаголовке Настроек — батарея и нерегулярность. |
| **Убийство задач ОС** | Force-stop, низкий заряд, ограничение фона — пользователь всё равно может получить TOTP после долгого отсутствия. |
| **Паттерн трафика ELTE** | Частый фоновый refresh у многих пользователей — держать интервалы консервативными; смотреть 429 в тестах. |
| **Play / App Store** | Background modes / permissions только при реализации; обоснование — **опциональное** maintenance сессии по явному выбору пользователя (не трекинг, не реклама). |

### Открытые вопросы (только план)

- Минимальный интервал: и батарея, и смысл для продукта?
- Один плагин vs platform channels?
- Запускать фоновый refresh только когда refresh JWT близок к expiry (нужен опциональный парсинг `exp`)?

---

## Активность портала / HWEB (исследование — опционально, ниже приоритет)

**Статус:** **возможный будущий подход**, **на одном уровне с** (не заменяя) foreground **3–4 мин** `GetNewTokens`. **Без реализации** в текущей волне; **исследование + опционально**, **ниже приоритет**, чем проактивный JWT refresh.

### Честность

- Student-data REST сегодня: **GET + Bearer JWT** на назначенном `hallgatoN` — cookie портала на этих GET **не** отправляются.
- Состояние portal / HWEB в приложении в основном **in-memory** для login flow; цикла «держать портал живым» нет.
- «Фейковая активность» может означать **best-effort** HTTP к portal / HWEB **только если** исследование покажет, что это продлевает **что-то** значимое для refresh hallgato или сессии ELTE.

**Неизвестно / не доказано:** влияют ли такие запросы на TTL refresh JWT, реже ли 2FA или это только шум. Считать **гипотезой** до HAR + live-тестов.

### Если когда-либо (не v1)

- Тот же tier, что опциональный фоновый keep-alive — **никогда** не замена `GetNewTokens`.
- Не хранить и не replay credentials сверх текущего auth-дизайна; без auto-2FA.
- Rate limits и восприятие abuse — документировать до эксперимента.

### Открытые вопросы

- Какие URL портала (если есть) коррелируют с более долгим refresh?
- Влияет ли опрос HWEB на hallgato JWT?
- Продукт / legal: допустимо ли документировать синтетическую «активность» пользователю?

---

## Опциональное сохранение пароля в Настройках (opt-in, по умолчанию ВЫКЛ)

**Статус:** **отгружено в 1.5.7** (16 сентября 2026) — toggle в Настройках + матрица wipe + pre-fill входа; без auto-2FA. (**Честность:** кратко было, затем Dart-пути **откачены в 1.5.6**; восстановлено в **1.5.7**.)

### Управление пользователем

- **Переключатель в Настройках** рядом с nickname / username — напр. «Запомнить пароль на этом устройстве» (**default ВЫКЛ**, только opt-in).
- **Выкл** (default): как сегодня — пароль очищается при logout и на путях wipe при истечении сессии (`neptun_password` в `flutter_secure_storage`, `DataCache`, `lib/storage.dart`).
- **Вкл:** хранить пароль в secure storage (`neptun_password`) после конца сессии **пока** пользователь не выключит toggle или не сделает **ручной logout** (рекомендация: при ручном logout **всё равно** стирать пароль для ясного «выйти = выйти»).

### Связь с 2FA и silent re-auth

- **2FA автоматизировать нельзя** — без seed TOTP, без обхода ELTE Login2FA.
- Сохранённый пароль — **только удобство** после смерти refresh или долгого фона: pre-fill поля login; **TOTP** пользователь вводит, когда ELTE требует Login2FA.
- **Не** меняет `trySilentReauth()` (**false** для ELTE), пока отдельное продуктовое решение не добавит re-login по паролю **с** обязательным UI 2FA — вне scope здесь.

### Взаимодействие с политикой (wall-clock снят в 1.5.6)

- Конец сессии по провалу токенов **не** удаляет `neptun_password` при opt-in — только токены / auth flags; пароль для следующего входа.
- Описано в TECHNICAL: `sessionWipeKeepCache(wipePassword:)` и матрица `SessionGuard` (ручной logout vs expiry).

### Компромиссы безопасности (копия в Настройках или privacy)

| Тема | Заметки |
|------|---------|
| **Украденный разблокированный телефон** | Пароль в secure storage доступен при доступе к устройству — только opt-in. |
| **MITM** | Уже в документации login; сохранённый пароль не ухудшает transport при официальных endpoint ELTE — всё равно ценный секрет на устройстве. |
| **Общее устройство** | Default ВЫКЛ; предупреждение в описании toggle. |
| **Ручной logout** | Очищать пароль (рекомендуется), даже если toggle был вкл. |

---

## Ограничения ELTE

- На портале **нет** «запомнить устройство» для пропуска 2FA при следующих входах (подтверждено пользователем).
- Maintenance только продлевает **уже выданный** refresh после успешного login + 2FA.

---

## Честность / риски

| Тема | Риск |
|------|------|
| **TTL refresh JWT** | Неизвестен до live-декода `exp` (или документации сервера). Позже можно добавить парсинг `exp` — **не** обязательно для v1. |
| **Rate limits** | ELTE / hallgato могут ограничивать частые `GetNewTokens`; интервал 3–4 мин — компромисс; в тестах смотреть 429 / ошибки. |
| **Длина сессии на устройстве** | Без wall-clock пользователь дольше «в системе», пока жив refresh или не вышел вручную. |
| **Фон** | При default в Настройках refresh в убитом процессе невозможен; опциональный фон — best-effort и с defer ОС — TOTP после долгого отсутствия возможен. |
| **Опциональный фон** | Батарея, отмена задач, нагрузка на ELTE при агрессивных интервалах — см. [Опциональный фоновый keep-alive](#опциональный-фоновый-keep-alive-настройки-по-умолчанию-выкл). |
| **Активность portal / HWEB** | Непроверенная польза; rate limits / policy — только исследование. |
| **Безопасность** | Refresh в secure storage остаётся ценным. **Ядро v1** не хранит пароль для silent ELTE re-login. **Опциональное** сохранение пароля (opt-in) усиливает риск компрометации устройства — см. [Опциональное сохранение пароля](#опциональное-сохранение-пароля-в-настройках-opt-in-по-умолчанию-выкл). |

---

## Вне scope (ядро v1)

**Ядро v1** = foreground **3–4 мин** `GetNewTokens` + снятие wall-clock + cold start по токенам. **Не** требовать для ядра v1:

- Auto-2FA / сохранённый seed TOTP
- **Включённый по умолчанию** фоновый keep-alive (опциональный toggle отгружен **1.5.7**, default off — [Опциональный фоновый keep-alive](#опциональный-фоновый-keep-alive-настройки-по-умолчанию-выкл))
- **Включённое по умолчанию** сохранение пароля (opt-in отгружен **1.5.7**, default off — [Опциональное сохранение пароля](#опциональное-сохранение-пароля-в-настройках-opt-in-по-умолчанию-выкл))
- Production «activity» portal / HWEB без sign-off исследования — [Активность портала / HWEB](#активность-портала--hweb-исследование--опционально-ниже-приоритет)

---

## Чеклист реализации

1. **Парность документов** — **готово (1.5.6)** — EN + RU план + TECHNICAL + DEV_BLOG.
2. **Helper проактивного refresh** — **готово (1.5.6)** — `_APIRequest._attemptTokenRefresh()` + `runForegroundTokenMaintenance()`.
3. **Планировщик foreground** — **готово (1.5.6)** — `HomePage` periodic timer + lifecycle pause/resume.
4. **Снять wall-clock** — **готово (1.5.6)** — сняты wall-clock API и enforce `SESSION_StartedAtMs`; `markParticipantSessionStarted` для post-login grace.
5. **Post-login grace** — **готово (1.5.6)** — ~45 с в `ensureValidSession`.
6. **Cold start** — **готово (1.5.6)** — gate по токенам (startup `GetNewTokens` — будущее).
7. **Тексты для пользователя** — **готово (1.5.6)** — `auth_sessionExpired_PleaseSignIn` для мёртвого refresh.
8. **TECHNICAL + DEV_BLOG + таблица честности** — **готово (1.5.6)** — версия **1.5.6**, тег **v1.5.6**.
9. **Ручная матрица тестов** — **не автоматизировано** — foreground 20+ min; фон 30+ min; kill с живым/мёртвым refresh; offline на тике.
10. **Регрессия виджетов** — **без изменений** — кэш-only, без JWT.
11. **Настройки — фоновый keep-alive** — **готово (1.5.7)** — `SETTING_BackgroundHallgatoKeepAlive`, строки, default **выкл**; `HallgatoBackgroundKeepAlive.syncScheduledTasks()` регистрирует WorkManager / iOS fetch только при вкл + login.
12. **Выбор фонового плагина** — **готово (1.5.7)** — Android `workmanager` **15 мин**; iOS `background_fetch` **15+ мин**; TECHNICAL § Session recovery.
13. **Политика батареи / ELTE** — **готово (1.5.7)** — консервативный фон; общий `GetNewTokens` + mutex; без дублирующего timer при `resumed`.
14. **Настройки — сохранение пароля** — **готово (1.5.7)** — toggle (`SETTING_RememberPasswordOnDevice`, default **выкл**); `sessionWipeKeepCache(wipePassword:)` + матрица `SessionGuard` (ручной / expiry / cold-start); pre-fill входа; строки EN/HU/RU. (**1.5.6** откатил Dart; восстановлено в **1.5.7**.)
15. **Store / manifest** — **готово (1.5.7)** — iOS `UIBackgroundModes` = `fetch` для опционального фона; Android WorkManager при toggle on.
16. **Исследование portal / HWEB** — при продолжении: spike с HAR, endpoints, pass/fail до user-facing «activity»; приоритет ниже шагов 2–10.

---

## Багфиксы — почта + календарь (отгружено 1.5.6)

**Статус:** **отгружено в 1.5.6** (тот же тег, что session v1 core). `SessionGuard` для этих пунктов не менялся.

### 1. Почта — дата эпохи и плейсхолдеры `ERROR` при cold entry — **отгружено (1.5.6)**

**Было (симптом):**

1. Cold start (или возврат после kill), при необходимости войти.
2. Открыть нижнюю вкладку **Mail / Сообщения** без pull-to-refresh.
3. В списке дата **1970. january. 1.** (Unix epoch) и строки с темой / отправителем / превью **`ERROR`** (скриншот пользователя, сентябрь 2026).
4. **Pull-to-refresh** (или принудительная перезагрузка почты) → появляются реальные темы, отправители и даты.

**Ожидание:** Первый кадр на Mail — кэш писем или loading/empty, а не sentinel `ERROR` и epoch.

**Подсказки для расследования (только чтение):**

| Область | Где |
|---------|-----|
| Fetch + early return при «свежем» кэше 24 ч | `HomePageState.fetchMails` — `lib/Pages/main_page.dart` |
| Загрузка кэша: `ERROR` + `sendDateMs: 0` до `fillWithExisting` | там же, `loadMailCache()` |
| Persist | `CachedMails_*`, `MailCacheTime`, `DataCache.getHasCachedMail()` — `lib/storage.dart` |
| Parse / модель | `api.MailEntry`, `MailRequest.getMails` — `lib/API/api_coms.dart` |
| UI списка | `lib/MailElements/mail_element_widget.dart` |

**Вероятные причины:**

- **Устаревший/битый кэш** при «свежем» `MailCacheTime` (< 24 ч) → `fetchMails` выходит **без** сети.
- **Сбой `fillWithExisting`** → остаются `ERROR` и **`sendDateMs == 0`** → UI показывает 1970-01-01.
- **Порядок при cold start:** вкладка Mail до готовности auth/сети; refresh с `force` потом успешен.

**Отгруженный фикс:** `fetchMails` / `loadMailCache()` в `lib/Pages/main_page.dart` — `_cachedMailEntryValid()` пропускает битые строки (`ERROR`, пустой ID, `sendDateMs <= 0`); частично невалидный кэш сбрасывает `HasCachedMail`, чтобы «свежий» 24 ч timestamp не блокировал сеть на cold Mail.

---

### 2. Календарь — заголовок education week и подпись «classes this week» — **отгружено (1.5.6)**

**Было (симптом):**

1. Вкладка **Calendar**.
2. Навигатор недели: **`3. education week`** (в EN строка с lowercase).
3. Подпись **`Classes this week: september 14. - september 18.`** с неудачным переносом (**`september 18.`** на второй строке), месяцы lowercase, точки после чисел — выглядит сломанным (скриншот, сентябрь 2026).

**Ожидание:** Читаемый заголовок недели и диапазон дат в одну строку (или осознанный wrap); capitalization и формат по локали; layout без «осиротевшей» части диапазона.

**Подсказки (только чтение):**

| Область | Где |
|---------|-----|
| Строки `calendarPage_weekNav_*` | `lib/language.dart` (+ RU/TR JSON) |
| Сборка подписи | `WeekoffseterElementWidget` — `lib/TimetableElements/timetable_element_widget.dart` |
| Номер education week | логика недели в `HomePageState` — `lib/Pages/main_page.dart` |
| Имена месяцев | `api.Generic.monthToText` — `lib/API/api_coms.dart` |

**Вероятные причины:**

- **Layout:** `EmojiRichText` без ограничений ширины → плохой wrap.
- **i18n:** шаблон EN + `monthToText` → lowercase и `%1.`; возможно нужен `DateFormat`.
- **Отдельно** от настройки номера недели (`szorgalmi`) — здесь **UI + форматирование**.

**Отгруженный фикс:** layout `WeekoffseterElementWidget` + строки `calendarPage_weekNav_*` (`lib/TimetableElements/timetable_element_widget.dart`, `lib/language.dart`, RU/TR JSON); заголовок education week и диапазон дат в подписи. **1.5.8** — одна карточка + фикс EN `${to.day}` в `calendarWeekDateRange` (`lib/API/api_coms.dart`).

---

## Ссылки (код сегодня)

| Область | Расположение |
|---------|--------------|
| `SessionGuard`, wall-clock | `lib/API/api_coms.dart` |
| `tryTokenRefresh`, `ensureValidSession` | `lib/API/api_coms.dart` (`_APIRequest`) |
| Cold start gate | `SessionGuard.isColdStartSessionUsable()`, `lib/Pages/startup_page.dart` |
| Lifecycle observer | `lib/Pages/main_page.dart` (`HomePage`) |
| Хранение токенов | `lib/storage.dart` (`DataCache`) |
| Login → Home stamp | `SetupPage` → `markParticipantSessionStarted()` (до `navigateToHomeRoot`) |

---

*Обновлено: 16 сентября 2026.*
