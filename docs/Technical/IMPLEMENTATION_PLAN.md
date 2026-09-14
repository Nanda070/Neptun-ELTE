# Neptun ELTE — implementation plan

> 🇷🇺 [Русская версия](IMPLEMENTATION_PLAN.ru.md) (richer user-facing twin; **same facts**)

**Owner / developer:** **Nanda** (full legal name only in Legal docs).  
**Product:** Neptun ELTE — unofficial mobile client for ELTE Neptun. Not a multi-university app.

This file is a **plan only**. Nothing listed here is implemented by writing the document. Do **not** treat unchecked items as shipped.

Last sync with the codebase: **September 2026**. Sources: `lib/**`, `docs/Technical/TECHNICAL.md`, `DEV_BLOG.md`. HAR inventory §4.2 from user captures 2026-09-13 (incomplete).

| | |
|--|--|
| **Status** | Foundation **1a / 1b / 1c / 1 / 2 / 3** + mail item **4** + ghost item **5 shipped** (Sep 2026). Items **6–14** still backlog |
| **Release** | Current marketing version **1.3.4** (`pubspec` **1.3.4+1**). Feature line **3** = plan items **1–3** done; patch **4** = mail search + unread filter (item **4**). **1.3.3** = post-2FA immediate session-expired logout fix. Next big feature block → **1.4.0**; final product → **2.0.0**. User-facing / Settings / docs use three numbers only — do not advertise `+build`. See [TECHNICAL § Versioning](TECHNICAL.md#versioning). |
| **Order** | Implement in the numbered group order below. Later items assume earlier honesty (**1a** logout re-login, **1b** background wall-clock, **1c** nav IA, session, cache, markbook math, mail IDs). |
| **Live ELTE login** | Portal + TOTP + OuterLogin path exists in code. Treat as **working MVP, not exhaustively re-tested** on every device. Email OTP is HAR-known, UI thin. If Student web is **full**, bridge fails after correct 2FA. |
| **HAR-gated** | **Tanterv graph / Academic Progress** still blocked (no curriculum XHR). **Student-card QR / number / expiry** still missing. **Bank + card-claim (NEK/FIR) + profile field names** captured 2026-09-13 (incomplete — user did not click every control). Exam / course registration is **not planned**. |

Product README: [`docs/README.md`](../README.md). Technical map: [`TECHNICAL.md`](TECHNICAL.md). Dev diary: [`DEV_BLOG.md`](DEV_BLOG.md).

---

## Contents

1. [Honesty and invariants](#1-honesty-and-invariants) — [Navigation IA (planned)](#navigation-ia-planned)
2. [Priority groups (implement in this order)](#2-priority-groups-implement-in-this-order)
3. [Work items 1a–1c + 1–14](#3-work-items-1a1c--114)
4. [HAR capture (user-actionable)](#4-har-capture-user-actionable) — [§4.2 captured inventory](#42-captured-inventory-incomplete--2026-09-13) — [§4.3 live Chrome](#43-live-chrome-walk-same-day-logged-in-hallgaton)
5. [Implementation templates (copy this pattern)](#5-implementation-templates-copy-this-pattern)
6. [What already exists (cheat sheet)](#6-what-already-exists-cheat-sheet)

---

## 1. Honesty and invariants

Document what the code **actually** does.

| Claim | Reality in repo |
|-------|-----------------|
| Bottom nav after login | **Shipped (1c):** **4** bottom tabs via `HomePage` + `BottomNavigatorWidget` — Calendar, Markbook, Periods, Mail. **Payments** in left drawer **above Settings** (index 4). Contacts + app version at bottom of Settings. Figma mockups may still show 5 tabs; **app IA is 4 + drawer**. |
| Session | `SessionGuard` (`lib/API/api_coms.dart`): **10-minute** wall clock from `HomePage` entry → `forceExpiredLogout` (foreground `Timer` + persisted `SESSION_StartedAtMs` checked on resume — **1b**). JWT refresh does **not** extend the clock. 401 + failed `GetNewTokens` also force logout. Username kept; password/JWT wiped; **academic cache kept** (`sessionWipeKeepCache` — **1**). **No silent ELTE portal re-auth** (needs 2FA). Logout wipe: portal Logout best-effort, jar + 2FA/antiforgery, `devicecookie_*`, training-id cache, tightened `_looksLikeInvalidCredentials` (**1a** shipped). |
| Cache | `DataCache` (`lib/storage.dart`). Flags + string lists. **All home surfaces** read cache first, then silent refresh (**1**). Banner `cache_showingFromCache` when serving stale/offline. Markbook / payments / periods / mail still use 24 h TTL for “fresh enough skip network”. Empty calendar weeks cached as `len == 0`. |
| Markbook numbers | Credit-weighted **átlag** = `Σ(grade × credit) / Σ(credit)` for completed subjects with `grade >= 2`. Second number **`Σ(grade × credit) / 30`**, labeled **/30** (ösztöndíj / scholarship as subtitle) — **not** “átlag ÷ 30”. Shared `MarkbookMath` (**2**). Ghost grade uses the same formulas. |
| Credits in header | This-term credits **and** accumulated completed credits (dedupe `subjectCode` via `getGradeHistoryAcrossTerms`). Diploma / official KKI **not** shown. |
| Calendar week | `GetCalendarEvents` with **Mon 00:00 – Sun 23:59:59**. Events outside the window dropped. Period banners (`eventType == 6`) stay out of day lists; they go to a strip. |
| ICS | **Import** parser exists (`lib/API/ics_calendar.dart`, `SetupPageCalendarLogin`). **No setup-hub button.** **Export does not exist.** |
| Mail | Inbox + pagination (20) + unread count + mark-read + HU→EN/RU translate. **Local search** (subject / sender / loaded body) + **unread-only chip** (client-side). `filterType=0` stays hardcoded (HAR honesty — no server unread filter). |
| Payments | `totalMoney` = sum of **`completed`** transaction `abs(ammount)` from the **last 50** `GetStudentPreviousTransactions`. Header string says “spent … Huf”. Collective invoices are a separate list. Payment notifs can schedule **one local notification per remaining day** (or 32 days if no deadline). |
| Maps | Room codes `LD`/`LE`/`LK` **decode in-app** (`DecodableRoomText`). **No maps URL.** |
| Curriculum | `URLs.CURRICULUMS_URL = "/api/GetCurriculums"` — **404** on live HWEB (old MobileService path). There is **no Tanterv menu**. Progress UI is **Studies → Advancement**. `GetStudentCurriculumTemplates` and `creditprogress` returned **empty** this term. Official average *labels* live on `RegistrySheet/GetStudentTrainingTermData`. `SubjectApplication/Curriculum` is a signup dropdown (seen, not planned). |
| Exam / course registration | **Not in the app. Not planned.** Do not add vizsgajelentkezés / tárgyjelentkezés UI. Signup XHRs seen in `finances.har` — **seen but not planned**. |
| Student card | **Not in the app.** HAR 2026-09-13: **claim / NEK / FIR** + **bank** + **profile** field names known. **No QR, no card number, no expiry.** |
| Homescreen widgets | **Removed** (was a stub). Native epic — last. |
| Live login | Implemented path: portal `Login` → `Login2FA` (TOTP) → `ToNeptunHWeb` → `OuterLogin` JWT on assigned `hallgatoN`. **Do not hardcode N.** Email OTP (`RequestEmailCode` / `CodePrefix`) HAR-known, UI thin. |

**Do not break:** ELTE hub login, TOTP 2FA popup (mode 9), cache-first calendar, room-code tap decode, LanguagePack HU+EN + RU/TR JSON. **1c shipped** — keep bottom at **4** (Calendar \| Markbook \| Periods \| Mail); Payments stays drawer-only (do **not** put Payments back on the bottom bar).

### Navigation IA (**1c shipped**)

**One-liner:** Bottom = **Calendar \| Markbook \| Periods \| Mail**; drawer **above Settings** = **Payments** (plus existing profile / balance / training / etc.). Contacts + app version at bottom of Settings.

| Surface | Code |
|---------|------|
| Bottom nav | **4 tabs:** Calendar, Markbook (Subjects), Periods, Mail / Messages |
| Left drawer | Profile, balance, training, **Payments** (above Settings), Settings, … |
| Settings | … existing toggles; **Contacts** sheet + marketing version label (`1.3.4`, no `+build`) at bottom |

Do not re-add Payments to the bottom bar.

---

## 2. Priority groups (implement in this order)

Later work is cheaper if earlier items land first.

### Foundation (do first)

| # | Item | Why this early |
|---|------|----------------|
| 1a | Logout → false invalid credentials | **DONE** (Sep 2026). Same-process re-login must work **before** other session UX polish (item 1). |
| 1b | Background ≥10 min → force logout | **DONE** (Sep 2026). Wall-clock must survive app suspend; `Timer`-only clock is dishonest on iOS/Android. |
| 1c | Nav IA: 4-tab bottom + Payments in drawer; Contacts/version in Settings | **DONE** (Sep 2026). UI structure **before** polishing strips on tabs. |
| 1 | Session + cache honesty | **DONE** (Sep 2026). Keep academic cache on expiry; cache-first tabs + banner. |
| 2 | Honest markbook | **DONE** (Sep 2026). `/30` labels + accumulated credits + `MarkbookMath`. |
| 3 | Clean calendar data | **DONE** (Sep 2026). Strip filters/sort; empty-week cache; no day-list period bleed. |

### Then mail

| # | Item | Why after foundation |
|---|------|----------------------|
| 4 | Mail search + unread filter | **DONE** (Sep 2026). Local search + unread chip; `filterType=0` unchanged. |

### Then parallel branches (after 1–4)

| # | Item | Gate |
|---|------|------|
| 5 | Ghost grade goal / what-if polish | **DONE** (Sep 2026). Live átlag+/30 in popup; optional target grade; same `MarkbookMath` formula. |
| 6 | Today summary + ZH/deadline strip + ICS **export** + class notification granularity | After item 3 |
| 7 | `totalMoney` accuracy + payment notification antispam | Independent of mail; after session/cache |
| 8 | Maps deep-link on LD/LE/LK decode | After calendar polish; uses `elte_room_code.dart` |
| 9 | What’s Changed (simple) | **After** session/cache **and** mail IDs (item 4) |
| 10 | Semester comparison | **After** honest markbook (item 2) |
| 11 | Academic Progress | **STILL blocked** — Sep 2026 HARs have no tanterv graph |
| 12 | Student card | Claim / bank / profile **field names captured**; QR / number / expiry **still missing** |
| 13 | App shortcuts | After session UX + deep links (items 1, 8) |
| 14 | Homescreen widgets | **Last** — native Android/iOS epic |

---

## 3. Work items 1a–1c + 1–14

### 1a. Logout → false “invalid credentials” (same process) — **DONE**

- **Why**  
  After logout, immediately signing in again with a **valid** password shows **invalid credentials** until the user kills and reopens the app. This is a session/logout bug, not a wrong password. It blocks every later session UX item (cache-on-expiry, re-login refresh). Docs previously claimed the portal cookie jar is cleared on logout; **that wipe is already in code** (`resetEltePortalState` + `_elteCookies.clear()`), and login even clears the jar again — **the repro still happens without a process restart**. Remaining leftover state is therefore something the current wipe misses (or a classifier that treats a leftover-session 200 as a bad password).

- **Depends on**  
  Nothing. Do this **before** item 1 (session + cache honesty / UX polish).

- **Already in code**  
  - `SessionGuard.userInitiatedLogout` / `forceExpiredLogout`: `resetEltePortalState()` then `DataCache.dataWipe()` (`lib/API/api_coms.dart`).  
  - `resetEltePortalState()`: `_elteCookies.clear()`, `_elteClearPortal2fa()` (2FA key, NeptunCode, **antiforgery**, Rendered, email prefix).  
  - `dataWipe()`: `prefs.clear()`, deletes secure `neptun_password` / `neptun_jwt_token` / `neptun_refresh_token`, `_localWipe()` (`HasLogin`, institute URL, training id, in-memory tokens), **keeps username**.  
  - Login: `setup_page.dart` calls `resetEltePortalState()` + `clearAuthBlock()`; `_tryEltePortalLogin` clears the jar again, GET `/Account/Login`, POST `LoginName` + `Password` + `__RequestVerificationToken`.  
  - Bare `LoginName` in a 200 body is **not** treated as invalid (comment: Bug B / CSRF). Invalid is `_looksLikeInvalidCredentials` (substring `invalid` / `hibás` / `érvénytelen`, or 401/403) or validation-summary strings.  
  - **Not wiped today:** `devicecookie_${USER}` in FlutterSecureStorage; `CalendarRequest._cachedTrainingIds`; no HTTP **portal Logout**; no shared `HttpClient` singleton (new `HttpClient()` per `_elteSend`, closed in `finally`) — but `HttpOverrides.global` is the `NeptunCerts` singleton.

- **What to build**  
  1. Repro without killing the app: logout → same (or new) valid password → log POST status, `Location`, whether `_elteCookies` was empty at POST, antiforgery present, and which branch returned `loginInvalidCredentials`.  
  2. Wipe **all** leftover process + persisted auth state on logout (and again at login start): in-memory `_elteCookies`, 2FA/antiforgery, access + refresh JWT, `HasLogin`, institute URL, training ids (`DataCache` + `CalendarRequest.clearTrainingIdCache()`), `devicecookie_*` in secure storage, refresh lock, `SessionGuard` flags.  
  3. If the in-memory jar is already empty and the false invalid remains: **POST a real portal logout** (or equivalent) so the server session dies; verify `HttpClient` / `HttpOverrides` is not leaking cookies at the platform layer.  
  4. Tighten `_looksLikeInvalidCredentials`: do **not** match the substring `invalid` on a full login HTML page (`is-invalid`, scripts). Only treat as wrong password when the portal actually reports it. CSRF / already-logged-in / 200 form redisplay → busy or retry, **not** invalid credentials.  
  5. `loginInvalidCredentials` / “Invalid username or password!” **only** when the password is actually wrong.

- **Where**  
  `lib/API/api_coms.dart` (`SessionGuard`, `resetEltePortalState`, `_tryEltePortalLogin`, `_looksLikeInvalidCredentials`, `_elteSend`), `lib/storage.dart` (`dataWipe` / device cookie / training id), `lib/Pages/setup_page.dart`, logout callers (`lib/Misc/app_drawer.dart`, `lib/Pages/main_page.dart`).

- **Via**  
  Portal: GET/POST `/Account/Login`, optional portal Logout. Classifier: `_looksLikeInvalidCredentials`, `loginInvalidCredentials` vs `loginServerBusy`. Storage: `dataWipe`, `getDeviceCookie` / `setDeviceCookie`, `clearTrainingIdCache`, `getAccessToken` / `getRefreshToken`, `HasLogin`.

- **Prerequisites**  
  None. Live ELTE login is **MVP / not exhaustively re-tested** — this item *is* the re-test of logout → login in the **same process**.

- **Done when**  
  Logout → immediately login with the same (or a new) **valid** password works **without** killing/reopening the app. “Invalid username or password” / `loginInvalidCredentials` **only** when the password is actually wrong.

- **Out of scope**  
  Item 1 cache-on-expiry UX, silent portal re-auth, email OTP UI, changing the 10-minute duration (keep 10 min; fix **how** it is measured in **1b**).

---

### 1b. Background ≥10 min → force logout (wall-clock vs paused Timer) — **DONE**

- **Why**  
  Product rule: if the user leaves the app for **10+ minutes**, force logout on return (same path as expired `SessionGuard`: clear tokens, keep username, snackbar, go to login). **Today:** background / swipe-away / lock does **not** log out — returning to the app keeps the account. Root cause (honest): Flutter `Timer` wall-clock often **pauses while the process is backgrounded** on iOS/Android, so `startSessionWallClock()` may never fire if the app was not in the foreground for those 10 minutes.

- **Depends on**  
  Nothing strictly; pair with **1a** / item **1**. Do not pretend the existing Timer alone is a true wall clock.

- **Already in code**  
  - `SessionGuard.sessionWallClockLimit = 10 min`, `startSessionWallClock()` (in-memory `Timer`), `cancelSessionWallClock()`, `forceExpiredLogout()` (`lib/API/api_coms.dart`).  
  - Started from `HomePage.initState`. No `AppLifecycleState.resumed` check against a stored timestamp.

- **What to build**  
  1. On session start / Home entry, store a **wall-clock timestamp** (`sessionStartedAt` / last-active epoch — prefs or secure storage is fine).  
  2. On `AppLifecycleState.resumed` (and optionally `paused`/`inactive` to refresh last-active): if `now - sessionStartedAt >= 10 min` → call **`forceExpiredLogout`** (same UX as timer expiry).  
  3. Optionally cancel/restart the foreground `Timer` on resume for the **remaining** time — but **do not** rely only on an in-memory Timer while suspended.  
  4. Keep duration at **10 minutes**; JWT refresh still must **not** extend the clock.

- **Where**  
  `lib/API/api_coms.dart` (`SessionGuard`), `lib/Pages/main_page.dart` (or a WidgetsBindingObserver / lifecycle owner), optionally `lib/storage.dart` for the timestamp key.

- **Via**  
  `WidgetsBindingObserver` / `AppLifecycleState`; existing `forceExpiredLogout` + pending message snackbar.

- **Prerequisites**  
  None. Live ELTE login remains MVP / not exhaustively re-tested.

- **Done when**  
  Background **≥10 min** → open app → kicked to login (tokens cleared, username kept, snackbar). Background **&lt;10 min** → still in session. Foreground continuous **10 min** still kicks as today.

- **Out of scope**  
  Changing the 10-minute policy, silent portal re-auth, OS-level background fetch / push to logout while killed forever (killed process is a separate cold-start path via JWT / `HasLogin` — document if touched).

---

### 1c. Nav IA: 4-tab bottom + Payments in drawer — **DONE**

- **Why**  
  Target information architecture: Calendar, Markbook, Periods, and Mail stay on the bottom bar; Payments stays drawer-only so the bar stays four icons. Contacts moved into Settings (with app version). Land this **before** polishing calendar strips / payments chrome as if five bottom tabs were permanent.

- **Depends on**  
  Nothing for structure. Prefer after **1a** so logout/login still reaches Home with the new nav. Session/cache (**1** / **1b**) can proceed in parallel.

- **Already in code**  
  - `BottomNavigatorWidget` + `HomePageState` page index 0–4: calendar, markbook, periods, mail, payments.  
  - `maxBottomNavWidgets = 4`; swipe cycles 0–3 only.  
  - `AppDrawer`: profile, balance, training switcher, **Payments above Settings**, Android update, logout — Periods/Contacts **not** in drawer.  
  - `SettingsPage`: Contacts sheet + `package_info_plus` version label at bottom.

- **What to build**  
  1. Bottom nav **only:** (0) Calendar, (1) Markbook / Subjects, (2) Periods, (3) Mail / Messages.  
  2. Drawer entry **Payments** placed **above Settings**; opening it shows the existing page widget (same APIs/cache).  
  3. Remap any hard-coded tab indices (shortcuts item **13**, deep links, `initialIndex`).  
  4. Do **not** put Payments back on the bottom bar.

- **Where**  
  `lib/Pages/main_page.dart`, `lib/Navigator/` bottom nav, `lib/Misc/app_drawer.dart`, `lib/Pages/settings_page.dart`, language keys if missing.

- **Via**  
  Existing `PaymentsPageWidget` / periods widgets; drawer `ListTile`; Settings Contacts sheet; index-based navigation (still no named routes unless a later item adds them).

- **Prerequisites**  
  Docs already state planned vs code (this plan + README + TECHNICAL). No Figma requirement to ship.

- **Done when**  
  After login: four bottom icons; Payments reachable from drawer above Settings; Contacts + version at bottom of Settings; all five feature surfaces still work with cache/API. Foreground/background session behavior unchanged by this item alone.

- **Out of scope**  
  Redesigning Payments/Periods content (item **7** etc.), Figma-only polish, re-adding Payments as a bottom tab.

---

### 1. Session + cache honesty — **DONE**

- **Why**  
  Users hit a 10-minute wall-clock logout and/or a dead JWT. Previously `forceExpiredLogout` → `DataCache.dataWipe()` cleared **tokens and academic cache**. Re-login then showed empty tabs until every endpoint returned. Calendar already had the right pattern (cache first, silent refresh). Other tabs often did not.

- **Depends on**  
  Item 1a (same-process re-login must work first). This is still the cache/session UX foundation.

- **Already in code**  
  - `SessionGuard` — `sessionWallClockLimit = 10 min`, `startSessionWallClock()`, `cancelSessionWallClock()`, `forceExpiredLogout()`, `userInitiatedLogout()`, `registerNavigator`, `consumePendingMessage()`, `isAuthBlocked` (`lib/API/api_coms.dart`).  
  - `HomePage.initState` starts the clock and registers navigation to `Splitter` (`lib/Pages/main_page.dart`).  
  - Login screen shows `SessionGuard.consumePendingMessage()` (`lib/Pages/setup_page.dart`).  
  - Refresh: `_APIRequest.ensureValidSession` → `POST /api/Account/GetNewTokens`. Silent portal re-auth **disabled**.  
  - Calendar: `fetchCalendar(allowCache: true, silentRefreshIfOnline: true)` reads `CachedCalendar_w{weekOffset}` then refreshes.  
  - Markbook / payments / periods / mail: 24 h TTL via `MarkbookCacheTime`, `PaymentsCacheTime`, `PeriodsCacheTime`, `MailCacheTime`.  
  - `dataWipe()` keeps username; `prefs.clear()` drops cache lists.

- **What to build**  
  1. On session expiry, **keep academic cache** (calendar / markbook / payments / periods / mail / terms / avatar). Wipe only password, JWT, refresh, device cookie, `HasLogin` as needed.  
  2. Every tab: **if cache exists, render it immediately**; refresh in the background; never replace a full list with an empty spinner because the session died.  
  3. If session is invalid: snackbar `auth_sessionExpired_PleaseSignIn` + login; cached UI may stay visible as **read-only** until re-login (decide and document).  
  4. Do not start mail-body fetch, course-details, or multi-term markbook walks without `ensureValidSession()`.  
  5. After successful re-login, silent refresh all home surfaces (calendar / markbook / mail / payments / periods — whether still bottom tabs or drawer); do not wait for pull-to-refresh.  
  6. Keep the 10-minute wall clock unless product later changes it — do not silently extend it on JWT refresh (current documented policy). Pair with **1b** so backgrounded time counts.

- **Where**  
  `lib/API/api_coms.dart` (`SessionGuard`, `dataWipe` call sites), `lib/storage.dart` (`dataWipe` vs a new `sessionWipeKeepCache()`), `lib/Pages/main_page.dart` (`fetchCalendar`, markbook/payments/periods/mail fetch), `lib/Pages/setup_page.dart` (pending message).

- **Via**  
  Cache flags: `HasCachedCalendar`, `HasCachedMarkbook`, `HasCachedPayments`, `HasCachedPeriods`, `HasCachedMail`.  
  List keys: `CachedCalendar_w{n}_$i`, `CachedCalendarLength`, `CachedMarkbook_$i`, `CachedPayments_$i`, `CachedPeriods_$i`, `CachedMails_$i`, `CachedMailsUnread`, `CACHED_TermsList`.  
  Auth: `getAccessToken`, `getRefreshToken`, `GetNewTokens`.

- **Prerequisites**  
  None. Live ELTE login remains **MVP / not exhaustively re-tested**.

- **Done when**  
  Kill JWT or wait 10 minutes **in foreground** (or background ≥10 min after **1b**) → login prompt, username prefilled, **previous week’s timetable and markbook still on screen or restored instantly after re-login**. Airplane mode with warm cache → no empty spinner on any home surface.

- **Out of scope**  
  Silent portal re-auth, email OTP UI, changing JWT lifetime, splitting monoliths.

---

### 2. Honest markbook (átlag vs /30, accumulated credits) — **DONE**

- **Why**  
  The header showed “credits this semester” (all rows). Two numbers shared one reaction emoji: **átlag** (credit-weighted) and **Σ(jegy×kredit)/30**. EN said “Average” / “Scholarship index”; HU “Átlagod” / “Ösztöndíj indexed”. Users need **átlag** vs **/30** named as such. Diploma-style **accumulated credits** can be summed from terms we **already fetch** — no new HAR.

- **Depends on**  
  Item 1 (do not empty the tab on refresh failure).

- **Already in code**  
  - `MarkbookRequest.getMarkbookSubjects` → `/api/TakenSubjects`, fallback `/api/RegisteredCourses/GetRegisteredCourses` (`lib/API/api_coms.dart`).  
  - `getRegisteredCourses`, `getGradeHistoryAcrossTerms(maxTerms: 8)`.  
  - Terms: `/api/RegisteredCourses/GetTerms`, `/api/TakenSubjects/Terms`, `/api/Periods/GetTerms` → `CACHED_TermsList`.  
  - UI: `MarkbookPageWidget`, `MarkbookElementWidget`, `_setupMarkbook`, `_markbookCalcAvg`, `_markbookCalcGhostAvg` (`lib/Pages/main_page.dart`).  
  - Keys: `markbookPage_AverageDisplay`, `markbookPage_AverageScholarshipDisplay`, `topheader_subjects_CreditsInSemester`, `markbook_myCourses_Header`, `markbook_gradeHistory_Header`.

- **What to build**  
  1. Relabel: **Átlag / Average** = `Σ(grade × credit) / Σ(credit)` for completed `grade >= 2`. **/30** = `Σ(grade × credit) / 30` (same numerator). Do **not** show átlag÷30.  
  2. Keep HU “ösztöndíj” as a subtitle if desired; the **big number** must say `/30`.  
  3. Header: this-term credits (taken) **and** accumulated completed credits from `getGradeHistoryAcrossTerms` / cached per-term subjects (dedupe by `subjectCode`).  
  4. Document that this is **app-computed**, not official KKI/GPA from Neptun. Official averages **endpoint exists** (`GET /api/Dashboard/GetAverages` + `GetAverageTypesDescription` with `creditIndex` / `adjustedCreditIndex` / `schoolarshipKey`) but this capture’s `dashboardAverageItems` was **[]** — do not show “official GPA” until a HAR has filled items.  
  5. Same formula functions used by ghost (item 5) — extract one helper, e.g. `MarkbookMath`.

- **Where**  
  `lib/Pages/main_page.dart` (`_markbookCalcAvg`, `_markbookCalcGhostAvg`, `MarkbookPageWidget` header), `lib/language.dart` + `Languages/LangExtentions/Russian.json` + `Turkish.json`, optionally a small `lib/Misc/markbook_math.dart`.

- **Via**  
  `TakenSubjects?request.termId=`, `Subject.credit` / `grade` / `completed` / `subjectCode`, `SELECTED_TermId`, `CACHED_TermsList`.

- **Prerequisites**  
  None. Official diploma totals / tanterv required-vs-optional → item 11 + HAR.

- **Done when**  
  A subject with 5 and 3 credits graded 5 and 3 shows átlag `4.25` and /30 `1.33…` ( (25+9)/8 and /30 ), not átlag/30. Accumulated credits rise when other terms have completed subjects already in grade history.

- **Out of scope**  
  Curriculum graph, official KKI field, changing the 1–5 grade scale.

---

### 3. Clean calendar data (strips + week view polish) — **DONE**

- **Why**  
  Week view and strips already existed but shared one `calendarEntries` list. Period banners could leak if filters change; next-48h was uncapped by “today”; tasks/ZH and exams were “first 8 in the loaded week”, not a real upcoming window. Polish here so item 6 is additive, not a rewrite.

- **Depends on**  
  Item 1 (cache-first week pages).

- **Already in code**  
  - `CalendarRequest.makeCalendarRequest` → `GET /api/Calendar/GetCalendarEvents` (`startDate`, `endDate`, `isClassesVisible`, `isExamsVisible`, `isFinalExamsVisible`, `isTasksVisible`, `isPeriodsVisible`, `studentTrainingIds[i]`).  
  - `getCalendarOneWeekJSON` — Monday–Sunday.  
  - `CalendarEntry`: `isExam` (`eventType == 1`), `isPeriodBanner` (`== 6`), `isTask` (`> 1 && != 6`).  
  - Strips in `CalendarPageWidget._extraCalendarSections`: `calendar_next48h_Header`, `calendar_tasks_Header`, `calendar_exams_Header`, `calendar_periods_Header`.  
  - Day lists: `TimetableElementWidget`, `FreedayElementWidget`, `WeekoffseterElementWidget` (`lib/TimetableElements/`, `lib/Pages/main_page.dart`).  
  - Settings filters: `getDisplayClasses` / `Exams` / `Periods` (`lib/Pages/settings_page.dart`).  
  - Details: `/api/Calendar/GetCourseDetails`, `/api/Tasks/GetTaskDetail`.  
  - Room: `DecodableRoomText`.

- **What to build**  
  1. Strips: sort by `startEpoch`; next-48h = classes+exams only (no period banners); tasks/ZH = `isTask` with `startEpoch >= now` (or due in window); exams upcoming, not “first 8 in this week only” if the API week has none.  
  2. Day columns: keep same-day break chips only; no next-Monday bleed (already guarded — do not regress).  
  3. Empty day = `FreedayElementWidget`, not a spinner, when cache says “loaded empty”.  
  4. Period banners only in the period strip, never as fake all-day classes.

- **Where**  
  `lib/Pages/main_page.dart` (`_setupCalendar`, `_extraCalendarSections`, `_fillOneCalendarElement`), `lib/API/api_coms.dart` (`CalendarEntry` mapping), `lib/TimetableElements/timetable_element_widget.dart`.

- **Via**  
  `GetCalendarEvents`, cache `CachedCalendar_w{offset}`, `HasCachedCalendar`, `CalendarCacheTermId`.

- **Prerequisites**  
  None.

- **Done when**  
  A week with only Monday classes does not invent a 163 h break. Period text appears in the period strip only. Pull-to-refresh with cache never blanks the week.

- **Out of scope**  
  ICS export (item 6), maps (item 8). Exam / course registration is **not planned**.

---

### 4. Mail search + unread filter — **DONE**

- **Why**  
  Inbox is a flat paginated list. Unread is a **count** in the header/drawer, not a filter. Search does not exist. Item 9 needs stable `messageId`s and a way to see “new unread”.

- **Depends on**  
  Item 1 (do not fetch pages 2…n on a dead session).

- **Already in code**  
  - `MailRequest.getMails` → `GET /api/Message/GetReceivedMessages?firstRow=&lastRow=&filterType=0` (20-row pages).  
  - `GetUnreadedMessagesCount` → `data.count` → `CachedMailsUnread`.  
  - `setMailRead` — POST candidates `SetReadedMessage` / `SetMessageAsReaded`.  
  - Body: `GET /api/Messages/{id}/Posts`.  
  - UI: `MailsPageWidget`, `MailElementWidget` (popup mode 3), `MessageTranslator`.  
  - Cache: `CachedMails_$i` (`MailEntry.toString` uses `\u0000` separators), `CachedMailsLength`, `MailCacheTime`.  
  - `MailEntry.ID` = `messageId`. `isRead` = `unreadedPostCount == 0`.  
  - **Shipped (item 4):** local search field + unread `FilterChip` on `MailsPageWidget`; filters loaded pages client-side; pagination accumulates into `mailEntries`; search query is never logged; API still `filterType=0`.

- **What to build**  
  1. Local search over **already loaded** pages: subject, sender, optional body after load.  
  2. Unread filter chip using `MailEntry.isRead`.  
  3. Sep 2026 mail HARs still send **`filterType=0`** on inbox, archived, and sent. No unread-only query seen — **client-side filter is enough**.  
  4. Keep pagination; search should query loaded items first, then optionally load next pages while session is valid.  
  5. Persist nothing secret in search logs.

- **Where**  
  `lib/Pages/main_page.dart` (`MailsPageWidget`, `_setupMails` / `mailList`), `lib/MailElements/mail_element_widget.dart`, `lib/API/api_coms.dart` (`MailRequest`), `lib/language.dart` + RU/TR JSON.

- **Via**  
  `GetReceivedMessages`, `GetUnreadedMessagesCount`, `CachedMails_*`, `messageId`.

- **Prerequisites**  
  Optional HAR: other `filterType` values, server-side search. Not a blocker.

- **Done when**  
  Typing part of a sender name hides other rows. Unread filter shows only 📬 cards. Cache + offline still filters locally. **Met in 1.3.4.**

- **Out of scope**  
  Compose / reply, attachments download manager, What’s Changed UI (item 9).

---

### 5. Ghost grade goal / what-if polish — **DONE**

- **Why**  
  Ghost grades already change átlag and /30 via `_markbookCalcGhostAvg`, but the UI is a raw 1–5 picker (popup mode 0) with no “target átlag” / “what if I get X on remaining credits”.

- **Depends on**  
  Item 2 (shared formula and labels).

- **Already in code**  
  - `MarkbookElementWidget.ghostGrade` (`-1` = none).  
  - `_mbookPopupResult` → `result + 1` as grade.  
  - `PopupWidgetHandler` mode 0: `popup_case0_GhostGradeHeader`, `popup_case0_SelectGrade`.  
  - Confetti when all subjects completed.

- **What to build**  
  1. Extract `MarkbookMath.weightedAvg` and `MarkbookMath.index30`.  
  2. Show live átlag + /30 in the ghost popup as the user taps a grade.  
  3. Optional: “need grade ≥ N on this subject to reach átlag X” — only if it uses the **same** formula (no fake scholarship rules).  
  4. Clear-ghost already exists (`result == -1`).

- **Where**  
  `lib/Misc/popup.dart` (mode 0), `lib/Pages/main_page.dart`, `lib/MarkbookElements/markbook_element_widget.dart`.

- **Via**  
  Same `Subject` fields as item 2. No new API.

- **Prerequisites**  
  Item 2 labels/formula helper.

- **Done when**  
  Setting a ghost 5 on an ungraded 3-credit subject updates both header numbers identically to finishing that subject with a 5.

- **Out of scope**  
  Official scholarship rules, KKI from server.

- **Shipped**  
  Live átlag + /30 preview in ghost popup; optional target-átlag hint via `MarkbookMath.minGradeForTargetAvg`; `GhostGradePopupData` + clear-ghost control. Marketing version unchanged on this item.

---

### 6. Today summary + ZH/deadline strip + ICS export + class notification granularity

- **Why**  
  Greeting line is time-of-day only (`topheader_calendar_greetMessage_*`). Strips are week-scoped. ICS can be **imported** but never **exported**. Class alerts are always 10 min + 5 min + start (`notif_class_BodyIn10Min` / `In5Min` / `Now`) with one Settings toggle.

- **Depends on**  
  Item 3 (clean `calendarEntries`). Item 1 (do not reschedule 30 notifications on a dead session).

- **Already in code**  
  - Strips: next 48 h / tasks / exams / periods.  
  - `GetTaskDetail` for ZH-like tasks.  
  - `ICSCalendar` **import** only; `file_picker` + `SetupPageCalendarLogin` (not on hub).  
  - Class notifs: `_setupClassesNotifications`, id bucket `1`, `SETTING_IsNeedClassNotifications`.  
  - `AppNotifications.scheduleNotification` (`lib/notifications.dart`).

- **What to build**  
  1. **Today summary** in the calendar header: next class today, or “no class today”, from cached week.  
  2. **ZH / deadline strip**: `isTask` (+ exam deadlines if already in calendar). Do not invent assignment APIs without HAR (optional HAR in §4 D).  
  3. **ICS export**: build `.ics` from current `calendarEntries` (VEVENT: `DTSTART`/`DTEND`/`SUMMARY`/`LOCATION`). Share sheet / save. This is **export**, not import. Optional later: official sync URL from `GET /api/Calendar/GetLinksForCalendarExport` (`data.url` / `data.urlForWebCalendars` → `web{N}.neptun.elte.hu/api/Calendar/CalendarExportFileToSyncronization?id=`). Do not log the `id`.  
  4. **Granularity**: Settings checkboxes — 10 min / 5 min / at start (default all on, matching today). Cancel+reschedule via `cancelScheduledNotifsId(1)`.

- **Where**  
  `lib/Pages/main_page.dart` (`CalendarPageWidget`, `_setupClassesNotifications`), `lib/Pages/settings_page.dart`, `lib/API/ics_calendar.dart` (add export helpers; do not break import), `lib/notifications.dart`, `lib/language.dart` + RU/TR.

- **Via**  
  `CalendarEntry`, `CachedCalendar_*`, `SETTING_IsNeedClassNotifications` + new keys e.g. `SETTING_ClassNotif10` / `5` / `0`.

- **Prerequisites**  
  None for export/summary. Teacher **email** still missing (tutors: `printname` / `employeeId` / `nickname` / avatar only). Extra assignment dates beyond calendar `isTask` → still optional.

- **Done when**  
  User can save an ICS that opens in Calendar.app / Google Calendar with this week’s classes. Settings can disable the 10-minute ping only. Today line matches the Monday–Sunday list.

- **Out of scope**  
  Re-advertising ICS **import** on the hub. Exam / course registration (**not planned**). Remote push.

---

### 7. Payment `totalMoney` accuracy + payment notification antispam

- **Why**  
  Header: “You have spent %0Huf”. Code sums **`completed`** rows only, `ammount.abs()`, from **50** newest transactions. Scholarships are stored as positive; fees as negative — both completed rows **add** to “spent”. Unpaid (`aktív`) are excluded from the sum but can generate **one local notification per remaining day** (or **32** if `dueDateMs == 0`).

- **Depends on**  
  Item 1 (cache payments list).

- **Already in code**  
  - `CashinRequest.getAllCashins` → `/api/Transactions/GetStudentPreviousTransactions?sortAndPage.firstRow=0&lastRow=50`.  
  - `getCollectiveInvoices` → `/api/FinancialDataDashboard/GetCollectiveInvoices`.  
  - `CashinEntry.completed` if status is `teljesített` / `törölt` / `pénzügyileg igazolt`.  
  - `_setupPayments`, `PaymentsPageWidget`, `PaymentElementWidget`.  
  - Notif id bucket `2`, `SETTING_IsNeedPaymentsNotifications`.

- **What to build**  
  1. Define `totalMoney` in the UI: **fees paid** (negative / outgoing) vs **net** vs **invoice balance**. Label must match the number. Prefer: paid outgoing + separate drawer **collective invoice balance** (already in drawer).  
  2. Paginate using `sortAndPage.firstRow` / `lastRow`. Web capture used **`lastRow=10`**; app today uses **50**. Filters exist (`GetStudentPreviousTransactionsFilters`: terms, currencies, directions, types). Do not claim “all time spent” on one page.  
  3. Antispam: at most **one** daily payment reminder (or one per unpaid invoice), not `daysRemaining` copies. No 32-day fan-out for undated items.  
  4. Keep `aktív` / `teljesített` as **protocol match keys**, not translated status tokens.

- **Where**  
  `lib/Pages/main_page.dart` (`_setupPayments`, `_setupPaymentsNotification`), `lib/API/api_coms.dart` (`CashinRequest`), `lib/PaymentsElements/payment_element_widget.dart`, `lib/language.dart` (`topheader_payments_TotalMoneySpent`).

- **Via**  
  `GetStudentPreviousTransactions`, `GetCollectiveInvoices`, `ACCOUNT_Balance` / `ACCOUNT_BalanceCurrency`, `CachedPayments_*`. Unpaid list: `GET /api/FinancialItem/GetItemsToBePayed` (this capture: **empty array** + `GetItemsToBePayedAdditionalData` flags). Detail: `GetStudentTransactionDetails?transactionId=`.

- **Prerequisites**  
  Unpaid-fees endpoint is now known; this account had **no** items. Bonuses / Diákhitel2 endpoints exist but were empty / unused in-app.

- **Done when**  
  Header number matches the sum of **paid fees** the UI lists (or the label is changed to “net / 50 latest”). Enabling payment notifs schedules **≤ 1/day**, not dozens.

- **Out of scope**  
  In-app payment / bank transfer. Student-card bank fields (item 12).

---

### 8. Maps deep-link on LD/LE/LK decode

- **Why**  
  Tap already toggles `LD-0-805` ↔ “Southern Building, Floor: 0, Room: 805”. Users still need a map. `url_launcher` is already a dependency (`LaunchMode.externalApplication`).

- **Depends on**  
  Item 3 recommended (same `DecodableRoomText` surfaces). Not blocked by mail.

- **Already in code**  
  - `ElteRoomCode`, `DecodableRoomText` (`lib/Misc/elte_room_code.dart`).  
  - Prefixes: **LD** Southern / Déli, **LE**/LÉ Northern / Északi, **LK** Chemistry (Northern). Unknown prefix kept.  
  - Used on timetable list, class dialog, exam/legacy popups.  
  - `url_launcher` in drawer / clickable spans. iOS `LSApplicationQueriesSchemes`: `https`, `http`, …

- **What to build**  
  1. After decode (or a second tap / map icon): open Apple Maps / Google Maps query for the **building**, optionally `floor`/`room` in the query string.  
  2. Suggested queries (ELTE Lágymányos, not GPS-surveyed in-app):  
     - LD → `ELTE Déli Tömb` / Southern Building, 1117 Budapest  
     - LE → `ELTE Északi Tömb`  
     - LK → `ELTE Kémiai tömb` / Northern chemistry  
  3. Unknown prefix: no broken pin; keep text-only decode.  
  4. Do not invent lat/long without a source. Query strings are enough.

- **Where**  
  `lib/Misc/elte_room_code.dart`, call sites in `lib/TimetableElements/timetable_element_widget.dart`, `lib/Misc/popup.dart`.

- **Via**  
  `ElteRoomCode.tryParse`, `url_launcher`, existing `roomCode_*` strings + one new `roomCode_OpenMap`.

- **Prerequisites**  
  None. Optional: confirm building names on campus. `information.har` also has `RoomSchedule/GetBuildings` + `GetSites` + `GetOrganizations` + `GetRoomsSchedules` (campus room list — not required for LD/LE/LK deep-link).

- **Done when**  
  Tap-through from `LD-0-805` opens a maps app whose search is Déli Tömb / Southern Building. `XY-1-1` (unknown) does not crash or open a wrong campus.

- **Out of scope**  
  Indoor floor plans, room-level GPS, non-Lágymányos campuses.

---

### 9. What’s Changed (simple)

- **Why**  
  After re-login or a silent refresh, users want “2 new mails, 1 new grade” — not a full activity product.

- **Depends on**  
  **Item 1** (cache survives session) **and item 4** (stable `messageId`, unread). Markbook `subjectCode`+`grade` from item 2.

- **Already in code**  
  Cached mail IDs, unread count, markbook serialization, calendar week cache. No snapshot-diff UI.

- **What to build**  
  1. On successful refresh, persist a small snapshot: set of `messageId`, pairs `(subjectCode, grade, termId)`, maybe next-class `startEpoch`.  
  2. Drawer or calendar strip: “N new messages”, “N grade changes” if diffs ≠ 0.  
  3. Tap opens mail tab with unread filter or markbook.  
  4. First install = no banner (no false “everything is new”).

- **Where**  
  `lib/storage.dart` (new keys e.g. `SNAPSHOT_MailIds`), `lib/Pages/main_page.dart`, `lib/Misc/app_drawer.dart`.

- **Via**  
  Existing caches + `MailEntry.ID` + `Subject.subjectCode`.

- **Prerequisites**  
  Items 1 and 4.

- **Done when**  
  Receiving one new inbox id after refresh shows “1 new message” once; second refresh without new mail shows nothing.

- **Out of scope**  
  Push, email digest, changelog of Neptun server messages.

---

### 10. Semester comparison

- **Why**  
  Grade history is a flat list (“Grades from other terms”). Comparison = átlag + /30 + credits **per term**, side by side.

- **Depends on**  
  **Item 2** (honest per-term math).

- **Already in code**  
  `getGradeHistoryAcrossTerms`, `TermsRequest.getTerms`, term switcher in drawer (`SELECTED_TermId`), `markbook_gradeHistory_Header`.

- **What to build**  
  1. Table/cards: term name, credits completed, átlag, /30 — **same helper as markbook**.  
  2. Use cached per-term `TakenSubjects` when present; fetch missing terms only with a valid session (item 1).  
  3. Cap remains ~8 terms unless HAR says otherwise.

- **Where**  
  `lib/Pages/main_page.dart` (`MarkbookPageWidget`), `lib/API/api_coms.dart` (`getGradeHistoryAcrossTerms`).

- **Via**  
  `TakenSubjects?request.termId=`, `CACHED_TermsList`.

- **Prerequisites**  
  Item 2. Not curriculum HAR.

- **Done when**  
  Two past terms with grades show two different átlag values that match opening that term in the switcher.

- **Out of scope**  
  Official transcript PDF, tanterv completion % (item 11).

---

### 11. Academic Progress — ONLY after live **tanterv** HAR (still missing)

- **Why**  
  Diploma progress (required vs optional, credits toward the program) is **not** in `TakenSubjects` alone. `GetCurriculums` is an unused old-API-shaped constant.

- **Depends on**  
  **HAR §4 C** — **not satisfied** by the Sep 2026 set. Items 1–2 for session + credit math. Do **not** start UI from guesswork.

- **Already in code**  
  `URLs.CURRICULUMS_URL = "/api/GetCurriculums"` — **never referenced** elsewhere.  
  Modern terms/subjects as above. No tanterv model.

- **What this capture does *not* unlock**  
  - `taken courses.har` fired **`GetRegisteredCourses`** (+ dashboard chrome), **not** `TakenSubjects` and **not** tanterv.  
  - `GET /api/SubjectApplication/Curriculum?subjectType=&termId=` is a **signup curriculum dropdown** (`value` / `text` / `isActualTerm`) — **seen but not planned**.  
  - Per-subject `SubjectCourse/GetSubjectDetails` has `curriculumTemplateId`, `requirementType`, `credit`, `isCompleted`, `recommendedTerm`, `preRequirement` — useful later, **not** a diploma graph.  
  - `GET /api/Dashboard/GetAverages` exists but `dashboardAverageItems` was **[]** (official GPA **not** unlocked).

- **What to build** (after a real tanterv HAR)  
  1. Call the **real** modern tanterv path from that HAR (still may not be `/api/GetCurriculums`).  
  2. Map required / optional / completed credits.  
  3. Simple progress UI on the markbook tab or a popup — **not** a new bottom tab (after **1c**: still not a 4th bottom tab).

- **Where**  
  `lib/API/api_coms.dart` (new request class), `lib/Pages/main_page.dart`.

- **Via**  
  Still unknown. Do not hardcode `hallgatoN`. Do not treat `SubjectApplication/Curriculum` as tanterv.

- **Prerequisites**  
  **Live tanterv HAR** (Tanulmányok → Tanterv, expand groups). Without it: skip this item.

- **Done when**  
  Numbers match the Neptun tanterv screen for the same training, on a live session.

- **Out of scope**  
  Building a fake progress bar from current-term credits only (that would be dishonest).

---

### 12. Student card — HAR captured (**incomplete**): claim / bank / profile; **no QR**

- **Why**  
  Drawer already has **name** and **photo**. Sep 2026 HARs now name bank + card-**claim** fields. They do **not** give a wallet QR, plastic-card number, or expiry. Do not invent those.

- **Depends on**  
  **HAR §4 B** (profile + administration + finances). Session/cache (item 1) before any new fetch.

- **Already in code**  
  `/api/UserInfo`, `/api/General/GetUserAvatar?imageSizeType=Normal`, `STUDENT_DisplayName`, `STUDENT_AvatarBase64`, drawer `MemoryImage`.

- **`/api/UserInfo` shape** (finances.har; values redacted)  
  `data.userStatus` (int), `data.studentTrainingId`, `data.name` (**not** top-level `printName`), `data.neptunCode` (redact), `data.substitutePrintName`, `data.isTokenRegistered`, `data.userAvatar.{avatarType, image` (thumbnail base64 JPEG), `fallbackColorCodeInHexa, printName}`. App already falls back `printName` → `name`.

- **Avatar extras**  
  `GET /api/General/GetUserAvatar?imageSizeType=Normal` (larger JPEG; also `userId` for someone else). Batch: `GET /api/General/GetUsersAvatar?imageSizeType=Thumbnail&userIds[n]=` (mail). Profile also has `GetGeneralUserData.profilePicture` (Normal-sized) and `UserProfile/GetDefaultAvatars` (canned art).

- **What to build** (only these HAR fields)  
  1. **Bank (read-only):** `GetDefaultBankAccountNumber` / `GetBankAccountDetails?bankAccountId=` / `GetUserBankAccountTabList` — `bankAccountOwner`, `isDefault`, `isForeign`, `isValid`, `bankName`, `otpStatus` (visibility flags). **Never log** `bankAccountNumber` / IBAN / SWIFT.  
  2. **Card claim status (not a wallet):** `StudentCard/StudentCardClaimProcess` — `claimType`, `nekId` (do not log), `firStatus` / `firStatusId`, `processStatus`, `finalDecision`, `registrationDate`, `trainingName`, `trainingFaculty`, `primaryInstituteName` / `primaryInstitutePrintCode`, `addressId`; addresses via `StudentCard/GetStudentAddress` (`address`, `addressType`). Previous claims list was **[]**.  
  3. **Profile (optional, Settings/drawer popup — not a new bottom tab):** `PersonalData/GetGeneralUserData` field **names** (no secrets in logs): `printName`, `firstName`, `lastName`, `title`, `bornName*`, `bornDate`, `bornCountry`, `bornPlace`, `sex`, `loginName`, `motherName*`, `numberOfChildren`, `educationalIdentifier`, `userCitizenship[]`, `extraFields[]` (`field` / `translation` / `value` / `required` — labels seen: EHA, ETR, …). `tajNumber` / `taxIdentifier` / `studentIdOnExam` were **empty** here. Contacts: `GetStudentPersonalDataContacts` (address / email / phone lists). Documents on this account: Passport + Permit of residence — **not** a student card.  
  4. Offline: cached photo + last **non-secret** claim/bank flags.

- **Where**  
  `lib/Misc/app_drawer.dart`, `CalendarRequest._persistUserInfoProfile`, new cache keys in `storage.dart`.

- **Via**  
  Paths above. `GET /api/FIR/GetStudentFIRData` returned **HTTP 410**. Do **not** invent a QR from Neptun code or `nekId`.

- **Prerequisites**  
  Field names are known. Legal: personal data (existing Privacy). Still missing for a “wallet card”: QR payload, card number, validity dates — **another click** if the web even has them.

- **Done when**  
  UI shows only captured fields and matches web Saját adatok / card-**claim** / bank for the capturing account. No decorative QR.

- **Out of scope**  
  NFC emulation. Decorative “card” from avatar only. Editing / POSTing personal or bank data (no save XHRs in this capture).

---

### 13. App shortcuts — after session UX + deep links

- **Why**  
  Long-press icon → Calendar / Mail / Payments is useful only if a **dead session** opens login (item 1) and maps/mail deep links exist.

- **Depends on**  
  Item 1. Item 8 if a “maps / next room” shortcut is included.

- **Already in code**  
  No `shortcuts.xml`, no iOS `UIApplicationShortcutItems`. Navigation is **index-based**, no named routes.

- **What to build**  
  1. Android pinned shortcuts + iOS home-screen quick actions: Calendar (bottom 0), Mail (bottom 3), Payments (drawer index 4).  
  2. Cold start: `Splitter` → if `HasLogin` and session valid → `HomePage` with tab index or drawer route; else login.  
  3. Do not open Home with a dead JWT and empty tabs. Prefer after **1c** so indices match target IA.

- **Where**  
  `android/app/src/main/res/xml/`, `AndroidManifest.xml`, `ios/Runner/Info.plist`, `lib/Pages/startup_page.dart`, `lib/Pages/main_page.dart` (initial tab).

- **Via**  
  Intent extras / URL scheme already listed (`https`, `http`, `mailto`, `tg`, …). Add an app-specific scheme only if needed.

- **Prerequisites**  
  Item 1. Optional item 8.

- **Done when**  
  Cold-start shortcut lands on the right tab or login; never a blank Home.

- **Out of scope**  
  Siri / App Intents, Android widgets (item 14).

---

### 14. Widgets — last, native epic

- **Why**  
  Homescreen widget was a **stub and was removed**. Real widgets are native (Glance / WidgetKit), need cached timetable **without** a live JWT, and conflict with 10-minute session policy.

- **Depends on**  
  Items 1 and 3 (cache honesty + clean week data). Prefer after 13.

- **Already in code**  
  None. TECHNICAL honesty: “Homescreen widget | Removed | Was a stub”.

- **What to build**  
  1. Android + iOS widgets: **today’s classes** from `CachedCalendar_w*` only.  
  2. Tap → app (item 13 deep link).  
  3. If cache missing: “Open Neptun ELTE”.  
  4. No JWT inside the widget process.

- **Where**  
  New native modules under `android/` and `ios/`; small Dart cache export. Do not revive the old stub.

- **Via**  
  SharedPreferences calendar strings / an App Group on iOS.

- **Prerequisites**  
  Native widget work, iOS App Group signing, Android glance/widget ids. Legal: local cache only.

- **Done when**  
  Widget shows today’s cached classes after the app has opened that week once; stale cache labeled as stale.

- **Out of scope**  
  Live-updating widget from Neptun every minute. Exam / course registration (not planned).

---

## 4. HAR capture (user-actionable)

HARs are how we learn **real** hallgato REST for features that are **not** in the app. Live ELTE login in the app is a **MVP**; these flows were **not** implemented and must be captured on the **website**.

### 4.1 How to capture (once per flow)

1. Use **Chrome** (or Edge/Firefox DevTools). Prefer a desktop session.  
2. Open `https://neptun.elte.hu` → log in (Neptun ID + password + 2FA).  
3. Open **Student web**. The portal assigns **`https://hallgatoN.neptun.elte.hu`** (`hallgato1`…`hallgatoN`, load-balanced).  
   - **Do not hardcode N.** Your capture may be `hallgato3` today and `hallgato4` tomorrow.  
   - In the HAR, keep the **host as a variable**: `https://hallgato{N}.neptun.elte.hu`.  
4. After the SPA loads (dashboard), open **DevTools → Network**.  
   - Check **Preserve log**.  
   - Filter: **Fetch/XHR** (plus Document if you need the OuterLogin 302).  
   - Disable cache if you want a clean first load.  
5. Click **only** the menu path for **one** target (**B** student card or **C** tanterv). Do not mix card + tanterv in one file. Do **not** capture exam / course registration (A is out of scope).  
6. **Save as HAR**: DevTools → Network → ⬇ / “Save all as HAR with content”.  
   - File name: `elte-har-student-card-YYYY-MM-DD.har` or `elte-har-curriculum-YYYY-MM-DD.har` (one flow).  
7. **Redact before any copy lives next to the repo:**  
   - Password, TOTP, email OTP, `GUID`, JWT `accessToken` / `refreshToken`, `Authorization: Bearer`, `Cookie`, `devicecookie-*`.  
   - Replace with `REDACTED`.  
8. **Do not commit HARs that still contain secrets.** Prefer a private note or a redacted JSON excerpt (URL + method + query + body shape + response shape).  
9. Capture on **`hallgatoN`**, not only `neptun.elte.hu`. Portal cookies ≠ HWEB Bearer. Most student APIs are **Bearer JWT on hallgatoN** (same pattern as `GetCalendarEvents`).  
10. Record for each kept request: **method, full URL (with `{N}`), query, request body, response JSON keys, cookie vs Bearer**.

Typical HWEB routes already seen in product docs (for orientation, not a click script): `/dashboard`, `/calendar/institutional-calendar`, `/studies`, `/messages`, `/administrations`, `/user-data`.

---

### 4.2 Captured inventory (incomplete) — 2026-09-13

User provided **8 HARs** (not copied into git). They did **not** click every button on every page. **Missing POSTs** (save, pay, compose, claim submit, signup) are **expected**. Host written as `hallgato{N}`. Tokens / cookies / JWT / passwords / Neptun codes / names / account numbers **redacted** below (field names only).

**Already used by the app** (seen again; no surprise): `GET /api/UserInfo`, `GET /api/General/GetUserAvatar`, `GET /api/Calendar/GetCalendarEvents`, `GET /api/Calendar/GetCourseDetails`, `GET /api/Calendar/GetStudentTrainings`, `GET /api/RegisteredCourses/GetRegisteredCourses` + `GetTerms`, `GET /api/Periods/GetPeriods` + `GetTerms` + `GetPeriodData`, `GET /api/Transactions/GetStudentPreviousTransactions`, `GET /api/FinancialDataDashboard/GetCollectiveInvoices`, `GET /api/Message/GetReceivedMessages` (`filterType=0`), `GET /api/Messages/{guid}/Posts`, `GET /api/Message/GetUnreadedMessagesCount`, `POST /api/Account/GetNewTokens` (`accessToken`, `sessionTimeoutInMinutes`), `GET /api/MyTrainings` (same idea as `ContextUserProfile/MyTrainings`).

**Signup (seen but not planned):** `GET /api/SubjectApplication/{Curriculum,SubjectGroup,SubjectTypes,SystemParameters,Terms}` and page `/subjects/registration` in `finances.har`. Do not implement.

| File | Notable **new** (or extra) APIs | Unlocks in plan? |
|------|--------------------------------|------------------|
| `profile.har` | `PersonalData/GetGeneralUserData`, `GetStudentPersonalDataContacts`, `GetStudentPersonalDocuments`, `GetStudentAddressDetails`, `GetStudentEmailDetails`, language/guest/parallel/pref. treatment/statements/GDPR/history; `BankAccount/GetBankAccountDetails`, `GetDefaultBankAccountNumber`; `UserProfile/GetUserProfileSettings`, `GetDefaultAvatars` | **Item 12** profile + bank field names. **Not** QR / card number. Documents here: Passport + residence permit. |
| `administration.har` | `StudentCard/StudentCardClaimProcess`, `GetStudentAddress`, `GetStudentCardPreviousClaims` (empty); `RequestForm/*`; `Questionnaires/*`; `GET /api/administration/semiannualregistration/semesters` | **Item 12** claim / NEK / FIR **status** (not wallet). Request forms / questionnaires / term registration = extras, not gated items. |
| `information.har` | `RoomSchedule/{GetBuildings,GetSites,GetOrganizations,GetRoomsSchedules}`; `Queries/*`; `FIR/GetStudentFIRData` (**410**); `POST ContextUserProfile/SaveFilter` | **Item 8** optional campus rooms. FIR dead. **Not** tanterv. |
| `taken courses.har` | Dashboard `GetAverages` (items **[]**), `GetAverageTypesDescription`, `GetUpcomingEvents`, `ExamOverview/*`; **`GetRegisteredCourses` only** | **Does not** unlock item 11. Official GPA **not** filled. App already has RegisteredCourses. |
| `calendar+subjects.har` | `Calendar/GetLinksForCalendarExport`; `GetNewAllAppointmentInvitations`; `ContextUserProfile/GetCalendarSelectedTypes` + `GetCalendarSelectedView`; `SubjectCourse/GetSubjectDetails` + `GetCourseDetails` + tutors + course list | **Item 6** official ICS/webcal URL. Course `language` / `teachingMethod`. **No teacher email.** Per-subject curriculum fields ≠ tanterv graph. |
| `messages.har` / `messages2.har` | `Message/GetReceivedArchivedMessages`, `GetSentMessages`, `GetMessageRelatedSettings`, `GetMessageLimitSetting`, `GetMessageSendingSettings`; `General/GetUsersAvatar`; `UserSearch/GetUsers` | **Item 4** extras (archive/sent/settings/search). `filterType` still **0**. Unread-only **not** seen. |
| `finances.har` | `FinancialItem/GetItemsToBePayed` (**[]**) + `AdditionalData`; `GetStudentTransactionDetails`; `GetStudentPreviousTransactionsFilters`; `FinancialBonuses/*` (empty); `FinancialOptions/GetStudentLoan2Data`; `BankAccount/GetUserBankAccountTabList` + `GetBankAccountPermissions`; `EnvironmentData` (`sessionTimeoutInMinutes=15`, `accessTokenExpirationInMinutes=5`); `UserInfo` (full shape); **SubjectApplication/\*** | **Item 7** unpaid list + detail + filters. **Item 12** bank list. Session timeouts vs app 10 min wall clock. Signup block = seen, not planned. |

**SPA chrome also seen (ignore for features):** `ContextUserProfile/GetColumnOrder*`, `GetFilter`, `Dashboard/GetNews`, `GetActiveDomainPasswordExpiration`, `Translations`, `Permissions`, `ExtendedMenuPermissions`, `Profiles/Favourites`.

**UserInfo / avatar / curriculum / card / bank — field names that decide items 11–12**

| Topic | Verdict | Field names (no values) |
|-------|---------|-------------------------|
| **UserInfo** | Already used; shape confirmed | `userStatus`, `studentTrainingId`, `name`, `neptunCode`, `substitutePrintName`, `isTokenRegistered`, `userAvatar.{avatarType,image,fallbackColorCodeInHexa,printName}` |
| **Avatar** | Already used + extras | `GetUserAvatar.image` (`imageSizeType=Normal`); `GetUsersAvatar` (`Thumbnail` + `userIds[]`); `GetGeneralUserData.profilePicture`; `GetDefaultAvatars.{normalImage,thumbnailImage,avatarType}` |
| **Curriculum / tanterv** | **No separate tanterv API** (live Chrome 2026-09-13) | `/api/GetCurriculums` **404**. Menu: Advancement, not Tanterv. `GET /api/Advancement/GetStudentCurriculumTemplates` → `data: []`. `GET /api/advancement/creditprogress` and `GET /api/Dashboard/creditprogress` → `data` null. Per-subject template fields on `GetSubjectDetails` remain. |
| **Official GPA** | **Schema captured; values mostly empty** (early term) | Dashboard `GetAverages.dashboardAverageItems` []. `GET /api/Advancement/GetTermAveragesByTraining`: `creditIndex`, `sumAverage`, `average` + labels. `GET /api/RegistrySheet/GetStudentTrainingTermData?studentTrainingTermDataId=` (id from term averages, **not** dashboard `studentTrainingTermDataId` which was null): `averagesCreditIndicies` (Credit, CreditAll, SumCredit, SumCreditAll, Average, SumAverage), `furtherHalfYearAverages` (SchoolarshipKey, RepeatExam, KorrigaltKreditIndex, KreditIndex, ElismertKredit, NemElismertKredit), `furtherCumulativeAverages` (SumRepeatExam, SumKorrigaltKreditIndex, KumNemElismertKredit, KumElismertKredit). On this account **only CreditAll had a value**; other official numbers empty. |
| **Student card** | **Claim**, not wallet | `StudentCardClaimProcess`: `id`, `claimType`, `nekId`, `fileInfo[]`, `firStatus`, `firStatusId`, `processStatus`, `finalDecision`, `registrationDate`, `trainingName`, `trainingFaculty`, `primaryInstituteName`, `primaryInstitutePrintCode`, `addressId`, dates. `GetStudentAddress`: `id`, `address`, `addressType`. Previous claims []. **No QR / cardNumber / expiry** |
| **Bank** | **Captured** | `bankAccountId`, `bankAccountNumber` (redact), `bankAccountOwner`, `bankAccountSwiftCode`, `bankName`, `bankAddress`, `isDefault`, `isForeign`, `isValid`, `otpStatus`, `otpStatusIsVisible`, permission flags |

**Guess next clicks** (still optional): reopen Advancement / Registry sheet **after the term closes** when official averages fill; mail compose **POST**; pay **POST**; profile **save**; card-claim **submit**; teacher person page (email). **Tanterv menu does not exist** on this HWEB. **QR / wallet card does not exist** on Student Card request (`/administrations/student-card`) — claim form only, no QR image.

### 4.3 Live Chrome walk (same day, logged-in `hallgato{N}`)

Owner allowed AppleScript JS on their already-logged-in Chrome. Walked Studies / Advancement, Student Card request, Registered subjects. One hard `location.href` to Registry sheet hit **error 5002** and bounced to the portal; **Student web** (`ToNeptunHWeb`) recovered the HWEB session. No HAR files saved; no tokens/PII copied into git.

| Page | APIs / result |
|------|----------------|
| `/studies/advancement` | `GetTermAveragesByTraining`, `creditprogress` (empty), `GetStudentCurriculumTemplates` (`[]`), `GetAverageTypesDescription` |
| `/administrations/student-card` | Same claim APIs as HAR. UI: request form + empty “Earlier requests”. **No QR / barcode.** |
| `/subjects/registered-subjects` | `GET /api/TakenSubjects/Terms` (`creditSum`, `completedCredit`, `isClosed`, `value`, `text`) + `GET /api/TakenSubjects?request.termId=` (app already uses this) |
| `/studies/registry-sheet` | Hard navigation **5002**. Data still reachable: `GetStudentTrainingTermData` with `studentTrainingTermDataId` from Advancement term row |
| `/api/Calendar/GetLinksForCalendarExport` | Confirmed `data.url`, `data.urlForWebCalendars` (do not store raw URLs — may contain secrets) |
| Environment | Portal `EnvironmentData` already said session **15 min** / JWT **5 min**; app wall-clock logout is **10 min** |

---

### A. Exam / course registration — **not planned**

**Out of scope.** Do not capture a HAR for vizsgajelentkezés / tárgyjelentkezés and do not build signup UI. Calendar may still **show** exams (`GetCalendarEvents`); that is display-only.

---

### B. Student card / profile / bank

**Where to click**

1. Menu **Saját adatok** / User data (`/user-data` on HWEB).  
2. Tabs/sections: personal data, **diákigazolvány** / student card / NEPTUN card if present, **bankszámla** / bank account.  
3. If a QR or card image loads, note the request that returns it (not only `<img>` from a CDN).  
4. Do **not** screenshot the QR into git.

**Endpoints to look for**

| Look for | Notes |
|----------|--------|
| `/api/UserInfo` | **Already used** — name, training, `userAvatar.image` |
| `/api/General/GetUserAvatar?imageSizeType=Normal` | **Already used** — larger JPEG |
| `*StudentCard*`, `*Card*`, `*Diakigazolvany*`, `*NEK*`, `*QR*` | Unknown — keep |
| Bank / `BankAccount` / `Szamlaszam` | Unknown — keep |

**Fields we need** (only if present)

- Card number / identifier, validity dates, university name.  
- QR/barcode **payload** (string), not a photo of the screen.  
- Bank: account holder, IBAN/number, currency — **redact** in stored copies.

**Already have vs missing** (after 2026-09-13 capture)

| Have | Missing |
|------|---------|
| Display name, Neptun code, avatar (`UserInfo` / `GetUserAvatar`) | **QR payload**, plastic/digital **card number**, **expiry** |
| Training label switcher | FIR live API (`GetStudentFIRData` = 410) |
| Bank field names + claim/NEK/FIR status + `GetGeneralUserData` | Save / edit POSTs (not clicked) |

---

### C. Curriculum / academic progress

**Where to click**

1. **Tanulmányok** → **Tanterv** / Curriculum / Training plan (HWEB may live under `/studies`).  
2. Open the **active training** (same one as the app drawer switcher).  
3. Expand a semester or “kötelező / kötelezően választható / szabadon választható” if the web shows those groups.  
4. If a “progress / teljesítés / kredit” summary exists, load that page too.

**`GetCurriculums`**

- App constant: `URLs.CURRICULUMS_URL = "/api/GetCurriculums"` (old MobileService-style path).  
- **Never called.** Modern HWEB may use a different route (`/api/...Curriculum...`). Keep **whatever XHR actually fires**.

**Response fields we need**

- Required vs optional vs elective subject lists.  
- Credit totals toward the **diploma / training** (not only the current term).  
- Subject codes that join to `TakenSubjects.subjectCode`.  
- Completion flags if the server already computes them.

**Already have vs missing** (after 2026-09-13 capture)

| Have | Missing |
|------|---------|
| Per-term `TakenSubjects` + `TakenSubjects/Terms` (`creditSum`, `completedCredit`) | **Tanterv graph** — HWEB has no Tanterv page; templates/creditprogress **empty** this term |
| App-computed átlag / /30 | Filled official numbers (schema is known; values empty until the term has results) |
| Official **labels** on `GetStudentTrainingTermData` + term averages on Advancement | Diploma-wide required/optional/elective lists |

---

### D. Optional useful while capturing

Same login, **separate** HAR files if the Network log gets huge:

| If you see it on web | Why it helps | Status after this capture |
|----------------------|----------------|--------------------------|
| Teacher **email** on course/person page | Calendar dialog only has `courseTutor` name (`GetCourseDetails`); tutors = `printname` / `employeeId` / avatar | **Still missing** |
| Assignment / ZH due dates **not** on the institutional calendar | Item 6 strip; today `isTask` + `GetTaskDetail` | **Still missing** |
| Official **GPA / KKI / ösztöndíjindex** on a results page | `GetAverages` / `GetAverageTypesDescription` exist; items were **[]** | **Click the page that fills items** |

---

## 5. Implementation templates (copy this pattern)

Agents implementing any item above should follow this, not invent a second architecture.

### i18n

- Add keys to `LanguagePack` in `lib/language.dart` (**HU + EN** required fields).  
- Add the same keys to `Languages/LangExtentions/Russian.json` and `Turkish.json`.  
- User-visible chrome only. **Do not** translate Neptun payload titles (`Előadás`, `aktív`, `teljesített`) unless they are app chrome.  
- Missing RU/TR keys fall back to EN via `getStr`.

### Cache

- Read cache first (`HasCached*` + `Cached*_$i`).  
- Silent refresh when `getHasNetwork()` and session valid.  
- **Never** empty-screen if a cache list exists.  
- Calendar already does this — copy `fetchCalendar`.

### Session

- `ensureValidSession()` before long walks (all terms, all mail pages).  
- On failure: `SessionGuard.forceExpiredLogout` / existing snackbar — **do not** start a 10-term fetch.  
- Do not hardcode `hallgatoN`; use `DataCache.getInstituteUrl()`.

### Docs

- Same turn: `docs/README.md` + `README.ru.md` (user-visible features only), `TECHNICAL.md` + `TECHNICAL.ru.md` (honesty table / API if endpoints change), this plan if a gate changes.  
- Owner line stays **Nanda**.  
- Mark live ELTE login / HAR-only features as untested until captured.

### Product invariants

- Do **not** break ELTE hub, TOTP 2FA, or existing login error codes (`loginOk` / `loginNeeds2fa` / `loginInvalidCredentials` / `loginServerBusy`).  
- Nav: bottom stays **4** (Calendar \| Markbook \| Periods \| Mail) — Payments via drawer above Settings; Contacts + version in Settings (**1c**).  
- Session: 10-min policy uses real wall-clock across background (**1b** shipped), not Timer-while-suspended alone.  
- Do **not** split `main_page.dart` / `api_coms.dart` “for cleanliness” in the same PR as a feature.  
- No first-party backend. No creator push server.

---

## 6. What already exists (cheat sheet)

| Area | Files | APIs / keys |
|------|-------|-------------|
| Session | `lib/API/api_coms.dart` `SessionGuard`, `HomePage` | 10 min wall clock (`Timer` + resume timestamp); `GetNewTokens`; `auth_sessionExpired_PleaseSignIn`; **1a**/**1b**/**1** shipped (`sessionWipeKeepCache`) |
| Cache | `lib/storage.dart` `DataCache` | Cache-first all home tabs + `cache_showingFromCache` (**1**) |
| Nav | `BottomNavigatorWidget`, `AppDrawer`, `main_page.dart`, `settings_page.dart` | **1c shipped:** 4 bottom (Calendar, Markbook, Periods, Mail) + Payments in drawer above Settings; Contacts + version in Settings |
| Calendar | `main_page.dart` `CalendarPageWidget`, `TimetableElementWidget`, `WeekoffseterElementWidget` | `GetCalendarEvents`, strips polish (**3**) |
| Markbook | `MarkbookPageWidget`, `MarkbookElementWidget`, `lib/Misc/markbook_math.dart` | `TakenSubjects`, átlag + `/30`, accumulated credits (**2**) |
| Ghost | `popup.dart` mode 0 | `_markbookCalcGhostAvg` |
| Mail | `MailsPageWidget`, `MailElementWidget`, `message_translator.dart` | `GetReceivedMessages`, `GetUnreadedMessagesCount`, `/api/Messages/{id}/Posts` |
| Payments | `PaymentsPageWidget`, `PaymentElementWidget` | `GetStudentPreviousTransactions`, `GetCollectiveInvoices` |
| Periods | `periods_element_widget.dart` | `GetPeriods` |
| Rooms | `lib/Misc/elte_room_code.dart` | LD/LE/LK decode only |
| ICS | `lib/API/ics_calendar.dart` | **Import only** |
| Notifs | `lib/notifications.dart`, Settings toggles | ids 0 exam, 1 class, 2 payment, 3 period |
| Curriculum | `URLs.CURRICULUMS_URL` | **Unused**; tanterv still not in HARs |
| Profile | `UserInfo`, `GetUserAvatar` | Name + photo; HAR also names bank + card-claim (not in app) |
| Widgets | — | **Removed stub** |

---

*End of plan. If this disagrees with the code, the code wins. Tanterv / Academic Progress and student-card QR stay blocked. Bank + claim field names are captured (incomplete). Exam / course registration is not planned — do not add it back.*
