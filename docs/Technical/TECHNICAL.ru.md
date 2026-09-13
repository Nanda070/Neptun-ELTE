# Neptun ELTE — техническая документация

> 🇬🇧 [English](TECHNICAL.md) · 📋 [План реализации (RU)](IMPLEMENTATION_PLAN.ru.md) · [EN](IMPLEMENTATION_PLAN.md) · 📱 [iOS vs Android (RU)](IOS_VS_ANDROID.ru.md) · [EN](IOS_VS_ANDROID.md) · 📝 [Dev Blog (RU)](DEV_BLOG.ru.md) · [EN](DEV_BLOG.md)

> **Аудитория:** разработчики и люди с доступом к репозиторию.  
> Файл только в git (`docs/Technical/TECHNICAL.ru.md`). **Не** публикуется как сайт, **не** имеет отдельного веб-маршрута.  
> Идентификаторы кода, пути, пакеты и API-маршруты — на английском, как в репозитории.

Последняя сверка с кодовой базой: **сентябрь 2026** (репо **Neptun-ELTE**, display name Neptun ELTE, хаб только ELTE, без `/ujhallgato` для ELTE, языки EN/HU/RU/TR, логин modern API + 2FA-код, «неверный пароль» vs «сервер занят»). Источники: `lib/**`, `pubspec.yaml`, `ios/`, `android/`, `Languages/`, `Themes/`, `universityNameUrlPairs.json`, `.github/`.

**Владелец и разработчик:** **Nanda** (полное юридическое имя — только в Legal).

