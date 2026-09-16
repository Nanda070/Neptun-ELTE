# Neptun ELTE — technical documentation

> 🇷🇺 [Русская версия](TECHNICAL.ru.md) · 📝 [Dev Blog (EN)](DEV_BLOG.md) · [RU](DEV_BLOG.ru.md)

> **Audience:** developers and anyone with repo access.  
> Git-only (`docs/Technical/TECHNICAL.md`). **Not** published as a website, **no** public route.  
> Code identifiers, paths, packages, and API routes stay in English, as in the repo.

Last sync with the codebase: **16 September 2026** (repo **Neptun-ELTE**, display name Neptun ELTE, ELTE-only hub, no `/ujhallgato` for ELTE, languages EN/HU/RU/TR, modern API login + 2FA code path, “invalid password” vs “server busy”; session/API HTTP facts below match `lib/API/api_coms.dart` — GET+Bearer on `hallgatoN`, no keep-alive). Sources: `lib/**`, `pubspec.yaml`, `ios/`, `android/`, `Languages/`, `Themes/`, `universityNameUrlPairs.json`, `.github/`.

**Owner / developer:** **Nanda**.

Product overview + Legal index: [`docs/README.md`](../README.md) / [`docs/README.ru.md`](../README.ru.md).  
**Backlog** (remaining work): this file’s [honesty table](#11-honesty-full-vs-thin) + [§20 decisions](#20-why-we-chose-this) and the Dev Blog [“In progress / planned”](DEV_BLOG.md#in-progress--planned-honest) section. Numbered `IMPLEMENTATION_PLAN.md` / `.ru.md` were **deleted** after **1.5.0** (plan item **11** Academic Progress / tanterv was **dropped** earlier — do not rebuild).  
Indoor campus map (LD/LE A→B): **map data first** — [CAMPUS_MAP_PLAN.md](CAMPUS_MAP_PLAN.md) / [RU](CAMPUS_MAP_PLAN.ru.md); Phase **0–1 done** (schema in [`campus_map_research/schema/`](campus_map_research/schema/SCHEMA.md)); Flutter UI deferred until the graph package is finished. Research: [`campus_map_research/`](campus_map_research/README.md).  
Dev diary: [`DEV_BLOG.md`](DEV_BLOG.md) / [`DEV_BLOG.ru.md`](DEV_BLOG.ru.md).  
Legal files: [Privacy EN](../Legal-En/PRIVACY.md) · [Terms EN](../Legal-En/TERMS.md) · [Cookies EN](../Legal-En/COOKIES.md) · [RU](../Legal-Ru/) · [HU](../Legal-Hu/).  
iOS quick start: [§14](#14-ios) only — **no** separate `DEVELOPER.md`.  
Product features are shared on both platforms after Android APK parity; remaining platform-only notes (updater / signing / CI / haptics / toast) live in [§14](#14-ios) and [§15](#15-android). The separate `IOS_VS_ANDROID*` matrix was **deleted**.  
UI mockups (Figma, not shipped code): [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups) — **Android** = polished target; **iOS** = current Flutter shell + additive polish. Mockups may still show **5** bottom tabs; **app IA** is **4** (Calendar \| Markbook \| Periods \| Mail) + Payments in drawer above Settings (plan **1c**). Owner **Nanda**.

---

## Contents

1. [Product overview](#1-product-overview) — [Versioning](#versioning)
2. [Repository](#2-repository)
3. [Stack](#3-stack)
4. [Architecture and request flow](#4-architecture-and-request-flow)
5. [Screens](#5-screens)
6. [Setup / login](#6-setup--login)
7. [Home tabs (4 bottom + Payments drawer)](#7-home-tabs-4-bottom--payments-drawer)
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
- ELTE uses a **central** portal (`neptun.elte.hu` / login + News). It does **not** use Obuda/BME-style `/ujhallgato`. After portal login, **Student web** bridges via `/ToNeptunWeb/ToNeptunHWeb` onto one of several identical HWEB hosts: **`hallgato1`…`hallgatoN.neptun.elte.hu`** (load-balanced; e.g. `hallgato4`). The app authenticates on the **portal**, then sets the institute URL to the assigned **`hallgatoN`** and calls modern JWT REST **there**. Do not hardcode `N`.
- Display name: **Neptun ELTE**.
- Version (`pubspec.yaml`): **1.5.10+1** — user-facing / Settings / docs = **1.5.10** (see [Versioning](#versioning) below).
- Dart package: `neptun2` (imports `package:neptun2/...`).
- UI languages: **EN** (default) and **HU** built-in; **RU** and **TR** downloaded from GitHub.
- Platforms: **Android** and **iOS**. No `web/`, Windows, macOS, or Linux in this repo (`linux/` was removed).
- This is **not** an official SDA/ELTE app and **not** an App Store / Play production brand.

Repo: [Nanda070/Neptun-ELTE](https://github.com/Nanda070/Neptun-ELTE). Independent product; earlier authors are credits only.

### Versioning

Owner policy (**Nanda**). **Marketing / user-facing version is always three numbers `1.x.y`.** Do **not** treat Flutter `+build` (e.g. old `+21`) as the version story in Settings, README, or product talk.

Flutter still needs `x.y.z+build` in `pubspec.yaml` for stores. Prefer **`1.x.y+1`**. Use a larger `+N` only if Android requires a monotonic `versionCode`; never advertise `+N` as the product version. Settings shows **`info.version` only** (e.g. `1.5.10`). Mirror `build-name` to iOS `MARKETING_VERSION` / Android `versionName` fallbacks.

Scheme: **`1.<feature-line>.<patch>`**

| Line | Meaning |
|------|---------|
| **1.x.y** | Pre-final product line only. Feature line `x` advances when a planned foundation/feature block ships; patch `y` for bugfixes / auth / small tweaks within that line. |
| **1.3.0** | Feature line **3** = plan items **1–3** shipped (session cache, markbook math, calendar strips). |
| **1.3.3** | Line 3 + patch for immediate post-2FA session-expired logout (`SessionGuard` stale wall-clock / 401 grace). |
| **1.3.4** | Line 3 + plan item **4** — mail local search + unread-only chip (`filterType=0` stays API-honest). |
| **1.5.10** | **Current.** Patch — session maintenance reliability: drop WorkManager / BGFetch **`requiresDeviceIdle`** (1.5.9 idle blocked nearly all background runs); keep network + battery-not-low + **45 min** period with **15 min** Android initial delay; on `resumed` **immediate** `GetNewTokens` then calendar+mail refresh; remember-password keeps password across **manual** log out too. Tag **v1.5.10**. |
| **1.5.9** | Patch — battery-minimized optional **background hallgato keep-alive**: Android WorkManager **45 min** (was 15) with network + `requiresBatteryNotLow` + `requiresDeviceIdle` (not charging-required); iOS Background Fetch minimum **45 min**; cancel OS tasks while `resumed`; coalesce skip if last `GetNewTokens` success within **25 min**. Tag **v1.5.9**. |
| **1.5.8** | Patch on feature line **5** — Calendar **education-week navigator**: single-card layout (`WeekoffseterElementWidget`) + fix EN same-month date range (`${to.day}` not `$to.day`). Tag **v1.5.8**. |
| **1.5.7** | Patch — optional Settings **background hallgato keep-alive** (`SETTING_BackgroundHallgatoKeepAlive`, default off; Android WorkManager 15 min / iOS Background Fetch 15+ min; shared `GetNewTokens`) + **restore** opt-in **Remember password on this device** (`SETTING_RememberPasswordOnDevice`; Dart paths were briefly on `main` then **reverted in 1.5.6**, restored here). Builds on **1.5.6** session v1 core. Tag **v1.5.7**. |
| **1.5.6** | [HALLGATO_SESSION_PLAN](HALLGATO_SESSION_PLAN.md) **v1 core**: removed client **10-minute** session wall-clock; foreground proactive `POST /api/Account/GetNewTokens` every **3 min 30 s** while `AppLifecycleState.resumed`; pause on background; reactive GET 401 refresh unchanged; ~45 s post-login grace kept. Tag **v1.5.6**. |
| **1.5.5** | Patch — drawer Settings/Bug report/Logout no longer double Material icon + label emoji (`stripLeadingEmoji`); splash is color-only (no launcher icon on entry; Android 12 uses solid tile). Tag **v1.5.5**. |
| **1.5.4** | Patch — Android 10-min session wall-clock reliability (`SessionGuard` continue-from-stamp, prefs race fix, 15s ticker + lifecycle re-check); Bug report / emoji ghost duplicate fix (`EmojiRichText` untinted color-emoji spans). Policy still **10 min** wall-clock. Tag **v1.5.4**. |
| **1.5.3** | Patch — new launcher / adaptive app icon (Android + iOS) from updated ELTE Neptun branding; splash uses refreshed `assets/neptun2_logo.png`. Session policy unchanged (still **10 min**). Tag **v1.5.3**. |
| **1.5.2** | Patch — Android functional parity with iOS: App Widget “Today’s classes” from calendar cache (no JWT), `neptunelte://` deep-link intent + maps/mailto `<queries>`, release APK signing fallback when `key.properties` absent; Android OTP/2FA white-screen fix (opaque `TwoFactorCodePage`). Session policy unchanged (still **10 min**). |
| **1.5.1** | Patch — removes Calendar “Next 48 hours” strip (today / ZH / week / ICS / What’s Changed unchanged). Session policy unchanged. |
| **1.5.0** | Feature line **5** — plan items **10** (semester comparison) + **14** (iOS WidgetKit MVP; Android widget later in **1.5.2**). Item **11** (Academic Progress / tanterv) **dropped**. Numbered plan files deleted; backlog = TECHNICAL + DEV_BLOG. |
| **1.4.0** | Feature line **4** — plan items **5–9** + **12–13** (ghost what-if, calendar today/ZH/ICS export/class-notif granularity, payments honesty, maps deep-link, What’s Changed, student card claim/bank/profile **no QR**, home shortcuts). |
| **1.3.2** | Line 3 + patch for post-2FA black-screen navigation (`app_navigator`). |
| **1.3.1** | Line 3 + patch for auth / 2FA / Student-web-full messaging fixes. |
| **1.5.10**, … | Further patches on feature line **5**. Next big block after **1.5.x** → **1.6.0** (or **2.0.0** if that is the final/RC cut). |
| **2.0.0** | Final / release-candidate product line. Everything before that stays **1.x.y**. |

Bump `pubspec.yaml` (and iOS / Android mirrors) when releasing. Keep docs EN+RU and Settings aligned on the three-number marketing version.

**Android GitHub auto-update:** `AppUpdater` (`lib/Misc/auto_updater.dart`) prompts only when the latest Release `tag_name` is **strictly newer** than the installed `versionName`. Shipping a fix to sideload users requires a new marketing `1.x.y`, a **new** git tag `v1.x.y`, and a GitHub Release with the new APK — do **not** replace an APK on an existing same-version tag and expect auto-install. Policy: `.cursor/rules/android-github-release-tags.mdc`. Pure docs/chore commits need not bump/tag unless an APK ships.

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
│   ├── Technical/                 # TECHNICAL + DEV_BLOG + session plan (EN + RU)
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
| `docs/Technical/` | TECHNICAL + DEV_BLOG + `HALLGATO_SESSION_PLAN*` + `CAMPUS_MAP_PLAN*` (EN + RU); research under `campus_map_research/` |
| `docs/Legal-*` | Privacy, Terms, Cookies (EN / RU / HU) |
| `docs/README*.md` | Full product README |
| `test/` | Unit smoke: `elte_room_code_test.dart`; placeholder `widget_test.dart` |
| `.github/workflows/betabuild.yml` | CI: `flutter build apk --debug` |
| `.github/workflows/ios-ipa.yml` | CI: unsigned iOS IPA → artifact / GitHub Release |

**Missing:** `web/`, `linux/`, `macos/`, `windows/`, and any first-party backend. (No `IMPLEMENTATION_PLAN*` — deleted.)

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
6. After ELTE login, almost all student-data traffic is **GET** with `Authorization: Bearer <access JWT>` to the assigned `hallgatoN.neptun.elte.hu`. Portal cookies stay in an **in-memory** jar on `neptun.elte.hu` and are **not** attached to those REST GETs.

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
| `HomePage` (`lib/Pages/main_page.dart`) | **4** bottom tabs after login (Calendar, Markbook, Periods, Mail). Payments = drawer index 4. `WidgetsBindingObserver` → foreground JWT maintenance + optional background keep-alive sync |
| `SettingsPage` (`settings_page.dart`) | Theme, language, font, notifications, haptics, week offset; optional **background keep-alive** + **Remember password on this device**; **Contacts** sheet + marketing version only (`package_info_plus` `info.version`, e.g. `1.5.10` — no `+build`) at bottom |
| `AppDrawer` (`lib/Misc/app_drawer.dart`) | Greeting = `UserInfo` full name + Neptun code (no training ID under name); avatar photo from HWEB base64 (`userAvatar` / `GetUserAvatar`) with initials fallback; term, balance, multi-training switcher; **Student card / profile** page (item **12**); **Payments above Settings**; update (Android), logout |
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
| 2FA TOTP / email | `POST /Account/Login2FA` (`Phase=RequestTOTP` + `TOTPCode`, or email phases) → opaque `TwoFactorCodePage` (not transparent popup 9; Android white-screen fix in **1.5.2**) |
| `ToNeptunHWeb` → `outerlogin?GUID=` | App posts HWeb form, follows 302 |
| `POST /api/Account/OuterLogin` | Saves JWT; sets institute URL to **`https://hallgatoN.neptun.elte.hu`** |
| Student REST | **GET** + `Authorization: Bearer <access JWT>` on that hallgato host (`/api/UserInfo`, calendar, …). Portal cookies **not** sent. |

App setup UI:

1. `Splitter` → if `getHasLogin()` then `HomePage`, else ELTE hub (**display name: Neptun ELTE**).
2. Hub sets `PageDTO` to `elteInstituteName` + `elteNeptunBaseUrl` (`https://neptun.elte.hu`) → `SetupPageLogin`.
3. Credentials: Neptun code (`toUpperCase()`) + password.
4. If API returns 2FA → enter **6-digit TOTP** (Authenticator), then app bridges to hallgato via OuterLogin.
5. Demo: `DEMO` / `DEMO`.

**Honesty:** ELTE login is **portal Potlap + OuterLogin**, not `neptun.elte.hu/api/Account/Authenticate` (that returns empty 400). Dual-phase: portal cookies on `neptun.elte.hu` live in `_elteCookies` (**in-memory, not persisted**) → TOTP → OuterLogin → JWT. Password is stored in secure storage, but `trySilentReauth()` **returns false** for ELTE (needs interactive 2FA). Email OTP helper `elteRequestEmailOtp` exists in `api_coms.dart` and is **unused by UI** (TOTP-first). If Student web is **full**, bridge fails even after correct 2FA — UI must show `loginStudentWebFull`, **not** invalid credentials.

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

Login candidates start at **`https://neptun.elte.hu`** — not `/ujhallgato`. After OuterLogin, the persisted institute URL is **`https://hallgatoN.neptun.elte.hu`**.

Candidates: primary + ELTE root aliases only.

On success, persist the API base login selected (do not overwrite with a stale list URL). For ELTE that base becomes the assigned `hallgatoN`.

---

## 7. Home tabs (4 bottom + Payments drawer)

`HomePageState` + `BottomNavigatorWidget`. Swipe left/right among bottom tabs (`maxBottomNavWidgets = 4`). **No named routes.**

**Code today:**

| Index | Surface | Content |
|-------|---------|---------|
| 0 | bottom | Calendar — week timetable, classes/exams |
| 1 | bottom | Markbook (Subjects) — credits, average, ghost grade |
| 2 | bottom | Periods — registration, exams, subject signup |
| 3 | bottom | Mail / Messages — inbox, local search, unread filter, mark read |
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
| Mark-read (POST) | `/api/Message/SetReadedMessage`, `/api/Messages/SetReadedMessage`, `/api/Message/SetMessageAsReaded` (name variants) |

Unused HWEB paths seen in Sep 2026 captures (not called by the app) were inventoried in the former numbered plan §4.2 (files **deleted**). Coverage was incomplete; HARs are not in git. Known leftovers: mail archive/sent/settings, finance unpaid detail, official ICS/webcal URL — **not** product backlog unless re-opened. Exam/course registration XHRs seen — **not planned**.

Login body (JWT `Authenticate` — **dead for ELTE**; kept for the old/non-ELTE modern path):

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

### HTTP methods (ELTE Dart client)

After login, almost all student-data traffic is **GET** with `Authorization: Bearer <access JWT>` to the assigned `hallgatoN.neptun.elte.hu`. Portal cookies are **not** attached to REST GETs (`getRequest` sets Bearer + `Content-Type` + `Accept-Language` only).

**POST** exists for: portal `Login`, `Login2FA`, `OuterLogin` / `ToNeptunHWeb`, `POST /api/Account/GetNewTokens` (refresh JWT as Bearer, body `{}`), mark-mail-read (`SetReadedMessage` + name variants). **No PUT/DELETE** in the Dart client.

**Reads vs writes:** the only student-data **mutation** is mark-as-read. Student card, payments, mail compose, and exam registration are **not** writes here (card/payments are GET; compose / exam signup are not implemented).

### Session recovery and JWT maintenance

Refresh / re-login on **401/403 GET** lives in `_APIRequest` via `ensureValidSession` → `GetNewTokens` (when a refresh token exists). Else `trySilentReauth()` — **always false for ELTE** (needs interactive 2FA). Else `SessionGuard.forceExpiredLogout` wipes **auth only** via `DataCache.sessionWipeKeepCache(wipePassword: …)` (JWT / refresh / device cookie / `HasLogin`; **keeps username + academic cache**; password cleared unless Settings **Remember password on this device** is on — see below), navigates to login via `navigateToLoginRoot()` (root `pushAndRemoveUntil(Splitter)` — **not** `popUntil` on a sole Home route, which could empty the navigator into a black screen), and shows `auth_sessionExpired_PleaseSignIn`. The **POST** path has **no** 401 retry. **Manual logout** and **session expiry** both respect the remember-password opt-in (keep password when ON). Portal leftovers: best-effort portal `Account/Logout`, `resetEltePortalState`, `CalendarRequest.clearTrainingIdCache`, wipe `devicecookie_*`, tighten `_looksLikeInvalidCredentials` (no bare `invalid` on HTML `is-invalid`) so same-process re-login is not stuck on false “invalid credentials” (**1a**). Full `dataWipe()` (prefs.clear including cache) remains available for hard reset — not used on normal logout.

**Session end policy (1.5.6 / HALLGATO v1 core):** No client **10-minute wall-clock** forced logout. Session ends on **manual logout** or when refresh is dead (`GetNewTokens` fails with 401/403 or empty tokens on proactive or reactive refresh). The client does **not** parse JWT `exp`. Access JWT lifetime ~10–15 min is **observational** (Neptun practice). `SessionGuard.markParticipantSessionStarted()` (from `SetupPage`, before `navigateToHomeRoot`) sets post-login grace only — it does **not** persist `SESSION_StartedAtMs` or arm timers.

**Foreground proactive refresh (1.5.6 + resume fix 1.5.10):** While `AppLifecycleState.resumed`, `HomePage` runs a periodic timer every **3 min 30 s** (`SessionGuard.foregroundTokenMaintenanceInterval`) calling `SessionGuard.runForegroundTokenMaintenance()` → `_APIRequest.runProactiveTokenMaintenance(fromBackground: false)` → `POST …/api/Account/GetNewTokens` when `getIsModernApi()` and a refresh token exist. On each **`resumed`**, Home also runs **immediate** maintenance (do not wait for the first periodic tick — `Timer.periodic` delays first fire by a full interval), then refreshes calendar + mail if still logged in. Timer is **cancelled** on `paused` / `detached` / `hidden` (kept during brief `inactive`). Uses the same `_isRefreshingToken` lock as reactive `ensureValidSession` (skips tick if refresh in flight). **401/403** on foreground maintenance → `forceExpiredLogout`; network / transient errors → retry on next tick (GET 401 path remains fallback).

**Optional background keep-alive (Settings, default OFF; reliability 1.5.10):** Toggle **Keep session alive in background** (`SETTING_BackgroundHallgatoKeepAlive`). When on, logged in with a refresh token, **and** lifecycle is `paused` / `hidden` / `detached` (or lifecycle null at cold start), `HallgatoBackgroundKeepAlive.syncScheduledTasks()` registers **Android** `workmanager` periodic work (**45 min**; **15 min** initial delay; network + battery not low; **not** device-idle — idle blocked nearly all runs in **1.5.9**; **not** charging-required) and starts **iOS** `background_fetch` (minimum **45 min**, system-deferred — OS may never run). While `resumed`, background tasks are **cancelled** (foreground owns maintenance). Headless / fetch ticks call `SessionGuard.runBackgroundTokenMaintenance()` → same `GetNewTokens` with `fromBackground: true`; skip if last successful proactive refresh was within **25 min** (shared prefs coalesce). Shared refresh mutex; **401/403** logged only — no headless logout UI. When off or logged out, tasks are cancelled. Honesty: not a SLA; OEM Doze may still defer.

**Post-login grace (1.3.3):** For ~45 s after `markParticipantSessionStarted`, `ensureValidSession` does **not** call `forceExpiredLogout` when refresh/silent re-auth fail but an access token is still present — avoids an immediate kick from a race or flaky first API after fresh 2FA.

**Cold start:** `SessionGuard.isColdStartSessionUsable()` allows Home when `HasLogin` and a non-empty access token — **not** blocked by a wall-clock stamp. Dead/missing access token → wipe auth, login + TOTP. Long background without foreground refresh may still require full login when refresh JWT expires on the server.

**Cache honesty (plan item 1 shipped):** Every home surface (calendar / markbook / periods / mail / payments) paints from `HasCached*` lists first when present; network refresh is silent. On dead session / offline / failed refresh, lists are **not** replaced with an empty spinner. UI may show `cache_showingFromCache` banner. Empty calendar weeks are cached as `len == 0` so freedays render without a loading spinner. Multi-term markbook walks skip when `SessionGuard.isAuthBlocked`.

**Optional password retention (1.5.7; manual logout keep 1.5.10):** Settings → **Behavior & other** → **Remember password on this device** (`SETTING_RememberPasswordOnDevice`, default **off**). When on, `neptun_password` survives `sessionWipeKeepCache` on token failure / `forceExpiredLogout` / cold-start wipe **and** on **manual Log out** (login field pre-fill; **2FA still manual**). Turning the toggle off clears stored password. Wipe JWTs / `HasLogin` always. (**Honesty:** an earlier cut briefly landed then **1.5.6** reverted the Dart paths; **1.5.7** restores them; **1.5.10** keeps password on manual logout when opted in.) Portal/HWEB activity remains design-only in [HALLGATO_SESSION_PLAN.md](HALLGATO_SESSION_PLAN.md).

---

## 9. Auth, 2FA, tokens

| What | Where |
|------|-------|
| Password, JWT access/refresh, device cookie | `flutter_secure_storage` (`DataCache`) |
| Username, institute URL, cache flags, settings | `shared_preferences` |
| Demo | `setIsDemoAccount(1)` |

**JWT lifetime:** Access tokens are short-lived (~10–15 min **observational** on Neptun — the client does **not** parse JWT `exp`). Foreground maintenance refreshes before typical access expiry while the app is open; without a working refresh token, proactive or reactive refresh failure forces logout rather than showing empty “logged in” screens. `trySilentReauth()` is skipped for ELTE.

**2FA (modern):** `isTwoFactorRequired` / `requiresTwoFactor` / `twoFactorLoginToken` without `accessToken` (often HTTP 202) → code `2` → opaque `TwoFactorCodePage` via root `appNavigatorKey` (`lib/Pages/two_factor_page.dart`) → user types 6-digit **TOTP** → `submitTwoFactorCode`. The 2FA route pops **before** the HWEB bridge; on success setup calls `navigateToHomeRoot()` (`lib/app_navigator.dart` → root `pushAndRemoveUntil(HomePage)`), not a page-local `BuildContext`, so a disposed login route cannot leave a **black screen** (iOS) or **white window background** (Android; fixed in **1.5.2** by leaving transparent popup mode 9 for login 2FA).

**2FA (old):** unsupported → usually `0`.

**ELTE web vs app:** Web offers TOTP + E-mail backup (`XXX-XXXXXX`). App UI: TOTP field only. Helper `elteRequestEmailOtp` exists in code, **unused by UI**. Obsolete “2FA won’t work” banner **removed**.

---

## 10. Domain features

### 10.1 Timetable

Week view, `getUserWeekOffset()`, first study week `getFirstWeekEpoch()` from `getFirstStudyweek()`. Anchor is the Monday of the semester season week (autumn: week containing **1 Sep**; spring: week containing **1 Feb**) when the teaching/`szorgalmi` period starts within that fortnight — **not** subject-registration or login windows (those previously produced inflated weeks ~36 then ~16). Education week = whole weeks from that Monday to *this* Monday + `currentWeekOffset` (1 = current calendar page). Example ELTE autumn 2026: **1–7 Sep → week 1**, **7–14 Sep → week 2**. Online home open always recomputes and overwrites the cached epoch. Modern: `GetCalendarEvents` with **Mon–Sun** `endDate` (not next Monday — that wrongly pulled next week’s Monday classes, causing a ~163h fake “break” and duplicate lessons). Events outside the requested window are dropped. Same-day gap chips only (5 min–12 h), localized break strings. Course details + Calendar Settings filters (`isClassesVisible` / exams / periods). UI strips (plan item **3**): ZH/deadlines = upcoming tasks + exams from now (sorted by `startEpoch`); period banners (`typeId == 6`) **only** in the period strip, never as day-list classes. The former “Next 48 hours” classes+exams strip was **removed**. Pull-to-refresh keeps cached week painted. Drawer training switcher when multiple trainings are known. **Room codes** matching `Campus-Floor-Room[-Stream][-Group]` (e.g. `LD-0-805` or `LD-0-805-01-11`) are tappable in the timetable list, class dialog, and exam/legacy popups: tap toggles compact code ↔ localized summary (`Southern Building, Floor: 0, Room: 805, …`). Mapped prefixes: **LD** Southern / Déli, **LE**/LÉ Northern / Északi, **LK** Chemistry block (Northern); unknown prefix kept as-is. After decode, **LD/LE/LK** show **Open map** (`roomCode_OpenMap`) → Apple Maps / Google Maps building search (`ELTE Déli Tömb` / `Északi Tömb` / `Kémiai tömb`, 1117 Budapest) via `url_launcher`; unknown prefix stays text-only (no wrong pin). No invented lat/long. Stream/Group only shown when present in the code (`lib/Misc/elte_room_code.dart`).

### 10.2 Markbook

Subjects tab = markbook: taken subjects (with subject codes), credits, grades, ghost grade (popup 0), confetti. Shared math in `lib/Misc/markbook_math.dart` (**plan item 2**): **Átlag / Average** = `Σ(grade × credit) / Σ(credit)` for completed `grade >= 2`; **/30** = `Σ(grade × credit) / 30` (same numerator — **not** átlag÷30). Header shows this-term credits **and** accumulated completed credits (deduped by `subjectCode` across `getGradeHistoryAcrossTerms`). **Semester comparison** (**plan item 10**): per-term cards via `getSemesterComparison` / `CachedMarkbookTerm_*` (cache-first; same `MarkbookMath`). UI labels say `/30` explicitly; note: **app-computed**, not official Neptun KKI/GPA (`GetAverages` was empty in Sep 2026 HAR). Also lists **My courses** (`GetRegisteredCourses`) and a compact **grade history** across recent terms.

### 10.3 Payments / periods / mail

Charges and deadlines; **collective invoices** list + balance; periods with timers; inbox + **local search** (subject / sender / loaded body) + **unread-only chip** (client-side; API still `filterType=0`) + mark read; full mail thread posts. Message detail: optional HU→EN/RU machine translate (`MessageTranslator`) — **working**; offline/HTTP failure → `null` (caller keeps original). First use on a device shows a 5s inaccuracy disclaimer snackbar (`hasSeenMailTranslateDisclaimer`).

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
| Modern JWT + refresh | **Solid** | GET+Bearer on assigned `hallgatoN`; proactive + reactive `GetNewTokens`; JWT `exp` **not** parsed; no client wall-clock (1.5.6) |
| Modern 2FA TOTP (ELTE portal) | **Working MVP** | Portal Login2FA + OuterLogin JWT on hallgatoN. **Student web full** → `loginStudentWebFull` snackbar (not invalid password) |
| Modern 2FA email | **Helper in code; unused by UI** | `elteRequestEmailOtp` (`RequestEmailCode` / `CodePrefix`); TOTP-first UI |
| JWT Authenticate on neptun.elte.hu | **Dead for ELTE** | Empty HTTP 400; AD institute uses portal |
| Silent ELTE re-auth | **Disabled** | `trySilentReauth()` returns false; password stored but 2FA is interactive |
| Student-data writes | **Mark-read only** | Card / payments / mail compose / exam registration are not writes |
| Session keep-alive | **Foreground + optional background (1.5.6+)** | Foreground 3 min 30 s while `resumed` + **immediate** refresh on resume (**1.5.10**); optional Settings background (`workmanager` / `background_fetch`, **45 min** + network/battery-not-low, idle removed in **1.5.10**, default off). Widgets cache-only, no JWT |
| Old API 2FA | **None** | |
| Local iOS notifications | **Working MVP** | No Android-style exact alarm |
| ICS | **Dead UI** | Class exists, no setup entry |
| Homescreen widget | **iOS WidgetKit + Android App Widget MVP** | Today’s classes from calendar cache; no JWT. Shared `WidgetBridge` → App Group (iOS) / SharedPreferences (Android) |
| Mail translator | **Working** | HU→EN/RU via public gtx endpoint; failure → keep original; disclaimer once per device |
| Campus indoor map | **Research + schema** | Dump + Phase 1 schema in `campus_map_research/schema/`; [CAMPUS_MAP_PLAN](CAMPUS_MAP_PLAN.md) Phase 0–1 done, Phase 2 (digitize LD) next; Flutter UI deferred (Phase B). Shipped app still external maps deep-link only |
| App shortcuts | **Shipped (13)** | Android `shortcuts.xml` + iOS `UIApplicationShortcutItems`; Calendar / Mail / Payments; cold-start session gate |
| Automated tests | **Thin** | `test/elte_room_code_test.dart` (room/maps); `test/widget_test.dart` placeholder — **no** CI analyze/test job yet |
| APK / Play update | **Android only** | Hidden on iOS |
| Education week number | **Fixed (Sep 2026)** | Season Monday (Sep/Feb 1 week) + teaching period; ignores registration anchors; online refresh overwrites cache |
| App Store / Play production | **Not the current goal** | |
| Drawer profile photo | **Working** | ELTE HWEB: `data.userAvatar.image` on `/api/UserInfo` + `/api/General/GetUserAvatar?imageSizeType=Normal` (base64 JPEG). Cached in `DataCache`; drawer `MemoryImage`; initials on failure/empty |
| Student card / profile | **Claim / bank / profile only** | Item **12**: `StudentCardPage` + `StudentCardRequest`. Bank flags (no IBAN/SWIFT logged). Claim status (no QR / card number / expiry — HWEB has none). Optional `GetGeneralUserData` + contacts. Cache `STUDENT_CardCacheJson` |
| Drawer training ID line | **Removed** | Raw `studentTrainingId` / GUID must not show under the name; human labels only in the multi-training dropdown |

Monoliths: `main_page.dart`, `api_coms.dart`, `popup.dart`, `setup_page.dart`, `language.dart` — ~1400–2600 lines each. **Do not split** while the goal is iOS/login, not a rewrite.

---

## 12. Data layer

`DataCache` (`lib/storage.dart`) is the only layer.

Cache flags: calendar, markbook, payments, periods, mail, first week, term list. Offline UI reads cache. This is **not** a full offline product.

Secrets: username/password/JWT/device cookie in secure storage (migrated from older SharedPreferences). ELTE **portal** cookies (`_elteCookies`) are **in-memory only** — not persisted; wiped by `resetEltePortalState()` on logout.

`sessionWipeKeepCache(wipePassword: …)` = session expiry / logout auth wipe: clears tokens/device cookie/`HasLogin`, **keeps username + academic cache**; password cleared when `wipePassword` is true (default). `SessionGuard` passes `wipePassword: false` whenever the remember-password toggle is on (manual logout **and** automatic session death); `true` when the toggle is off. `dataWipe` = full prefs wipe including cache (hard reset only). Drawer shows HWEB profile photo when available, else **initials** from display name / Neptun code.

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
| Widget extension | `com.nanda070.neptunmobile.TodayClassesWidget` (App Group `group.com.nanda070.neptunmobile`) |
| Tests | `com.nanda070.neptunmobile.RunnerTests` |
| Team (local) | `48FW5533N7` (Automatic signing) |
| `PRODUCT_NAME` | `Runner` (do not change — breaks Flutter) |

**WidgetKit / App Widget:** iOS extension `TodayClassesWidget` ships CFBundleVersion / ShortVersion from build settings (`CURRENT_PROJECT_VERSION` / `MARKETING_VERSION`, kept in sync with marketing **1.5.7**). Empty appex `CFBundleVersion` fails device install (`MissingBundleVersion`). Android `TodayClassesWidgetProvider` reads the same JSON snapshot (no JWT).

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
- `UIApplicationShortcutItems`: Calendar / Mail / Payments (plan item **13**)

### Platform-only notes

No separate matrix doc (`IOS_VS_ANDROID*` deleted after Android APK functional parity). Shared product surface on both OSes; remaining differences:

- **Distribution / updater:** Android — GitHub APK `AppUpdater` + Play `in_app_update` when installed from Play; iOS — updater UI hidden / no-op (no TestFlight / IPA auto-update twin).
- **Signing:** Android — local `key.properties` + keystore (debug fallback if absent); iOS — Xcode Team / profiles (not in repo). App Store **not set up**.
- **CI:** Android debug APK (`betabuild.yml`); unsigned iOS IPA (`ios-ipa.yml`). No analyze/test job yet.
- **IDs:** iOS `com.nanda070.neptunmobile` · Android `com.nanda070.neptun_mobile.app`.
- **Haptics / toast / alarms:** iOS `HapticFeedback`; Android `vibration` + exact-alarm APIs; Fluttertoast often invisible on iOS (`custom_snackbar.dart` exists).
- **Links (`url_launcher`):** should work on both (Android-only gate removed).
- **SPM warning:** `flutter_secure_storage`, `open_filex` — not a blocker yet.

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

Platform-only notes vs iOS: see [§14](#14-ios) (updater / signing / CI / haptics). Product features match after APK parity.

| Field | Value |
|-------|-------|
| `applicationId` / namespace | `com.nanda070.neptun_mobile.app` |
| `compileSdk` | 36 |
| Java / Kotlin | 17 |
| minSdk | `flutter.minSdkVersion` |

```bash
flutter pub get
flutter run -d android
flutter build apk --release
```

Play: `in_app_update` if `installerStore == com.android.vending`. Otherwise GitHub APK (`lib/Misc/auto_updater.dart`) — **Android only**. Auto-update compares Release `tag_name` to installed `versionName` (**strictly newer** only); same-tag APK clobber does not prompt. Each APK ship needs a new `1.x.y` + `v1.x.y` Release.

Release signing: local `android/key.properties` + keystore (gitignored). If absent, release builds fall back to the **debug** keystore so sideload beta APKs still produce.

CI: `.github/workflows/betabuild.yml` — Ubuntu, debug APK. `.github/workflows/ios-ipa.yml` — macOS, unsigned IPA for Sideloadly (no Apple signing secrets in repo yet).

---

## 16. Removed / disabled

| Feature | State |
|---------|-------|
| Donate / Buy Me a Coffee | Removed from UI |
| zoligamer branding | Stripped (packages, funding, theme/language URLs) |
| Pirate + DE/RO/UA/AR/ES/ZH | Removed from language catalog |
| `linux/` | Removed |
| Homescreen widget | iOS WidgetKit + Android App Widget MVP |
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
| Don’t split monoliths yet | Only thin unit smoke tests; goal is platform + product honesty, not Clean Architecture |
| EN default, only EN/HU/RU/TR | Owner request; fewer dead packs |
| GitHub raw for institutes/languages/themes | Update without an APK/IPA release |
| `badCertificateCallback => true` | Broken campus certs; MITM risk accepted |
| Removed obsolete 2FA “won’t work” banner | ELTE requires 2FA; app supports code entry |
| No Authenticator deep-link / auto-OTP | TOTP is typed manually; Microsoft Authenticator stays external |
| Email OTP helper exists; unused by UI | `elteRequestEmailOtp` implements portal `GetEmail` / `CodePrefix`; UI is TOTP-first (no email OTP screen) |
| SessionGuard JWT maintenance, not wall-clock | No 10 min client timer; logout on manual / dead refresh; `exp` not decoded |
| Background session keep-alive | Optional Settings toggle (default off); **45 min** OS-scheduled + battery-not-low + network (**1.5.10**, idle removed); 15 min Android initial delay; coalesce 25 min; cancel while resumed; immediate GetNewTokens on resume; foreground 3 min 30 s remains primary; widgets sync cache without JWT |
| `loginServerBusy` ≠ invalid password | Neptun overload was shown as a bad password |
| `loginStudentWebFull` ≠ invalid password | HWEB capacity full after correct 2FA was painted as bad password (`submitTwoFactor` → `false` → `_paintRed`) |
| ELTE hub → `https://neptun.elte.hu` | Portal login + 2FA. After `/ToNeptunWeb/ToNeptunHWeb`, JWT REST is on load-balanced `hallgato1…N` — never hardcode a single node |
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
| `docs/Technical/DEV_BLOG.md` / `DEV_BLOG.ru.md` | Chronological dev diary + remaining backlog notes |
| `docs/Technical/HALLGATO_SESSION_PLAN.md` / `.ru.md` | Hallgato JWT maintenance — **v1 core + mail/calendar fixes shipped 1.5.6**; optional background keep-alive + password retention **1.5.7**; battery minimization **1.5.9**; reliability (idle drop, resume refresh, password on manual logout) **1.5.10**; portal/HWEB research still design-only |
| `docs/Technical/CAMPUS_MAP_PLAN.md` / `.ru.md` | Finish-the-map-first plan — Phase 0–1 done (schema); Phase 2 digitize LD next; Phase B (Flutter) deferred; research + schema under `campus_map_research/` |
| `test/elte_room_code_test.dart` | Unit tests for ELTE room-code / maps deep-link |
| `test/widget_test.dart` | Placeholder widget test |
| `docs/Legal-En/` · `Legal-Ru/` · `Legal-Hu/` | Privacy, Terms, Cookies |
| `docs/LICENSE` | LGPL-3.0-only (canonical); root `LICENSE` mirrors it |
| `pubspec.yaml` | Version, dependencies |
| `lib/main.dart` | `MaterialApp`, theme, registers login/home roots |
| `lib/app_navigator.dart` | Root `appNavigatorKey`; `navigateToHomeRoot` / `navigateToLoginRoot` |
| `lib/app_shortcuts.dart` | Home-screen shortcut ids → view index; MethodChannel bridge (item **13**) |
| `lib/widget_bridge.dart` | Today’s-classes snapshot → iOS App Group / Android SharedPreferences (no JWT) |
| `android/.../TodayClassesWidgetProvider.kt` | Android App Widget MVP (item **14**) |
| `android/.../res/xml/shortcuts.xml` | Static Android launcher shortcuts |
| `ios/Runner/Info.plist` | Display name, notifications, URL schemes, `UIApplicationShortcutItems` |
| `lib/Pages/startup_page.dart` | Login / home branch; cold-start shortcut + session gate (**13**) |
| `lib/Pages/setup_page.dart` | Login, URL, 2FA callback, ICS class |
| `lib/Pages/main_page.dart` | Home + **4** bottom tabs + drawer Payments (**1c**); `initialView` for shortcuts |
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
| `lib/Misc/app_drawer.dart` | Drawer + entry to student card / profile |
| `lib/Pages/student_card_page.dart` | Item **12** claim / bank / profile UI (no QR) |
| `lib/Misc/auto_updater.dart` | GitHub APK, Android-only |
| `universityNameUrlPairs.json` | Institutes — **ELTE only** (`https://neptun.elte.hu`) |
| `Languages/supportedLanguages.json` | RU/TR catalog |
| `Themes/supportedThemes.json` | Remote themes |
| `ios/Runner.xcodeproj/project.pbxproj` | Bundle ID, Team |
| `android/app/build.gradle` | `applicationId` |
| `.github/workflows/betabuild.yml` | Android CI |
| `.github/workflows/ios-ipa.yml` | Unsigned iOS IPA → Release / artifact |

---

*End of document. If this disagrees with the code, the code and a fresh `git log` win.*
