# Neptun ELTE — technical documentation

> 🇷🇺 [Русская версия](TECHNICAL.ru.md)

> **Audience:** developers and anyone with repo access.  
> Git-only (`docs/TECHNICAL.md`). **Not** published as a website, **no** public route.  
> Code identifiers, paths, packages, and API routes stay in English, as in the repo.

Last sync with the codebase: **September 2026** (repo **Neptun-ELTE**, display name Neptun ELTE, ELTE-only hub, no `/ujhallgato` for ELTE, languages EN/HU/RU/TR, modern API login + 2FA code path, “invalid password” vs “server busy”). Sources: `lib/**`, `pubspec.yaml`, `ios/`, `android/`, `Languages/`, `Themes/`, `universityNameUrlPairs.json`, `.github/`.

Short iOS cheatsheet: [`docs/DEVELOPER.md`](DEVELOPER.md). Product overview: [`README.md`](../README.md) / [`README.ru.md`](../README.ru.md).

---

## Contents

1. [Product overview](#1-product-overview)
2. [Repository](#2-repository)
3. [Stack](#3-stack)
4. [Architecture and request flow](#4-architecture-and-request-flow)
5. [Screens](#5-screens)
6. [Setup / login](#6-setup--login)
7. [Home tabs (5)](#7-home-tabs-5)
8. [Neptun APIs](#8-neptun-apis)
9. [Auth, 2FA, tokens](#9-auth-2fa-tokens)
10. [Domain features](#10-domain-features)
11. [Honesty: full vs thin](#11-honesty-full-vs-thin)
12. [Data layer](#12-data-layer)
13. [Notifications](#13-notifications)
14. [iOS](#14-ios)
15. [Android](#15-android)
16. [Removed / disabled](#16-removed--disabled)
17. [Environment](#17-environment)
18. [Build, CI, run](#18-build-ci-run)
19. [History and contacts](#19-history-and-contacts)
20. [Why we chose this](#20-why-we-chose-this)
21. [Important files](#21-important-files)

---

## 1. Product overview

**Neptun ELTE** is an unofficial mobile client for **ELTE** (Eötvös Loránd University) **Neptun** (SDA Informatika): timetable, markbook, payments, periods, messages.

- **Scope:** ELTE only. Not a multi-university picker.
- Institute list file still exists as `universityNameUrlPairs.json` but contains **a single entry**: ELTE → `https://neptun.elte.hu`.
- Setup UI is an **ELTE hub**: one button → login (no institute list, no custom URL).
- ELTE uses a **central** Neptun host (`neptun.elte.hu` / `Account/Login`). It does **not** use Obuda/BME-style `/ujhallgato`. After web login, students open **Hallgatói web (HWEB)** in the top menu; the mobile client talks to the modern JWT API on the same host.
- Display name: **Neptun ELTE**.
- Version (`pubspec.yaml`): **1.0.5+18**.
- Dart package: `neptun2` (imports `package:neptun2/...`).
- UI languages: **EN** (default) and **HU** built-in; **RU** and **TR** downloaded from GitHub.
- Platforms: **Android** and **iOS**. No `web/`, Windows, macOS, or Linux in this repo (`linux/` was removed).
- This is **not** an official SDA/ELTE app and **not** an App Store / Play production brand.

Repo: [Nanda070/Neptun-ELTE](https://github.com/Nanda070/Neptun-ELTE). Independent product; earlier authors are credits only.

---

## 2. Repository

```
Neptun-ELTE/
├── lib/                      # Entire product (Dart)
│   ├── main.dart
│   ├── storage.dart          # DataCache singleton
│   ├── language.dart         # EN/HU + remote packs
│   ├── colors.dart           # Themes
│   ├── notifications.dart
│   ├── haptics.dart
│   ├── API/                  # Neptun HTTP + ICS parser
│   ├── Pages/                # Screens
│   ├── Navigator/            # Top / bottom nav
│   ├── Misc/                 # Drawer, popup, updater, snackbar
│   └── *Elements/            # Tab widgets
├── android/                  # Native Android
├── ios/                      # Native iOS (flutter create)
├── Languages/                # supportedLanguages.json + JSON packs
├── Themes/                   # supportedThemes.json + palettes
├── universityNameUrlPairs.json
├── docs/                     # TECHNICAL.md (EN), TECHNICAL.ru.md, DEVELOPER.md
├── .github/workflows/        # Android debug APK only
├── pubspec.yaml
├── README.md                 # EN product README
└── README.ru.md
```

| Path | Role |
|------|------|
| `lib/` | UI, API, cache, notifications |
| `android/` | Gradle, `applicationId` `com.nanda070.neptun_mobile.app` |
| `ios/` | Xcode, Bundle ID `com.nanda070.neptunmobile` |
| `Languages/` | Downloadable language catalog (`ru`, `tr` only) |
| `Themes/` | Downloadable theme catalog |
| `docs/` | Developer documentation |
| `.github/workflows/betabuild.yml` | CI: `flutter build apk --debug` |

**Missing:** `test/`, `web/`, `linux/`, `macos/`, `windows/`, and any first-party backend.

---

## 3. Stack

| Layer | Tech |
|-------|------|
| UI | **Flutter** / **Dart** `>=3.1.4 <4.0.0`, **Material 3** |
| State | `provider` — theme only (`ThemeNotifier`); everything else is the `DataCache` singleton |
| Network | `http` (primary), `dio` (APK download on Android) |
| Local | `shared_preferences`, `flutter_secure_storage`, `path_provider`, `file_picker` |
| Notifications | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Other | `url_launcher`, `package_info_plus`, `device_info_plus`, `connectivity_plus`, `vibration`, `fluttertoast`, `open_filex`, `flutter_native_splash`, `linked_scroll_controller` |
| Android-only | `in_app_update` (Play), `AppUpdater` (GitHub APK) |
| Navigation | **No named routes**: `Navigator.push` + bottom-nav index |

There is **no** app backend. Academic data comes from the selected institute’s Neptun. Languages / themes / institute list come from this repo’s GitHub raw files.

---

## 4. Architecture and request flow

```
Device (Android / iOS)
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

**Invariants:**

1. No first-party backend, no push server. Notifications are **local**.
2. Modern vs old API is chosen from the URL (`.aspx` → old; otherwise modern) plus `DataCache.getIsModernApi()`.
3. `Provider` does not hold academic data.
4. TLS: `NeptunCerts.badCertificateCallback` accepts **any** certificate (`lib/API/api_coms.dart`). Needed for broken campus TLS; MITM risk is accepted.
5. The in-app institute list is fetched from **`main` on GitHub**. Local JSON in a checkout is unused until it is pushed.

---

## 5. Screens

Navigation: `MaterialPageRoute`, no `routes:` map.

| Widget / file | Role |
|---------------|------|
| `Splitter` (`lib/Pages/startup_page.dart`) | Splash: load cache, theme, languages; login vs home |
| `SetupPageLoginTypeSelection` (`setup_page.dart`) | **ELTE hub** — one button → login (no institute list / custom URL) |
| `SetupPageInstitudeSelection` | Legacy list UI (unused by hub; list JSON is ELTE-only) |
| `SetupPageURLInput` | Legacy custom URL (not shown on hub) |
| `SetupPageLogin` | Neptun-код + password |
| `SetupPageCalendarLogin` | ICS import (class exists; **not opened from the hub**) |
| `HomePage` (`lib/Pages/main_page.dart`) | 5 tabs after login |
| `SettingsPage` (`settings_page.dart`) | Theme, language, font, notifications, haptics, week offset |
| `AppDrawer` (`lib/Misc/app_drawer.dart`) | Term, balance, settings, update (Android), logout |
| `PopupWidgetHandler` (`lib/Misc/popup.dart`) | Modal modes 0–9 |

---

## 6. Setup / login

### How ELTE web works (official)

User flow on `neptun.elte.hu` ([ELTE guide](https://www.elte.hu/en/neptun-administration-of-progress)):

1. Open central portal → **Log in** (Neptun ID 6 chars + password).
2. **Two-step authentication** — code from authenticator app **or** primary Neptun email.
3. After auth, click **Student web** / Open student web (HWEB) in the top menu.

There is **no** separate `/ujhallgato` for ELTE (unlike Óbuda/BME). One central host; HWEB is a post-login destination in the portal UI.

### How this app maps that flow

| Web step | App |
|----------|-----|
| Portal login | `POST https://neptun.elte.hu/api/Account/Authenticate` |
| 2FA (app or email code) | Same endpoint again with `token` = 6-digit code → popup mode 9 |
| Open Student web | **No browser button** — after JWT `accessToken`, student data APIs are called directly (calendar, subjects, …). That is the mobile equivalent of being inside Student web. |

App setup UI:

1. `Splitter` → if `getHasLogin()` then `HomePage`, else ELTE hub (**display name: Neptun ELTE**).
2. Hub sets `PageDTO` to `elteInstituteName` + `elteNeptunBaseUrl` (`https://neptun.elte.hu`) → `SetupPageLogin`.
3. Credentials: Neptun code (`toUpperCase()`) + password.
4. If API returns 2FA → enter 6-digit code (authenticator **or** email OTP).
5. Demo: `DEMO` / `DEMO`.

**Honesty:** Live ELTE login still depends on Neptun availability. Email 2FA on the website may include a “send code” choice before the digits appear; the app currently accepts the **same 6-digit `token` field** used by the modern Neptun JWT client (as in other universities). If ELTE requires an extra “send email OTP” API call before the code works, that still needs a live Network capture to wire. The in-app 2FA warning banner is **kept** until a live check succeeds.

Constants: `InstitutesRequest.elteInstituteName`, `elteNeptunBaseUrl`.

### `InstitutesRequest.validateLoginCredentialsUrl` codes

| Code | Constant | UI |
|------|----------|-----|
| `1` | `loginOk` | Enter Home |
| `2` | `loginNeeds2fa` | Popup mode 9 (6 digits — app or email) |
| `0` | `loginInvalidCredentials` | Red fields, “Invalid username or password!” |
| `3` | `loginServerBusy` | Snackbar “Neptun servers are having a hard time...” — **not** a bad password |

Modern login timeout: **20 s** per URL candidate. Empty body / 5xx / timeout / HTML → `loginServerBusy`.

### URL normalization (ELTE)

`normalizeModernApiBaseUrl` strips `/login`, `/MobileService.svc`, `/Account`, `/Account/Login`.

API base: **`https://neptun.elte.hu`** — not `/ujhallgato`.

Candidates: primary + ELTE root aliases only.

On success, persist the API base login selected (do not overwrite with a stale list URL).

---

## 7. Home tabs (5)

`HomePageState` + `BottomNavigatorWidget`. Swipe left/right. **No named routes.**

| Index | Icon | Content |
|-------|------|---------|
| 0 | calendar | Week timetable, classes/exams |
| 1 | backpack | Markbook: credits, average, ghost grade |
| 2 | price_change | Fees and deadlines; drawer shows balance |
| 3 | timer | Periods (registration, exams, subject signup) |
| 4 | email | Inbox, unread, mark read |

Term: `getSelectedTermId()` / `getSelectedTermName()`, term list is cached.

---

## 8. Neptun APIs

Two families in `lib/API/api_coms.dart`.

### Old (`*.aspx` / `MobileService.svc`)

Base: `{host}/…/MobileService.svc`.

| `URLs` constant | Path |
|-----------------|------|
| `TRAININGS_URL` | `/api/GetTrainings` |
| `CALENDAR_URL` | `/api/GetCalendarData` |
| `MARKBOOK_URL` | `/api/GetMarkbookData` |
| `GETCASHIN_URL` | `/api/GetCashinData` |
| `PERIODS_URL` | `/api/GetPeriods` |
| `MESSAGES_URL` | `/api/GetMessages` |
| `MESSAGE_SET_READ` | `/api/SetReadedMessage` |

`URLs.INSTITUTIONS_URL` (cloudapp) is **not** called. The live institute list is the GitHub JSON.

**No 2FA on the old API.**

### Modern (JWT)

Base: `{institute without /Account}` + `/api/...`.

| Purpose | Path (examples) |
|---------|-----------------|
| Login / 2FA | `POST /api/Account/Authenticate` |
| Refresh | `POST /api/Account/GetNewTokens` |
| Trainings | `/api/Calendar/GetStudentTrainings`, `/api/UserInfo`, `/api/ContextUserProfile/MyTrainings` |
| Calendar | `/api/Calendar/GetCalendarEvents` |
| Class details | `/api/Calendar/GetCourseDetails` |
| Tasks | `/api/Tasks/GetTaskDetail` |
| Subjects | `/api/TakenSubjects`, `/api/RegisteredCourses/GetRegisteredCourses` |
| Terms | `/api/RegisteredCourses/GetTerms`, `/api/TakenSubjects/Terms`, `/api/Periods/GetTerms` |
| Payments | `/api/Transactions/GetStudentPreviousTransactions` |
| Balance | `/api/FinancialDataDashboard/GetCollectiveInvoices` |
| Periods | `/api/Periods/GetPeriods` |
| Mail | `/api/Message/GetUnreadedMessagesCount`, `GetReceivedMessages`, `/api/Messages/{id}/Posts` |

Login body:

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

For 2FA, resend with `token` = code; optionally `Authorization: Bearer` from `twoFactorLoginToken`. Cookie `devicecookie-<b64(username)>=...`.

Refresh / re-login on 401 lives in `_APIRequest`.

---

## 9. Auth, 2FA, tokens

| What | Where |
|------|-------|
| Password, JWT access/refresh, device cookie | `flutter_secure_storage` (`DataCache`) |
| Username, institute URL, cache flags, settings | `shared_preferences` |
| Demo | `setIsDemoAccount(1)` |

**2FA (modern):** `isTwoFactorRequired` / `requiresTwoFactor` / `twoFactorLoginToken` without `accessToken` (often HTTP 202) → code `2` → popup 9 → `submitTwoFactorCode`.

**2FA (old):** unsupported → usually `0`.

The login banner (`loginPage_setupPage_2faWarning`) still says 2FA cannot log in. That text is **stale vs the code**. **Do not remove** until ELTE is verified on a live account.

---

## 10. Domain features

### 10.1 Timetable

Week view, `getUserWeekOffset()`, first study week `getFirstWeekEpoch()`. Modern: `GetCalendarEvents` + course details.

### 10.2 Markbook

Subjects, credits, average, ghost grade (popup 0), confetti.

### 10.3 Payments / periods / mail

Charges and deadlines; periods with timers; inbox + mark read.

### 10.4 Settings

Theme, language, font 80–140%, four notification types, family-friendly loading copy, haptics, week offset, update check (Android).

### 10.5 Themes

Built-in (`lib/colors.dart`): Light, Dark, AMOLED Black, Midnight Ocean, Emerald Forest, plus two more built-in dark palettes.

Remote (`Themes/supportedThemes.json`): E-Ink, Gum, Forest, Blu.

### 10.6 Languages

| Code | Source |
|------|--------|
| `en` | `lib/language.dart` — **default** |
| `hu` | `lib/language.dart` |
| `ru`, `tr` | `Languages/LangExtentions/*.json` via `supportedLanguages.json` |

Other packs (DE, RO, UA, AR, ES, ZH, Pirate) were **removed**.

Notification channel names and some settings headers are still **hardcoded Hungarian**.

### 10.7 ICS

`lib/API/ics_calendar.dart`, `SetupPageCalendarLogin`, `file_picker`. **No button** on the first setup screen. Code still runs if `getHasICSFile()` is set.

---

## 11. Honesty: full vs thin

| Area | Level | Notes |
|------|-------|-------|
| Android client (login, 5 tabs, cache) | **Full / mid-beta** | Real API, not a stub |
| iOS simulator + device release | **Working** | Bundle without `_`; Automatic signing |
| Modern JWT + refresh | **Solid** | |
| Modern 2FA | **Code present, live ELTE unconfirmed** | “Doesn’t work” banner kept |
| Old API 2FA | **None** | |
| Local iOS notifications | **Working MVP** | No Android-style exact alarm |
| ICS | **Dead UI** | Class exists, no setup entry |
| Homescreen widget | **Removed** | Was a stub |
| APK / Play update | **Android only** | Hidden on iOS |
| Tests | **None** | No `test/` folder |
| App Store / Play production | **Not the current goal** | |

Monoliths: `main_page.dart`, `api_coms.dart`, `popup.dart`, `setup_page.dart`, `language.dart` — ~1400–2600 lines each. **Do not split** while the goal is iOS/login, not a rewrite.

---

## 12. Data layer

`DataCache` (`lib/storage.dart`) is the only layer.

Cache flags: calendar, markbook, payments, periods, mail, first week, term list. Offline UI reads cache. This is **not** a full offline product.

Secrets: username/password/JWT/device cookie in secure storage (migrated from older SharedPreferences).

`dataWipe` = logout.

No analytics file in git (`.gitignore`: `/lib/app_analitics_server_send.dart`).

---

## 13. Notifications

`lib/notifications.dart` — **not** remote push.

| Type | When |
|------|------|
| Classes | 10 min, 5 min, at start |
| Exams | ~2 weeks ahead |
| Payments | daily until paid |
| Periods | day before and start day |

- Android: channels + exact-alarm permission.  
- iOS: `DarwinInitializationSettings`, `requestPermissions`.  
- Channel names: hardcoded Hungarian.  
- iOS Simulator lies; test on a device.

---

## 14. iOS

### Identity

| Field | Value |
|-------|-------|
| Display name | `Neptun ELTE` (`CFBundleDisplayName` / Android `android:label`) |
| `CFBundleName` | `NeptunELTE` |
| Bundle ID | **`com.nanda070.neptunmobile`** |
| Tests | `com.nanda070.neptunmobile.RunnerTests` |
| Team (local) | `48FW5533N7` (Automatic signing) |
| `PRODUCT_NAME` | `Runner` (do not change — breaks Flutter) |

**Why no underscore in the Bundle ID:** Automatic Signing names the profile `XC com nanda070 neptun_mobile app`. Underscores in that name are invalid → `The attribute 'name' is invalid` / no profiles.

Android `applicationId` is **different**: `com.nanda070.neptun_mobile.app`. Intentional after the Xcode fix.

### Debug vs release

On **iOS 14+**, a **debug** build **cannot** launch from the home-screen icon — only from Flutter / Xcode. For the icon: `flutter run --release` / `flutter build ios --release`.

### Signing / device

1. `open ios/Runner.xcworkspace`  
2. Runner → Signing & Capabilities → Automatically manage signing → Team.  
3. iPhone: **Settings → General → VPN & Device Management** → trust Apple Development.  
4. Install: `flutter run --release -d Nanda` or `xcrun devicectl device install app`.

### Info.plist (important)

- `NSUserNotificationsUsageDescription`
- `LSApplicationQueriesSchemes`: `https`, `http`, `mailto`, `tg`, `telegram`, `discord`

### iOS vs Android-only

| Feature | iOS |
|---------|-----|
| Links (`url_launcher`) | Should work (Android-only gate removed) |
| Haptics | `HapticFeedback` |
| APK updater / Play IAU | Hidden / do not call |
| Fluttertoast | Often invisible; `custom_snackbar.dart` exists |
| SPM warning | `flutter_secure_storage`, `open_filex` — not a blocker yet |

### Commands

```bash
cd /path/to/Neptun-ELTE
flutter pub get
cd ios && pod install && cd ..

# Simulator
flutter run -d "iPhone 17 Pro"

# Phone, home-screen icon
flutter run --release -d Nanda
```

Regenerate the shell (does not wipe `lib/`):

```bash
flutter create --platforms=ios --org com.nanda070 --project-name neptun2 .
```

After create, confirm Bundle ID is `com.nanda070.neptunmobile` (not `neptun_mobile`).

---

## 15. Android

| Field | Value |
|-------|-------|
| `applicationId` / namespace | `com.nanda070.neptun_mobile.app` |
| `compileSdk` | 36 |
| Java / Kotlin | 17 |
| minSdk | `flutter.minSdkVersion` |

```bash
flutter pub get
flutter run -d android
flutter build apk --debug
```

Play: `in_app_update` if `installerStore == com.android.vending`. Otherwise GitHub APK (`lib/Misc/auto_updater.dart`) — **Android only**.

CI: `.github/workflows/betabuild.yml` — Ubuntu, debug APK, **no** analyze/test/iOS.

---

## 16. Removed / disabled

| Feature | State |
|---------|-------|
| Donate / Buy Me a Coffee | Removed from UI |
| zoligamer branding | Stripped (packages, funding, theme/language URLs) |
| Pirate + DE/RO/UA/AR/ES/ZH | Removed from language catalog |
| `linux/` | Removed |
| Homescreen widget stub | Removed |
| `AppUpdateHelper` / `appMinimumAllowedVersion.json` | Removed (dead version-gate) |
| `cupertino_icons`, `change_app_package_name` | Dropped from pubspec |
| ICS from first setup screen | Not wired |
| Popup mode 1 (old settings) | Dead duplicate of `settings_page.dart` |
| Popup 2 / 6 / 7 | Essentially no callers |
| Analytics | File not in git |
| App Store | Not set up |
| Remote institutes URL (cloudapp) | Constant exists, unused |

---

## 17. Environment

The client has **no** secrets and **no** `.env`.

External config is JSON on GitHub `main`:

- `universityNameUrlPairs.json`
- `Languages/supportedLanguages.json`
- `Themes/supportedThemes.json`

Android release signing: local `key.properties` (not in git).

iOS: Team / profile in Xcode, not in the repo.

---

## 18. Build, CI, run

### Local

```bash
flutter pub get
flutter devices
flutter run -d <device-id>
```

iPhone release: `--release` (see §14).

### CI

Only `flutter build apk --debug --no-shrink` on `ubuntu-latest`. **No** iOS job.

### GitHub raw

Until JSON changes are on `main` at `Nanda070/Neptun-ELTE`, installed apps keep fetching the **old** institute/language lists.

---

## 19. History and contacts

Independent project under **Nanda070**. Do not brand it as “the zoligamer fork”.

Earlier related work: **domedav** (Neptun 2), **zoligamer** (previous fork).

| | |
|--|--|
| GitHub | [Nanda070](https://github.com/Nanda070) |
| Discord | nandak070 |
| Telegram | nanda070 |
| Email | adnan.huseynli1@gmail.com |
| Web | https://nanda.is-a.dev/ · cheterin.online · chetmedia.com |

Issues: https://github.com/Nanda070/Neptun-ELTE/issues

License: MIT (`LICENSE`).

---

## 20. Why we chose this

| Decision | Why |
|----------|-----|
| Two bundle IDs (iOS without `_`) | Xcode Automatic Signing breaks on `neptun_mobile` in the profile name |
| Don’t split monoliths yet | No tests; goal is platform + login, not Clean Architecture |
| EN default, only EN/HU/RU/TR | Owner request; fewer dead packs |
| GitHub raw for institutes/languages/themes | Update without an APK/IPA release |
| `badCertificateCallback => true` | Broken campus certs; MITM risk accepted |
| Keep the 2FA banner | Live ELTE unconfirmed; university requires 2FA |
| `loginServerBusy` ≠ invalid password | Neptun overload was shown as a bad password |
| ELTE hub → `https://neptun.elte.hu` | Central portal; **not** `/ujhallgato` (Obuda/BME-style). `/Account` is SPA login only |
| Single institute in JSON | Product is ELTE-only; multi-uni picker removed from hub UI |
| Keep ICS in code | Old users may still have a file; don’t advertise the UI |
| iOS release for the icon | iOS 14+ debug restriction |
| No first-party backend | Client talks to the institute directly |
| `Provider` for theme only | Historical monolith; don’t add Bloc “just in case” |

---

## 21. Important files

| File | Why |
|------|-----|
| `README.md` / `README.ru.md` | Product overview |
| `docs/TECHNICAL.md` | This document (EN) |
| `docs/TECHNICAL.ru.md` | Russian version |
| `docs/DEVELOPER.md` | Short iOS cheatsheet |
| `pubspec.yaml` | Version, dependencies |
| `lib/main.dart` | `MaterialApp`, theme, `Splitter` |
| `lib/Pages/startup_page.dart` | Login / home branch |
| `lib/Pages/setup_page.dart` | Login, URL, 2FA callback, ICS class |
| `lib/Pages/main_page.dart` | Home + 5 tabs |
| `lib/Pages/settings_page.dart` | Live settings |
| `lib/API/api_coms.dart` | All HTTP, login, URL normalize |
| `lib/API/ics_calendar.dart` | ICS parser |
| `lib/storage.dart` | `DataCache` |
| `lib/language.dart` | EN/HU + RU/TR download |
| `lib/colors.dart` | Palettes |
| `lib/notifications.dart` | Local notifications |
| `lib/haptics.dart` | Android vibration / iOS `HapticFeedback` |
| `lib/Misc/popup.dart` | Modes 0–9 (9 = 2FA) |
| `lib/Misc/app_drawer.dart` | Drawer |
| `lib/Misc/auto_updater.dart` | GitHub APK, Android-only |
| `universityNameUrlPairs.json` | Institutes — **ELTE only** (`https://neptun.elte.hu`) |
| `Languages/supportedLanguages.json` | RU/TR catalog |
| `Themes/supportedThemes.json` | Remote themes |
| `ios/Runner/Info.plist` | Display name, notifications, URL schemes |
| `ios/Runner.xcodeproj/project.pbxproj` | Bundle ID, Team |
| `android/app/build.gradle` | `applicationId` |
| `.github/workflows/betabuild.yml` | Android CI |

---

*End of document. If this disagrees with the code, the code and a fresh `git log` win.*
