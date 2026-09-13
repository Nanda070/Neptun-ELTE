# Neptun ELTE — technical documentation

> 🇷🇺 [Русская версия](TECHNICAL.ru.md) · 📋 [Implementation plan (EN)](IMPLEMENTATION_PLAN.md) · [RU](IMPLEMENTATION_PLAN.ru.md) · 📱 [iOS vs Android (EN)](IOS_VS_ANDROID.md) · [RU](IOS_VS_ANDROID.ru.md) · 📝 [Dev Blog (EN)](DEV_BLOG.md) · [RU](DEV_BLOG.ru.md)

> **Audience:** developers and anyone with repo access.  
> Git-only (`docs/Technical/TECHNICAL.md`). **Not** published as a website, **no** public route.  
> Code identifiers, paths, packages, and API routes stay in English, as in the repo.

Last sync with the codebase: **September 2026** (repo **Neptun-ELTE**, display name Neptun ELTE, ELTE-only hub, no `/ujhallgato` for ELTE, languages EN/HU/RU/TR, modern API login + 2FA code path, “invalid password” vs “server busy”). Sources: `lib/**`, `pubspec.yaml`, `ios/`, `android/`, `Languages/`, `Themes/`, `universityNameUrlPairs.json`, `.github/`.

**Owner / developer:** **Nanda** (full legal name only in Legal docs).

