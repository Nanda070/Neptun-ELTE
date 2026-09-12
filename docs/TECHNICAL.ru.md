# Neptun Mobile — техническая документация

> 🇬🇧 [English](TECHNICAL.md)

> **Аудитория:** разработчики и люди с доступом к репозиторию.  
> Файл только в git (`docs/TECHNICAL.ru.md`). **Не** публикуется как сайт, **не** имеет отдельного веб-маршрута.  
> Идентификаторы кода, пути, пакеты и API-маршруты — на английском, как в репозитории.

Последняя сверка с кодовой базой: **сентябрь 2026** (iOS-таргет, языки EN/HU/RU/TR, логин modern API + 2FA-код, ELTE URL, разделение «неверный пароль» vs «сервер занят»). Источники: `lib/**`, `pubspec.yaml`, `ios/`, `android/`, `Languages/`, `Themes/`, `universityNameUrlPairs.json`, `.github/`.

Короткий iOS-шпаргалка: [`docs/DEVELOPER.md`](DEVELOPER.md). Продуктовый обзор: [`README.md`](../README.md) / [`README.ru.md`](../README.ru.md).

---

## Оглавление

1. [Обзор продукта](#1-обзор-продукта)
2. [Репозиторий](#2-репозиторий)
3. [Стек](#3-стек)
4. [Архитектура и поток запросов](#4-архитектура-и-поток-запросов)
5. [Экраны](#5-экраны)
6. [Setup / вход](#6-setup--вход)
7. [Home tabs (5 вкладок)](#7-home-tabs-5-вкладок)
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

**Neptun Mobile** — неофициальный мобильный клиент университетской системы **Neptun** (SDA Informatika): расписание, зачётка, платежи, периоды, сообщения.

- Целевая аудитория: студенты вузов, у которых есть Neptun-код и студенческий портал.
- Список институтов: `universityNameUrlPairs.json` (грузится с GitHub raw, не как Flutter-asset).
- Display name: **Neptun Mobile**.
- Версия (`pubspec.yaml`): **1.0.5+18**.
- Dart-пакет: `neptun2` (импорты `package:neptun2/...`).
- Языки UI: **EN** (дефолт) и **HU** вшиты; **RU** и **TR** качаются с GitHub.
- Платформы: **Android** и **iOS**. Web / Windows / macOS / Linux в репо **нет** (linux/ удалён).
- Это **не** официальное приложение SDA и **не** App Store / Play production-бренд.

Репозиторий: [Nanda070/Neptun-Mobile-fork](https://github.com/Nanda070/Neptun-Mobile-fork). Продукт независимый; прошлые авторы указаны только в credits.

---

## 2. Репозиторий

```
Neptun-Mobile-fork/
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
├── docs/                     # TECHNICAL.md (EN), TECHNICAL.ru.md, DEVELOPER.md
├── .github/workflows/        # Только Android debug APK
├── pubspec.yaml
├── README.md                 # EN, пользовательский
└── README.ru.md
```

| Путь | Назначение |
|------|------------|
| `lib/` | UI, API, кэш, уведомления |
| `android/` | Gradle, `applicationId` `com.nanda070.neptun_mobile.app` |
| `ios/` | Xcode, Bundle ID `com.nanda070.neptunmobile` |
| `Languages/` | Каталог скачиваемых языков (сейчас только `ru`, `tr`) |
| `Themes/` | Каталог скачиваемых тем |
| `docs/` | Документация для разработчиков |
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
   └─ HTTP → raw.githubusercontent.com/Nanda070/Neptun-Mobile-fork
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
| `SetupPageLoginTypeSelection` (`setup_page.dart`) | Выбор: список вузов **или** ручной URL |
| `SetupPageInstitudeSelection` | Поиск института |
| `SetupPageURLInput` | Ручной Neptun URL |
| `SetupPageLogin` | Neptun-код + пароль |
| `SetupPageCalendarLogin` | ICS-импорт (класс есть; **с первого экрана не открывается**) |
| `HomePage` (`lib/Pages/main_page.dart`) | 5 вкладок после входа |
| `SettingsPage` (`settings_page.dart`) | Тема, язык, шрифт, уведомления, хаптика, неделя |
| `AppDrawer` (`lib/Misc/app_drawer.dart`) | Семестр, баланс, настройки, апдейт (Android), выход |
| `PopupWidgetHandler` (`lib/Misc/popup.dart`) | Модальные режимы 0–9 |

---

## 6. Setup / вход

Порядок:

1. `Splitter` → если `getHasLogin()` → `HomePage`, иначе setup.
2. Тип входа: список институтов **или** URL.
3. Логин: код (в API уходит `toUpperCase()`) + пароль.
4. Демо: `DEMO` / `DEMO` → фейковые данные, без сети.

### Коды `InstitutesRequest.validateLoginCredentialsUrl`

| Код | Константа | UI |
|-----|-----------|-----|
| `1` | `loginOk` | Вход на Home |
| `2` | `loginNeeds2fa` | Popup mode 9 (6 цифр) |
| `0` | `loginInvalidCredentials` | Красные поля, «Invalid username or password!» |
| `3` | `loginServerBusy` | Snackbar «Neptun servers are having a hard time...» — **не** неверный пароль |

Таймаут modern login: **20 с** на кандидата URL. Пустой ответ / 5xx / timeout / HTML → `loginServerBusy`.

### Нормализация URL

`normalizeModernApiBaseUrl` снимает `/login`, `/MobileService.svc`, хвост `/Account`.

Для **ELTE** (`*.elte.hu` и путь пустой или `/Account`) базой становится `https://neptun.elte.hu/ujhallgato`.

Кандидаты modern login (`_modernLoginBaseCandidates`): primary → для ELTE ещё `/ujhallgato`, `/hallgato`, root. Первый **чёткий** invalid credentials останавливает перебор; busy пробует следующий.

**Не проверено живым ELTE-аккаунтом** (веб был «student web is full»). Предупреждение UI про 2FA **пока оставлено**.

После успеха **не** перезаписывать `instituteUrl` сырым URL из списка (иначе снова `/Account`). Пишется база, которую выставил логин.

---

## 7. Home tabs (5 вкладок)

`HomePageState` + `BottomNavigatorWidget`. Свайп влево/вправо. **Named routes нет.**

| Index | Иконка | Содержание |
|-------|--------|------------|
| 0 | calendar | Недельное расписание, пары/экзамены |
| 1 | backpack | Зачётка: кредиты, средний, ghost grade |
| 2 | price_change | Начисления, дедлайны; в drawer — баланс |
| 3 | timer | Периоды (регистрация, экзамены, запись) |
| 4 | email | Входящие, непрочитанные, mark read |

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
| Календарь | `/api/Calendar/GetCalendarEvents` |
| Детали пары | `/api/Calendar/GetCourseDetails` |
| Задания | `/api/Tasks/GetTaskDetail` |
| Предметы | `/api/TakenSubjects`, `/api/RegisteredCourses/GetRegisteredCourses` |
| Термины | `/api/RegisteredCourses/GetTerms`, `/api/TakenSubjects/Terms`, `/api/Periods/GetTerms` |
| Платежи | `/api/Transactions/GetStudentPreviousTransactions` |
| Баланс | `/api/FinancialDataDashboard/GetCollectiveInvoices` |
| Периоды | `/api/Periods/GetPeriods` |
| Почта | `/api/Message/GetUnreadedMessagesCount`, `GetReceivedMessages`, `/api/Messages/{id}/Posts` |

Тело логина:

```json
{
  "userName": "...",
  "password": "...",
  "captcha": "",
  "captchaIdentifier": "",
  "token": "",
  "LCID": 1038
}
```

При 2FA повтор с `token` = код; опционально `Authorization: Bearer` от `twoFactorLoginToken`. Cookie `devicecookie-<b64(username)>=...`.

Refresh / повторный логин при 401 — в `_APIRequest`.

---

## 9. Auth, 2FA, токены

| Что | Где |
|-----|-----|
| Пароль, JWT access/refresh, device cookie | `flutter_secure_storage` (`DataCache`) |
| Username, URL института, флаги кэша, настройки | `shared_preferences` |
| Демо | `setIsDemoAccount(1)` |

**2FA (modern):** ответ с `isTwoFactorRequired` / `requiresTwoFactor` / `twoFactorLoginToken` без `accessToken` (часто HTTP 202) → код `2` → popup 9 → `submitTwoFactorCode`.

**2FA (old):** не поддерживается → обычно `0`.

Плашка на логине (`loginPage_setupPage_2faWarning`) всё ещё говорит, что с 2FA войти нельзя. Текст **устарел относительно кода**. **Не удалять**, пока ELTE не проверен на живом аккаунте.

---

## 10. Доменные возможности

### 10.1 Расписание

Неделя, сдвиг `getUserWeekOffset()`, первая неделя семестра `getFirstWeekEpoch()`. Modern: `GetCalendarEvents` + детали курса.

### 10.2 Зачётка

Предметы, кредиты, средний, ghost grade (popup 0), конфетти.

### 10.3 Платежи / периоды / почта

Начисления и дедлайны; периоды с таймерами; входящие + mark read.

### 10.4 Настройки

Тема, язык, шрифт 80–140%, уведомления (4 типа), family-friendly тексты загрузки, вибрация, сдвиг недели, проверка обновлений (Android).

### 10.5 Темы

Вшитые (`lib/colors.dart`): Light, Dark, AMOLED Black, Midnight Ocean, Emerald Forest, плюс ещё две встроенные тёмные палитры.

Remote (`Themes/supportedThemes.json`): E-Ink, Gum, Forest, Blu.

### 10.6 Языки

| Код | Откуда |
|-----|--------|
| `en` | `lib/language.dart` — **default** |
| `hu` | `lib/language.dart` |
| `ru`, `tr` | `Languages/LangExtentions/*.json` через `supportedLanguages.json` |

Другие паки (DE, RO, UA, AR, ES, ZH, Pirate) **удалены**.

Тексты каналов уведомлений и часть заголовков настроек всё ещё **захардкожены по-венгерски**.

### 10.7 ICS

`lib/API/ics_calendar.dart`, `SetupPageCalendarLogin`, `file_picker`. С экрана выбора входа **кнопки нет**. Код живой, если в кэше `getHasICSFile()`.

---

## 11. Честность: full vs thin

| Область | Уровень | Комментарий |
|---------|---------|-------------|
| Android клиент (логин, 5 вкладок, кэш) | **Full / mid-beta** | Реальный API, не каркас |
| iOS симулятор + release на устройстве | **Working** | Bundle без `_`; signing Automatic |
| Modern JWT + refresh | **Solid** | |
| 2FA modern | **Код есть, live ELTE не подтверждён** | Плашка «не работает» оставлена |
| Old API 2FA | **Нет** | |
| Локальные уведомления iOS | **Working MVP** | Нет exact alarm как на Android |
| ICS | **Dead UI** | Класс есть, входа с setup нет |
| Homescreen widget | **Удалён** | Был заглушкой |
| APK / Play update | **Android only** | На iOS скрыто |
| Тесты | **Нет** | Папки `test/` нет |
| App Store / Play production | **Не цель текущего состояния** | |

Монолит: `main_page.dart`, `api_coms.dart`, `popup.dart`, `setup_page.dart`, `language.dart` — по ~1400–2600 строк. **Не дробить**, пока цель — iOS/логин, не рефакторинг.

---

## 12. Слой данных

`DataCache` (`lib/storage.dart`) — единственный слой.

Кэш флагов: календарь, зачётка, платежи, периоды, почта, первая неделя, список терминов. При потере сети UI читает кэш. Это **не** полноценный offline-продукт.

Секреты: username/password/JWT/device cookie в secure storage (миграция со старого SharedPreferences).

`dataWipe` — выход.

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

### Идентичность

| Поле | Значение |
|------|----------|
| Display name | `Neptun Mobile` (`CFBundleDisplayName`) |
| `CFBundleName` | `NeptunMobile` (без пробела — имя нативного таргета) |
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

| Фича | iOS |
|------|-----|
| Ссылки (`url_launcher`) | Должны работать (Android-gate снят) |
| Haptics | `HapticFeedback` |
| APK updater / Play IAU | Скрыто / не вызывать |
| Fluttertoast | Часто не виден; есть `custom_snackbar.dart` |
| SPM warning | `flutter_secure_storage`, `open_filex` — пока не блокер |

### Команды

```bash
cd /path/to/Neptun-Mobile-fork
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

Пока изменения JSON не в `main` на `Nanda070/Neptun-Mobile-fork`, приложение у пользователей качает **старый** список вузов/языков.

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

Issues: https://github.com/Nanda070/Neptun-Mobile-fork/issues

Лицензия: MIT (`LICENSE`).

---

## 20. Ключевые решения «почему так»

| Решение | Почему |
|---------|--------|
| Два Bundle ID (iOS без `_`) | Xcode Automatic Signing ломается на `neptun_mobile` в имени профиля |
| Не дробить монолиты сейчас | Нет тестов; цель — платформа и логин, не Clean Architecture |
| EN default, только EN/HU/RU/TR | Запрос владельца; меньше мёртвых паков |
| GitHub raw для вузов/языков/тем | Обновление без релиза APK/IPA |
| `badCertificateCallback => true` | Вузы с кривыми сертификатами; риск MITM принят |
| 2FA-плашку не удалять | Live ELTE не подтверждён; веб был full |
| `loginServerBusy` ≠ invalid password | Перегрузка Neptun маскировалась под «неверный пароль» |
| ELTE → `/ujhallgato` | `/Account` — SPA, не REST; путь из документации neptun-api, **не** из live capture |
| ICS оставить в коде | Может быть у старых юзеров; UI не рекламировать |
| Release на iOS для иконки | Системное ограничение debug с iOS 14 |
| Нет своего backend | Клиент ходит в вуз напрямую |
| `Provider` только для темы | Исторический монолит; не вводить Bloc «на всякий» |

---

## 21. Карта важных файлов

| Файл | Зачем |
|------|-------|
| `README.md` / `README.ru.md` | Пользовательский обзор |
| `docs/TECHNICAL.md` | Этот документ (EN) |
| `docs/TECHNICAL.ru.md` | Русская версия |
| `docs/DEVELOPER.md` | Короткая iOS-шпаргалка |
| `pubspec.yaml` | Версия, зависимости |
| `lib/main.dart` | `MaterialApp`, тема, `Splitter` |
| `lib/Pages/startup_page.dart` | Ветка login / home |
| `lib/Pages/setup_page.dart` | Вход, URL, 2FA callback, ICS-класс |
| `lib/Pages/main_page.dart` | Home + 5 вкладок |
| `lib/Pages/settings_page.dart` | Живые настройки |
| `lib/API/api_coms.dart` | Весь HTTP, логин, нормализация URL |
| `lib/API/ics_calendar.dart` | Парсер ICS |
| `lib/storage.dart` | `DataCache` |
| `lib/language.dart` | EN/HU + загрузка RU/TR |
| `lib/colors.dart` | Палитры |
| `lib/notifications.dart` | Локальные нотификации |
| `lib/haptics.dart` | Android vibration / iOS `HapticFeedback` |
| `lib/Misc/popup.dart` | Режимы 0–9 (9 = 2FA) |
| `lib/Misc/app_drawer.dart` | Drawer |
| `lib/Misc/auto_updater.dart` | GitHub APK, Android-only |
| `universityNameUrlPairs.json` | Вузы (ELTE: `…/ujhallgato`) |
| `Languages/supportedLanguages.json` | Каталог RU/TR |
| `Themes/supportedThemes.json` | Remote-темы |
| `ios/Runner/Info.plist` | Display name, нотификации, URL schemes |
| `ios/Runner.xcodeproj/project.pbxproj` | Bundle ID, Team |
| `android/app/build.gradle` | `applicationId` |
| `.github/workflows/betabuild.yml` | Android CI |

---

*Конец документа. При расхождении с кодом приоритет у кода и свежего `git log`.*
