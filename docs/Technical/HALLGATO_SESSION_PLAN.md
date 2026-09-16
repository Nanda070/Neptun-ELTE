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

- **No** periodic requests while the Flutter isolate is not running (no WorkManager / background_fetch for session keep-alive in **v1** of this plan).
- Long background: refresh JWT may expire on the server; user may need full login when they return — **acceptable**; the app cannot guarantee keep-alive without background execution.

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
| **Background** | Cannot refresh while killed; user may need TOTP after long absence even if they were “active” yesterday. |
| **Security** | Refresh token in secure storage remains high value; maintenance does not store password for silent ELTE re-login (and must not). |

---

## Explicitly out of scope (v1)

Do **not** implement or document as part of v1 shipping criteria:

- Auto-2FA / stored TOTP seed
- Background **WorkManager** / `background_fetch` session keep-alive
- Fake portal or HWEB activity pings

**Optional future note:** background refresh could reduce TOTP frequency for power users but adds OS policy, battery, and security review — defer unless product asks.

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