Product overview + Legal index: [`docs/README.md`](../README.md) / [`docs/README.ru.md`](../README.ru.md).  
Implementation backlog (not shipped): [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) / [`IMPLEMENTATION_PLAN.ru.md`](IMPLEMENTATION_PLAN.ru.md).  
Dev diary: [`DEV_BLOG.md`](DEV_BLOG.md) / [`DEV_BLOG.ru.md`](DEV_BLOG.ru.md).  
Legal files: [Privacy EN](../Legal-En/PRIVACY.md) · [Terms EN](../Legal-En/TERMS.md) · [Cookies EN](../Legal-En/COOKIES.md) · [RU](../Legal-Ru/) · [HU](../Legal-Hu/).  
iOS quick start: [§14](#14-ios) only — **no** separate `DEVELOPER.md`.  
Platform matrix (what each OS has/lacks): [`IOS_VS_ANDROID.md`](IOS_VS_ANDROID.md) / [`IOS_VS_ANDROID.ru.md`](IOS_VS_ANDROID.ru.md).  
UI mockups (Figma, not shipped code): [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups) — **Android** = polished target; **iOS** = current Flutter shell + additive plan fields. Mockups may still show **5** bottom tabs; **app IA** is **4** (Calendar \| Markbook \| Periods \| Mail) + Payments in drawer above Settings (plan **1c**). Owner **Nanda**.

---

## Contents

1. [Product overview](#1-product-overview) — [Versioning](#versioning)
2. [Repository](#2-repository)
3. [Stack](#3-stack)
4. [Architecture and request flow](#4-architecture-and-request-flow)
5. [Screens](#5-screens)
6. [Setup / login](#6-setup--login)
7. [Home tabs (5 today; planned 3 + drawer)](#7-home-tabs-5-today-planned-3--drawer)
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
- ELTE uses a **central** portal (`neptun.elte.hu` / login + News). It does **not** use Obuda/BME-style `/ujhallgato`. After portal login, **Student web** bridges via `/ToNeptunWeb/ToNeptunHWeb` onto one of several identical HWEB hosts: **`hallgato1`…`hallgatoN.neptun.elte.hu`** (load-balanced; e.g. `hallgato4`). The mobile client authenticates and calls modern JWT APIs on **`https://neptun.elte.hu`**, not a specific `hallgatoN` shell.
- Display name: **Neptun ELTE**.
- Version (`pubspec.yaml`): **1.3.1+1** — user-facing / Settings / docs = **1.3.1** (see [Versioning](#versioning) below).
- Dart package: `neptun2` (imports `package:neptun2/...`).
- UI languages: **EN** (default) and **HU** built-in; **RU** and **TR** downloaded from GitHub.
- Platforms: **Android** and **iOS**. No `web/`, Windows, macOS, or Linux in this repo (`linux/` was removed).
- This is **not** an official SDA/ELTE app and **not** an App Store / Play production brand.

Repo: [Nanda070/Neptun-ELTE](https://github.com/Nanda070/Neptun-ELTE). Independent product; earlier authors are credits only.

### Versioning

Owner policy (**Nanda**). **Marketing / user-facing version is always three numbers `1.x.y`.** Do **not** treat Flutter `+build` (e.g. old `+21`) as the version story in Settings, README, or product talk.

Flutter still needs `x.y.z+build` in `pubspec.yaml` for stores. Prefer **`1.x.y+1`**. Use a larger `+N` only if Android requires a monotonic `versionCode`; never advertise `+N` as the product version. Settings shows **`info.version` only** (e.g. `1.3.1`). Mirror `build-name` to iOS `MARKETING_VERSION` / Android `versionName` fallbacks.

Scheme: **`1.<feature-line>.<patch>`**

| Line | Meaning |
|------|---------|
| **1.x.y** | Pre-final product line only. Feature line `x` advances when a planned foundation/feature block ships; patch `y` for bugfixes / auth / small tweaks within that line. |
| **1.3.0** | Feature line **3** = plan items **1–3** shipped (session cache, markbook math, calendar strips). |
| **1.3.1** | **Current.** Line 3 + patch for auth / 2FA / Student-web-full messaging fixes. |
| **1.4.0**, **1.4.1**, … | Next big feature block (e.g. mail search / ICS / maps), then patches. |
| **2.0.0** | Final / release-candidate product line. Everything before that stays **1.x.y**. |

Bump `pubspec.yaml` (and iOS / Android mirrors) when releasing. Keep docs EN+RU and Settings aligned on the three-number marketing version.

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
├── docs/
│   ├── README.md / README.ru.md   # Product README (full)
│   ├── LICENSE                    # Canonical LGPL-3.0-only text
│   ├── Technical/                 # TECHNICAL + IMPLEMENTATION_PLAN + DEV_BLOG (EN + RU)
│   ├── Legal-En/ · Legal-Ru/ · Legal-Hu/
│   └── …
├── .github/workflows/        # Android debug APK + unsigned iOS IPA
├── pubspec.yaml
├── README.md                 # Short pointer → docs/
└── LICENSE                   # Identical copy of docs/LICENSE (GitHub)
```

| Path | Role |
|------|------|
| `lib/` | UI, API, cache, notifications |
| `android/` | Gradle, `applicationId` `com.nanda070.neptun_mobile.app` |
| `ios/` | Xcode, Bundle ID `com.nanda070.neptunmobile` |
| `Languages/` | Downloadable language catalog (`ru`, `tr` only) |
| `Themes/` | Downloadable theme catalog |
| `docs/Technical/` | TECHNICAL + IMPLEMENTATION_PLAN + DEV_BLOG (EN + RU) |
| `docs/Legal-*` | Privacy, Terms, Cookies (EN / RU / HU) |
| `docs/README*.md` | Full product README |
| `.github/workflows/betabuild.yml` | CI: `flutter build apk --debug` |
| `.github/workflows/ios-ipa.yml` | CI: unsigned iOS IPA → artifact / GitHub Release |

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
| `HomePage` (`lib/Pages/main_page.dart`) | **4** bottom tabs after login (Calendar, Markbook, Periods, Mail). Payments = drawer index 4. `WidgetsBindingObserver` → `SessionGuard.checkSessionWallClockOnResume` |
| `SettingsPage` (`settings_page.dart`) | Theme, language, font, notifications, haptics, week offset; **Contacts** sheet + marketing version only (`package_info_plus` `info.version`, e.g. `1.3.1` — no `+build`) at bottom |
| `AppDrawer` (`lib/Misc/app_drawer.dart`) | Greeting = `UserInfo` full name + Neptun code (no training ID under name); avatar photo from HWEB base64 (`userAvatar` / `GetUserAvatar`) with initials fallback; term, balance, multi-training switcher; **Payments above Settings**; update (Android), logout |
| `PopupWidgetHandler` (`lib/Misc/popup.dart`) | Modal modes 0–9 |

**Design mockups (Figma only — no Flutter change from this file):** [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups). Pages: `Android — polished target` and `iOS — current + polish`. Mockups may still show **5-tab** icon nav; **app IA** is bottom **Calendar \| Markbook \| Periods \| Mail** + Payments in drawer above Settings (plan **1c**).

---

## 6. Setup / login

### How ELTE web works (official)

User flow on `neptun.elte.hu` ([ELTE guide](https://www.elte.hu/en/neptun-administration-of-progress)):

1. Open central portal → **Log in** (Neptun ID 6 chars + password).
2. **Two-step authentication** (observed on live ELTE UI + HAR, Sep 2026):
   - **Primary — TOTP:** field “TOTP code” + Log in. User types **6 digits** from Microsoft Authenticator (or similar). Optional “New TOTP pairing”.
   - **Backup — E-mail:** grey **E-mail** → portal `POST /Account/Login2FA` with `Phase=RequestTOTP&GetEmail=true`, then `Phase=RequestEmailCode` with `CodePrefix` (3 digits shown) + `EmailCode` (6 digits after `-`). Examples: `154-855139`.
3. After auth, **Student web** `POST /ToNeptunWeb/ToNeptunHWeb` (`NeptunWebType=HWeb`) → **302** to `https://hallgatoN.neptun.elte.hu/outerlogin?GUID=…&languageid=1033` → SPA calls `POST /api/Account/OuterLogin` `{"guid":"…","lcid":1033}` → **JWT `accessToken`**. Under load the portal may say **“Neptun student web is full”**.

**`hallgatoN` = which server:** ELTE runs many identical student-web machines (`hallgato1`, `hallgato2`, `hallgato3`, `hallgato4`, …). The digit is the **node index for load balancing**. Live HAR landed on **`hallgato3`** (`serverName: ELTE_HW3`). The portal assigns a node automatically. Do not hardcode `N`.

Observed HWEB paths (same assigned node, after OuterLogin): `/dashboard`, `/calendar/institutional-calendar`, `/studies`, `/messages`, `/administrations`, `/user-data`, …

Portal (`neptun.elte.hu` Potlap cookies) ≠ HWEB API host (`hallgatoN`). **`POST https://neptun.elte.hu/api/Account/Authenticate` returns empty HTTP 400** — not the ELTE login path. HWEB `Authenticate` **302 → portal** when `isADAuthenticationInInstitute` is true.

### How this app maps that flow

| Web step | App |
|----------|-----|
| Portal `POST /Account/Login` | Same form post (`LoginName`/`Password` + antiforgery) |
| 2FA TOTP / email | `POST /Account/Login2FA` (`Phase=RequestTOTP` + `TOTPCode`, or email phases) → popup mode 9 |
| `ToNeptunHWeb` → `outerlogin?GUID=` | App posts HWeb form, follows 302 |
| `POST /api/Account/OuterLogin` | Saves JWT; sets institute URL to **`https://hallgatoN.neptun.elte.hu`** |
| Student REST | Bearer JWT on that hallgato host (`/api/UserInfo`, calendar, …) |

App setup UI:

1. `Splitter` → if `getHasLogin()` then `HomePage`, else ELTE hub (**display name: Neptun ELTE**).
2. Hub sets `PageDTO` to `elteInstituteName` + `elteNeptunBaseUrl` (`https://neptun.elte.hu`) → `SetupPageLogin`.
3. Credentials: Neptun code (`toUpperCase()`) + password.
4. If API returns 2FA → enter **6-digit TOTP** (Authenticator), then app bridges to hallgato via OuterLogin.
5. Demo: `DEMO` / `DEMO`.

**Honesty:** ELTE login is **portal Potlap + OuterLogin**, not `neptun.elte.hu/api/Account/Authenticate` (that returns empty 400). App implements Login → Login2FA (TOTP) → ToNeptunHWeb → OuterLogin JWT on whichever `hallgatoN` the portal assigns. Email OTP (`RequestEmailCode` / `CodePrefix`) is captured in HAR; UI still focuses on TOTP (helper `elteRequestEmailOtp` exists). If Student web is **full**, bridge fails even after correct 2FA — UI must show `loginStudentWebFull`, **not** invalid credentials.

Constants: `InstitutesRequest.elteInstituteName`, `elteNeptunBaseUrl`.

### `InstitutesRequest.validateLoginCredentialsUrl` codes

| Code | Constant | UI |
|------|----------|-----|
| `1` | `loginOk` | Enter Home |
| `2` | `loginNeeds2fa` | Popup mode 9 (6-digit TOTP) |
| `0` | `loginInvalidCredentials` | Red fields, “Invalid username or password!” |
| `3` | `loginServerBusy` | Snackbar “Neptun servers are having a hard time...” — **not** a bad password |
| `4` | `loginStudentWebFull` | Snackbar “Student web is full. Please try again later.” — **not** a bad password / TOTP |

Modern login timeout: **20 s** per URL candidate. Empty body / 5xx / timeout / HTML → `loginServerBusy`.

**Honesty — Student web full after 2FA:** Correct password + correct TOTP can still fail at `ToNeptunHWeb` / OuterLogin when ELTE HWEB capacity is exhausted (“Neptun student web is full” / HU megtelt / “nincs szabad”). That used to surface as **invalid username or password** because `submitTwoFactorCode` returned a bare `false` and setup painted `_paintRed`. Now: after TOTP succeeds the UI shows **“Connecting to Student web…”** and retries the bridge for ~**7 s**; success navigates to Home immediately; persistent full/busy shows `loginStudentWebFull` / busy snackbar — credentials stay valid.

### URL normalization (ELTE)

`normalizeModernApiBaseUrl` strips `/login`, `/MobileService.svc`, `/Account`, `/Account/Login`.

API base: **`https://neptun.elte.hu`** — not `/ujhallgato`.

Candidates: primary + ELTE root aliases only.

On success, persist the API base login selected (do not overwrite with a stale list URL).

---

## 7. Home tabs (4 bottom + Payments drawer)

`HomePageState` + `BottomNavigatorWidget`. Swipe left/right among bottom tabs (`maxBottomNavWidgets = 4`). **No named routes.**

**Code today:**

| Index | Surface | Content |
|-------|---------|---------|
| 0 | bottom | Calendar — week timetable, classes/exams |
| 1 | bottom | Markbook (Subjects) — credits, average, ghost grade |
| 2 | bottom | Periods — registration, exams, subject signup |
| 3 | bottom | Mail / Messages — inbox, unread, mark read |
| 4 | drawer only | Payments — fees and deadlines; drawer also shows balance |

**Nav IA (plan 1c):** bottom = **Calendar \| Markbook \| Periods \| Mail**; **Payments** in the left drawer **above Settings**. Contacts + app version live at the bottom of Settings (not in the drawer).

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
| Avatar | `/api/UserInfo` → `data.userAvatar.image` (thumbnail base64 JPEG) + `data.userAvatar.printName`; display name is `data.name` (not top-level `printName`); `/api/General/GetUserAvatar?imageSizeType=Normal` (larger base64 JPEG) |
| Calendar | `/api/Calendar/GetCalendarEvents` |
| Class details | `/api/Calendar/GetCourseDetails` |
| Tasks | `/api/Tasks/GetTaskDetail` |
| Subjects | `/api/TakenSubjects`, `/api/RegisteredCourses/GetRegisteredCourses` |
| Terms | `/api/RegisteredCourses/GetTerms`, `/api/TakenSubjects/Terms`, `/api/Periods/GetTerms` |
| Payments | `/api/Transactions/GetStudentPreviousTransactions` |
| Balance | `/api/FinancialDataDashboard/GetCollectiveInvoices` |
| Periods | `/api/Periods/GetPeriods` |
| Mail | `/api/Message/GetUnreadedMessagesCount`, `GetReceivedMessages`, `/api/Messages/{id}/Posts` |

Unused HWEB paths seen in Sep 2026 captures (not called by the app) live in [`IMPLEMENTATION_PLAN.md` §4.2](IMPLEMENTATION_PLAN.md#42-captured-inventory-incomplete--2026-09-13) — coverage incomplete; HARs are not in git.

Login body:

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

`LCID` follows the app language (`AppStrings.getNeptunLcid()`): EN `1033`, HU `1038`, RU `1049`, TR `1055`. GET requests also send `Accept-Language`. Full API locale for periods/subjects may require re-login after a language change.

For 2FA, resend with `token` = code; optionally `Authorization: Bearer` from `twoFactorLoginToken`. Cookie `devicecookie-<b64(username)>=...`.

Refresh / re-login on 401 lives in `_APIRequest` via `ensureValidSession` → `GetNewTokens` (when a refresh token exists). **Silent ELTE portal re-auth is disabled** (needs 2FA). If refresh fails, `SessionGuard.forceExpiredLogout` wipes **auth only** via `DataCache.sessionWipeKeepCache()` (password / JWT / refresh / device cookie / `HasLogin`; **keeps username + academic cache**), navigates to login, and shows `auth_sessionExpired_PleaseSignIn`. Manual / expired logout share that wipe. Portal leftovers: best-effort portal `Account/Logout`, `resetEltePortalState`, `CalendarRequest.clearTrainingIdCache`, wipe `devicecookie_*`, tighten `_looksLikeInvalidCredentials` (no bare `invalid` on HTML `is-invalid`) so same-process re-login is not stuck on false “invalid credentials” (**1a**). Full `dataWipe()` (prefs.clear including cache) remains available for hard reset — not used on normal logout.

**App session wall clock (user-visible):** On entering `HomePage` (successful login or cold start into a stored session), `SessionGuard.startSessionWallClock()` stores `SESSION_StartedAtMs` and arms a **10-minute** `Timer` for the remaining time. When it fires, the same `forceExpiredLogout` path runs (wipe tokens, keep username + academic cache, snackbar, navigate to login). Manual logout cancels the timer; a new login / new `HomePage` entry restarts it. Token refresh does **not** extend the wall clock. This is intentional alignment with short-lived Neptun access JWTs (~10–15 min from issue): the UI logs out on a fixed wall clock from **session entry**, not only after the next 401.

**Background wall clock (plan 1b shipped):** `HomePage` is a `WidgetsBindingObserver`. On `AppLifecycleState.resumed`, `SessionGuard.checkSessionWallClockOnResume()` compares `now` to the persisted session start; if `>= 10 min` → `forceExpiredLogout`; else re-arms the foreground `Timer` for the remaining duration. Do not rely on an in-memory `Timer` alone while the process is suspended. Foreground continuous 10 min still kicks as before.

**Cache honesty (plan item 1 shipped):** Every home surface (calendar / markbook / periods / mail / payments) paints from `HasCached*` lists first when present; network refresh is silent. On dead session / offline / failed refresh, lists are **not** replaced with an empty spinner. UI may show `cache_showingFromCache` banner. Empty calendar weeks are cached as `len == 0` so freedays render without a loading spinner. Multi-term markbook walks skip when `SessionGuard.isAuthBlocked`.

---

## 9. Auth, 2FA, tokens

| What | Where |
|------|-------|
| Password, JWT access/refresh, device cookie | `flutter_secure_storage` (`DataCache`) |
| Username, institute URL, cache flags, settings | `shared_preferences` |
| Demo | `setIsDemoAccount(1)` |

**JWT lifetime:** Access tokens are short-lived (~10–15 min in practice on Neptun). Refresh may issue a new access token, but the app still force-logs out after **10 minutes from Home entry** (see wall clock above). Without a working refresh token, a 401 also forces logout rather than showing empty “logged in” screens.

**2FA (modern):** `isTwoFactorRequired` / `requiresTwoFactor` / `twoFactorLoginToken` without `accessToken` (often HTTP 202) → code `2` → popup 9 → user types 6-digit **TOTP** → `submitTwoFactorCode`. After success, setup closes the 2FA popup **before** navigating to `HomePage` (`pushAndRemoveUntil`) so a delayed pop cannot blank the screen.

**2FA (old):** unsupported → usually `0`.

**ELTE web vs app:** Web offers TOTP + E-mail backup (`XXX-XXXXXX`). App: TOTP field only. Obsolete “2FA won’t work” banner **removed**.

---

## 10. Domain features

### 10.1 Timetable

Week view, `getUserWeekOffset()`, first study week `getFirstWeekEpoch()` from `getFirstStudyweek()`. Anchor is the Monday of the semester season week (autumn: week containing **1 Sep**; spring: week containing **1 Feb**) when the teaching/`szorgalmi` period starts within that fortnight — **not** subject-registration or login windows (those previously produced inflated weeks ~36 then ~16). Education week = whole weeks from that Monday to *this* Monday + `currentWeekOffset` (1 = current calendar page). Example ELTE autumn 2026: **1–7 Sep → week 1**, **7–14 Sep → week 2**. Online home open always recomputes and overwrites the cached epoch. Modern: `GetCalendarEvents` with **Mon–Sun** `endDate` (not next Monday — that wrongly pulled next week’s Monday classes, causing a ~163h fake “break” and duplicate lessons). Events outside the requested window are dropped. Same-day gap chips only (5 min–12 h), localized break strings. Course details + Calendar Settings filters (`isClassesVisible` / exams / periods). UI strips (plan item **3**): next 48h = **classes + exams** only (sorted by `startEpoch`); tasks/ZH and exams = upcoming from now (not “first 8 in week” including past); period banners (`typeId == 6`) **only** in the period strip, never as day-list classes. Pull-to-refresh keeps cached week painted. Drawer training switcher when multiple trainings are known. **Room codes** matching `Campus-Floor-Room[-Stream][-Group]` (e.g. `LD-0-805` or `LD-0-805-01-11`) are tappable in the timetable list, class dialog, and exam/legacy popups: tap toggles compact code ↔ localized summary (`Southern Building, Floor: 0, Room: 805, …`). Mapped prefixes: **LD** Southern / Déli, **LE**/LÉ Northern / Északi, **LK** Chemistry block (Northern); unknown prefix kept as-is. Stream/Group only shown when present in the code (`lib/Misc/elte_room_code.dart`).

### 10.2 Markbook

Subjects tab = markbook: taken subjects (with subject codes), credits, grades, ghost grade (popup 0), confetti. Shared math in `lib/Misc/markbook_math.dart` (**plan item 2**): **Átlag / Average** = `Σ(grade × credit) / Σ(credit)` for completed `grade >= 2`; **/30** = `Σ(grade × credit) / 30` (same numerator — **not** átlag÷30). Header shows this-term credits **and** accumulated completed credits (deduped by `subjectCode` across `getGradeHistoryAcrossTerms`). UI labels say `/30` explicitly; note: **app-computed**, not official Neptun KKI/GPA (`GetAverages` was empty in Sep 2026 HAR). Also lists **My courses** (`GetRegisteredCourses`) and a compact **grade history** across recent terms.

### 10.3 Payments / periods / mail

Charges and deadlines; **collective invoices** list + balance; periods with timers; inbox + mark read; full mail thread posts. Message detail: optional HU→EN/RU machine translate (`MessageTranslator`); first use on a device shows a 5s inaccuracy disclaimer snackbar (`hasSeenMailTranslateDisclaimer`).

**Payments UI chrome** (tab title, empty state, deadlines, currency symbol, notification bodies, drawer balance label) uses `LanguagePack` (EN/HU built-in; RU/TR JSON). **Transaction / invoice titles and statuses from Neptun** (`transactionPayingType`, `transactionStatus`, collective-invoice labels) usually remain **Hungarian** — that is server payload language, not a missing app string.

### 10.4 Settings

Theme, language, font 80–140%, four notification types, family-friendly loading copy, haptics, week offset, calendar display filters, update check (Android).

### 10.5 Themes

Built-in picker (`lib/colors.dart`): **Light** and **Dark** only. Preference is stored in `THEME_AppTheme` and applied on startup; system brightness does **not** overwrite it. Remote `Themes/supportedThemes.json` packs are no longer offered in the UI.

### 10.6 Languages

| Code | Source |
|------|--------|
| `en` | `lib/language.dart` — **default** |
| `hu` | `lib/language.dart` |
| `ru`, `tr` | `Languages/LangExtentions/*.json` via `supportedLanguages.json`, **also bundled as Flutter assets** |

Other packs (DE, RO, UA, AR, ES, ZH, Pirate) were **removed**.

Settings **Contacts** uses `topmenu_buttons_Contacts` (localized). Payment notification bodies use `notif_payment_Body*`. Missing keys in a downloaded/cached RU/TR pack fall back to EN unless filled by the **bundled** asset merge (`AppStrings.loadBundledLanguagePacks` before `initialize`). GitHub `main` packs should stay in sync with the EN key set so network refresh does not lag.

**Course / subject detail chrome** (calendar class tap dialog + task dialog: Type / Teacher / Room / Close / loading room / missing placeholders) uses `courseDetail_*` + `popup_case4_5_SubjectCode`. **Subject titles, course types (e.g. Előadás), rooms, and teacher names from Neptun** stay in whatever language the API returns — often Hungarian even when the app UI is EN.

Also localized through `LanguagePack`: class/exam notification bodies (`notif_exam_*`, `notif_class_*`), settings font-scale label, mail error/empty strings, 2FA popup (`popup_case9_*`), Android updater UX (`updater_*`), API user-visible fallbacks / DEMO labels (`api_fallback_*`, `api_demo_*`), transport/mail errors (`api_error_*`, `mail_preview_TapToLoadBody`), and session-expired API messages (`auth_sessionExpired_PleaseSignIn`).

### 10.7 ICS

`lib/API/ics_calendar.dart`, `SetupPageCalendarLogin`, `file_picker`. **No button** on the first setup screen. Code still runs if `getHasICSFile()` is set.

---

## 11. Honesty: full vs thin

| Area | Level | Notes |
|------|-------|-------|
| Android client (login, 4-tab nav + drawer, cache) | **Full / mid-beta** | Real API, not a stub. Nav IA **1c** |
| iOS simulator + device release | **Working** | Bundle without `_`; Automatic signing |
| Modern JWT + refresh | **Solid** | |
| Modern 2FA TOTP (ELTE portal) | **Working MVP** | Portal Login2FA + OuterLogin JWT on hallgatoN. **Student web full** → `loginStudentWebFull` snackbar (not invalid password) |
| Modern 2FA email | **HAR known; UI thin** | `RequestEmailCode` + CodePrefix; prefer TOTP in app |
| JWT Authenticate on neptun.elte.hu | **Dead for ELTE** | Empty HTTP 400; AD institute uses portal |
| Old API 2FA | **None** | |
| Local iOS notifications | **Working MVP** | No Android-style exact alarm |
| ICS | **Dead UI** | Class exists, no setup entry |
| Homescreen widget | **Removed** | Was a stub |
| APK / Play update | **Android only** | Hidden on iOS |
| Education week number | **Fixed (Sep 2026)** | Season Monday (Sep/Feb 1 week) + teaching period; ignores registration anchors; online refresh overwrites cache |
| App Store / Play production | **Not the current goal** | |
| Drawer profile photo | **Working** | ELTE HWEB: `data.userAvatar.image` on `/api/UserInfo` + `/api/General/GetUserAvatar?imageSizeType=Normal` (base64 JPEG). Cached in `DataCache`; drawer `MemoryImage`; initials on failure/empty |
| Drawer training ID line | **Removed** | Raw `studentTrainingId` / GUID must not show under the name; human labels only in the multi-training dropdown |

Monoliths: `main_page.dart`, `api_coms.dart`, `popup.dart`, `setup_page.dart`, `language.dart` — ~1400–2600 lines each. **Do not split** while the goal is iOS/login, not a rewrite.

---

## 12. Data layer

`DataCache` (`lib/storage.dart`) is the only layer.

Cache flags: calendar, markbook, payments, periods, mail, first week, term list. Offline UI reads cache. This is **not** a full offline product.

Secrets: username/password/JWT/device cookie in secure storage (migrated from older SharedPreferences).

`sessionWipeKeepCache` = normal logout / session expiry: clears password/tokens/device cookie/`HasLogin`, **keeps username + academic cache** (calendar / markbook / payments / periods / mail / terms / avatar). `dataWipe` = full prefs wipe including cache (hard reset only). Drawer shows HWEB profile photo when available, else **initials** from display name / Neptun code.

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

### Quick cheatsheet

Identity, API, 2FA, cache, and languages are documented in this file. Day-to-day iOS checklist:

| Item | Value |
|------|--------|
| Display name | **Neptun ELTE** |
| iOS Bundle ID | `com.nanda070.neptunmobile` (no `_` — otherwise Xcode breaks provisioning) |
| Android `applicationId` | `com.nanda070.neptun_mobile.app` |
| Dart package | `neptun2` |
| Default language | English |
| Themes | Light / Dark only (persisted; system brightness does not override) |
| Bug reports | https://nanda.is-a.dev |
| Scope | **ELTE only** — portal `https://neptun.elte.hu`; HWEB SPA `hallgatoN.neptun.elte.hu` |

```bash
flutter pub get
cd ios && pod install && cd ..
flutter devices

# Simulator
flutter run -d "iPhone 17 Pro"

# Phone: home-screen icon needs release (iOS 14+ debug will not open from the icon)
flutter run --release -d Nanda
```

Signing: `ios/Runner.xcworkspace` → Automatically manage signing → Team.  
On the phone: **Settings → General → VPN & Device Management** → trust the developer.

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

Full side-by-side: [`IOS_VS_ANDROID.md`](IOS_VS_ANDROID.md) (RU: [`IOS_VS_ANDROID.ru.md`](IOS_VS_ANDROID.ru.md)).

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

Compared with iOS: [`IOS_VS_ANDROID.md`](IOS_VS_ANDROID.md).

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

CI: `.github/workflows/betabuild.yml` — Ubuntu, debug APK. `.github/workflows/ios-ipa.yml` — macOS, unsigned IPA for Sideloadly (no Apple signing secrets in repo yet).

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

- **Android:** `betabuild.yml` — `flutter build apk --debug --no-shrink` on `ubuntu-latest`.
- **iOS IPA:** `ios-ipa.yml` — `flutter build ios --release --no-codesign` on `macos-latest`, packages `Neptun-ELTE-<version>-unsigned.ipa`, uploads as a workflow artifact, and (when a release tag is set) attaches it to that GitHub Release. Trigger: `workflow_dispatch`, `release` published, or push of `v*` tags.
- **Signed IPA / TestFlight:** not in CI yet. Would need repo secrets such as `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `BUILD_PROVISION_PROFILE_BASE64` (optional `KEYCHAIN_PASSWORD`, `APPLE_TEAM_ID`). Until then, install via **Sideloadly** (or similar) with the user’s own Apple ID.

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

Bug reports: https://nanda.is-a.dev (in-app links; not the GitHub Issues form)

License: LGPL-3.0-only ([`docs/LICENSE`](../LICENSE); root `LICENSE` is an identical copy for GitHub).

---

## 20. Why we chose this

| Decision | Why |
|----------|-----|
| Two bundle IDs (iOS without `_`) | Xcode Automatic Signing breaks on `neptun_mobile` in the profile name |
| Don’t split monoliths yet | No tests; goal is platform + login, not Clean Architecture |
| EN default, only EN/HU/RU/TR | Owner request; fewer dead packs |
| GitHub raw for institutes/languages/themes | Update without an APK/IPA release |
| `badCertificateCallback => true` | Broken campus certs; MITM risk accepted |
| Removed obsolete 2FA “won’t work” banner | ELTE requires 2FA; app supports code entry |
| No Authenticator deep-link / auto-OTP | TOTP is typed manually; Microsoft Authenticator stays external |
| No email OTP (`XXX-XXXXXX`) yet | Needs Network capture of E-mail button + Authenticate `token` shape |
| `loginServerBusy` ≠ invalid password | Neptun overload was shown as a bad password |
| `loginStudentWebFull` ≠ invalid password | HWEB capacity full after correct 2FA was painted as bad password (`submitTwoFactor` → `false` → `_paintRed`) |
| ELTE hub → `https://neptun.elte.hu` | Portal + JWT API. HWEB is load-balanced across `hallgato1…N` after `/ToNeptunWeb/ToNeptunHWeb` — never hardcode a single node |
| Single institute in JSON | Product is ELTE-only; multi-uni picker removed from hub UI |
| Keep ICS in code | Old users may still have a file; don’t advertise the UI |
| iOS release for the icon | iOS 14+ debug restriction |
| No first-party backend | Client talks to the institute directly |
| `Provider` for theme only | Historical monolith; don’t add Bloc “just in case” |

---

## 21. Important files

| File | Why |
|------|-----|
| `docs/README.md` / `docs/README.ru.md` | Product overview |
| `docs/Technical/TECHNICAL.md` | This document (EN) |
| `docs/Technical/TECHNICAL.ru.md` | Russian version |
| `docs/Technical/IOS_VS_ANDROID.md` / `IOS_VS_ANDROID.ru.md` | iOS vs Android platform matrix |
| `docs/Technical/IMPLEMENTATION_PLAN.md` / `IMPLEMENTATION_PLAN.ru.md` | Prioritized implementation plan (not shipped) |
| `docs/Technical/DEV_BLOG.md` / `DEV_BLOG.ru.md` | Chronological dev diary |
| `docs/Legal-En/` · `Legal-Ru/` · `Legal-Hu/` | Privacy, Terms, Cookies |
| `docs/LICENSE` | LGPL-3.0-only (canonical); root `LICENSE` mirrors it |
| `pubspec.yaml` | Version, dependencies |
| `lib/main.dart` | `MaterialApp`, theme, `Splitter` |
| `lib/Pages/startup_page.dart` | Login / home branch |
| `lib/Pages/setup_page.dart` | Login, URL, 2FA callback, ICS class |
| `lib/Pages/main_page.dart` | Home + **4** bottom tabs + drawer Payments (**1c**) |
| `lib/Pages/settings_page.dart` | Live settings (Contacts + app version at bottom) |
| `lib/API/api_coms.dart` | All HTTP, login, URL normalize |
| `lib/API/ics_calendar.dart` | ICS parser |
| `lib/storage.dart` | `DataCache` |
| `lib/language.dart` | EN/HU + RU/TR download |
| `lib/colors.dart` | Palettes |
| `lib/notifications.dart` | Local notifications |
| `lib/haptics.dart` | Android vibration / iOS `HapticFeedback` |
| `lib/Misc/popup.dart` | Modes 0–9 (9 = 2FA) |
| `lib/Misc/elte_room_code.dart` | ELTE room-code parse + tap-to-decode label |
| `lib/Misc/app_drawer.dart` | Drawer |
| `lib/Misc/auto_updater.dart` | GitHub APK, Android-only |
| `universityNameUrlPairs.json` | Institutes — **ELTE only** (`https://neptun.elte.hu`) |
| `Languages/supportedLanguages.json` | RU/TR catalog |
| `Themes/supportedThemes.json` | Remote themes |
| `ios/Runner/Info.plist` | Display name, notifications, URL schemes |
| `ios/Runner.xcodeproj/project.pbxproj` | Bundle ID, Team |
| `android/app/build.gradle` | `applicationId` |
| `.github/workflows/betabuild.yml` | Android CI |
| `.github/workflows/ios-ipa.yml` | Unsigned iOS IPA → Release / artifact |

---

*End of document. If this disagrees with the code, the code and a fresh `git log` win.*