Продуктовый обзор + индекс Legal: [`docs/README.ru.md`](../README.ru.md) / [`docs/README.md`](../README.md).  
Бэклог реализации (не сделано): [`IMPLEMENTATION_PLAN.ru.md`](IMPLEMENTATION_PLAN.ru.md) / [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).  
Дневник разработки: [`DEV_BLOG.ru.md`](DEV_BLOG.ru.md) / [`DEV_BLOG.md`](DEV_BLOG.md).  
Legal: [Конфиденциальность RU](../Legal-Ru/PRIVACY.md) · [Условия RU](../Legal-Ru/TERMS.md) · [Cookie RU](../Legal-Ru/COOKIES.md) · [EN](../Legal-En/) · [HU](../Legal-Hu/).  
Краткий iOS-старт: только [§14](#14-ios) — **отдельного** `DEVELOPER.md` **нет**.  
Матрица платформ (что есть/нет на каждой ОС): [`IOS_VS_ANDROID.ru.md`](IOS_VS_ANDROID.ru.md) / [`IOS_VS_ANDROID.md`](IOS_VS_ANDROID.md).  
UI-макеты (Figma, не код приложения): [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups) — **Android** = целевой polish; **iOS** = текущая оболочка Flutter + аддитивные поля из плана. Макеты могут ещё показывать **5** нижних вкладок; **в приложении IA** — **4** (Calendar \| Markbook \| Periods \| Mail) + Payments в drawer над Settings (п. **1c**). Владелец **Nanda**.

---

## Оглавление

1. [Обзор продукта](#1-обзор-продукта) — [Версионирование](#версионирование)
2. [Репозиторий](#2-репозиторий)
3. [Стек](#3-стек)
4. [Архитектура и поток запросов](#4-архитектура-и-поток-запросов)
5. [Экраны](#5-экраны)
6. [Setup / вход](#6-setup--вход)
7. [Home tabs (5 сегодня; план 3 + drawer)](#7-home-tabs-5-сегодня-план-3--drawer)
8. [API Neptun](#8-api-neptun)
9. [Auth, 2FA, токены](#9-auth-2fa-токены)
10. [Доменные возможности](#10-доменные-возможности)
11. [Честность: full vs thin](#11-честность-full-vs-thin)
12. [Слой данных](#12-слой-данных)
13. [Уведомления](#13-уведомления)
14. [iOS](#14-ios)
15. [Android](#15-android)
16. [Отключённые / удалённые функции](#16-отключённые--удалённые-функции)
17. [Переменные окружения](#17-переменные-окружения)
18. [Сборка, CI, запуск](#18-сборка-ci-запуск)
19. [История и контакты](#19-история-и-контакты)
20. [Ключевые решения «почему так»](#20-ключевые-решения-почему-так)
21. [Карта важных файлов](#21-карта-важных-файлов)

---

## 1. Обзор продукта

**Neptun ELTE** — неофициальный мобильный клиент **ELTE** (Eötvös Loránd Tudományegyetem) **Neptun** (SDA Informatika): расписание, зачётка, платежи, периоды, сообщения.

- **Скоуп:** только ELTE. Не мульти-вузовский пикер.
- Файл `universityNameUrlPairs.json` остаётся, но содержит **одну** запись: ELTE → `https://neptun.elte.hu`.
- Экран setup — **хаб ELTE**: одна кнопка → логин (без списка вузов и без ручного URL).
- ELTE — **центральный** портал (`neptun.elte.hu` / логин + News). **Нет** `/ujhallgato` как у Óbuda/BME. После логина **Student web** идёт через `/ToNeptunWeb/ToNeptunHWeb` на один из одинаковых HWEB-хостов: **`hallgato1`…`hallgatoN.neptun.elte.hu`** (балансировка; напр. `hallgato4`). Мобильный клиент логинится и зовёт modern JWT API на **`https://neptun.elte.hu`**, не конкретный `hallgatoN`.
- Display name: **Neptun ELTE**.
- Версия (`pubspec.yaml`): **1.1.0+19** (см. [Версионирование](#версионирование) ниже).
- Dart-пакет: `neptun2` (импорты `package:neptun2/...`).
- Языки UI: **EN** (дефолт) и **HU** вшиты; **RU** и **TR** качаются с GitHub.
- Платформы: **Android** и **iOS**. Web / Windows / macOS / Linux в репо **нет** (linux/ удалён).
- Это **не** официальное приложение SDA/ELTE и **не** App Store / Play production-бренд.

Репозиторий: [Nanda070/Neptun-ELTE](https://github.com/Nanda070/Neptun-ELTE). Продукт независимый; прошлые авторы указаны только в credits.

### Версионирование

Политика владельца (**Nanda**). Формат Flutter: `x.y.z+build` в `pubspec.yaml` (`build-name` + `build-number`). Android `versionName` / iOS `CFBundleShortVersionString` берут `build-name`; номер сборки магазина — `build-number` (+N, увеличивать на каждый shippable build).

| Линия | Смысл |
|-------|--------|
| **1.0** | То, что сейчас на GitHub как опубликованная базовая линия (утверждение пользователя о текущей публичной линии до этого обновления). Старые деревья / теги могут ещё показывать **1.0.5+18**, пока этот bump не закоммичен и не отгружен. |
| **1.1.0** | **Это** обновление: foundation **1a** / **1b**, nav IA **1c** (4 нижние вкладки + Payments в drawer; Contacts + версия в Settings) и polish-пакет при отгрузке. |
| **1.1.x** | Багфиксы / мелкие правки на линии 1.1 (напр. **1.1.1**). |
| **1.2**, **1.3**, … | Следующие **крупные** feature-релизы. |
| **1.2.1**, **1.2.2**, … | Патчи внутри этой major.minor линии. |

При релизе поднимать `pubspec.yaml` (и зеркала iOS `MARKETING_VERSION` / Android fallback, если есть). Не заводить параллельную схему в UI-строках.

---

## 2. Репозиторий

```
Neptun-ELTE/
├── lib/                      # Весь продукт (Dart)
│   ├── main.dart
│   ├── storage.dart          # DataCache singleton
│   ├── language.dart         # EN/HU + remote packs
│   ├── colors.dart           # Темы
│   ├── notifications.dart
│   ├── haptics.dart
│   ├── API/                  # Neptun HTTP + ICS parser
│   ├── Pages/                # Экраны
│   ├── Navigator/            # Top / bottom nav
│   ├── Misc/                 # Drawer, popup, updater, snackbar
│   └── *Elements/            # Виджеты вкладок
├── android/                  # Native Android
├── ios/                      # Native iOS (сгенерирован flutter create)
├── Languages/                # supportedLanguages.json + JSON-паки
├── Themes/                   # supportedThemes.json + JSON-палитры
├── universityNameUrlPairs.json
├── docs/
│   ├── README.md / README.ru.md   # Полный продуктовый README
│   ├── LICENSE                    # Канонический LGPL-3.0-only
│   ├── Technical/                 # TECHNICAL + IMPLEMENTATION_PLAN + DEV_BLOG (EN + RU)
│   ├── Legal-En/ · Legal-Ru/ · Legal-Hu/
│   └── …
├── .github/workflows/        # Только Android debug APK
├── pubspec.yaml
├── README.md                 # Короткий указатель → docs/
└── LICENSE                   # Идентичная копия docs/LICENSE (для GitHub)
```

| Путь | Назначение |
|------|------------|
| `lib/` | UI, API, кэш, уведомления |
| `android/` | Gradle, `applicationId` `com.nanda070.neptun_mobile.app` |
| `ios/` | Xcode, Bundle ID `com.nanda070.neptunmobile` |
| `Languages/` | Каталог скачиваемых языков (сейчас только `ru`, `tr`) |
| `Themes/` | Каталог скачиваемых тем |
| `docs/Technical/` | TECHNICAL + IMPLEMENTATION_PLAN + DEV_BLOG (EN + RU) |
| `docs/Legal-*` | Privacy, Terms, Cookies (EN / RU / HU) |
| `docs/README*.md` | Полный продуктовый README |
| `.github/workflows/betabuild.yml` | CI: `flutter build apk --debug` |

**Нет:** `test/`, `web/`, `linux/`, `macos/`, `windows/`, backend этого приложения.

---

## 3. Стек

| Слой | Технологии |
|------|------------|
| UI | **Flutter** / **Dart** `>=3.1.4 <4.0.0`, **Material 3** |
| Состояние | `provider` — только тема (`ThemeNotifier`); остальное — синглтон `DataCache` |
| Сеть | `http` (основной), `dio` (скачивание APK на Android) |
| Локально | `shared_preferences`, `flutter_secure_storage`, `path_provider`, `file_picker` |
| Уведомления | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Прочее | `url_launcher`, `package_info_plus`, `device_info_plus`, `connectivity_plus`, `vibration`, `fluttertoast`, `open_filex`, `flutter_native_splash`, `linked_scroll_controller` |
| Android-only | `in_app_update` (Play), `AppUpdater` (GitHub APK) |
| Навигация | **без named routes**: `Navigator.push` + индекс нижней панели |

Отдельного сервера приложения **нет**. Все учебные данные идут на инстанс Neptun выбранного вуза. Языки / темы / список вузов — raw GitHub этого репо.

---

## 4. Архитектура и поток запросов

```
Устройство (Android / iOS)
   │
   ├─ Flutter UI (lib/Pages, lib/*Elements)
   │       │
   │       ▼
   │   DataCache (lib/storage.dart)
   │     SharedPreferences + flutter_secure_storage
   │
   ├─ HTTP → {instituteBase}/api/...     modern JWT Neptun
   │         {instituteBase}/MobileService.svc/api/...   old API
   │
   └─ HTTP → raw.githubusercontent.com/Nanda070/Neptun-ELTE
              universityNameUrlPairs.json
              Languages/supportedLanguages.json
              Themes/supportedThemes.json
```

**Инварианты:**

1. Нет своего бэкенда и нет push-сервера. Уведомления **локальные**.
2. Modern vs old API определяется URL (`.aspx` → old; иначе modern) и флагом `DataCache.getIsModernApi()`.
3. `Provider` не несёт учебные данные.
4. TLS: `NeptunCerts.badCertificateCallback` принимает **любой** сертификат (`lib/API/api_coms.dart`). Нужно вузам с кривым TLS; это сознательный риск.
5. Список вузов в приложении читается с **`main` на GitHub**. Локальный JSON в checkout **не** используется, пока не запушен.

---

## 5. Экраны

Навигация: `MaterialPageRoute`, без `routes:` map.

| Виджет / файл | Назначение |
|---------------|------------|
| `Splitter` (`lib/Pages/startup_page.dart`) | Сплэш: грузит кэш, тему, языки; ветка login / home |
| `SetupPageLoginTypeSelection` (`setup_page.dart`) | **Хаб ELTE** — одна кнопка → логин (без списка вузов / URL) |
| `SetupPageInstitudeSelection` | Старый список (хаб не открывает; JSON — только ELTE) |
| `SetupPageURLInput` | Старый ручной URL (на хабе не показывается) |
| `SetupPageLogin` | Neptun-код + пароль |
| `SetupPageCalendarLogin` | ICS-импорт (класс есть; **с хаба не открывается**) |
| `HomePage` (`lib/Pages/main_page.dart`) | **4** нижние вкладки после входа (Calendar, Markbook, Periods, Mail). Payments = индекс drawer 4. `WidgetsBindingObserver` → `SessionGuard.checkSessionWallClockOnResume` |
| `SettingsPage` (`settings_page.dart`) | Тема, язык, шрифт, уведомления, хаптика, неделя; **Contacts** + версия приложения (`package_info_plus`, напр. `1.1.0+19`) внизу |
| `AppDrawer` (`lib/Misc/app_drawer.dart`) | Приветствие = полное имя из `UserInfo` + код Neptun (без training ID под именем); фото аватара из HWEB base64 (`userAvatar` / `GetUserAvatar`) с fallback на инициалы; семестр, баланс, переключатель training; **Payments над Settings**; апдейт (Android), выход |
| `PopupWidgetHandler` (`lib/Misc/popup.dart`) | Модальные режимы 0–9 |

**Макеты в Figma (только дизайн — без правок Flutter из этого файла):** [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups). Страницы: `Android — polished target` и `iOS — current + polish`. Макеты могут ещё показывать **5-tab** icon nav; **в приложении IA** — снизу **Calendar \| Markbook \| Periods \| Mail** + Payments в drawer над Settings (п. **1c**).

---

## 6. Setup / вход

### Как устроен веб ELTE (официально)

Поток на `neptun.elte.hu` ([гайд ELTE](https://www.elte.hu/en/neptun-administration-of-progress)):

1. Центральный портал → **Log in** (Neptun ID 6 символов + пароль).
2. **Двухфакторная аутентификация** (live UI + HAR, сент. 2026):
   - **Основной — TOTP:** поле «TOTP code» + Log in. **6 цифр** из Microsoft Authenticator.
   - **Запасной — E-mail:** `POST /Account/Login2FA` с `Phase=RequestTOTP&GetEmail=true`, затем `Phase=RequestEmailCode` с `CodePrefix` (3 цифры) + `EmailCode` (6 цифр после `-`). Пример из HAR: `154-855139`.
3. После входа **Student web:** `POST /ToNeptunWeb/ToNeptunHWeb` (`NeptunWebType=HWeb`) → **302** на `https://hallgatoN.neptun.elte.hu/outerlogin?GUID=…&languageid=1033` → `POST /api/Account/OuterLogin` `{"guid":"…","lcid":1033}` → **JWT `accessToken`**. При нагрузке — **«Neptun student web is full»**.

**`hallgatoN` = какой сервер:** `hallgato1…N` — балансировка. В live HAR — **`hallgato3`** (`ELTE_HW3`). Портал сам назначает узел.

Наблюдаемые пути HWEB после OuterLogin: `/dashboard`, `/calendar/…`, `/studies`, `/messages`, `/administrations`, `/user-data`, …

Портал (`neptun.elte.hu` Potlap) ≠ API-хост HWEB (`hallgatoN`). **`POST https://neptun.elte.hu/api/Account/Authenticate` → пустой HTTP 400** — это не путь ELTE. На hallgato `Authenticate` при AD **302 → портал**.

### Как это отражено в приложении

| Шаг на сайте | Приложение |
|--------------|------------|
| `POST /Account/Login` | Та же форма (`LoginName`/`Password` + antiforgery) |
| 2FA TOTP / email | `POST /Account/Login2FA` → popup mode 9 |
| `ToNeptunHWeb` → `outerlogin?GUID=` | App постит HWeb, следует 302 |
| `POST /api/Account/OuterLogin` | Сохраняет JWT; institute URL = **`https://hallgatoN.neptun.elte.hu`** |
| Student REST | Bearer JWT на этом hallgato |

UI setup:

1. `Splitter` → если `getHasLogin()` → `HomePage`, иначе хаб (**имя на экране: Neptun ELTE**).
2. Хаб → `elteInstituteName` + `elteNeptunBaseUrl` (`https://neptun.elte.hu`) → `SetupPageLogin`.
3. Код + пароль.
4. При 2FA — **6 цифр TOTP**, затем OuterLogin на hallgato.
5. Демо: `DEMO` / `DEMO`.

**Честность:** ELTE-логин = **портал Potlap + OuterLogin**, не JWT Authenticate на `neptun.elte.hu`. Email OTP известен по HAR; в UI пока акцент на TOTP. Если Student web **full** — мост после 2FA не пройдёт; UI показывает `loginStudentWebFull`, **не** «неверный пароль».

Константы: `InstitutesRequest.elteInstituteName`, `elteNeptunBaseUrl`.

### Коды `InstitutesRequest.validateLoginCredentialsUrl`

| Код | Константа | UI |
|-----|-----------|-----|
| `1` | `loginOk` | Вход на Home |
| `2` | `loginNeeds2fa` | Popup mode 9 (6 цифр TOTP) |
| `0` | `loginInvalidCredentials` | Красные поля, «Invalid username or password!» |
| `3` | `loginServerBusy` | Snackbar «Neptun servers are having a hard time...» — **не** неверный пароль |
| `4` | `loginStudentWebFull` | Snackbar «Студенческий веб переполнен. Попробуйте позже.» — **не** неверный пароль / TOTP |

Таймаут modern login: **20 с** на кандидата. Пустой ответ / 5xx / timeout / HTML → `loginServerBusy`.

**Честность — Student web full после 2FA:** Верный пароль + верный TOTP всё равно могут не пустить на `ToNeptunHWeb` / OuterLogin, когда ёмкость HWEB ELTE исчерпана («Neptun student web is full» / megtelt / «nincs szabad»). Раньше это выглядело как **неверный логин/пароль**, потому что `submitTwoFactorCode` возвращал голый `false`, а setup красил `_paintRed`. Теперь после успеха TOTP UI показывает **«Подключение к студенческому вебу…»** и ~**7 с** ретраит мост; успех → сразу Home; устойчивый full/busy → snackbar `loginStudentWebFull` / busy — учётные данные при этом верные.

### Нормализация URL (ELTE)

`normalizeModernApiBaseUrl` снимает `/login`, `/MobileService.svc`, `/Account`, `/Account/Login`.

База API: **`https://neptun.elte.hu`** — не `/ujhallgato`.

Кандидаты: primary + root ELTE.

После успеха сохраняется база, выбранная логином.

---

## 7. Home tabs (4 снизу + Payments в drawer)

`HomePageState` + `BottomNavigatorWidget`. Свайп влево/вправо среди нижних вкладок (`maxBottomNavWidgets = 4`). **Named routes нет.**

**Код сегодня:**

| Index | Поверхность | Содержание |
|-------|-------------|------------|
| 0 | снизу | Calendar — недельное расписание, пары/экзамены |
| 1 | снизу | Markbook (Subjects) — кредиты, средний, ghost grade |
| 2 | снизу | Periods — регистрация, экзамены, запись |
| 3 | снизу | Mail / Messages — входящие, непрочитанные, mark read |
| 4 | только drawer | Payments — начисления и дедлайны; в drawer также баланс |

**Nav IA (п. 1c):** снизу **Calendar \| Markbook \| Periods \| Mail**; **Payments** — в левый drawer **над Settings**. Contacts + версия приложения — внизу Settings (не в drawer).

Семестр: `getSelectedTermId()` / `getSelectedTermName()`, список терминов кэшируется.

---

## 8. API Neptun

Два семейства в `lib/API/api_coms.dart`.

### Old (`*.aspx` / `MobileService.svc`)

База: `{host}/…/MobileService.svc`.

| Константа `URLs` | Путь |
|------------------|------|
| `TRAININGS_URL` | `/api/GetTrainings` |
| `CALENDAR_URL` | `/api/GetCalendarData` |
| `MARKBOOK_URL` | `/api/GetMarkbookData` |
| `GETCASHIN_URL` | `/api/GetCashinData` |
| `PERIODS_URL` | `/api/GetPeriods` |
| `MESSAGES_URL` | `/api/GetMessages` |
| `MESSAGE_SET_READ` | `/api/SetReadedMessage` |

`URLs.INSTITUTIONS_URL` (cloudapp) **не вызывается**. Живой список вузов — GitHub JSON.

**2FA на old API нет.**

### Modern (JWT)

База: `{institute без /Account}` + `/api/...`.

| Назначение | Путь (примеры) |
|------------|----------------|
| Логин / 2FA | `POST /api/Account/Authenticate` |
| Refresh | `POST /api/Account/GetNewTokens` |
| Тренинги | `/api/Calendar/GetStudentTrainings`, `/api/UserInfo`, `/api/ContextUserProfile/MyTrainings` |
| Аватар | `/api/UserInfo` → `data.userAvatar.image` (thumbnail base64 JPEG) + `data.userAvatar.printName`; отображаемое имя — `data.name` (не top-level `printName`); `/api/General/GetUserAvatar?imageSizeType=Normal` (больший base64 JPEG) |
| Календарь | `/api/Calendar/GetCalendarEvents` |
| Детали пары | `/api/Calendar/GetCourseDetails` |
| Задания | `/api/Tasks/GetTaskDetail` |
| Предметы | `/api/TakenSubjects`, `/api/RegisteredCourses/GetRegisteredCourses` |
| Термины | `/api/RegisteredCourses/GetTerms`, `/api/TakenSubjects/Terms`, `/api/Periods/GetTerms` |
| Платежи | `/api/Transactions/GetStudentPreviousTransactions` |
| Баланс | `/api/FinancialDataDashboard/GetCollectiveInvoices` |
| Периоды | `/api/Periods/GetPeriods` |
| Почта | `/api/Message/GetUnreadedMessagesCount`, `GetReceivedMessages`, `/api/Messages/{id}/Posts` |

Неиспользуемые пути HWEB из захватов сент. 2026 (приложение их не вызывает) — в [`IMPLEMENTATION_PLAN.ru.md` §4.2](IMPLEMENTATION_PLAN.ru.md#42-снятый-инвентарь-неполно--2026-09-13); покрытие неполное, HAR в git нет.

Тело логина:

```json
{
  "userName": "...",
  "password": "...",
  "captcha": "",
  "captchaIdentifier": "",
  "token": "",
  "LCID": 1033
}
```

`LCID` следует языку приложения (`AppStrings.getNeptunLcid()`): EN `1033`, HU `1038`, RU `1049`, TR `1055`. GET также шлёт `Accept-Language`. Полная смена языка API для периодов/предметов после смены языка может потребовать повторного входа.

При 2FA повтор с `token` = код; опционально `Authorization: Bearer` от `twoFactorLoginToken`. Cookie `devicecookie-<b64(username)>=...`.

Refresh / повторный логин при 401 — в `_APIRequest` через `ensureValidSession` → `GetNewTokens` (если есть refresh token). **Тихий повторный вход через портал ELTE отключён** (нужна 2FA). Если refresh не удался, `SessionGuard.forceExpiredLogout` стирает **только auth** через `DataCache.sessionWipeKeepCache()` (пароль / JWT / refresh / device cookie / `HasLogin`; **логин + учебный кэш сохраняются**), открывает экран входа и показывает `auth_sessionExpired_PleaseSignIn`. Ручной / просроченный выход делят этот wipe. Leftovers портала: best-effort portal `Account/Logout`, `resetEltePortalState`, `CalendarRequest.clearTrainingIdCache`, wipe `devicecookie_*`, ужесточённый `_looksLikeInvalidCredentials` (без голого `invalid` на HTML `is-invalid`) — повторный вход в том же процессе без ложных «неверных данных» (**1a**). Полный `dataWipe()` (prefs.clear включая кэш) остаётся для hard reset — не используется при обычном logout.

**Wall-clock сессии приложения (видимо пользователю):** При входе на `HomePage` `SessionGuard.startSessionWallClock()` сохраняет `SESSION_StartedAtMs` и ставит **`Timer` на оставшиеся до 10 минут**. По срабатыванию — тот же путь `forceExpiredLogout` (токены стираются, логин + учебный кэш остаются). Ручной выход отменяет таймер; новый логин / новый вход на `HomePage` перезапускает. Refresh JWT **не** продлевает wall-clock.

**Wall-clock в фоне (п. 1b сделан):** `HomePage` — `WidgetsBindingObserver`. На `AppLifecycleState.resumed` `SessionGuard.checkSessionWallClockOnResume()` сравнивает `now` с сохранённым стартом; если `>= 10 мин` → `forceExpiredLogout`, иначе перезаводит Timer на остаток. Не полагаться только на in-memory Timer в suspend. Непрерывный foreground 10 мин по-прежнему выкидывает.

**Честность кэша (п. 1 сделан):** Каждая home-поверхность (календарь / зачётка / периоды / почта / платежи) сначала рисует из `HasCached*`; сеть — тихий refresh. При мёртвой сессии / offline / ошибке refresh списки **не** заменяются пустым спиннером. Баннер `cache_showingFromCache`. Пустые недели календаря кэшируются как `len == 0`. Обход семестров зачётки пропускается при `SessionGuard.isAuthBlocked`.

---

## 9. Auth, 2FA, токены

| Что | Где |
|-----|-----|
| Пароль, JWT access/refresh, device cookie | `flutter_secure_storage` (`DataCache`) |
| Username, URL института, флаги кэша, настройки | `shared_preferences` |
| Демо | `setIsDemoAccount(1)` |

**Срок JWT:** access-токены короткоживущие (~10–15 мин на практике в Neptun). Refresh может выдать новый access token, но приложение всё равно принудительно выходит через **10 минут после входа на Home** (см. wall-clock выше). Без рабочего refresh token 401 тоже форсирует logout, а не пустые экраны «как будто вошёл».

**2FA (modern):** `isTwoFactorRequired` / `requiresTwoFactor` / `twoFactorLoginToken` без `accessToken` (часто HTTP 202) → код `2` → popup 9 → пользователь вводит 6 цифр **TOTP** → `submitTwoFactorCode`. После успеха setup **сначала закрывает** popup 2FA, затем переходит на `HomePage` (`pushAndRemoveUntil`), чтобы отложенный `pop` не дал чёрный экран.

**2FA (old):** не поддерживается → обычно `0`.

**Веб ELTE vs приложение:** на сайте TOTP + E-mail (`XXX-XXXXXX`). В приложении: только поле TOTP. Устаревшая плашка «с 2FA войти нельзя» **удалена**.

---

## 10. Доменные возможности

### 10.1 Расписание

Неделя, сдвиг `getUserWeekOffset()`, первая неделя семестра `getFirstWeekEpoch()` из `getFirstStudyweek()`. Якорь — понедельник недели сезона семестра (осень: неделя с **1 сент.**; весна: неделя с **1 февр.**), если учебный/`szorgalmi` период начинается в те же ~2 недели — **не** окна записи на предметы / bejelentkezés (из‑за них раньше получались ~36, затем ~16). Окт. неделя = целые недели с того понедельника до *текущего* понедельника + `currentWeekOffset` (1 = текущая страница календаря). Пример ELTE осень 2026: **1–7 сент. → неделя 1**, **7–14 сент. → неделя 2**. При онлайн-открытии home epoch всегда пересчитывается. Modern: `GetCalendarEvents` с **пн–вс** `endDate` (не следующий понедельник — иначе подтягивались занятия следующего пн, ложный «перерыв» ~163 ч и дубли). События вне окна отбрасываются. Чипы перерыва только в тот же день (5 мин–12 ч), строки локализованы. Детали курса + фильтры календаря в настройках (`isClassesVisible` / exams / periods). Полосы UI (п. **3**): 48 ч = **пары + экзамены** (сортировка по `startEpoch`); ZH и экзамены — ближайшие от сейчас; баннеры периодов (`typeId == 6`) **только** в полосе периодов. Pull-to-refresh не обнуляет неделю из кэша. Переключатель обучения в drawer, если известно несколько training. **Коды аудиторий** вида `Кампус-Этаж-Аудитория[-Поток][-Группа]` (напр. `LD-0-805` или `LD-0-805-01-11`) нажимаются в списке расписания, диалоге занятия и popup экзамена/legacy: тап переключает короткий код ↔ локализованную расшифровку. Префиксы: **LD** Южный / Déli, **LE**/LÉ Северный / Északi, **LK** хим. блок (Северный); неизвестный префикс как есть. Поток/Группа только если есть в коде (`lib/Misc/elte_room_code.dart`).

### 10.2 Зачётка

Вкладка «Предметы» = зачётка: взятые предметы (с кодами), кредиты, оценки, ghost grade (popup 0), конфетти. Общая формула в `lib/Misc/markbook_math.dart` (**п. 2**): **Átlag / Average** = `Σ(оценка × кредит) / Σ(кредит)` для сданных `grade >= 2`; **/30** = `Σ(оценка × кредит) / 30` (тот же числитель — **не** átlag÷30). Шапка: кредиты семестра **и** накопленные сданные (дедуп по `subjectCode` через `getGradeHistoryAcrossTerms`). Подписи явно говорят `/30`; пометка: **счёт приложения**, не официальный KKI/GPA Neptun (`GetAverages` в HAR сент. 2026 был пуст). Также **Мои курсы** (`GetRegisteredCourses`) и компактная **история оценок** по недавним семестрам.

### 10.3 Платежи / периоды / почта

Начисления и дедлайны; список **collective invoices** + баланс; периоды с таймерами; входящие + mark read; полная цепочка постов письма. В карточке письма: опциональный машинный перевод HU→EN/RU (`MessageTranslator`); при первом использовании на устройстве показывается 5‑секундный snackbar о возможной неточности (`hasSeenMailTranslateDisclaimer`).

**Chrome UI платежей** (заголовок вкладки, пустое состояние, дедлайны, символ валюты, тексты уведомлений, баланс в drawer) идёт через `LanguagePack` (EN/HU встроены; RU/TR JSON). **Названия транзакций/счетов и статусы из Neptun** (`transactionPayingType`, `transactionStatus`, подписи collective invoice) обычно остаются **на венгерском** — это язык ответа сервера, а не пропущенная строка приложения.

### 10.4 Настройки

Тема, язык, шрифт 80–140%, уведомления (4 типа), family-friendly тексты загрузки, вибрация, сдвиг недели, фильтры календаря, проверка обновлений (Android).

### 10.5 Темы

Встроенный выбор (`lib/colors.dart`): только **Light** и **Dark**. Предпочтение хранится в `THEME_AppTheme` и применяется при старте; яркость системы **не** перезаписывает его. Remote-пакеты из `Themes/supportedThemes.json` в UI больше не предлагаются.

### 10.6 Языки

| Код | Откуда |
|-----|--------|
| `en` | `lib/language.dart` — **default** |
| `hu` | `lib/language.dart` |
| `ru`, `tr` | `Languages/LangExtentions/*.json` через `supportedLanguages.json`, **также bundled как Flutter assets** |

Другие паки (DE, RO, UA, AR, ES, ZH, Pirate) **удалены**.

Пункт Settings **Contacts** — ключ `topmenu_buttons_Contacts`. Тела уведомлений о платежах — `notif_payment_Body*`. Недостающие ключи в скачанном/кэшированном RU/TR падают в EN, если их не заполнит **bundled**-merge (`AppStrings.loadBundledLanguagePacks` до `initialize`). Пакеты на GitHub `main` должны совпадать с набором ключей EN, чтобы сетевой refresh не отставал.

**Chrome деталей занятия / предмета** (диалог тапа по календарю + задача: Тип / Преподаватель / Аудитория / Закрыть / загрузка аудитории / плейсхолдеры) — `courseDetail_*` + `popup_case4_5_SubjectCode`. **Названия предметов, типы курсов (напр. Előadás), аудитории и ФИО из Neptun** остаются на языке ответа API — часто венгерский даже при EN UI.

Также через `LanguagePack`: тела уведомлений о занятиях/экзаменах (`notif_exam_*`, `notif_class_*`), подпись масштаба шрифта, ошибки почты, 2FA popup (`popup_case9_*`), UX Android-updater (`updater_*`), пользовательские fallback/DEMO API (`api_fallback_*`, `api_demo_*`), ошибки транспорта/почты (`api_error_*`, `mail_preview_TapToLoadBody`) и сообщения об истечении сессии в API (`auth_sessionExpired_PleaseSignIn`).

### 10.7 ICS

`lib/API/ics_calendar.dart`, `SetupPageCalendarLogin`, `file_picker`. С экрана выбора входа **кнопки нет**. Код живой, если в кэше `getHasICSFile()`.

---

## 11. Честность: full vs thin

| Область | Уровень | Комментарий |
|---------|---------|-------------|
| Android клиент (логин, 4 вкладки + drawer, кэш) | **Full / mid-beta** | Реальный API, не каркас. Nav IA **1c** |
| iOS симулятор + release на устройстве | **Working** | Bundle без `_`; signing Automatic |
| Modern JWT + refresh | **Solid** | |
| 2FA modern TOTP (портал ELTE) | **Working MVP** | Login2FA + OuterLogin JWT на hallgatoN. **Student web full** → snackbar `loginStudentWebFull` (не «неверный пароль») |
| 2FA modern email | **HAR известен; UI тонкий** | `RequestEmailCode` + CodePrefix |
| JWT Authenticate на neptun.elte.hu | **Мёртв для ELTE** | Пустой HTTP 400; AD → портал |
| Old API 2FA | **Нет** | |
| Локальные уведомления iOS | **Working MVP** | Нет exact alarm как на Android |
| ICS | **Dead UI** | Класс есть, входа с setup нет |
| Homescreen widget | **Удалён** | Был заглушкой |
| APK / Play update | **Android only** | На iOS скрыто |
| Номер учебной недели | **Исправлено (сент. 2026)** | Понедельник сезона (неделя 1 сент./1 февр.) + учебный период; без якоря регистрации; онлайн-refresh перезаписывает кэш |
| Тесты | **Нет** | Папки `test/` нет |
| App Store / Play production | **Не цель текущего состояния** | |
| Фото в drawer | **Работает** | ELTE HWEB: `data.userAvatar.image` на `/api/UserInfo` + `/api/General/GetUserAvatar?imageSizeType=Normal` (base64 JPEG). Кэш в `DataCache`; drawer `MemoryImage`; инициалы при ошибке/пустом ответе |
| Строка training ID в drawer | **Убрана** | Сырой `studentTrainingId` / GUID не показывается под именем; человекочитаемые подписи — только в dropdown при нескольких training |

Монолит: `main_page.dart`, `api_coms.dart`, `popup.dart`, `setup_page.dart`, `language.dart` — по ~1400–2600 строк. **Не дробить**, пока цель — iOS/логин, не рефакторинг.

---

## 12. Слой данных

`DataCache` (`lib/storage.dart`) — единственный слой.

Кэш флагов: календарь, зачётка, платежи, периоды, почта, первая неделя, список терминов. При потере сети UI читает кэш. Это **не** полноценный offline-продукт.

Секреты: username/password/JWT/device cookie в secure storage (миграция со старого SharedPreferences).

`sessionWipeKeepCache` — обычный logout / истечение сессии: стирает пароль/токены/device cookie/`HasLogin`, **сохраняет username + учебный кэш** (календарь / зачётка / платежи / периоды / почта / семестры / аватар). `dataWipe` — полный wipe prefs включая кэш (только hard reset). Drawer показывает фото профиля HWEB при наличии, иначе **инициалы** из имени / кода Neptun.

Аналитики в git **нет** (`.gitignore`: `/lib/app_analitics_server_send.dart`).

---

## 13. Уведомления

`lib/notifications.dart` — **не** remote push.

| Тип | Когда (логика) |
|-----|----------------|
| Пары | за 10 мин, 5 мин, в начале |
| Экзамены | за ~2 недели |
| Платежи | ежедневно, пока не оплачено |
| Периоды | за день и в день старта |

- Android: каналы + exact alarm permission.  
- iOS: `DarwinInitializationSettings`, `requestPermissions`.  
- Имена каналов — венгерский хардкод.  
- На симуляторе iOS уведомления врут; проверять на устройстве.

---

## 14. iOS

### Краткая шпаргалка

Идентичность, API, 2FA, кэш и языки — в этом файле. Чеклист на каждый день:

| Пункт | Значение |
|------|--------|
| Display name | **Neptun ELTE** |
| iOS Bundle ID | `com.nanda070.neptunmobile` (без `_` — иначе Xcode ломает provisioning) |
| Android `applicationId` | `com.nanda070.neptun_mobile.app` |
| Dart-пакет | `neptun2` |
| Язык по умолчанию | English |
| Темы | только Light / Dark (сохраняются; системная яркость не перезаписывает) |
| Баг-репорты | https://nanda.is-a.dev |
| Скоуп | **только ELTE** — портал `https://neptun.elte.hu`; HWEB SPA `hallgatoN.neptun.elte.hu` |

```bash
flutter pub get
cd ios && pod install && cd ..
flutter devices

# Симулятор
flutter run -d "iPhone 17 Pro"

# Телефон: с иконки нужен release (iOS 14+ debug так не открывается)
flutter run --release -d Nanda
```

Signing: `ios/Runner.xcworkspace` → Automatically manage signing → Team.  
На телефоне: **Settings → General → VPN & Device Management** → доверить разработчику.

### Идентичность

| Поле | Значение |
|------|----------|
| Display name | `Neptun ELTE` (`CFBundleDisplayName` / Android `android:label`) |
| `CFBundleName` | `NeptunELTE` |
| Bundle ID | **`com.nanda070.neptunmobile`** |
| Tests | `com.nanda070.neptunmobile.RunnerTests` |
| Team (локальная разработка) | `48FW5533N7` (Automatic signing) |
| `PRODUCT_NAME` | `Runner` (не менять — ломает Flutter) |

**Почему Bundle ID без underscore:** Automatic Signing строит имя профиля `XC com nanda070 neptun_mobile app`. Подчёркивания в этом имени недопустимы → `The attribute 'name' is invalid` / no profiles.

Android `applicationId` **другой**: `com.nanda070.neptun_mobile.app`. Так и задумано после фикса Xcode.

### Debug vs release

На **iOS 14+** debug-сборку **нельзя** открыть с иконки — только из Flutter / Xcode. Для домашнего экрана: `flutter run --release` / `flutter build ios --release`.

### Signing / устройство

1. `open ios/Runner.xcworkspace`  
2. Runner → Signing & Capabilities → Automatically manage signing → Team.  
3. iPhone: **Settings → General → VPN & Device Management** → доверить Apple Development.  
4. Установка: `flutter run --release -d Nanda` или `xcrun devicectl device install app`.

### Info.plist (важное)

- `NSUserNotificationsUsageDescription`
- `LSApplicationQueriesSchemes`: `https`, `http`, `mailto`, `tg`, `telegram`, `discord`

### Известные iOS-дыры vs Android-only

Полное сравнение: [`IOS_VS_ANDROID.ru.md`](IOS_VS_ANDROID.ru.md) (EN: [`IOS_VS_ANDROID.md`](IOS_VS_ANDROID.md)).

| Фича | iOS |
|------|-----|
| Ссылки (`url_launcher`) | Должны работать (Android-gate снят) |
| Haptics | `HapticFeedback` |
| APK updater / Play IAU | Скрыто / не вызывать |
| Fluttertoast | Часто не виден; есть `custom_snackbar.dart` |
| SPM warning | `flutter_secure_storage`, `open_filex` — пока не блокер |

### Команды

```bash
cd /path/to/Neptun-ELTE
flutter pub get
cd ios && pod install && cd ..

# Симулятор
flutter run -d "iPhone 17 Pro"

# Телефон, иконка с домашнего экрана
flutter run --release -d Nanda
```

Пересоздать оболочку (не трёт `lib/`):

```bash
flutter create --platforms=ios --org com.nanda070 --project-name neptun2 .
```

После create проверить Bundle ID = `com.nanda070.neptunmobile` (не `neptun_mobile`).

---

## 15. Android

Сравнение с iOS: [`IOS_VS_ANDROID.ru.md`](IOS_VS_ANDROID.ru.md).

| Поле | Значение |
|------|----------|
| `applicationId` / namespace | `com.nanda070.neptun_mobile.app` |
| `compileSdk` | 36 |
| Java / Kotlin | 17 |
| minSdk | `flutter.minSdkVersion` |

```bash
flutter pub get
flutter run -d android
flutter build apk --debug
```

Play: `in_app_update`, если `installerStore == com.android.vending`. Иначе GitHub APK (`lib/Misc/auto_updater.dart`) — **только Android**.

CI: `.github/workflows/betabuild.yml` — Ubuntu, debug APK, **без** analyze/test/iOS.

---

## 16. Отключённые / удалённые функции

| Функция | Состояние |
|---------|-----------|
| Donate / Buy Me a Coffee | Удалено из UI |
| zoligamer branding | Вычищен (пакеты, funding, URL тем/языков) |
| Pirate + DE/RO/UA/AR/ES/ZH | Удалены из каталога языков |
| `linux/` | Удалён |
| Homescreen widget stub | Удалён |
| `AppUpdateHelper` / `appMinimumAllowedVersion.json` | Удалены (мёртвый version-gate) |
| `cupertino_icons`, `change_app_package_name` | Убраны из pubspec |
| ICS с первого экрана | Не подключён |
| Popup mode 1 (старые настройки) | Мёртвый дубль `settings_page.dart` |
| Popup 2 / 6 / 7 | По сути без caller (рейтинг Play / logout unavailable / old version) |
| Аналитика | Файла в git нет |
| App Store | Не настроено |
| Remote institutes URL (cloudapp) | Константа есть, не вызывается |

---

## 17. Переменные окружения

Секретов и `.env` у клиента **нет**.

Конфиги «снаружи» — JSON на GitHub `main`:

- `universityNameUrlPairs.json`
- `Languages/supportedLanguages.json`
- `Themes/supportedThemes.json`

Android release signing: локальный `key.properties` (не в git).

iOS: Team / профиль в Xcode, не в репо.

---

## 18. Сборка, CI, запуск

### Локально

```bash
flutter pub get
flutter devices
flutter run -d <device-id>
```

Release на iPhone: `--release` (см. §14).

### CI

Только `flutter build apk --debug --no-shrink` на `ubuntu-latest`. iOS job **нет**.

### GitHub raw

Пока изменения JSON не в `main` на `Nanda070/Neptun-ELTE`, приложение у пользователей качает **старый** список вузов/языков.

---

## 19. История и контакты

Проект независимый под **Nanda070**. Не позиционировать как «форк zoligamer» в продуктовой идентичности.

Исторически работали над связанным кодом: **domedav** (Neptun 2), **zoligamer** (предыдущий форк).

| | |
|--|--|
| GitHub | [Nanda070](https://github.com/Nanda070) |
| Discord | nandak070 |
| Telegram | nanda070 |
| Email | adnan.huseynli1@gmail.com |
| Web | https://nanda.is-a.dev/ · cheterin.online · chetmedia.com |

Баг-репорты: https://nanda.is-a.dev (ссылки в приложении; не форма GitHub Issues)

Лицензия: LGPL-3.0-only ([`docs/LICENSE`](../LICENSE); корневой `LICENSE` — идентичная копия для GitHub).

---

## 20. Ключевые решения «почему так»

| Решение | Почему |
|---------|--------|
| Два Bundle ID (iOS без `_`) | Xcode Automatic Signing ломается на `neptun_mobile` в имени профиля |
| Не дробить монолиты сейчас | Нет тестов; цель — платформа и логин, не Clean Architecture |
| EN default, только EN/HU/RU/TR | Запрос владельца; меньше мёртвых паков |
| GitHub raw для вузов/языков/тем | Обновление без релиза APK/IPA |
| `badCertificateCallback => true` | Вузы с кривыми сертификатами; риск MITM принят |
| Убрана устаревшая плашка «2FA не работает» | В ELTE 2FA обязательна; приложение умеет ввод кода |
| Нет deep-link / auto-OTP из Authenticator | TOTP вводится вручную; Microsoft Authenticator снаружи |
| Нет email OTP (`XXX-XXXXXX`) пока | Нужен Network capture кнопки E-mail и формата `token` |
| `loginServerBusy` ≠ invalid password | Перегрузка Neptun маскировалась под «неверный пароль» |
| `loginStudentWebFull` ≠ invalid password | Переполнение HWEB после верного 2FA красилось как неверный пароль (`submitTwoFactor` → `false` → `_paintRed`) |
| Хаб ELTE → `https://neptun.elte.hu` | Портал + JWT API. HWEB балансируется по `hallgato1…N` после `/ToNeptunWeb/ToNeptunHWeb` — один узел не хардкодить |
| Один вуз в JSON | Продукт только ELTE; мульти-пикер убран с хаба |
| ICS оставить в коде | Может быть у старых юзеров; UI не рекламировать |
| Release на iOS для иконки | Системное ограничение debug с iOS 14 |
| Нет своего backend | Клиент ходит в вуз напрямую |
| `Provider` только для темы | Исторический монолит; не вводить Bloc «на всякий» |

---

## 21. Карта важных файлов

| Файл | Зачем |
|------|-------|
| `docs/README.md` / `docs/README.ru.md` | Пользовательский обзор |
| `docs/Technical/TECHNICAL.md` | Этот документ (EN) |
| `docs/Technical/TECHNICAL.ru.md` | Русская версия |
| `docs/Technical/IOS_VS_ANDROID.md` / `IOS_VS_ANDROID.ru.md` | Матрица iOS vs Android |
| `docs/Technical/IMPLEMENTATION_PLAN.md` / `IMPLEMENTATION_PLAN.ru.md` | Приоритетный план реализации (не сделано) |
| `docs/Technical/DEV_BLOG.md` / `DEV_BLOG.ru.md` | Хронологический Dev Blog |
| `docs/Legal-En/` · `Legal-Ru/` · `Legal-Hu/` | Privacy, Terms, Cookies |
| `docs/LICENSE` | LGPL-3.0-only (канон); корневой `LICENSE` зеркалирует |
| `pubspec.yaml` | Версия, зависимости |
| `lib/main.dart` | `MaterialApp`, тема, `Splitter` |
| `lib/Pages/startup_page.dart` | Ветка login / home |
| `lib/Pages/setup_page.dart` | Вход, URL, 2FA callback, ICS-класс |
| `lib/Pages/main_page.dart` | Home + **4** нижние вкладки + drawer Payments (**1c**) |
| `lib/Pages/settings_page.dart` | Живые настройки (Contacts + версия внизу) |
| `lib/API/api_coms.dart` | Весь HTTP, логин, нормализация URL |
| `lib/API/ics_calendar.dart` | Парсер ICS |
| `lib/storage.dart` | `DataCache` |
| `lib/language.dart` | EN/HU + загрузка RU/TR |
| `lib/colors.dart` | Палитры |
| `lib/notifications.dart` | Локальные нотификации |
| `lib/haptics.dart` | Android vibration / iOS `HapticFeedback` |
| `lib/Misc/popup.dart` | Режимы 0–9 (9 = 2FA) |
| `lib/Misc/elte_room_code.dart` | Разбор кодов аудиторий ELTE + тап-расшифровка |
| `lib/Misc/app_drawer.dart` | Drawer |
| `lib/Misc/auto_updater.dart` | GitHub APK, Android-only |
| `universityNameUrlPairs.json` | Вузы — **только ELTE** (`https://neptun.elte.hu`) |
| `Languages/supportedLanguages.json` | Каталог RU/TR |
| `Themes/supportedThemes.json` | Remote-темы |
| `ios/Runner/Info.plist` | Display name, нотификации, URL schemes |
| `ios/Runner.xcodeproj/project.pbxproj` | Bundle ID, Team |
| `android/app/build.gradle` | `applicationId` |
| `.github/workflows/betabuild.yml` | Android CI |

---

*Конец документа. При расхождении с кодом приоритет у кода и свежего `git log`.*
