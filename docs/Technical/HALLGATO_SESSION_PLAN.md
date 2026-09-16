# Hallgato session maintenance — design plan

**Status:** design / plan only — **not implemented in app code** (as of **16 September 2026**).  
**Owner:** Nanda.  
**Canonical twin:** [HALLGATO_SESSION_PLAN.ru.md](HALLGATO_SESSION_PLAN.ru.md).

> Related shipped facts: [TECHNICAL.md § Session recovery and wall clock](TECHNICAL.md#session-recovery-and-wall-clock), [§ Auth, 2FA, tokens](TECHNICAL.md#9-auth-2fa-tokens).

---

## Goal

Minimize the number of full logins (**password + TOTP**) while keeping the user alive in the **hallgato** JWT session during normal app use.

- **Full login** = ELTE portal password + interactive 6-digit TOTP (no “remember device” on ELTE — user confirmed).
- **Session maintenance** = refresh access (and optionally refresh) tokens via the existing hallgato API, without portal activity fakes.

---

## Current shipped behavior (honesty)

Until this plan is implemented, the app still enforces:

| Mechanism | Behavior |
|-----------|----------|
| **10-minute wall clock** | `SessionGuard.sessionWallClockLimit` — force logout from **participant session start**, independent of JWT refresh (`lib/API/api_coms.dart`, `SessionGuard`). |
| **Reactive refresh** | On **401/403** for **GET** requests, `_APIRequest.ensureValidSession()` → `tryTokenRefresh()` (`POST /api/Account/GetNewTokens`) → ELTE `trySilentReauth()` (**always false**) → `forceExpiredLogout`. |
| **Foreground lifecycle** | `HomePage` (`lib/Pages/main_page.dart`) observes lifecycle for **wall-clock** re-check, not proactive token refresh. |
| **Background / killed** | No periodic hallgato calls while the process is dead. Widgets: cache-only, **no JWT** (unchanged). |
| **JWT `exp`** | Client does **not** decode JWT `exp` today; access lifetime ~10–15 min is **observational** only. |

**Planned policy change (not shipped):** remove the client **10-minute wall-clock** forced logout. Session ends on **manual logout** or **token failure** (refresh dead / `GetNewTokens` fails), not an arbitrary timer.

---

## Target behavior — app open (foreground)

### Interval

While the app is in **`AppLifecycleState.resumed`**, run proactive maintenance every **3–4 minutes** (use a single chosen interval in implementation, e.g. **3 min 30 s**, or jitter between 3 and 4 min — document the chosen constant in code comments).

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
| `resumed` | Start or resume periodic maintenance |
| `inactive`, `paused`, `detached`, `hidden` | Pause / cancel timer — **no** proactive `GetNewTokens` |
| Process killed | No maintenance (see cold start below) |

**Integration point:** same `WidgetsBindingObserver` surface as today’s wall-clock checks on `HomePage` — replace or coexist during migration (wall-clock removal is the end state).

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

### Cold start scenarios (after plan is implemented)

Assumes wall-clock removal and persisted tokens in `flutter_secure_storage` (`DataCache`).

| Situation | Expected flow |
|-----------|----------------|
| **Access still valid** (token present; server accepts GET) | `Splitter` / `startup_page.dart` → Home; normal GETs with Bearer access JWT |
| **Access expired, refresh still valid** | Optional proactive `GetNewTokens` on startup **or** first GET 401 → `ensureValidSession()` → Home without TOTP |
| **Refresh dead or missing** | Wipe auth via existing paths → login screen → **password + TOTP** |
| **No `HasLogin` / no tokens** | Login screen |

**Note on today’s cold start:** `SessionGuard.isColdStartSessionUsable()` also rejects sessions when the **10-minute wall-clock** stamp is expired — that check should be **removed** when the wall-clock policy is removed.

**Widgets:** unchanged — read calendar cache only; **no JWT** in widget extensions.

---

## Optional background keep-alive (Settings, default OFF)

**Status:** design / optional tier — **not** part of v1 core shipping criteria unless product explicitly promotes it. **Default: OFF.**

### User control

- **Settings toggle** — e.g. “Keep session alive in background” (exact copy TBD in `language.dart` EN/RU/HU).
- When **off** (default): behavior matches [Target behavior — app closed / long background](#target-behavior--app-closed--long-background) — foreground maintenance only.
- When **on**: best-effort hallgato session maintenance while the app is **not** in `AppLifecycleState.resumed`.

### Platform mechanisms (implementation choice — document in TECHNICAL when shipped)

| Platform | Candidate | Notes |
|----------|-----------|--------|
| **Android** | [`workmanager`](https://pub.dev/packages/workmanager) (or equivalent) | Periodic / expedited work subject to Doze, App Standby, OEM killers; not real-time. |
| **iOS** | [`background_fetch`](https://pub.dev/packages/background_fetch) and/or **BGTaskScheduler** | Intervals are **system-controlled**; often **15+ minutes** or longer; no guarantee of 3–4 min cadence in background. |

**Design constraint — battery:** use **conservative** intervals in background (e.g. align with OS minimum practical cadence — **not** the same 3–4 min as foreground). Coalesce with the same `GetNewTokens` helper as foreground maintenance; **no** aggressive polling or parallel timers. Document honestly that **OS may defer or skip** tasks; background maintenance is **best-effort**, not a SLA.

### Behavior when enabled

- Run **`POST …/api/Account/GetNewTokens`** (same as foreground primary mechanism) when a background task fires and auth is not blocked.
- Respect existing refresh lock (`_isRefreshingToken`); skip tick if a foreground refresh is in flight.
- **401/403** on background refresh: prefer **not** to show UI from a headless task — persist “refresh dead” state or defer to next foreground open → login + TOTP (exact UX TBD; must not fight `SessionGuard` rules when implemented).
- **Network errors:** retry on next OS-scheduled run; do not spam ELTE.

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

**Status:** design / optional convenience — **not** v1 core unless product ships it with foreground maintenance.

### User control

- **Settings toggle** alongside existing nickname / username preference — e.g. “Remember password on this device” (**default OFF**, opt-in only).
- When **off** (default): match today’s intent — password cleared on logout and on existing session-expiry wipe paths (`neptun_password` in `flutter_secure_storage` via `DataCache` in `lib/storage.dart`).
- When **on:** persist password in secure storage (`neptun_password`) across session end **until** user disables the toggle or performs **manual logout** (manual logout should still wipe password unless product explicitly chooses otherwise — **recommend wipe on manual logout even when toggle on** for clear user expectation).

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
| **Manual logout** | Should clear password (recommended) so “logout” means logout even if toggle was on. |

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
- **Enabled-by-default** background keep-alive (optional toggle may ship later — [Optional background keep-alive](#optional-background-keep-alive-settings-default-off))
- **Enabled-by-default** password retention (optional opt-in may ship later — [Optional password retention](#optional-password-retention-in-settings-opt-in-default-off))
- Production portal or HWEB “activity” pings without research sign-off — [Portal / HWEB “activity”](#portal--hweb-activity-research--optional-lower-priority)

---

## Implementation checklist (future dev)

Numbered steps only — **no code in this task**.

1. **Document parity** — keep EN + RU plan twins and TECHNICAL pointers updated when behavior ships.
2. **Proactive refresh helper** — extract or wrap `tryTokenRefresh()` (`lib/API/api_coms.dart`, `_APIRequest`) for callable maintenance (respect `_isRefreshingToken`, `SessionGuard.isAuthBlocked`).
3. **Foreground scheduler** — in `HomePage` (`lib/Pages/main_page.dart`) or a small dedicated module: `Timer` / `periodic` every **3–4 min** only when `AppLifecycleState.resumed`; cancel on pause/background (mirror existing lifecycle observer pattern used for wall-clock).
4. **Remove wall-clock policy** — delete or bypass `SessionGuard.sessionWallClockLimit`, `startSessionWallClock`, `checkSessionWallClockOnResume`, persisted `SESSION_StartedAtMs` enforcement, and wall-clock branch in `isColdStartSessionUsable()`; keep `markParticipantSessionStarted` only if still needed for post-login grace or rename purpose in comments.
5. **Post-login grace** — re-evaluate `_postLoginGrace` (~45 s) in `SessionGuard.ensureValidSession` paths after wall-clock removal; keep if still needed for 2FA race.
6. **Cold start** — update `startup_page.dart` / `isColdStartSessionUsable()` to gate on tokens + optional startup `GetNewTokens`, not 10-min stamp.
7. **User-visible copy** — ensure `auth_sessionExpired_PleaseSignIn` still matches “refresh dead” vs “wall clock” (wall-clock-specific messaging can be removed).
8. **TECHNICAL + DEV_BLOG + honesty table** — state JWT-maintenance policy; bump marketing version only when shipping to users (Android APK → new tag per repo rules).
9. **Manual test matrix** — foreground 20+ min without TOTP; background 30+ min; kill app with valid refresh; kill with dead refresh; airplane mode during maintenance tick.
10. **Widgets regression** — confirm widget sync still cache-only, no JWT.
11. **Settings — background keep-alive** — add localized strings + toggle (default **off**); persist pref key (name TBD, e.g. `settings_backgroundSessionKeepAlive`); gate registration of WorkManager / iOS background task only when on; subtitle explaining battery + irregular schedule.
12. **Background plugin choice** — Android: WorkManager periodic task with conservative interval; iOS: `background_fetch` and/or BGTaskScheduler; document chosen package + minimum interval + deferral behavior in TECHNICAL § session.
13. **Battery / ELTE policy** — no foreground-equivalent 3–4 min polling in background; single coalesced `GetNewTokens` per task; backoff on errors; no duplicate timer while app is `resumed` (foreground scheduler owns that window).
14. **Settings — password retention** — toggle (default **off**); wire to `neptun_password` read/write in `DataCache` / login flow; on token-failure logout respect opt-in (retain password); on manual logout wipe password (recommended); Settings security copy EN/RU/HU.
15. **Store / manifest** — Android permissions + iOS `UIBackgroundModes` / BGTask identifiers only if background toggle ships; Play / App Store justification text aligned with optional user-enabled maintenance.
16. **Portal / HWEB research** — if pursued: spike doc with HAR, endpoints, and pass/fail before any user-facing “activity” feature; keep lower priority than steps 2–10.

---

## Planned bug fixes (same release wave or follow-up)

**Status:** documented only — **not implemented** (16 September 2026). May ship with hallgato session maintenance or as a separate patch; **do not change `SessionGuard` for these items** unless a fix explicitly requires it.

### 1. Mail — epoch date and `ERROR` placeholders on cold entry

**Symptom (repro):**

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

**Fix direction (future):** Invalidate or skip cache when parsed entries are invalid; do not treat “fresh” timestamp alone as sufficient; ensure first successful API fetch after login replaces cache; optional empty/loading UI instead of ERROR sentinels.

---

### 2. Calendar — education week header and “classes this week” subtitle

**Symptom (repro):**

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

**Fix direction (future):** Layout pass on `WeekoffseterElementWidget` (centered subtitle, soft wrap, or `FittedBox` / `Text.rich` with non-breaking span around date range); align month/day formatting with HU/EN/RU expectations.

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
