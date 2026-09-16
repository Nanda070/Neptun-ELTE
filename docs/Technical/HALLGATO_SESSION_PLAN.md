# Hallgato session maintenance — design plan

**Status:** **v1 core** + **mail cache fix** + **calendar week UI** shipped in **1.5.6** (16 September 2026). **Background keep-alive** + **password retention** Settings toggles shipped in **1.5.7** (both default OFF). Portal/HWEB activity, cold-start proactive `GetNewTokens`, JWT `exp` parse, and live-test matrix remain **future / research**.  
**Owner:** Nanda.  
**Canonical twin:** [HALLGATO_SESSION_PLAN.ru.md](HALLGATO_SESSION_PLAN.ru.md).

> Related shipped facts: [TECHNICAL.md § Session recovery and wall clock](TECHNICAL.md#session-recovery-and-wall-clock), [§ Auth, 2FA, tokens](TECHNICAL.md#9-auth-2fa-tokens).

---

## Goal

Minimize the number of full logins (**password + TOTP**) while keeping the user alive in the **hallgato** JWT session during normal app use.

- **Full login** = ELTE portal password + interactive 6-digit TOTP (no “remember device” on ELTE — user confirmed).
- **Session maintenance** = refresh access (and optionally refresh) tokens via the existing hallgato API, without portal activity fakes.

---

## Shipped behavior — v1 core (1.5.6)

| Mechanism | Behavior |
|-----------|----------|
| **Session end** | **Manual logout** or **dead refresh** (`GetNewTokens` 401/403 / empty tokens). **No** client 10-minute wall-clock (`SESSION_StartedAtMs` enforcement removed). |
| **Foreground proactive refresh** | Every **3 min 30 s** while `AppLifecycleState.resumed` → `SessionGuard.runForegroundTokenMaintenance()` → `POST /api/Account/GetNewTokens` (modern API + refresh token). Paused on background. Interval: `SessionGuard.foregroundTokenMaintenanceInterval`. |
| **Reactive refresh** | On **401/403** for **GET** requests, `_APIRequest.ensureValidSession()` → `tryTokenRefresh()` → ELTE `trySilentReauth()` (**always false**) → `forceExpiredLogout`. Shares `_isRefreshingToken` lock with foreground maintenance. |
| **Post-login grace** | ~45 s after `markParticipantSessionStarted` — reactive path skips forced logout if access token still present. |
| **Cold start** | `isColdStartSessionUsable()`: `HasLogin` + non-empty access token only (no wall-clock stamp). |
| **Background / killed** | No periodic hallgato calls while the process is dead. Widgets: cache-only, **no JWT** (unchanged). |
| **JWT `exp`** | Client does **not** decode JWT `exp`; access lifetime ~10–15 min is **observational** only. |

---

## Target behavior — app open (foreground)

### Interval

While the app is in **`AppLifecycleState.resumed`**, run proactive maintenance every **3 min 30 s** — **`SessionGuard.foregroundTokenMaintenanceInterval`** in `lib/API/api_coms.dart` (shipped **1.5.6**).

### Primary mechanism

**`POST {hallgatoBase}/api/Account/GetNewTokens`**

- **Authorization:** `Bearer <refresh JWT>` (same as today’s `tryTokenRefresh()` in `lib/API/api_coms.dart`).
- **Body:** `{}`.
- **Not** fake ELTE portal “activity” or HWEB polling — only the existing REST refresh path.

### Rationale

- Access JWT lifetime is observational **~10–15 minutes** on Neptun hallgato.
- Refresh **before** access expiry so active use does not depend on the first failing GET + 401 path.
- Reuse stored refresh token; persist new `accessToken` / `refreshToken` from response (same as current `tryTokenRefresh()` success path).

### Lifecycle rules

| State | Maintenance timer |
|-------|-------------------|
| `resumed` | **Immediate** `GetNewTokens` (**1.5.10**) + start periodic maintenance every 3m30; refresh calendar/mail |
| `inactive` | Keep foreground timer (brief OS overlay) |
| `paused`, `detached`, `hidden` | Pause / cancel timer; re-arm optional background keep-alive |
| Process killed | No maintenance (see cold start below) |

**Integration point:** `HomePage` `WidgetsBindingObserver` — starts/stops the maintenance `Timer` on `resumed` vs background states (wall-clock removed in **1.5.6**).

### Failure handling (foreground)

| Outcome | Planned UX |
|---------|------------|
| `GetNewTokens` **200** with tokens | Continue; reset maintenance schedule |
| **401/403** or empty tokens | Treat refresh as dead → `SessionGuard.forceExpiredLogout` (keep username + academic cache) → login + TOTP |
| Network error / timeout | Do **not** logout immediately; retry on next tick; existing GET 401 path remains fallback |
| Concurrent refresh | Respect existing `_isRefreshingToken` / refresh lock in `_APIRequest` — maintenance must not fight reactive refresh |

---

## Target behavior — app closed / long background

- **Default (v1 core):** **no** periodic requests while the Flutter isolate is not running. Only foreground **3–4 min** `GetNewTokens` applies (see above).
- Long background with default settings: refresh JWT may expire on the server; user may need full login when they return — **acceptable**; keep-alive is not guaranteed without optional background maintenance (below).
- **Optional:** user may enable background keep-alive in Settings — see [Optional background keep-alive (Settings, default OFF)](#optional-background-keep-alive-settings-default-off).

### Cold start scenarios (shipped)

Wall-clock removed; tokens in `flutter_secure_storage` (`DataCache`).

| Situation | Expected flow |
|-----------|----------------|
| **Access still valid** (token present; server accepts GET) | `Splitter` / `startup_page.dart` → Home; normal GETs with Bearer access JWT |
| **Access expired, refresh still valid** | Optional proactive `GetNewTokens` on startup **or** first GET 401 → `ensureValidSession()` → Home without TOTP |
| **Refresh dead or missing** | Wipe auth via existing paths → login screen → **password + TOTP** |
| **No `HasLogin` / no tokens** | Login screen |

**Cold start (shipped):** wall-clock branch **removed** from `isColdStartSessionUsable()` in **1.5.6**.

**Widgets:** unchanged — read calendar cache only; **no JWT** in widget extensions.

---

## Optional background keep-alive (Settings, default OFF)

**Status:** **shipped** (optional tier, **default OFF**) — `SETTING_BackgroundHallgatoKeepAlive`, `lib/Misc/hallgato_background_keepalive.dart`, Settings → Behavior & other. **Not** required for v1 core; foreground 3 min 30 s maintenance remains primary.

### User control

- **Settings toggle** — **Keep session alive in background** (`settings_backgroundHallgatoKeepAlive` in `language.dart` EN/HU/RU).
- When **off** (default): behavior matches [Target behavior — app closed / long background](#target-behavior--app-closed--long-background) — foreground maintenance only.
- When **on**: best-effort hallgato session maintenance while the app is **not** in `AppLifecycleState.resumed`.

### Platform mechanisms (shipped — see TECHNICAL § Session recovery)

| Platform | Shipped | Notes |
|----------|---------|--------|
| **Android** | [`workmanager`](https://pub.dev/packages/workmanager) | Periodic **45 min** (reliability **1.5.10**; OS floor still 15 min); `requiresBatteryNotLow` + network; **no** `requiresDeviceIdle` (idle blocked nearly all runs in **1.5.9**); **15 min** initial delay; **not** charging-required; Doze / OEM may defer further. |
| **iOS** | [`background_fetch`](https://pub.dev/packages/background_fetch) | `UIBackgroundModes` = `fetch`; minimum **45 min**; system may defer or **never** run (force-quit / Background App Refresh off). |

**Design constraint — battery / reliability (1.5.9 → 1.5.10):** prefer **longer** background intervals (**45 min**) over the OS 15 min floor — tradeoff: less refresh guarantee while backgrounded, less drain. **1.5.10** drops `requiresDeviceIdle` (too strict) and uses a **15 min** Android initial delay. Cancel WorkManager / BGFetch while `resumed` (foreground owns maintenance; **immediate** GetNewTokens on resume). Coalesce: skip background tick if last successful `GetNewTokens` (fg or bg) was within **25 min**. **No** charging-required. Document honestly that **OS may defer or skip** tasks; background maintenance is **best-effort**, not a SLA.

### Behavior when enabled

- Run **`POST …/api/Account/GetNewTokens`** (same as foreground primary mechanism) when a background task fires and auth is not blocked.
- Respect existing refresh lock (`_isRefreshingToken`); skip tick if a foreground refresh is in flight or last success within coalesce window (**25 min**, **1.5.9**).
- **401/403** on background refresh: **no headless UI** — log and defer; next foreground GET / proactive refresh or login + TOTP.
- **Network errors:** retry on next OS-scheduled run; do not spam ELTE.
- Register OS tasks only when toggle **on** + logged in + **not** `resumed`; cancel on resume / logout / toggle off.

### Risks and store policy

| Topic | Notes |
|-------|--------|
| **Battery** | User-opt-in; conservative schedule; explain in Settings subtitle that background refresh uses battery and may be irregular. |
| **OS killing tasks** | Android/iOS may never run work while force-stopped, low battery, or restricted background data — user may still need TOTP after long absence. |
| **ELTE traffic pattern** | Frequent background refresh from many users could look unlike normal app use — keep intervals conservative; monitor 429 in testing. |
| **Play / App Store** | Declare background modes / permissions only if implemented; justify as **optional** session maintenance the user explicitly enabled (not tracking, not ads). |

### Open questions (plan-only)

- Minimum interval that is both battery-safe and worth shipping?
- Single combined plugin vs platform channels?
- Should background refresh run only when refresh JWT is within N minutes of suspected expiry (requires optional JWT `exp` parsing)?

---

## Portal / HWEB “activity” (research — optional, lower priority)

**Status:** **possible future approach**, **on par with** (not replacing) foreground **3–4 min** `GetNewTokens`. **No implementation** in current plan wave; **research + optional**, **lower priority** than proactive JWT refresh.

### Honesty

- Student-data REST today: **GET + Bearer JWT** on assigned `hallgatoN` — portal cookies are **not** sent on those GETs.
- Portal / HWEB session state in the app is largely **in-memory** for login flows; there is no shipped “keep portal alive” loop.
- “Fake activity” might mean **best-effort** HTTP requests to portal or HWEB endpoints **only if** research proves they extend **anything** relevant to hallgato refresh or ELTE session lifetime.

**Unknown / unproven:** whether such requests extend refresh JWT TTL, reduce 2FA prompts, or only create noise. Treat as **hypothesis** until captured HAR + live tests document server behavior.

### If ever pursued (not v1)

- Same tier as optional background keep-alive — **never** a substitute for `GetNewTokens`.
- Must not store or replay credentials beyond existing auth design; no automated 2FA.
- Rate limits and ELTE ToS / abuse perception — document before any experiment.

### Open questions

- Which portal URLs (if any) correlate with longer refresh validity?
- Does HWEB polling affect hallgato JWT at all?
- Legal/product: is synthetic “activity” acceptable to document openly to users?

---

## Optional password retention in Settings (opt-in, default OFF)

**Status:** **shipped in 1.5.7** (16 September 2026) — Settings toggle + wipe matrix + login pre-fill; no auto-2FA. (**Honesty:** briefly landed then Dart paths **reverted in 1.5.6**; restored in **1.5.7**.)

### User control

- **Settings toggle** alongside existing nickname / username preference — e.g. “Remember password on this device” (**default OFF**, opt-in only).
- When **off** (default): match today’s intent — password cleared on logout and on existing session-expiry wipe paths (`neptun_password` in `flutter_secure_storage` via `DataCache` in `lib/storage.dart`).
- When **on:** persist password in secure storage (`neptun_password`) across session end **and** **manual logout** (**1.5.10** product choice — pre-fill after Log out; wipe only when toggle OFF or `dataWipe`).

### Relationship to 2FA and silent re-auth

- **2FA cannot be automated** — no stored TOTP seed, no bypass of ELTE Login2FA.
- Saved password is **convenience only** after refresh dies or user returns from long background: pre-fill login field; user still enters **TOTP** whenever ELTE requires Login2FA.
- Does **not** change `trySilentReauth()` (**false** for ELTE) unless a separate, explicitly scoped product decision adds password-based re-login **with** mandatory 2FA UI — out of scope here.

### Policy interaction (planned wall-clock removal)

- When **10-minute wall-clock** is removed, session end on token failure should **not** delete `neptun_password` if user opted in — only tokens / auth flags cleared via existing wipe paths; password retained for next login convenience.
- Document in TECHNICAL when shipped: which `DataCache` / logout methods respect the toggle.

### Security tradeoffs (must appear in Settings copy or linked privacy note)

| Topic | Notes |
|-------|--------|
| **Stolen unlocked phone** | Password at rest in secure storage is recoverable to anyone with device access + unlocked app or backup extraction — opt-in only. |
| **MITM** | Already documented for login traffic; stored password does not worsen transport if user only uses official ELTE endpoints — still high value secret on device. |
| **Shared device** | Recommend default OFF; warn in toggle description. |
| **Manual logout** | **1.5.10:** keep password when toggle ON (pre-fill); wipe JWTs / HasLogin always. Toggle OFF or `dataWipe` clears password. |

---

## ELTE constraints

- Portal has **no** “remember this device” for skipping 2FA on later logins (user confirmed).
- Maintenance only extends an **already established** refresh token from a prior successful login + 2FA.

---

## Honesty / risks

| Topic | Risk |
|-------|------|
| **Refresh JWT TTL** | Unknown until live decode of JWT `exp` (or server docs). Plan may add optional `exp` parsing later — **not** required for v1 doc. |
| **Rate limits** | ELTE / hallgato may throttle frequent `GetNewTokens`; 3–4 min interval is a balance — monitor 429 / errors in testing. |
| **Device session length** | Longer-lived sessions on device if wall-clock is removed — user stays “logged in” until refresh dies or manual logout. |
| **Background** | With default Settings, cannot refresh while killed; optional background keep-alive is best-effort and OS-deferred — user may still need TOTP after long absence. |
| **Optional background** | Battery drain, task cancellation, uneven ELTE load if intervals too aggressive — see [Optional background keep-alive](#optional-background-keep-alive-settings-default-off). |
| **Portal / HWEB activity** | Unproven benefit; could trigger rate limits or policy questions — research only. |
| **Security** | Refresh token in secure storage remains high value. **v1 core** does not store password for silent ELTE re-login. **Optional** password retention (opt-in) increases impact of device compromise — see [Optional password retention](#optional-password-retention-in-settings-opt-in-default-off). |

---

## Explicitly out of scope (v1 core)

**v1 core** shipping criteria = foreground **3–4 min** `GetNewTokens` + planned wall-clock removal + cold-start token gating. Do **not** require for v1 core:

- Auto-2FA / stored TOTP seed
- **Enabled-by-default** background keep-alive (optional toggle shipped **1.5.7**, default off — [Optional background keep-alive](#optional-background-keep-alive-settings-default-off))
- **Enabled-by-default** password retention (optional opt-in shipped **1.5.7**, default off — [Optional password retention](#optional-password-retention-in-settings-opt-in-default-off))
- Production portal or HWEB “activity” pings without research sign-off — [Portal / HWEB “activity”](#portal--hweb-activity-research--optional-lower-priority)

---

## Implementation checklist

1. **Document parity** — **done (1.5.6)** — EN + RU plan twins + TECHNICAL + DEV_BLOG.
2. **Proactive refresh helper** — **done (1.5.6)** — `_APIRequest._attemptTokenRefresh()` + `runForegroundTokenMaintenance()`.
3. **Foreground scheduler** — **done (1.5.6)** — `HomePage` periodic timer + lifecycle pause/resume.
4. **Remove wall-clock policy** — **done (1.5.6)** — removed wall-clock APIs and `SESSION_StartedAtMs` enforcement; `markParticipantSessionStarted` kept for post-login grace.
5. **Post-login grace** — **done (1.5.6)** — ~45 s kept in `ensureValidSession`.
6. **Cold start** — **done (1.5.6)** — token gate only (optional startup `GetNewTokens` still future).
7. **User-visible copy** — **done (1.5.6)** — `auth_sessionExpired_PleaseSignIn` used for refresh-dead only.
8. **TECHNICAL + DEV_BLOG + honesty table** — **done (1.5.6)** — version **1.5.6**, tag **v1.5.6**.
9. **Manual test matrix** — **not automated** — foreground 20+ min; background 30+ min; kill with valid/dead refresh; airplane mode during tick.
10. **Widgets regression** — **unchanged** — cache-only, no JWT.
11. **Settings — background keep-alive** — **done (1.5.7)** — `SETTING_BackgroundHallgatoKeepAlive`, localized strings, default **off**; `HallgatoBackgroundKeepAlive.syncScheduledTasks()` gates WorkManager / iOS background fetch only when on + logged in.
12. **Background plugin choice** — **done (1.5.7)**; **battery tune (1.5.9)** / **reliability (1.5.10)** — Android `workmanager` **45 min** + battery-not-low + network (idle removed); iOS `background_fetch` **45+ min**; TECHNICAL § Session recovery.
13. **Battery / ELTE policy** — **done (1.5.7 / 1.5.9 / 1.5.10)** — longer background cadence; shared `GetNewTokens` + mutex; cancel BG while `resumed`; immediate resume refresh; 25 min coalesce; no charging-required; no device-idle.
14. **Settings — password retention** — **done (1.5.7)**; **manual logout keep (1.5.10)** — toggle (`SETTING_RememberPasswordOnDevice`, default **off**); keep password on manual logout when ON; login pre-fill; EN/HU/RU strings.
15. **Store / manifest** — **done (1.5.7)** — iOS `UIBackgroundModes` includes `fetch` for optional background keep-alive; Android WorkManager registration when toggle on; optional user-enabled maintenance only.
16. **Portal / HWEB research** — if pursued: spike doc with HAR, endpoints, and pass/fail before any user-facing “activity” feature; keep lower priority than steps 2–10.

---

## Bug fixes — mail + calendar (shipped 1.5.6)

**Status:** **shipped in 1.5.6** (same tag as session v1 core). No `SessionGuard` changes for these items.

### 1. Mail — epoch date and `ERROR` placeholders on cold entry — **shipped (1.5.6)**

**Was (symptom):**

1. Cold-start the app (or return after kill) and sign in if needed.
2. Open the bottom **Mail / Messages** tab without pull-to-refresh.
3. List shows grouped date **1970. january. 1.** (Unix epoch) and rows with subject / sender / preview **`ERROR`** (see user screenshot, September 2026).
4. **Pull-to-refresh** (or otherwise force mail reload) → real subjects, senders, and dates appear.

**Expected:** First paint on Mail should show cached mail or a loading/empty state — not sentinel `ERROR` rows and epoch dates.

**Investigation hints (read-only):**

| Area | Location |
|------|----------|
| Mail fetch + 24 h “fresh cache” early return | `HomePageState.fetchMails` — `lib/Pages/main_page.dart` |
| Cache load uses `ERROR` + `sendDateMs: 0` until `fillWithExisting` | same file, `loadMailCache()` |
| Persisted rows | `CachedMails_*`, `MailCacheTime`, `DataCache.getHasCachedMail()` — `lib/storage.dart` |
| Parse / model | `api.MailEntry`, `MailRequest.getMails` — `lib/API/api_coms.dart` |
| List UI | `lib/MailElements/mail_element_widget.dart` |

**Likely causes to verify:**

- **Stale or corrupt mail cache** painted while `MailCacheTime` is still “fresh” (< 24 h) → `fetchMails` returns **without** network (`cacheFresh && paintedFromCache` path).
- **`fillWithExisting` failure** leaves default `ERROR` and **`sendDateMs == 0`** → UI formats as 1970-01-01.
- **Cold-start ordering:** Mail tab loads before auth/network ready; first attempt falls back to bad cache; manual refresh runs `force` path and succeeds.

**Shipped fix:** `fetchMails` / `loadMailCache()` in `lib/Pages/main_page.dart` — `_cachedMailEntryValid()` skips corrupt rows (`ERROR` sentinels, empty ID, `sendDateMs <= 0`); partial invalid cache clears `HasCachedMail` so a stale “fresh” 24 h timestamp does not block network fetch on cold Mail tab.

---

### 2. Calendar — education week header and “classes this week” subtitle — **shipped (1.5.6)**

**Was (symptom):**

1. Open **Calendar** tab.
2. Week navigator shows header like **`3. education week`** (lowercase “education week” per EN string).
3. Subtitle like **`Classes this week: september 14. - september 18.`** with awkward wrap (**`september 18.`** alone on the second line), lowercase month names, trailing periods after day numbers — looks broken vs polished target (screenshot, September 2026).

**Expected:** Readable week title and a single-line (or intentionally wrapped) date range; locale-appropriate capitalization and date formatting; layout that uses available width (no orphan line break mid-range).

**Investigation hints (read-only):**

| Area | Location |
|------|----------|
| Week header + subtitle strings | `calendarPage_weekNav_*` — `lib/language.dart` (+ RU/TR JSON packs) |
| Subtitle assembly (`monthToText`, day params) | `WeekoffseterElementWidget` — `lib/TimetableElements/timetable_element_widget.dart` |
| Education week number for viewed page | `HomePageState` calendar week logic — `lib/Pages/main_page.dart` |
| Month name helper | `api.Generic.monthToText` — `lib/API/api_coms.dart` |

**Likely causes to verify:**

- **Layout:** subtitle is plain `EmojiRichText` without `maxLines` / width constraints → bad wrap on narrow widths.
- **Copy / i18n:** EN template uses lowercase month tokens from `monthToText` and punctuation (`%1.`) — may need `DateFormat` / per-locale capitalization instead of manual strings.
- **Separate from** education-week **number** tuning (`szorgalmi` anchor) — this item is **UI + formatting**, not week-index math (unless subtitle `from`/`to` dates are wrong).

**Shipped fix:** `WeekoffseterElementWidget` layout + `calendarPage_weekNav_*` copy (`lib/TimetableElements/timetable_element_widget.dart`, `lib/language.dart`, RU/TR JSON); improved education-week title and date-range subtitle formatting. **1.5.8** — unified single-card chrome + `calendarWeekDateRange` `${to.day}` EN fix (`lib/API/api_coms.dart`).

---

## References (code today)

| Area | Location |
|------|----------|
| `SessionGuard`, wall clock | `lib/API/api_coms.dart` |
| `tryTokenRefresh`, `ensureValidSession` | `lib/API/api_coms.dart` (`_APIRequest`) |
| Cold start gate | `SessionGuard.isColdStartSessionUsable()`, `lib/Pages/startup_page.dart` |
| Lifecycle observer | `lib/Pages/main_page.dart` (`HomePage`) |
| Token storage | `lib/storage.dart` (`DataCache`) |
| Login → Home stamp | `SetupPage` → `markParticipantSessionStarted()` (before `navigateToHomeRoot`) |

---

*Last updated: 16 September 2026.*
