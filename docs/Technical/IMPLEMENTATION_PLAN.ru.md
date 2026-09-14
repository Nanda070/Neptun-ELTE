# Neptun ELTE — план реализации

> 🇬🇧 [English](IMPLEMENTATION_PLAN.md) (те же факты; эта версия — более подробный пользовательский план)

**Владелец / разработчик:** **Nanda** (полное юридическое имя — только в Legal).  
**Продукт:** Neptun ELTE — неофициальный мобильный клиент ELTE Neptun. Не мультивуз.

Это **только план**. Появление файла в репозитории **не** означает, что пункты уже сделаны.

Последняя сверка с кодом: **сентябрь 2026**. Источники: `lib/`**, `[TECHNICAL.ru.md](TECHNICAL.ru.md)`, `[DEV_BLOG.ru.md](DEV_BLOG.ru.md)`. Инвентарь HAR §4.2 по захватам пользователя 2026-09-13 (неполно).


|                      |                                                                                                                                                                                                                                |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Статус**           | Foundation **1a / 1b / 1c / 1 / 2 / 3** + почта п. **4** + платежи п. **7 сделан** (сен 2026). Пункты **5–6, 8–14** ещё в бэклоге                                                                                                                                                   |
| **Релиз**            | Текущая маркетинговая версия **1.3.4** (`pubspec` **1.3.4+1**). Feature-line **3** = пункты плана **1–3**; патч **4** = поиск почты + фильтр непрочитанных (п. **4**). **1.3.3** = фикс мгновенного «сессия истекла» после 2FA. Следующий крупный блок → **1.4.0**; финал → **2.0.0**. Для пользователя / Settings / docs — только три числа, без рекламы `+build`. См. [TECHNICAL § Версионирование](TECHNICAL.ru.md#версионирование). |
| **Порядок**          | Делать строго по номерам групп. Поздние фичи опираются на честность (**1a** повторный вход после logout, **1b** wall-clock в фоне, **1c** nav IA, сессия, кэш, формула зачётки, `messageId`).                                                                            |
| **Живой логин ELTE** | В коде есть путь portal + TOTP + OuterLogin. Считать **working MVP, не исчерпывающе перепроверено** на всех устройствах. Email OTP известен по HAR, UI тонкий. Если Student web **full** — мост падает даже после верного 2FA. |
| **Только после HAR** | **Граф tanterv / Academic Progress** всё ещё закрыт (нет XHR учебного плана). **QR / номер / срок студенческого** не сняты. **Банк + заявка на карту (NEK/FIR) + имена полей профиля** сняты 2026-09-13 (неполно — кликнуты не все кнопки). Запись на экзамен / курс **не планируем**. |


Продуктовый README: `[docs/README.ru.md](../README.ru.md)`. Техническая карта: `[TECHNICAL.ru.md](TECHNICAL.ru.md)`. Дневник: `[DEV_BLOG.ru.md](DEV_BLOG.ru.md)`.

---



## Оглавление

1. [Честность и инварианты](#1-честность-и-инварианты) — [Navigation IA (план)](#navigation-ia-план)
2. [Группы приоритета (в этом порядке)](#2-группы-приоритета-в-этом-порядке)
3. [Работы 1a–1c + 1–14](#3-работы-1a1c--114)
4. [Как снять HAR (пошагово)](#4-как-снять-har-пошагово) — [§4.2 снятый инвентарь](#42-снятый-инвентарь-неполно--2026-09-13) — [§4.3 живой Chrome](#43-живой-проход-chrome-тот-же-день-вход-на-hallgaton)
5. [Шаблоны для агентов](#5-шаблоны-для-агентов)
6. [Что уже есть в коде (шпаргалка)](#6-что-уже-есть-в-коде-шпаргалка)

---



## 1. Честность и инварианты

Пишем то, что код **реально** делает.


| Утверждение              | Как в репозитории                                                                                                                                                                                                                                                                                    |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Нижняя навигация после входа | **Сделано (1c):** **4** нижние вкладки через `HomePage` + `BottomNavigatorWidget` — Calendar, Markbook, Periods, Mail. **Payments** в левом drawer **над Settings** (индекс 4). Contacts + версия приложения внизу Settings. Макеты Figma могут ещё показывать 5; **в приложении IA — 4 + drawer**. |
| Сессия                   | `SessionGuard` (`lib/API/api_coms.dart`): **10-минутный** wall-clock с входа в `HomePage` → `forceExpiredLogout` (foreground `Timer` + сохранённый `SESSION_StartedAtMs` на resume — **1b**). Refresh JWT **не** продлевает. 401 + провал `GetNewTokens` тоже выкидывают. Логин сохраняется; пароль/JWT стираются; **учебный кэш сохраняется** (`sessionWipeKeepCache` — **1**). **Тихого portal re-auth нет**. Wipe на logout: portal Logout best-effort, jar + 2FA/antiforgery, `devicecookie_*`, кэш training id, ужесточённый `_looksLikeInvalidCredentials` (**1a** сделан). |
| Кэш                      | `DataCache` (`lib/storage.dart`). **Все home-поверхности**: сначала кэш, потом тихий refresh (**1**). Баннер `cache_showingFromCache` при stale/offline. Зачётка / платежи / периоды / почта: TTL 24 ч. Пустые недели календаря кэшируются как `len == 0`. |
| Цифры зачётки            | **Átlag** = `Σ(оценка × кредит) / Σ(кредит)` по сданным с `grade >= 2`. **/30** = `Σ(оценка × кредит) / 30` (подпись `/30`, ösztöndíj как уточнение) — **не** «átlag ÷ 30». Общий `MarkbookMath` (**2**). Ghost — те же формулы. |
| Кредиты в шапке          | Кредиты **текущего семестра** **и** накопленные сданные (дедуп `subjectCode` через `getGradeHistoryAcrossTerms`). Официальный диплом / KKI **не** показываем. |
| Неделя                   | `GetCalendarEvents` **пн 00:00 – вс 23:59:59**. События вне окна отбрасываются. Баннеры периодов (`eventType == 6`) не в днях, а в полосе.                                                                                                                                                           |
| ICS                      | **Импорт** есть (`lib/API/ics_calendar.dart`, `SetupPageCalendarLogin`). Кнопки на хабе **нет**. **Экспорта нет.**                                                                                                                                                                                   |
| Почта                    | Входящие + страницы по 20 + счётчик непрочитанных + пометка прочитанным + перевод HU→EN/RU. **Локальный поиск** (тема / отправитель / загруженное тело) + **чип непрочитанных** (клиент). `filterType=0` остаётся зашитым (честность HAR — серверного unread-фильтра нет).                                                                                                                                |
| Платежи                  | `totalMoney` = сумма **оплаченных исходящих** (`completed && ammount < 0`) из **последних 50** `GetStudentPreviousTransactions`. Шапка: «Оплаченные взносы (последние 50)». Стипендии / входящие не входят. Collective invoices — отдельный список / баланс в drawer. Нотификации: **≤ 1/день** (ближайший неоплаченный; переназначается при setup). Без fan-out по `daysRemaining` / без 32 без даты. |
| Карты                    | Коды `LD`/`LE`/`LK` **расшифровываются в приложении**. **Ссылки в карты нет.**                                                                                                                                                                                                                       |
| Tanterv                  | `URLs.CURRICULUMS_URL = "/api/GetCurriculums"` — на живом HWEB **404** (старый MobileService). Отдельного меню **Tanterv нет**. Прогресс: **Studies → Advancement**. `GetStudentCurriculumTemplates` и `creditprogress` в этом семестре **пустые**. Официальные *подписи* средних — `RegistrySheet/GetStudentTrainingTermData`. `SubjectApplication/Curriculum` — выпадающий список записи (видно, не планируем). |
| Запись на экзамен / курс | **В приложении нет. Не планируем.** Не возвращать UI vizsgajelentkezés / tárgyjelentkezés. XHR записи в `finances.har` — **видно, но не планируем**. |
| Студенческий             | **В приложении нет.** HAR 2026-09-13: известны **заявка / NEK / FIR** + **банк** + поля **профиля**. **Нет QR, номера карты, срока.** |
| Виджеты на рабочем столе | **Удалены** (был stub). Нативный эпик — в конце.                                                                                                                                                                                                                                                     |
| Живой логин              | Portal `Login` → `Login2FA` (TOTP) → `ToNeptunHWeb` → `OuterLogin` JWT на выданном `hallgatoN`. **N не хардкодить.** Email OTP (`RequestEmailCode` / `CodePrefix`) — HAR есть, UI тонкий.                                                                                                            |


**Не ломать:** хаб ELTE, TOTP (popup 9), кэш-сначала у календаря, тап-расшифровку аудитории, LanguagePack HU+EN и JSON RU/TR. **1c сделан** — снизу **4** (Calendar \| Markbook \| Periods \| Mail); Payments только в drawer (**не** возвращать Payments на нижнюю панель).

### Navigation IA (**1c сделан**)

**Одной строкой:** снизу = **Calendar \| Markbook \| Periods \| Mail**; в drawer **над Settings** = **Payments** (плюс уже существующие профиль / баланс / training / и т.д.). Contacts + версия — внизу Settings.

| Поверхность | Код |
|-------------|-----|
| Нижний nav | **4 вкладки:** Calendar, Markbook (Subjects), Periods, Mail / Messages |
| Левый drawer | Профиль, баланс, training, **Payments** (над Settings), Settings, … |
| Settings | … существующие переключатели; **Contacts** + маркетинговая версия (`1.3.4`, без `+build`) внизу |

Не возвращать Payments на нижнюю панель.

---

## 2. Группы приоритета (в этом порядке)

Поздние задачи дешевле, если сначала закрыть фундамент.

### Фундамент (делать первым)


| №   | Работа                                    | Зачем так рано                                                                                                |
| --- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 1a  | После logout — ложные неверные данные     | **СДЕЛАНО** (сент. 2026). Повторный вход в том же процессе — **до** полировки UX сессии (п. 1).                |
| 1b  | Фон ≥10 мин → принудительный выход        | **СДЕЛАНО** (сент. 2026). Wall-clock переживает suspend; timestamp + resume.                                  |
| 1c  | Nav IA: 4 вкладки снизу + Payments в drawer; Contacts/версия в Settings | **СДЕЛАНО** (сент. 2026). Структура UI **до** полировки полос на вкладках. |
| 1   | Честность сессии и кэша                   | **СДЕЛАНО** (сент. 2026). Кэш при expiry; cache-first + баннер.                     |
| 2   | Честная зачётка                           | **СДЕЛАНО** (сент. 2026). Подписи `/30` + накопленные кредиты + `MarkbookMath`. |
| 3   | Чистые данные календаря                   | **СДЕЛАНО** (сент. 2026). Полосы/сортировка; пустые недели; без bleed периодов.   |




### Потом почта


| №   | Работа                       | Почему после фундамента                                                             |
| --- | ---------------------------- | ----------------------------------------------------------------------------------- |
| 4   | Поиск и фильтр непрочитанных | **СДЕЛАНО** (сен 2026). Локальный поиск + чип unread; `filterType=0` без изменений. |




### Потом параллельные ветки (после 1–4)


| №   | Работа                                                            | Гейт                                             |
| --- | ----------------------------------------------------------------- | ------------------------------------------------ |
| 5   | Ghost / what-if                                                   | Та же формула, что в п. 2                        |
| 6   | Сегодня + полоса ZH/дедлайны + ICS **export** + гранулярность пар | После п. 3                                       |
| 7   | Точность `totalMoney` + антиспам платёжных нотификаций            | **DONE** (сен 2026). Оплаченные исходящие + подпись «последние 50»; ≤1/день |
| 8   | Deep-link карт на LD/LE/LK                                        | После полировки календаря; `elte_room_code.dart` |
| 9   | «Что изменилось» (простое)                                        | **После** сессии/кэша **и** почтовых id (п. 4)   |
| 10  | Сравнение семестров                                               | **После** честной зачётки (п. 2)                 |
| 11  | Academic Progress                                                 | **Всё ещё закрыт** — в HAR сент. 2026 нет графа tanterv |
| 12  | Студенческий                                                      | Имена полей заявки / банка / профиля **сняты**; QR / номер / срок **нет** |
| 13  | App shortcuts                                                     | После UX сессии и deep-link (п. 1, 8)            |
| 14  | Виджеты                                                           | **Последними** — нативный Android/iOS эпик       |


---



## 3. Работы 1a–1c + 1–14

### 1a. После logout — ложные «неверные данные» (тот же процесс) — **СДЕЛАНО**

- **Зачем / Why**  
  После выхода сразу же вход с **верным** паролем показывает **неверные данные**, пока пользователь не убьёт и не откроет приложение заново. Это баг сессии/logout, не неверный пароль. Блокирует всю дальнейшую полировку сессии (кэш при истечении, refresh после входа). Раньше в доках писали, что cookie jar портала очищается при выходе; **этот wipe уже в коде** (`resetEltePortalState` + `_elteCookies.clear()`), и логин чистит jar ещё раз — **репро всё равно есть без перезапуска процесса**. Значит, остаётся состояние, которое текущий wipe не снимает (или классификатор, который считает 200 от leftover-сессии неверным паролем).

- **Зависит от / Depends on**  
  Ни от чего. Делать **до** п. 1 (честность сессии и кэша / полировка UX).

- **Уже есть в коде / Already in code**  
  - `SessionGuard.userInitiatedLogout` / `forceExpiredLogout`: `resetEltePortalState()` затем `DataCache.dataWipe()` (`lib/API/api_coms.dart`).  
  - `resetEltePortalState()`: `_elteCookies.clear()`, `_elteClearPortal2fa()` (ключ 2FA, NeptunCode, **antiforgery**, Rendered, email prefix).  
  - `dataWipe()`: `prefs.clear()`, удаляет из secure storage `neptun_password` / `neptun_jwt_token` / `neptun_refresh_token`, `_localWipe()` (`HasLogin`, URL института, training id, токены в памяти), **логин сохраняется**.  
  - Логин: `setup_page.dart` вызывает `resetEltePortalState()` + `clearAuthBlock()`; `_tryEltePortalLogin` снова чистит jar, GET `/Account/Login`, POST `LoginName` + `Password` + `__RequestVerificationToken`.  
  - Голое поле `LoginName` в теле 200 **не** считается неверным паролем (комментарий: Bug B / CSRF). Invalid — `_looksLikeInvalidCredentials` (подстрока `invalid` / `hibás` / `érvénytelen`, или 401/403) либо строки validation-summary.  
  - **Сегодня не стирается:** `devicecookie_${USER}` в FlutterSecureStorage; `CalendarRequest._cachedTrainingIds`; нет HTTP **portal Logout**; нет общего singleton `HttpClient` (новый `HttpClient()` на каждый `_elteSend`, `close` в `finally`) — но `HttpOverrides.global` это singleton `NeptunCerts`.

- **Что сделать / What to build**  
  1. Репро без убийства приложения: logout → тот же (или новый) верный пароль → залогировать статус POST, `Location`, был ли `_elteCookies` пуст на POST, есть ли antiforgery, какая ветка вернула `loginInvalidCredentials`.  
  2. Стереть **всё** leftover-состояние процесса и сохранённый auth при выходе (и снова в начале логина): in-memory `_elteCookies`, 2FA/antiforgery, access + refresh JWT, `HasLogin`, URL института, training id (`DataCache` + `CalendarRequest.clearTrainingIdCache()`), `devicecookie_*` в secure storage, refresh lock, флаги `SessionGuard`.  
  3. Если in-memory jar уже пуст, а ложный invalid остаётся: **POST настоящего portal logout** (или эквивалент), чтобы умерла серверная сессия; проверить, не течёт ли cookie через `HttpClient` / `HttpOverrides` на уровне платформы.  
  4. Ужесточить `_looksLikeInvalidCredentials`: **не** матчить подстроку `invalid` по всей HTML страницы логина (`is-invalid`, скрипты). Неверный пароль — только когда портал это явно сообщает. CSRF / уже-залогинен / 200 с повторной формой → busy или retry, **не** invalid credentials.  
  5. `loginInvalidCredentials` / «Invalid username or password!» **только** когда пароль реально неверный.

- **Где / Where**  
  `lib/API/api_coms.dart` (`SessionGuard`, `resetEltePortalState`, `_tryEltePortalLogin`, `_looksLikeInvalidCredentials`, `_elteSend`), `lib/storage.dart` (`dataWipe` / device cookie / training id), `lib/Pages/setup_page.dart`, вызовы logout (`lib/Misc/app_drawer.dart`, `lib/Pages/main_page.dart`).

- **Через что / Via**  
  Портал: GET/POST `/Account/Login`, опционально portal Logout. Классификатор: `_looksLikeInvalidCredentials`, `loginInvalidCredentials` vs `loginServerBusy`. Хранение: `dataWipe`, `getDeviceCookie` / `setDeviceCookie`, `clearTrainingIdCache`, `getAccessToken` / `getRefreshToken`, `HasLogin`.

- **Нужно заранее / Prerequisites**  
  Нет. Живой логин ELTE — **MVP / не исчерпывающе перепроверен**; этот пункт и есть повторная проверка logout → login **в том же процессе**.

- **Готово когда / Done when**  
  Logout → сразу вход с тем же (или новым) **верным** паролем работает **без** убийства/переоткрытия приложения. «Неверные данные» / `loginInvalidCredentials` **только** когда пароль реально неверный.

- **Не делать / Out of scope**  
  П. 1 UX кэша при истечении сессии, тихий portal re-auth, UI email OTP, смена **длительности** 10 минут (оставить 10 мин; **как** измерять — в **1b**).

---

### 1b. Фон ≥10 мин → принудительный выход (wall-clock vs замирающий Timer) — **СДЕЛАНО**

- **Зачем / Why**  
  Правило продукта: если пользователь ушёл из приложения на **10+ минут**, при возврате — принудительный выход (тот же путь, что у просроченного `SessionGuard`: стереть токены, оставить username, snackbar, экран логина). **Сегодня:** фон / свайп / блокировка **не** разлогинивают — возврат оставляет аккаунт. Причина (честно): Flutter `Timer` часто **замирает, пока процесс в фоне** на iOS/Android, поэтому `startSessionWallClock()` может никогда не сработать, если приложение не было на переднем плане эти 10 минут.

- **Зависит от / Depends on**  
  Ничего строго; рядом с **1a** / п. **1**. Не делать вид, что одного Timer достаточно для настоящего wall-clock.

- **Уже есть в коде / Already in code**  
  - `SessionGuard.sessionWallClockLimit = 10 мин`, `startSessionWallClock()` (in-memory `Timer`), `cancelSessionWallClock()`, `forceExpiredLogout()` (`lib/API/api_coms.dart`).  
  - Старт из `HomePage.initState`. Нет проверки `AppLifecycleState.resumed` против сохранённого timestamp.

- **Что сделать / What to build**  
  1. При старте сессии / входе в Home сохранить **wall-clock timestamp** (`sessionStartedAt` / epoch последней активности — prefs или secure storage).  
  2. На `AppLifecycleState.resumed` (и опционально `paused`/`inactive` для обновления last-active): если `now - sessionStartedAt >= 10 мин` → **`forceExpiredLogout`** (тот же UX, что у таймера).  
  3. Опционально отменить/перезапустить foreground `Timer` на resume на **остаток** времени — но **не** полагаться только на in-memory Timer в suspend.  
  4. Длительность **10 минут**; JWT refresh по-прежнему **не** продлевает часы.

- **Где / Where**  
  `lib/API/api_coms.dart` (`SessionGuard`), `lib/Pages/main_page.dart` (или WidgetsBindingObserver), опционально `lib/storage.dart` для ключа timestamp.

- **Через что / Via**  
  `WidgetsBindingObserver` / `AppLifecycleState`; существующий `forceExpiredLogout` + pending snackbar.

- **Нужно заранее / Prerequisites**  
  Нет. Живой логин ELTE — MVP / не исчерпывающе перепроверен.

- **Готово когда / Done when**  
  Фон **≥10 мин** → открыть приложение → выброс на логин (токены стёрты, username сохранён, snackbar). Фон **&lt;10 мин** → сессия жива. Непрерывный foreground **10 мин** по-прежнему выкидывает, как сегодня.

- **Не делать / Out of scope**  
  Менять политику «10 минут», тихий portal re-auth, OS background fetch / push для logout при полном убийстве процесса (cold start — отдельный путь через JWT / `HasLogin`).

---

### 1c. Nav IA: 4 вкладки снизу + Payments в drawer — **СДЕЛАНО**

- **Зачем / Why**  
  Целевая IA: Calendar, Markbook, Periods и Mail на нижней панели; Payments только в drawer (четыре иконки). Contacts перенесены в Settings (с версией приложения). Сделать **до** полировки полос календаря / платежей так, будто пять нижних вкладок навсегда.

- **Зависит от / Depends on**  
  Для структуры — ничего. Желательно после **1a**, чтобы logout/login снова открывал Home с новой навигацией. Сессия/кэш (**1** / **1b**) можно параллельно.

- **Уже есть в коде / Already in code**  
  - `BottomNavigatorWidget` + индекс страниц `HomePageState` 0–4: calendar, markbook, periods, mail, payments.  
  - `maxBottomNavWidgets = 4`; свайп только 0–3.  
  - `AppDrawer`: профиль, баланс, training, **Payments над Settings**, апдейт Android, logout — Periods/Contacts **не** в drawer.  
  - `SettingsPage`: лист Contacts + версия через `package_info_plus` внизу.

- **Что сделать / What to build**  
  1. Нижний nav **только:** (0) Calendar, (1) Markbook / Subjects, (2) Periods, (3) Mail / Messages.  
  2. В drawer пункт **Payments** **над Settings**; открывает существующий page widget (те же API/кэш).  
  3. Перемапить жёсткие индексы вкладок (shortcuts п. **13**, deep links, `initialIndex`).  
  4. **Не** возвращать Payments на нижнюю панель.

- **Где / Where**  
  `lib/Pages/main_page.dart`, `lib/Navigator/` bottom nav, `lib/Misc/app_drawer.dart`, `lib/Pages/settings_page.dart`, ключи языка при необходимости.

- **Через что / Via**  
  Существующие `PaymentsPageWidget` / periods widgets; `ListTile` в drawer; Contacts в Settings; навигация по индексу (named routes не обязательны).

- **Нужно заранее / Prerequisites**  
  Docs уже различают план и код (этот план + README + TECHNICAL). Figma не обязателен для ship.

- **Готово когда / Done when**  
  После входа: четыре иконки снизу; Payments из drawer над Settings; Contacts + версия внизу Settings; все пять поверхностей всё ещё работают с кэшем/API. Поведение сессии фон/foreground этим пунктом само по себе не меняется.

- **Не делать / Out of scope**  
  Редизайн содержимого Payments/Periods (п. **7** и др.), polish только в Figma, возврат Payments как нижней вкладки.

---

### 1. Честность сессии и кэша — **СДЕЛАНО**

- **Зачем / Why**  
Через 10 минут wall-clock или мёртвый JWT вызывался `forceExpiredLogout` → `DataCache.dataWipe()`. Стирались **токены и учебный кэш**. После повторного входа вкладки были пустые, пока все API не ответят. Календарь уже умел «кэш → тихий refresh». Остальные вкладки часто нет.
- **Зависит от / Depends on**  
  П. 1a (сначала должен работать повторный вход в том же процессе). Это по-прежнему фундамент UX кэша/сессии.
- **Уже есть в коде / Already in code**  
  - `SessionGuard`: `sessionWallClockLimit = 10 мин`, `startSessionWallClock()`, `cancelSessionWallClock()`, `forceExpiredLogout()`, `userInitiatedLogout()`, `registerNavigator`, `consumePendingMessage()`, `isAuthBlocked` (`lib/API/api_coms.dart`).  
  - `HomePage.initState` заводит таймер и ведёт на `Splitter` (`lib/Pages/main_page.dart`).  
  - Экран логина показывает `consumePendingMessage()` (`lib/Pages/setup_page.dart`).  
  - Refresh: `_APIRequest.ensureValidSession` → `POST /api/Account/GetNewTokens`. Тихий portal re-auth **выключен**.  
  - Календарь: `fetchCalendar(allowCache: true, silentRefreshIfOnline: true)` читает `CachedCalendar_w{weekOffset}`.  
  - Зачётка / платежи / периоды / почта: TTL 24 ч — `MarkbookCacheTime`, `PaymentsCacheTime`, `PeriodsCacheTime`, `MailCacheTime`.  
  - `dataWipe()` оставляет username; `prefs.clear()` убивает списки кэша.
- **Что сделать / What to build**  
  1. При истечении сессии **сохранять учебный кэш** (календарь, зачётка, платежи, периоды, почта, семестры, аватар). Стирать пароль, JWT, refresh, device cookie, при необходимости `HasLogin`.
  2. Каждая вкладка: **если кэш есть — сразу рисовать**; refresh в фоне; не подменять полный список пустым спиннером из-за мёртвой сессии.
  3. Невалидная сессия: snackbar `auth_sessionExpired_PleaseSignIn` + логин; кэш можно оставить **read-only** до входа (решение зафиксировать в TECHNICAL).
  4. Не начинать загрузку тела письма, деталей пары, обход всех семестров без `ensureValidSession()`.
  5. После успешного входа — тихий refresh всех home-поверхностей (календарь / зачётка / почта / платежи / периоды — будь то нижние вкладки или drawer), без обязательного pull-to-refresh.
  6. 10-минутный wall-clock **не** продлевать от JWT refresh (текущая задокументированная политика), пока продукт это не изменит явно. Вместе с **1b**, чтобы время в фоне считалось.
- **Где / Where**  
`lib/API/api_coms.dart` (`SessionGuard`, вызовы wipe), `lib/storage.dart` (`dataWipe` vs новый `sessionWipeKeepCache()`), `lib/Pages/main_page.dart` (fetch календарь/зачётка/платежи/периоды/почта), `lib/Pages/setup_page.dart`.
- **Через что / Via**  
Флаги: `HasCachedCalendar`, `HasCachedMarkbook`, `HasCachedPayments`, `HasCachedPeriods`, `HasCachedMail`.  
Ключи: `CachedCalendar_w{n}_$i`, `CachedCalendarLength`, `CachedMarkbook_$i`, `CachedPayments_$i`, `CachedPeriods_$i`, `CachedMails_$i`, `CachedMailsUnread`, `CACHED_TermsList`.  
Auth: `getAccessToken`, `getRefreshToken`, `GetNewTokens`.
- **Нужно заранее / Prerequisites**  
Нет. Живой логин ELTE по-прежнему **MVP / не исчерпывающе перепроверен**.
- **Готово когда / Done when**  
Убить JWT или подождать 10 минут **на переднем плане** (или фон ≥10 мин после **1b**) → промпт входа, логин подставлен, **прошлая неделя и зачётка на экране или мгновенно после re-login**. Режим самолёта с тёплым кэшем → ни на одной home-поверхности нет пустого спиннера.
- **Не делать / Out of scope**  
Тихий portal re-auth, полный UI email OTP, смена TTL JWT, распил монолитов.

---



### 2. Честная зачётка (átlag vs /30, накопленные кредиты) — **СДЕЛАНО**

- **Зачем / Why**  
Шапка: «кредиты в этом семестре» (все строки). Два числа с одним эмодзи: **átlag** (среднее, взвешенное кредитами) и **Σ(jegy×kredit)/30**. EN: «Average» / «Scholarship index»; HU: «Átlagod» / «Ösztöndíj indexed». Нужны явные подписи **átlag** и **/30**. Накопленные кредиты можно сложить из семестров, которые **уже качаем** — без нового HAR.
- **Зависит от / Depends on**  
П. 1 (вкладка не должна опустеть при ошибке refresh).
- **Уже есть в коде / Already in code**  
  - `MarkbookRequest.getMarkbookSubjects` → `/api/TakenSubjects`, запасной `/api/RegisteredCourses/GetRegisteredCourses`.  
  - `getRegisteredCourses`, `getGradeHistoryAcrossTerms(maxTerms: 8)`.  
  - Семестры: `/api/RegisteredCourses/GetTerms`, `/api/TakenSubjects/Terms`, `/api/Periods/GetTerms` → `CACHED_TermsList`.  
  - UI: `MarkbookPageWidget`, `MarkbookElementWidget`, `_setupMarkbook`, `_markbookCalcAvg`, `_markbookCalcGhostAvg`.  
  - Ключи: `markbookPage_AverageDisplay`, `markbookPage_AverageScholarshipDisplay`, `topheader_subjects_CreditsInSemester`, `markbook_myCourses_Header`, `markbook_gradeHistory_Header`.
- **Что сделать / What to build**  
  1. Подписи: **Átlag / Average** = `Σ(оценка × кредит) / Σ(кредит)` для сданных `grade >= 2`. **/30** = `Σ(оценка × кредит) / 30` (тот же числитель). **Не** показывать átlag÷30.
  2. «Ösztöndíj» можно оставить мелким пояснением; крупное число должно говорить **/30**.
  3. Шапка: кредиты этого семестра **и** сумма сданных кредитов из `getGradeHistoryAcrossTerms` / кэша по семестрам (дедуп по `subjectCode`).
  4. В UI и TECHNICAL явно: это **счёт приложения**, не официальный KKI/GPA с сайта. Официальный endpoint есть (`GET /api/Dashboard/GetAverages` + `GetAverageTypesDescription`: `creditIndex` / `adjustedCreditIndex` / `schoolarshipKey`), но в этом захвате `dashboardAverageItems` = **[]** — «официальный GPA» не показывать, пока HAR не принесёт заполненные items.
  5. Одна функция для ghost (п. 5), например `MarkbookMath`.
- **Где / Where**  
`lib/Pages/main_page.dart`, `lib/language.dart`, `Languages/LangExtentions/Russian.json`, `Turkish.json`, опционально `lib/Misc/markbook_math.dart`.
- **Через что / Via**  
`TakenSubjects?request.termId=`, поля `Subject`, `SELECTED_TermId`, `CACHED_TermsList`.
- **Нужно заранее / Prerequisites**  
Нет. Официальные итоги диплома / обязательные vs факультатив — п. 11 + HAR.
- **Готово когда / Done when**  
Предметы 5 кр на 5 и 3 кр на 3 дают átlag `4.25` и /30 `1.33…` ((25+9)/8 и /30), не átlag/30. Накопленные кредиты растут, если в истории других семестров уже есть сданные предметы.
- **Не делать / Out of scope**  
Грапа tanterv, официальный KKI, смена шкалы 1–5.

---



### 3. Чистые данные календаря (полосы + неделя) — **СДЕЛАНО**

- **Зачем / Why**  
Неделя и полосы уже были, но делили один `calendarEntries`. Баннеры периодов могли утечь при фильтрах; «ближайшие 48 ч» не про «сегодня»; ZH и экзамены — «первые 8 в загруженной неделе», а не реальное окно вперёд. Сначала привести данные в порядок, чтобы п. 6 был надстройкой, а не перепиской.
- **Зависит от / Depends on**  
П. 1 (кэш страниц недели).
- **Уже есть в коде / Already in code**  
  - `GET /api/Calendar/GetCalendarEvents` (`startDate`, `endDate`, `isClassesVisible`, `isExamsVisible`, `isFinalExamsVisible`, `isTasksVisible`, `isPeriodsVisible`, `studentTrainingIds[i]`).  
  - `getCalendarOneWeekJSON` — пн–вс.  
  - `CalendarEntry`: `isExam` (`eventType == 1`), `isPeriodBanner` (`== 6`), `isTask` (`> 1 && != 6`).  
  - Полосы: `calendar_next48h_Header`, `calendar_tasks_Header`, `calendar_exams_Header`, `calendar_periods_Header`.  
  - Дни: `TimetableElementWidget`, `FreedayElementWidget`, `WeekoffseterElementWidget`.  
  - Фильтры в Settings: `getDisplayClasses` / `Exams` / `Periods`.  
  - Детали: `GetCourseDetails`, `GetTaskDetail`.  
  - Аудитория: `DecodableRoomText`.
- **Что сделать / What to build**  
  1. Полосы сортировать по `startEpoch`; 48 ч = пары+экзамены (без баннеров периодов); ZH = `isTask` с `startEpoch >= now`; экзамены — ближайшие, не «первые 8 этой недели», если в неделе пусто.
  2. Колонки дней: чипы перерыва только в тот же день; не возвращать протекание следующего понедельника.
  3. Пустой день при «загружено, событий нет» = `FreedayElementWidget`, не спиннер.
  4. Баннеры периодов только в полосе периодов.
- **Где / Where**  
`lib/Pages/main_page.dart` (`_setupCalendar`, `_extraCalendarSections`, `_fillOneCalendarElement`), `lib/API/api_coms.dart`, `lib/TimetableElements/timetable_element_widget.dart`.
- **Через что / Via**  
`GetCalendarEvents`, `CachedCalendar_w{offset}`, `HasCachedCalendar`, `CalendarCacheTermId`.
- **Нужно заранее / Prerequisites**  
Нет.
- **Готово когда / Done when**  
Неделя только с понедельником не рисует «перерыв» ~163 ч. Текст периода — только в полосе периодов. Pull-to-refresh с кэшем не обнуляет неделю.
- **Не делать / Out of scope**  
ICS export (п. 6), карты (п. 8). Запись на экзамен / курс **не планируем**.

---



### 4. Поиск писем + фильтр непрочитанных — **СДЕЛАНО**

- **Зачем / Why**  
Входящие — плоский список со страницами. Непрочитанные — только **счётчик** в шапке/drawer. Поиска нет. П. 9 нужен стабильный `messageId` и способ увидеть «новые непрочитанные».
- **Зависит от / Depends on**  
П. 1 (не качать страницы 2…n на мёртвой сессии).
- **Уже есть в коде / Already in code**  
  - `GET /api/Message/GetReceivedMessages?firstRow=&lastRow=&filterType=0` (по 20).  
  - `GetUnreadedMessagesCount` → `data.count` → `CachedMailsUnread`.  
  - `setMailRead` — POST-кандидаты `SetReadedMessage` / `SetMessageAsReaded`.  
  - Тело: `GET /api/Messages/{id}/Posts`.  
  - UI: `MailsPageWidget`, `MailElementWidget` (popup 3), `MessageTranslator`.  
  - Кэш: `CachedMails_$i` (разделитель `\u0000`), `CachedMailsLength`, `MailCacheTime`.  
  - `MailEntry.ID` = `messageId`. `isRead` = `unreadedPostCount == 0`.  
  - **Сделано (п. 4):** поле поиска + `FilterChip` unread на `MailsPageWidget`; фильтр по уже загруженным страницам на клиенте; пагинация накапливает в `mailEntries`; строка поиска в логи не пишется; API по-прежнему `filterType=0`.
- **Что сделать / What to build**  
  1. Локальный поиск по **уже загруженным** страницам: тема, отправитель, опционально тело после открытия.  
  2. Чип «непрочитанные» по `MailEntry.isRead`.  
  3. HAR почты сент. 2026 по-прежнему шлёт **`filterType=0`** на inbox / archive / sent. Unread-only query не видели — **фильтр на клиенте достаточен**.  
  4. Пагинацию сохранить; поиск сначала по загруженному, дальше докачка только при валидной сессии.  
  5. Поисковые строки в логи не писать.
- **Где / Where**  
`lib/Pages/main_page.dart` (`MailsPageWidget`, `mailList`), `lib/MailElements/mail_element_widget.dart`, `lib/API/api_coms.dart` (`MailRequest`), `lib/language.dart` + RU/TR.
- **Через что / Via**  
`GetReceivedMessages`, `GetUnreadedMessagesCount`, `CachedMails_*`, `messageId`.
- **Нужно заранее / Prerequisites**  
Опциональный HAR: другие `filterType`, серверный search. Не блокер.
- **Готово когда / Done when**  
Часть имени отправителя прячет остальные строки. Фильтр unread оставляет только 📬. Офлайн + кэш фильтрует локально. **Выполнено в 1.3.4.**
- **Не делать / Out of scope**  
Написание/ответ, менеджер вложений, UI «Что изменилось» (п. 9).

---



### 5. Ghost / цель / what-if

- **Зачем / Why**  
Призрачная оценка уже двигает átlag и /30 (`_markbookCalcGhostAvg`), но UI — голый выбор 1–5 (popup 0) без «какой átlag станет» и без цели.
- **Зависит от / Depends on**  
П. 2 (общая формула и подписи).
- **Уже есть в коде / Already in code**  
  - `MarkbookElementWidget.ghostGrade` (`-1` = нет).  
  - `_mbookPopupResult` → `result + 1`.  
  - Popup mode 0: `popup_case0_GhostGradeHeader`, `popup_case0_SelectGrade`.  
  - Конфетти, когда все предметы сданы.
- **Что сделать / What to build**  
  1. Вынести `MarkbookMath.weightedAvg` и `MarkbookMath.index30`.
  2. В popup живые átlag и /30 при тапе по оценке.
  3. Опционально: «нужна оценка ≥ N на этом предмете, чтобы átlag стал X» — **только** той же формулой, без выдуманных правил стипендии.
  4. Сброс ghost уже есть (`result == -1`).
- **Где / Where**  
`lib/Misc/popup.dart` (mode 0), `lib/Pages/main_page.dart`, `lib/MarkbookElements/markbook_element_widget.dart`.
- **Через что / Via**  
Те же поля `Subject`, что в п. 2. Нового API нет.
- **Нужно заранее / Prerequisites**  
Хелпер и подписи из п. 2.
- **Готово когда / Done when**  
Ghost 5 на несданном предмете 3 кр меняет оба числа шапки так же, как если бы предмет закрыли на 5.
- **Не делать / Out of scope**  
Официальные правила стипендии, KKI с сервера.

---



### 6. Строка «сегодня» + полоса ZH/дедлайны + ICS export + гранулярность пар

- **Зачем / Why**  
Приветствие — только время суток (`topheader_calendar_greetMessage_*`). Полосы завязаны на загруженную неделю. ICS можно **ввезти**, нельзя **вывезти**. Напоминания о паре всегда 10 мин + 5 мин + старт, один тумблер в Settings.
- **Зависит от / Depends on**  
П. 3 (чистый `calendarEntries`). П. 1 (не планировать пачку нотификаций на мёртвой сессии).
- **Уже есть в коде / Already in code**  
  - Полосы 48 ч / задания / экзамены / периоды.  
  - `GetTaskDetail` для ZH-подобных задач.  
  - Импорт ICS; `file_picker` + `SetupPageCalendarLogin` (с хаба не открывается).  
  - `_setupClassesNotifications`, bucket id `1`, `SETTING_IsNeedClassNotifications`.  
  - `AppNotifications` (`lib/notifications.dart`).
- **Что сделать / What to build**  
  1. **Сегодня** в шапке календаря: следующая пара сегодня или «сегодня пар нет» из кэша недели.
  2. **Полоса ZH/дедлайны**: `isTask` (+ дедлайны экзаменов, если уже в календаре). Новые API заданий без HAR не выдумывать (§4 D).
  3. **ICS export**: `.ics` из текущих `calendarEntries` (`DTSTART`/`DTEND`/`SUMMARY`/`LOCATION`). Шер / сохранение. Это **не** импорт. Позже опционально: официальный sync URL из `GET /api/Calendar/GetLinksForCalendarExport` (`data.url` / `data.urlForWebCalendars` → `web{N}.neptun.elte.hu/api/Calendar/CalendarExportFileToSyncronization?id=`). `id` в логи не писать.
  4. **Гранулярность**: чекбоксы 10 мин / 5 мин / в начале (по умолчанию все вкл.). Пересбор через `cancelScheduledNotifsId(1)`.
- **Где / Where**  
`lib/Pages/main_page.dart`, `lib/Pages/settings_page.dart`, `lib/API/ics_calendar.dart` (export рядом с import, import не ломать), `lib/notifications.dart`, i18n.
- **Через что / Via**  
`CalendarEntry`, `CachedCalendar_*`, `SETTING_IsNeedClassNotifications` + новые ключи вроде `SETTING_ClassNotif10` / `5` / `0`.
- **Нужно заранее / Prerequisites**  
Для export/summary — нет. Email преподавателя всё ещё нет (тьюторы: `printname` / `employeeId` / `nickname` / avatar). Даты заданий вне календарных `isTask` — по-прежнему опционально.
- **Готово когда / Done when**  
Сохранённый ICS открывается в Calendar.app / Google Calendar с парами этой недели. В Settings можно выключить только 10-минутный пинг. Строка «сегодня» совпадает со списком пн–вс.
- **Не делать / Out of scope**  
Снова рекламировать ICS **import** на хабе. Запись на экзамен / курс (**не планируем**). Remote push.

---



### 7. Точность `totalMoney` + антиспам нотификаций оплаты — **DONE**

- **Зачем / Why**  
Шапка: «потратил %0 Huf». Код суммировал только `completed`, `ammount.abs()`, из **50** последних транзакций. Стипендии (+ ) и взносы (− ) в «потратил» попадали одинаково, если статус completed. Неоплаченные (`aktív`) в сумму не входят, но могли породить **по нотификации на каждый оставшийся день** (или **32**, если `dueDateMs == 0`).
- **Зависит от / Depends on**  
П. 1 (кэш списка платежей).
- **Уже есть в коде / Already in code**  
  - `/api/Transactions/GetStudentPreviousTransactions?firstRow=0&lastRow=50`.  
  - `/api/FinancialDataDashboard/GetCollectiveInvoices`.  
  - `completed`, если статус `teljesített` / `törölt` / `pénzügyileg igazolt`.  
  - `_setupPayments`, `PaymentsPageWidget`, `PaymentElementWidget`.  
  - Нотификации bucket `2`, `SETTING_IsNeedPaymentsNotifications`.
- **Что сделать / What to build**  
  1. Зафиксировать смысл `totalMoney`: **оплаченные взносы** (исходящие) vs нетто vs баланс счёта. Подпись = числу. Предпочтительно: оплаченные исходящие + отдельно баланс collective invoice в drawer (он уже есть).  
  2. Пагинация через `sortAndPage.firstRow` / `lastRow`. На сайте в захвате **`lastRow=10`**; в приложении сейчас **50**. Фильтры есть (`GetStudentPreviousTransactionsFilters`: семестры, валюты, направления, типы). Не писать «за всё время» на одной странице.  
  3. Антиспам: максимум **одно** дневное напоминание (или одно на неоплаченный счёт), не `daysRemaining` копий и не 32 дня без даты.  
  4. `aktív` / `teljesített` оставить **ключами протокола**, не переводить как UI-статус.
- **Где / Where**  
`lib/Pages/main_page.dart`, `lib/API/api_coms.dart` (`CashinRequest`), `lib/PaymentsElements/payment_element_widget.dart`, `topheader_payments_TotalMoneySpent`.
- **Через что / Via**  
`GetStudentPreviousTransactions`, `GetCollectiveInvoices`, `ACCOUNT_Balance` / `ACCOUNT_BalanceCurrency`, `CachedPayments_*`. Неоплаченные: `GET /api/FinancialItem/GetItemsToBePayed` (в этом захвате **пустой массив** + флаги `GetItemsToBePayedAdditionalData`). Детали: `GetStudentTransactionDetails?transactionId=`.
- **Нужно заранее / Prerequisites**  
Endpoint неоплаченных известен; у этого аккаунта items не было. Bonuses / Diákhitel2 в HAR есть, в приложении не используем.
- **Готово когда / Done when**  
Число в шапке совпадает с суммой **оплаченных взносов** в списке (или подпись честно говорит «нетто / 50 последних»). Включённые нотификации оплаты — **≤ 1 в день**, не десятки. **Сделано:** `totalMoney` = Σ `abs(ammount)` для **completed && ammount < 0** на загруженной странице; шапка «Оплаченные взносы (последние 50)»; `CashinRequest.previousTransactionsPageSize = 50`; нотификация — **одно** напоминание на завтра по ближайшему неоплаченному (без fan-out).
- **Не делать / Out of scope**  
Оплата внутри приложения. Банк на студенческом (п. 12).

---



### 8. Deep-link карт по LD/LE/LK

- **Зачем / Why**  
Тап уже переключает `LD-0-805` ↔ «Southern Building, Floor: 0, Room: 805». Нужна карта. `url_launcher` уже в зависимостях.
- **Зависит от / Depends on**  
Желательно п. 3 (те же места с `DecodableRoomText`). Почта не блокер.
- **Уже есть в коде / Already in code**  
  - `ElteRoomCode`, `DecodableRoomText` (`lib/Misc/elte_room_code.dart`).  
  - **LD** Déli / Southern, **LE**/LÉ Északi / Northern, **LK** химический блок (Északi). Неизвестный префикс как есть.  
  - Список пар, диалог пары, exam/legacy popup.  
  - iOS schemes: `https`, `http`, …
- **Что сделать / What to build**  
  1. После расшифровки (второй тап или иконка карты): Apple Maps / Google Maps по **зданию**, этаж/комната в строке запроса.
  2. Запросы (Lágymányos, без своих GPS в приложении):
    - LD → `ELTE Déli Tömb` / Southern Building, 1117 Budapest  
    - LE → `ELTE Északi Tömb`  
    - LK → `ELTE Kémiai tömb`
  3. Неизвестный префикс — только текст, без ложного пина.
  4. Координаты не выдумывать.
- **Где / Where**  
`lib/Misc/elte_room_code.dart`, `lib/TimetableElements/timetable_element_widget.dart`, `lib/Misc/popup.dart`.
- **Через что / Via**  
`ElteRoomCode.tryParse`, `url_launcher`, ключи `roomCode_*` + новый `roomCode_OpenMap`.
- **Нужно заранее / Prerequisites**  
Нет. Опционально сверить названия корпусов. В `information.har` есть `RoomSchedule/GetBuildings` + `GetSites` + `GetOrganizations` + `GetRoomsSchedules` (список аудиторий кампуса — для LD/LE/LK deep-link не обязателен).
- **Готово когда / Done when**  
Из `LD-0-805` открываются карты с поиском Déli Tömb. Код с неизвестным префиксом не падает и не ведёт на чужой кампус.
- **Не делать / Out of scope**  
Поэтажные планы, GPS комнаты, кампусы кроме Lágymányos.

---



### 9. «Что изменилось» (простое)

- **Зачем / Why**  
После re-login или тихого refresh нужно «2 новых письма, 1 новая оценка» — не целый Activity OS.
- **Зависит от / Depends on**  
**П. 1** (кэш переживает сессию) **и п. 4** (стабильный `messageId`, unread). Оценки: `subjectCode`+`grade` из п. 2.
- **Уже есть в коде / Already in code**  
Кэш id писем, unread, сериализация зачётки, кэш недели. UI диффа нет.
- **Что сделать / What to build**  
  1. После успешного refresh сохранить снимок: множество `messageId`, пары `(subjectCode, grade, termId)`, опционально `startEpoch` следующей пары.
  2. Drawer или полоса календаря: «N новых писем», «N изменений оценок», если дифф ≠ 0.
  3. Тап → вкладка почты с unread или зачётка.
  4. Первый запуск — без баннера (не «всё новое»).
- **Где / Where**  
`lib/storage.dart` (ключи вроде `SNAPSHOT_MailIds`), `lib/Pages/main_page.dart`, `lib/Misc/app_drawer.dart`.
- **Через что / Via**  
Существующий кэш + `MailEntry.ID` + `Subject.subjectCode`.
- **Нужно заранее / Prerequisites**  
П. 1 и 4.
- **Готово когда / Done when**  
Один новый `messageId` после refresh даёт «1 новое письмо» один раз; повторный refresh без новых писем — тишина.
- **Не делать / Out of scope**  
Push, дайджест на почту, changelog сервера Neptun.

---



### 10. Сравнение семестров

- **Зачем / Why**  
История оценок — плоский список. Сравнение = átlag + /30 + кредиты **по семестрам** рядом.
- **Зависит от / Depends on**  
**П. 2** (честная математика на семестр).
- **Уже есть в коде / Already in code**  
`getGradeHistoryAcrossTerms`, `TermsRequest.getTerms`, переключатель семестра в drawer, `markbook_gradeHistory_Header`.
- **Что сделать / What to build**  
  1. Карточки/таблица: имя семестра, сданные кредиты, átlag, /30 — **тот же хелпер, что зачётка**.
  2. Кэш `TakenSubjects` по семестрам; недостающие — только при валидной сессии.
  3. Потолок ~8 семестров, пока HAR не скажет иначе.
- **Где / Where**  
`MarkbookPageWidget`, `getGradeHistoryAcrossTerms`.
- **Через что / Via**  
`TakenSubjects?request.termId=`, `CACHED_TermsList`.
- **Нужно заранее / Prerequisites**  
П. 2. HAR tanterv не нужен.
- **Готово когда / Done when**  
Два прошлых семестра с оценками дают два разных átlag, совпадающих с переключателем семестра.
- **Не делать / Out of scope**  
PDF транскрипта, % выполнения tanterv (п. 11).

---



### 11. Academic Progress — ТОЛЬКО после живого HAR по **tanterv** (всё ещё нет)

- **Зачем / Why**  
Прогресс к диплому (обязательные / факультатив, кредиты программы) **не** выводится из одного `TakenSubjects`. `GetCurriculums` — неиспользуемая константа в стиле старого API.
- **Зависит от / Depends on**  
**HAR §4 C** — набор сент. 2026 **не закрывает** гейт. П. 1–2 для сессии и кредитов. **Не** начинать UI наугад.
- **Уже есть в коде / Already in code**  
`URLs.CURRICULUMS_URL = "/api/GetCurriculums"` — **больше нигде нет**. Модели tanterv нет.
- **Что этот захват *не* открывает**  
  - `taken courses.har` вызвал **`GetRegisteredCourses`** (+ дашборд), **не** `TakenSubjects` и **не** tanterv.  
  - `GET /api/SubjectApplication/Curriculum?subjectType=&termId=` — **выпадающий список записи** (`value` / `text` / `isActualTerm`) — **видно, но не планируем**.  
  - У предмета `SubjectCourse/GetSubjectDetails` есть `curriculumTemplateId`, `requirementType`, `credit`, `isCompleted`, `recommendedTerm`, `preRequirement` — потом пригодится, это **не** граф диплома.  
  - `GET /api/Dashboard/GetAverages` есть, но `dashboardAverageItems` был **[]** (официальный GPA **не** открыт).
- **Что сделать / What to build** (после настоящего HAR tanterv)  
  1. Вызвать **реальный** modern-путь tanterv из того HAR (это всё ещё может быть не `/api/GetCurriculums`).
  2. Обязательные / необязательные / закрытые кредиты.
  3. Простой прогресс на вкладке зачётки или в popup — **не** новая нижняя вкладка (после **1c**: всё ещё не 4-я нижняя).
- **Где / Where**  
Новый request-класс в `lib/API/api_coms.dart`, UI в `main_page.dart`.
- **Через что / Via**  
По-прежнему неизвестно. `hallgatoN` не хардкодить. `SubjectApplication/Curriculum` tanterv **не** считать.
- **Нужно заранее / Prerequisites**  
**Живой HAR tanterv** (Tanulmányok → Tanterv, раскрыть группы). Без него пункт пропускаем.
- **Готово когда / Done when**  
Цифры совпадают с экраном tanterv на сайте для того же training, на живой сессии.
- **Не делать / Out of scope**  
Фейковый прогресс-бар из кредитов текущего семестра (это ложь).

---



### 12. Студенческий — HAR снят (**неполно**): заявка / банк / профиль; **нет QR**

- **Зачем / Why**  
В drawer уже есть **имя** и **фото**. HAR сент. 2026 называют банк и поля **заявки** на карту. Они **не** дают wallet QR, номер пластика и срок. Это не выдумывать.
- **Зависит от / Depends on**  
**HAR §4 B** (профиль + administration + finances). Сессия/кэш (п. 1) до любого нового fetch.
- **Уже есть в коде / Already in code**  
`/api/UserInfo`, `/api/General/GetUserAvatar?imageSizeType=Normal`, `STUDENT_DisplayName`, `STUDENT_AvatarBase64`, `MemoryImage` в drawer.
- **Форма `/api/UserInfo`** (finances.har; значения замазаны)  
`data.userStatus` (int), `data.studentTrainingId`, `data.name` (**не** top-level `printName`), `data.neptunCode` (redact), `data.substitutePrintName`, `data.isTokenRegistered`, `data.userAvatar.{avatarType, image` (thumbnail base64 JPEG), `fallbackColorCodeInHexa, printName}`. Приложение уже делает fallback `printName` → `name`.
- **Аватар, дополнения**  
`GET /api/General/GetUserAvatar?imageSizeType=Normal` (больший JPEG; ещё `userId` для другого человека). Пакет: `GET /api/General/GetUsersAvatar?imageSizeType=Thumbnail&userIds[n]=` (почта). В профиле ещё `GetGeneralUserData.profilePicture` (размер Normal) и `UserProfile/GetDefaultAvatars` (заготовки).
- **Что сделать / What to build** (только эти поля HAR)  
  1. **Банк (только чтение):** `GetDefaultBankAccountNumber` / `GetBankAccountDetails?bankAccountId=` / `GetUserBankAccountTabList` — `bankAccountOwner`, `isDefault`, `isForeign`, `isValid`, `bankName`, `otpStatus` (флаги видимости). **Не логировать** `bankAccountNumber` / IBAN / SWIFT.  
  2. **Статус заявки на карту (не wallet):** `StudentCard/StudentCardClaimProcess` — `claimType`, `nekId` (не логировать), `firStatus` / `firStatusId`, `processStatus`, `finalDecision`, `registrationDate`, `trainingName`, `trainingFaculty`, `primaryInstituteName` / `primaryInstitutePrintCode`, `addressId`; адреса через `StudentCard/GetStudentAddress` (`address`, `addressType`). Список прошлых заявок был **[]**.  
  3. **Профиль (опционально Settings/drawer popup — не 6-я вкладка):** имена полей `PersonalData/GetGeneralUserData` (секреты в логи не писать): `printName`, `firstName`, `lastName`, `title`, `bornName*`, `bornDate`, `bornCountry`, `bornPlace`, `sex`, `loginName`, `motherName*`, `numberOfChildren`, `educationalIdentifier`, `userCitizenship[]`, `extraFields[]` (`field` / `translation` / `value` / `required` — подписи: EHA, ETR, …). `tajNumber` / `taxIdentifier` / `studentIdOnExam` здесь были **пустыми**. Контакты: `GetStudentPersonalDataContacts` (адрес / email / телефон). Документы на этом аккаунте: Passport + Permit of residence — **не** студенческий.  
  4. Офлайн: кэш фото + последние **несекретные** флаги заявки/банка.
- **Где / Where**  
`lib/Misc/app_drawer.dart`, `_persistUserInfoProfile`, новые ключи в `storage.dart`.
- **Через что / Via**  
Пути выше. `GET /api/FIR/GetStudentFIRData` вернул **HTTP 410**. QR из кода Neptun или `nekId` **не** выдумывать.
- **Нужно заранее / Prerequisites**  
Имена полей известны. Legal: персональные данные (уже Privacy). Для «карты в кошельке» всё ещё нет: payload QR, номер, сроки — **ещё клик**, если такой экран на сайте вообще есть.
- **Готово когда / Done when**  
UI показывает только снятые поля и совпадает с Saját adatok / **заявкой** на карту / банком у аккаунта захвата. Декоративного QR нет.
- **Не делать / Out of scope**  
NFC-эмуляция. Декоративная «карта» из аватара. Редактирование / POST личных или банковских данных (save XHR в этом захвате не кликали).

---



### 13. App shortcuts — после UX сессии и deep-link

- **Зачем / Why**  
Долгий тап по иконке → Календарь / Почта / Платежи имеет смысл, только если мёртвая сессия ведёт на логин (п. 1) и deep-link уже есть.
- **Зависит от / Depends on**  
П. 1. П. 8 — если будет shortcut «карта / следующая аудитория».
- **Уже есть в коде / Already in code**  
Нет `shortcuts.xml`, нет iOS `UIApplicationShortcutItems`. Навигация **по индексу вкладки**, без named routes.
- **Что сделать / What to build**  
  1. Android shortcuts + iOS Home Screen Quick Actions: календарь (низ 0), почта (низ 3), платежи (drawer индекс 4).
  2. Cold start: `Splitter` → если `HasLogin` и сессия жива → `HomePage` с индексом или drawer-маршрутом, иначе логин.
  3. Не открывать Home с мёртвым JWT и пустыми вкладками. Лучше после **1c**, чтобы индексы совпали с целевой IA.
- **Где / Where**  
`android/app/src/main/res/xml/`, `AndroidManifest.xml`, `ios/Runner/Info.plist`, `startup_page.dart`, `main_page.dart`.
- **Через что / Via**  
Intent extras / уже прописанные schemes. Свой scheme — только если без него никак.
- **Нужно заранее / Prerequisites**  
П. 1. Опционально п. 8.
- **Готово когда / Done when**  
Cold-start shortcut попадает на нужную вкладку или на логин; пустого Home нет.
- **Не делать / Out of scope**  
Siri / App Intents, виджеты Android (п. 14).

---



### 14. Виджеты — последними, нативный эпик

- **Зачем / Why**  
Виджет на рабочем столе был **заглушкой и удалён**. Настоящие виджеты — native (Glance / WidgetKit), им нужен кэш расписания **без** живого JWT и они конфликтуют с политикой 10-минутной сессии.
- **Зависит от / Depends on**  
П. 1 и 3. Лучше после п. 13.
- **Уже есть в коде / Already in code**  
Ничего. TECHNICAL: «Homescreen widget | Удалён | Был stub».
- **Что сделать / What to build**  
  1. Android + iOS: **пары сегодня** только из `CachedCalendar_w`*.
  2. Тап → приложение (deep-link п. 13).
  3. Нет кэша: «Откройте Neptun ELTE».
  4. JWT в процессе виджета не хранить.
- **Где / Where**  
Новые native-модули в `android/` и `ios/`; маленький Dart-экспорт кэша. Старый stub не воскрешать.
- **Через что / Via**  
SharedPreferences строк календаря / App Group на iOS.
- **Нужно заранее / Prerequisites**  
Native widget work, iOS App Group, id виджета Android. Legal: только локальный кэш.
- **Готово когда / Done when**  
Виджет показывает сегодняшние пары после того, как приложение один раз открыло эту неделю; протухший кэш подписан как stale.
- **Не делать / Out of scope**  
Живой опрос Neptun каждую минуту. Запись на экзамен / курс (не планируем).

---



## 4. Как снять HAR (пошагово)

HAR нужен для REST, которых **нет** в приложении. Логин в приложении — **MVP**; эти сценарии на сайте **не реализованы** и их надо снять с **веба**.

### 4.1 Общая процедура (один файл = один сценарий)

1. **Chrome** (или Edge/Firefox DevTools), лучше десктоп.
2. Открыть `https://neptun.elte.hu` → войти (Neptun ID + пароль + 2FA).
3. Открыть **Student web**. Портал выдаёт `https://hallgatoN.neptun.elte.hu` (`hallgato1`…`hallgatoN`, балансировка).
  - **N не хардкодить.** Сегодня может быть `hallgato3`, завтра `hallgato4`.  
  - В заметках писать хост как `https://hallgato{N}.neptun.elte.hu`.
4. Когда SPA загрузилась (dashboard): **DevTools → Network**.
  - Включить **Preserve log**.  
  - Фильтр **Fetch/XHR** (Document — если нужен 302 OuterLogin).  
  - Disable cache — если нужен чистый первый заход.
5. Кликать **только** меню одного таргета (**B** студенческий или **C** tanterv). Не мешать карту + tanterv в одном файле. HAR записи на экзамен / курс **не** снимать (A вне скоупа).
6. **Save as HAR**: Network → ⬇ / «Save all as HAR with content».
  - Имя: `elte-har-student-card-YYYY-MM-DD.har` или `elte-har-curriculum-YYYY-MM-DD.har`.
7. **Вычистить секреты до любой копии рядом с репо:**
  пароль, TOTP, email OTP, `GUID`, JWT `accessToken` / `refreshToken`, `Authorization: Bearer`, `Cookie`, `devicecookie-*` → `REDACTED`.
8. **Не коммитить HAR с секретами.** Лучше частная заметка или отредленный JSON: URL + method + query + форма тела + форма ответа.
9. Снимать на `hallgatoN`, не только на `neptun.elte.hu`. Cookie портала ≠ Bearer HWEB. Большинство student API — **Bearer JWT на hallgatoN** (как `GetCalendarEvents`).
10. На каждый оставленный запрос: **метод, полный URL с** `{N}`**, query, body, ключи JSON ответа, cookie vs Bearer**.

Уже известные маршруты HWEB (ориентир, не скрипт кликов): `/dashboard`, `/calendar/institutional-calendar`, `/studies`, `/messages`, `/administrations`, `/user-data`.

---

### 4.2 Снятый инвентарь (неполно) — 2026-09-13

Пользователь дал **8 HAR** (в git не копировали). **Не** нажимались все кнопки на всех страницах. **Отсутствующие POST** (save, оплата, отправка письма, submit заявки, запись) — **ожидаемы**. Хост пишем как `hallgato{N}`. Токены / cookie / JWT / пароли / коды Neptun / имена / номера счетов ниже **замазаны** (только имена полей).

**Уже использует приложение** (увидели снова; сюрприза нет): `GET /api/UserInfo`, `GET /api/General/GetUserAvatar`, `GET /api/Calendar/GetCalendarEvents`, `GET /api/Calendar/GetCourseDetails`, `GET /api/Calendar/GetStudentTrainings`, `GET /api/RegisteredCourses/GetRegisteredCourses` + `GetTerms`, `GET /api/Periods/GetPeriods` + `GetTerms` + `GetPeriodData`, `GET /api/Transactions/GetStudentPreviousTransactions`, `GET /api/FinancialDataDashboard/GetCollectiveInvoices`, `GET /api/Message/GetReceivedMessages` (`filterType=0`), `GET /api/Messages/{guid}/Posts`, `GET /api/Message/GetUnreadedMessagesCount`, `POST /api/Account/GetNewTokens` (`accessToken`, `sessionTimeoutInMinutes`), `GET /api/MyTrainings` (тот же смысл, что `ContextUserProfile/MyTrainings`).

**Запись (видно, но не планируем):** `GET /api/SubjectApplication/{Curriculum,SubjectGroup,SubjectTypes,SystemParameters,Terms}` и страница `/subjects/registration` в `finances.har`. Не реализовывать.

| Файл | Заметные **новые** (или дополнительные) API | Что открывает в плане? |
|------|--------------------------------------------|-------------------------|
| `profile.har` | `PersonalData/GetGeneralUserData`, `GetStudentPersonalDataContacts`, `GetStudentPersonalDocuments`, `GetStudentAddressDetails`, `GetStudentEmailDetails`, язык/гость/параллель/льготы/заявления/GDPR/история; `BankAccount/GetBankAccountDetails`, `GetDefaultBankAccountNumber`; `UserProfile/GetUserProfileSettings`, `GetDefaultAvatars` | **П. 12** имена полей профиля + банка. **Не** QR / номер карты. Документы здесь: Passport + residence permit. |
| `administration.har` | `StudentCard/StudentCardClaimProcess`, `GetStudentAddress`, `GetStudentCardPreviousClaims` (пусто); `RequestForm/*`; `Questionnaires/*`; `GET /api/administration/semiannualregistration/semesters` | **П. 12** статус заявки / NEK / FIR (**не** wallet). Заявки / анкеты / регистрация семестра — extras, не гейты. |
| `information.har` | `RoomSchedule/{GetBuildings,GetSites,GetOrganizations,GetRoomsSchedules}`; `Queries/*`; `FIR/GetStudentFIRData` (**410**); `POST ContextUserProfile/SaveFilter` | **П. 8** опционально аудитории кампуса. FIR мёртв. **Не** tanterv. |
| `taken courses.har` | Дашборд `GetAverages` (items **[]**), `GetAverageTypesDescription`, `GetUpcomingEvents`, `ExamOverview/*`; **только `GetRegisteredCourses`** | **Не** открывает п. 11. Официальный GPA **не** заполнен. RegisteredCourses в приложении уже есть. |
| `calendar+subjects.har` | `Calendar/GetLinksForCalendarExport`; `GetNewAllAppointmentInvitations`; `ContextUserProfile/GetCalendarSelectedTypes` + `GetCalendarSelectedView`; `SubjectCourse/GetSubjectDetails` + `GetCourseDetails` + тьюторы + список курсов | **П. 6** официальный ICS/webcal URL. У курса `language` / `teachingMethod`. **Нет email преподавателя.** Поля curriculum у предмета ≠ граф tanterv. |
| `messages.har` / `messages2.har` | `Message/GetReceivedArchivedMessages`, `GetSentMessages`, `GetMessageRelatedSettings`, `GetMessageLimitSetting`, `GetMessageSendingSettings`; `General/GetUsersAvatar`; `UserSearch/GetUsers` | **П. 4** extras (архив/исходящие/настройки/поиск). `filterType` всё ещё **0**. Unread-only **не** видели. |
| `finances.har` | `FinancialItem/GetItemsToBePayed` (**[]**) + `AdditionalData`; `GetStudentTransactionDetails`; `GetStudentPreviousTransactionsFilters`; `FinancialBonuses/*` (пусто); `FinancialOptions/GetStudentLoan2Data`; `BankAccount/GetUserBankAccountTabList` + `GetBankAccountPermissions`; `EnvironmentData` (`sessionTimeoutInMinutes=15`, `accessTokenExpirationInMinutes=5`); `UserInfo` (полная форма); **SubjectApplication/\*** | **П. 7** неоплаченные + детали + фильтры. **П. 12** список банков. Таймауты сессии vs 10 мин wall clock приложения. Блок записи = видно, не планируем. |

**Хром SPA (для фич не нужен):** `ContextUserProfile/GetColumnOrder*`, `GetFilter`, `Dashboard/GetNews`, `GetActiveDomainPasswordExpiration`, `Translations`, `Permissions`, `ExtendedMenuPermissions`, `Profiles/Favourites`.

**UserInfo / аватар / curriculum / карта / банк — имена полей, от которых зависят п. 11–12**

| Тема | Вердикт | Имена полей (без значений) |
|------|---------|----------------------------|
| **UserInfo** | Уже используем; форма подтверждена | `userStatus`, `studentTrainingId`, `name`, `neptunCode`, `substitutePrintName`, `isTokenRegistered`, `userAvatar.{avatarType,image,fallbackColorCodeInHexa,printName}` |
| **Аватар** | Уже используем + extras | `GetUserAvatar.image` (`imageSizeType=Normal`); `GetUsersAvatar` (`Thumbnail` + `userIds[]`); `GetGeneralUserData.profilePicture`; `GetDefaultAvatars.{normalImage,thumbnailImage,avatarType}` |
| **Curriculum / tanterv** | **Отдельного tanterv API нет** (живой Chrome 2026-09-13) | `/api/GetCurriculums` **404**. Меню: Advancement, не Tanterv. `GET /api/Advancement/GetStudentCurriculumTemplates` → `data: []`. `GET /api/advancement/creditprogress` и `GET /api/Dashboard/creditprogress` → `data` null. Поля шаблона у предмета на `GetSubjectDetails` без изменений. |
| **Официальный GPA** | **Схема снята; значения почти пустые** (начало семестра) | Дашборд `GetAverages.dashboardAverageItems` []. `GET /api/Advancement/GetTermAveragesByTraining`: `creditIndex`, `sumAverage`, `average` + подписи. `GET /api/RegistrySheet/GetStudentTrainingTermData?studentTrainingTermDataId=` (id из строки Advancement, **не** dashboard `studentTrainingTermDataId` — тот был null): `averagesCreditIndicies` (Credit, CreditAll, SumCredit, SumCreditAll, Average, SumAverage), `furtherHalfYearAverages` (SchoolarshipKey, RepeatExam, KorrigaltKreditIndex, KreditIndex, ElismertKredit, NemElismertKredit), `furtherCumulativeAverages` (SumRepeatExam, SumKorrigaltKreditIndex, KumNemElismertKredit, KumElismertKredit). На этом аккаунте **значение было только у CreditAll**; остальные официальные цифры пустые. |
| **Студенческий** | **Заявка**, не wallet | `StudentCardClaimProcess`: `id`, `claimType`, `nekId`, `fileInfo[]`, `firStatus`, `firStatusId`, `processStatus`, `finalDecision`, `registrationDate`, `trainingName`, `trainingFaculty`, `primaryInstituteName`, `primaryInstitutePrintCode`, `addressId`, даты. `GetStudentAddress`: `id`, `address`, `addressType`. Прошлые заявки []. **Нет QR / cardNumber / expiry** |
| **Банк** | **Снято** | `bankAccountId`, `bankAccountNumber` (redact), `bankAccountOwner`, `bankAccountSwiftCode`, `bankName`, `bankAddress`, `isDefault`, `isForeign`, `isValid`, `otpStatus`, `otpStatusIsVisible`, флаги прав |

**Какие клики ещё нужны** (уже необязательно): снова открыть Advancement / Registry sheet **после закрытия семестра**, когда официальные средние заполнятся; compose **POST**; оплата **POST**; **save** профиля; **submit** заявки на карту; карточка преподавателя (email). Меню **Tanterv на этом HWEB нет**. **QR / wallet карты нет** на Student Card request (`/administrations/student-card`) — только форма заявки, без QR.

### 4.3 Живой проход Chrome (тот же день, вход на `hallgato{N}`)

Владелец включил JS из Apple Events в уже залогиненном Chrome. Пройдены Studies / Advancement, заявка на студенческий, Registered subjects. Жёсткий `location.href` на Registry sheet дал **error 5002** и выкинул на портал; **Student web** (`ToNeptunHWeb`) вернул HWEB. HAR не сохраняли; токены/PII в git не копировали.

| Страница | API / итог |
|----------|------------|
| `/studies/advancement` | `GetTermAveragesByTraining`, `creditprogress` (пусто), `GetStudentCurriculumTemplates` (`[]`), `GetAverageTypesDescription` |
| `/administrations/student-card` | Те же API заявки, что в HAR. UI: форма + пустые «Earlier requests». **Нет QR / штрихкода.** |
| `/subjects/registered-subjects` | `GET /api/TakenSubjects/Terms` (`creditSum`, `completedCredit`, `isClosed`, `value`, `text`) + `GET /api/TakenSubjects?request.termId=` (приложение уже так ходит) |
| `/studies/registry-sheet` | Жёсткая навигация **5002**. Данные всё равно доступны: `GetStudentTrainingTermData` с `studentTrainingTermDataId` из строки Advancement |
| `/api/Calendar/GetLinksForCalendarExport` | Подтверждены `data.url`, `data.urlForWebCalendars` (сырые URL не хранить — могут содержать секреты) |
| Сессия | `EnvironmentData` портала: сессия **15 мин** / JWT **5 мин**; wall-clock приложения — **10 мин** |

---

### A. Запись на экзамен / курс — **не планируем**

**Вне скоупа.** HAR на vizsgajelentkezés / tárgyjelentkezés не снимать и UI записи не строить. Календарь по-прежнему может **показывать** экзамены (`GetCalendarEvents`) — это только отображение.

---



### B. Студенческий / профиль / банк

**Куда кликать**

1. **Saját adatok** / User data (`/user-data`).
2. Блоки: личные данные, **diákigazolvány** / student card / карта NEPTUN если есть, **bankszámla**.
3. Если грузится QR или картинка карты — запомнить XHR, который её отдаёт, не только `<img>`.
4. Скриншот QR в git **не** класть.

**Какие endpoint искать**


| Искать                                                         | Комментарий                                            |
| -------------------------------------------------------------- | ------------------------------------------------------ |
| `/api/UserInfo`                                                | **Уже используем** — имя, training, `userAvatar.image` |
| `/api/General/GetUserAvatar?imageSizeType=Normal`              | **Уже используем** — JPEG                              |
| `*StudentCard*`, `*Card*`, `*Diakigazolvany*`, `*NEK*`, `*QR*` | Неизвестно — оставить                                  |
| Bank / `BankAccount` / `Szamlaszam`                            | Неизвестно — оставить                                  |


**Какие поля нужны** (если они есть)

- Номер / идентификатор карты, сроки, вуз.  
- **Строка** QR/штрихкода, не фото экрана.  
- Банк: владелец, IBAN/номер, валюта — в копиях **замазать**.

**Уже есть vs нет** (после захвата 2026-09-13)


| Есть | Нет |
| ---- | --- |
| ФИО, код Neptun, аватар (`UserInfo` / `GetUserAvatar`) | **Payload QR**, **номер** пластика/цифровой карты, **срок** |
| Переключатель training | Живой FIR (`GetStudentFIRData` = 410) |
| Имена полей банка + статус заявки/NEK/FIR + `GetGeneralUserData` | POST save / edit (не кликали) |


---



### C. Tanterv / academic progress

**Куда кликать**

1. **Tanulmányok** → **Tanterv** / Curriculum / учебный план (часто `/studies`).
2. Открыть **активный training** (тот же, что в drawer приложения).
3. Развернуть семестр или группы «kötelező / kötelezően választható / szabadon választható», если сайт так делит.
4. Если есть сводка «teljesítés / kredit / progress» — открыть и её.

**Про** `GetCurriculums`

- Константа приложения: `URLs.CURRICULUMS_URL = "/api/GetCurriculums"` (путь старого MobileService).  
- **Никогда не вызывается.** Modern HWEB может ходить в другой URL (`/api/...Curriculum...`). В HAR оставить **тот XHR, который реально ушёл**.

**Какие поля ответа нужны**

- Списки обязательных / обязательных по выбору / свободных предметов.  
- Итоги кредитов **к диплому / программе**, не только текущий семестр.  
- Коды предметов, стыкующиеся с `TakenSubjects.subjectCode`.  
- Флаги закрытия, если сервер их уже считает.

**Уже есть vs нет** (после захвата 2026-09-13)


| Есть | Нет |
| ---- | --- |
| `TakenSubjects` + `TakenSubjects/Terms` (`creditSum`, `completedCredit`) | **Граф tanterv** — на HWEB нет страницы Tanterv; templates/creditprogress **пустые** в этом семестре |
| Счётные átlag / /30 в приложении | Заполненные официальные цифры (схема известна; значения пустые, пока нет результатов семестра) |
| У предмета `curriculumTemplateId` / `requirementType` на `GetSubjectDetails` | Endpoint прогресса всей программы |


---



### D. Полезно снять заодно (отдельные HAR)

Та же сессия, **отдельные** файлы, если лог распухает:


| Если на сайте видно | Зачем нам | Статус после этого захвата |
| ------------------- | --------- | -------------------------- |
| **Email преподавателя** на карточке курса/человека | В диалоге пары только имя `courseTutor` (`GetCourseDetails`); тьюторы = `printname` / `employeeId` / avatar | **Всё ещё нет** |
| Дедлайны заданий / ZH, которых **нет** в институциональном календаре | Полоса п. 6; сейчас `isTask` + `GetTaskDetail` | **Всё ещё нет** |
| Официальные **GPA / KKI / ösztöndíjindex** на странице результатов | `GetAverages` / `GetAverageTypesDescription` есть; items были **[]** | **Кликнуть страницу, которая заполняет items** |


---



## 5. Шаблоны для агентов

Кто реализует любой пункт выше — копирует этот паттерн, а не вторую архитектуру.

### i18n

- Ключи в `LanguagePack` в `lib/language.dart` (**HU + EN** обязательны).  
- Те же ключи в `Languages/LangExtentions/Russian.json` и `Turkish.json`.  
- Только chrome приложения. Заголовки из Neptun (`Előadás`, `aktív`, `teljesített`) не переводить, если это не наша строка.  
- Нет ключа в RU/TR → fallback на EN (`getStr`).



### Кэш

- Сначала кэш (`HasCached*` + `Cached*_$i`).  
- Тихий refresh, если есть сеть и сессия.  
- **Никогда** пустой экран, если список в кэше есть.  
- Образец — `fetchCalendar`.



### Сессия

- `ensureValidSession()` перед длинными циклами (все семестры, все страницы почты).  
- Провал → существующий logout/snackbar, **не** стартовать обход 10 семестров.  
- Не хардкодить `hallgatoN`; база = `DataCache.getInstituteUrl()`.



### Документация

- В том же ходе: `docs/README.md` + `README.ru.md` (если фича видна пользователю), `TECHNICAL.md` + `TECHNICAL.ru.md` (honesty / API), этот план — если сдвинулся гейт.  
- Владелец — **Nanda**.  
- Живой логин ELTE и HAR-only помечать как непротестированные, пока нет захвата.



### Инварианты продукта

- **Не ломать** хаб ELTE, TOTP, коды логина (`loginOk` / `loginNeeds2fa` / `loginInvalidCredentials` / `loginServerBusy`).  
- Nav: снизу **4** (Calendar \| Markbook \| Periods \| Mail) — Payments через drawer над Settings; Contacts + версия в Settings (**1c**).  
- Сессия: политика 10 мин должна считать реальное wall-clock время в фоне (**1b**), а не только Timer в suspend.  
- **Не пилить** `main_page.dart` / `api_coms.dart` «для чистоты» в том же PR, что фича.  
- Нет своего бэкенда. Нет push-сервера автора.

---



## 6. Что уже есть в коде (шпаргалка)


| Область     | Файлы                                                                       | API / ключи                                                                   |
| ----------- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Сессия      | `SessionGuard`, `HomePage`                                                  | wall-clock 10 мин (`Timer` + resume timestamp); `GetNewTokens`; **1a**/**1b** сделаны |
| Кэш         | `lib/storage.dart` `DataCache`                                              | см. п. 1                                                                      |
| Nav         | `BottomNavigatorWidget`, `AppDrawer`, `main_page.dart`, `settings_page.dart` | **1c сделан:** 4 снизу (Calendar, Markbook, Periods, Mail) + Payments в drawer над Settings; Contacts + версия в Settings |
| Календарь   | `CalendarPageWidget`, `TimetableElementWidget`, `WeekoffseterElementWidget` | `GetCalendarEvents`, `GetCourseDetails`, `GetTaskDetail`                      |
| Зачётка     | `MarkbookPageWidget`, `MarkbookElementWidget`                               | `TakenSubjects`, `GetRegisteredCourses`, `getGradeHistoryAcrossTerms`         |
| Ghost       | `popup.dart` mode 0                                                         | `_markbookCalcGhostAvg`                                                       |
| Почта       | `MailsPageWidget`, `MailElementWidget`, `message_translator.dart`           | `GetReceivedMessages`, `GetUnreadedMessagesCount`, `/api/Messages/{id}/Posts` |
| Платежи     | `PaymentsPageWidget`, `PaymentElementWidget`                                | `GetStudentPreviousTransactions`, `GetCollectiveInvoices`                     |
| Периоды     | `periods_element_widget.dart`                                               | `GetPeriods`                                                                  |
| Аудитории   | `lib/Misc/elte_room_code.dart`                                              | только LD/LE/LK decode                                                        |
| ICS         | `lib/API/ics_calendar.dart`                                                 | **только импорт**                                                             |
| Нотификации | `lib/notifications.dart`, тумблеры Settings                                 | 0 экзамен, 1 пара, 2 оплата, 3 период                                         |
| Tanterv     | `URLs.CURRICULUMS_URL`                                                      | **не вызывается**; tanterv в HAR всё ещё нет                                  |
| Профиль     | `UserInfo`, `GetUserAvatar`                                                 | имя + фото; HAR также называет банк + заявку на карту (в приложении нет)      |
| Виджеты     | —                                                                           | **удалённый stub**                                                            |


---

*Конец плана. Если расходится с кодом — побеждает код. Tanterv / Academic Progress и QR студенческого остаются закрытыми. Банк + поля заявки сняты (неполно). Запись на экзамен / курс не планируем — не возвращать.*