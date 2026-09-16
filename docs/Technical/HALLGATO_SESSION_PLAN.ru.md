# Поддержка сессии hallgato — план (дизайн)

**Статус:** только дизайн / план — **в коде приложения не реализовано** (на **16 сентября 2026**).  
**Владелец:** Nanda.  
**Каноническая пара:** [HALLGATO_SESSION_PLAN.md](HALLGATO_SESSION_PLAN.md) (EN).

> Факты о текущей отгрузке: [TECHNICAL.ru.md — восстановление сессии и wall-clock](TECHNICAL.ru.md#session-recovery-and-wall-clock), [§ Auth, 2FA, tokens](TECHNICAL.ru.md#9-auth-2fa-tokens).

---

## Цель

Сократить число полных входов (**пароль + TOTP**), оставаясь в JWT-сессии **hallgato** при обычном использовании приложения.

- **Полный вход** = пароль ELTE portal + интерактивный 6-значный TOTP (на ELTE **нет** «запомнить устройство» — подтверждено пользователем).
- **Поддержка сессии** = обновление access (и при необходимости refresh) через существующий hallgato API, без имитации активности портала.

---

## Текущее поведение в отгрузке (честность)

Пока план не реализован, приложение по-прежнему:

| Механизм | Поведение |
|----------|-----------|
| **10-минутный wall-clock** | `SessionGuard.sessionWallClockLimit` — принудительный выход от **начала participant-сессии**, независимо от refresh JWT (`lib/API/api_coms.dart`, `SessionGuard`). |
| **Реактивный refresh** | При **401/403** на **GET** — `_APIRequest.ensureValidSession()` → `tryTokenRefresh()` (`POST /api/Account/GetNewTokens`) → для ELTE `trySilentReauth()` (**всегда false**) → `forceExpiredLogout`. |
| **Lifecycle на переднем плане** | `HomePage` (`lib/Pages/main_page.dart`) следит за lifecycle для **wall-clock**, не для проактивного refresh токена. |
| **Фон / убийство процесса** | Периодических вызовов hallgato нет. Виджеты: только кэш, **без JWT** (без изменений). |
| **JWT `exp`** | Клиент **не** декодирует `exp`; срок access ~10–15 мин — **наблюдение**, не декодирование. |

**Запланированная смена политики (не отгружено):** убрать клиентский **10-минутный wall-clock**. Сессия заканчивается при **ручном выходе** или **провале токенов** (мёртвый refresh / ошибка `GetNewTokens`), а не по произвольному таймеру.

---

## Целевое поведение — приложение открыто (foreground)

### Интервал

Пока приложение в **`AppLifecycleState.resumed`**, проактивная поддержка каждые **3–4 минуты** (в реализации зафиксировать один интервал, например **3 мин 30 с**, или jitter 3–4 мин — константу описать в комментариях кода).

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

**Точка интеграции:** тот же `WidgetsBindingObserver`, что и для wall-clock на `HomePage` — при миграции заменить или временно сосуществовать (конечное состояние — без wall-clock).

### Ошибки (foreground)

| Исход | Планируемый UX |
|-------|----------------|
| `GetNewTokens` **200** с токенами | Продолжить; сбросить расписание maintenance |
| **401/403** или пустые токены | Refresh мёртв → `SessionGuard.forceExpiredLogout` (логин + кэш сохраняются) → вход + TOTP |
| Сеть / timeout | **Не** logout сразу; повтор на следующем тике; GET 401 path остаётся запасным |
| Параллельный refresh | Уважать `_isRefreshingToken` / lock в `_APIRequest` — maintenance не должен конфликтовать с реактивным refresh |

---

## Целевое поведение — закрыто / долгий фон

- **Нет** периодических запросов, пока isolate Flutter не работает (WorkManager / background_fetch для keep-alive **не** в **v1** плана).
- Долгий фон: refresh на сервере может протухнуть; при возврате может понадобиться полный вход — **допустимо**; без фонового исполнения keep-alive не гарантируется.

### Cold start (после реализации плана)

Предполагается снятие wall-clock и токены в `flutter_secure_storage` (`DataCache`).

| Ситуация | Ожидаемый поток |
|----------|-----------------|
| **Access ещё валиден** (токен есть; GET принимаются) | `Splitter` / `startup_page.dart` → Home; обычные GET с Bearer access |
| **Access истёк, refresh жив** | Опционально `GetNewTokens` при старте **или** первый GET 401 → `ensureValidSession()` → Home без TOTP |
| **Refresh мёртв или нет** | Wipe auth существующими путями → экран входа → **пароль + TOTP** |
| **Нет `HasLogin` / токенов** | Экран входа |

**Сегодня на cold start:** `SessionGuard.isColdStartSessionUsable()` также отклоняет сессию при истёкшем **10-минутном wall-clock** — эту проверку нужно **убрать** вместе с политикой wall-clock.

**Виджеты:** без изменений — только кэш календаря; **без JWT** в расширениях.

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
| **Фон** | Пока процесс мёртв, refresh невозможен; после долгого отсутствия может понадобиться TOTP. |
| **Безопасность** | Refresh в secure storage остаётся ценным активом; maintenance **не** хранит пароль для silent ELTE re-login (и не должен). |

---

## Вне scope v1

**Не** включать в критерии отгрузки v1:

- Auto-2FA / сохранённый seed TOTP
- Фоновый **WorkManager** / `background_fetch` для keep-alive
- Фейковая активность портала / HWEB

**Заметка на будущее:** фоновый refresh мог бы реже требовать TOTP, но добавляет политику ОС, батарею и security review — отложить без запроса продукта.

---

## Чеклист реализации (будущая разработка)

Только нумерованные шаги — **код в этой задаче не пишем**.

1. **Парность документов** — при отгрузке обновлять EN + RU план и указатели в TECHNICAL.
2. **Helper проактивного refresh** — вынести или обернуть `tryTokenRefresh()` (`lib/API/api_coms.dart`, `_APIRequest`) для maintenance (учитывать `_isRefreshingToken`, `SessionGuard.isAuthBlocked`).
3. **Планировщик foreground** — в `HomePage` (`lib/Pages/main_page.dart`) или отдельный модуль: `Timer` / `periodic` каждые **3–4 мин** только при `AppLifecycleState.resumed`; отмена в фоне (как у wall-clock observer).
4. **Снять wall-clock** — убрать или обойти `SessionGuard.sessionWallClockLimit`, `startSessionWallClock`, `checkSessionWallClockOnResume`, enforce `SESSION_StartedAtMs`, ветку wall-clock в `isColdStartSessionUsable()`; `markParticipantSessionStarted` оставить только если нужен для post-login grace.
5. **Post-login grace** — пересмотреть `_postLoginGrace` (~45 с) в путях `ensureValidSession` после снятия wall-clock.
6. **Cold start** — обновить `startup_page.dart` / `isColdStartSessionUsable()`: gate по токенам + опциональный startup `GetNewTokens`, не 10-мин stamp.
7. **Тексты для пользователя** — `auth_sessionExpired_PleaseSignIn` для «refresh мёртв»; убрать messaging, завязанный на wall-clock.
8. **TECHNICAL + DEV_BLOG + таблица честности** — описать политику JWT-maintenance; bump маркетинговой версии только при отгрузке пользователям (Android APK → новый tag по правилам репо).
9. **Ручная матрица тестов** — foreground 20+ мин без TOTP; фон 30+ мин; kill с живым refresh; kill с мёртвым refresh; offline на тике maintenance.
10. **Регрессия виджетов** — кэш-only, без JWT.

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
