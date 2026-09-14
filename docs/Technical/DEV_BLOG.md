# Neptun ELTE — Dev Blog

Short development diary for **Neptun ELTE** (owner: **Nanda**).  
Times are **Europe/Budapest (UTC+2)**. Facts track the repo and live work — not a marketing changelog.

> 🇷🇺 [Русская версия](DEV_BLOG.ru.md) · 📘 [Technical](TECHNICAL.md) · [Product README](../README.md)

---

## 2026-09-09

**[2026-09-09, 23:06]**

- Baseline Android release line **1.0.5+18** still branded as Neptun Mobile.
- Pre–ELTE-only product: multi-institute list and older language packs still in tree.

---

## 2026-09-13 — iOS, languages, ELTE hub

**[2026-09-13, 00:18]**

- Brought up the **iOS** project (`ios/`, CocoaPods, signing path for Automatic Team).
- Physical iPhone: use **`flutter run --release`** so the home-screen icon appears (iOS 14+ debug limit).
- Bundle ID **`com.nanda070.neptunmobile`** (no underscore — Xcode signing); Android stays `com.nanda070.neptun_mobile.app`.
- Languages trimmed to **EN / HU** built-in + **RU / TR** GitHub packs.
- Removed joke / unused packs (Pirate, Chinese, German, Spanish, Romanian, Ukrainian, UAE, etc.).

**[2026-09-13, 00:29]**

- Login / **2FA** path extended for modern Neptun APIs (code entry after password).
- First iOS login fixes land; still iterating on the real ELTE portal flow.

**[2026-09-13, 00:38 – 00:42]**

- Developer / technical docs expanded (EN + RU) for iOS run, signing, and honesty notes.

**[2026-09-13, 01:45]**

- Product scoped to **ELTE only**.
- Hub UI: one institute button — no multi-university picker, no custom URL.
- `universityNameUrlPairs.json` reduced to a single entry: ELTE → **`https://neptun.elte.hu`**.
- Explicitly **not** Obuda/BME-style **`/ujhallgato`**.

**[2026-09-13, 01:50]**

- Display / docs rename: **Neptun ELTE** (repo target **Neptun-ELTE**).
- Themes catalog and language strings updated for the new name.
- Android label / iOS display name aligned.

**[2026-09-13, 02:12]**

- Documented and wired student-web bridge awareness: after portal login, Student web lands on **`hallgatoN.neptun.elte.hu`** (load-balanced nodes `1…N`).
- Do **not** hardcode a single `hallgato` host — the portal assigns the node (live HAR examples: `hallgato3` / `ELTE_HW3`).

**[2026-09-13, 04:20]**

- Major login correction: **`POST https://neptun.elte.hu/api/Account/Authenticate` is a dead end for ELTE** (empty HTTP 400).
- Correct path matches the website: portal **Potlap** `Login` → **`Login2FA`** (TOTP) → **`ToNeptunHWeb`** → **`OuterLogin`** JWT on the assigned `hallgatoN`.
- Distinguishes **invalid password** vs **server busy** / overload (no longer shown as a bad password).
- Email OTP format from HAR documented as **`XXX-XXXXXX`** (3-digit prefix + 6 digits); app UI still prioritizes **Authenticator TOTP**.
- Obsolete banner “2FA won’t work / you can’t log in with 2FA” **removed** — ELTE requires 2FA and the app accepts a code.

---

## 2026-09-13 — polish, UX, docs (same night → morning)

**[2026-09-13, ~04:45]**

- Fixed **black screen after successful 2FA**: close the 2FA popup **before** `pushAndRemoveUntil(HomePage)` so a delayed `pop` cannot blank the navigator.
- Education week numbering: prefer **study / teaching period** (`szorgalmi`, study period, …) over **subject-registration** windows that start earlier and inflated the week (~36). Still iterating toward sensible **week 1–2** for early September.
- UX: persist **Light / Dark** only as preferred app themes; bug-report / contact links → **[nanda.is-a.dev](https://nanda.is-a.dev)**; logout keeps **username**, clears **password** / session + portal cookie jar.
- Payments / Contacts UI chrome i18n; titles coming straight from the Neptun API may remain Hungarian.

**[2026-09-13, ~05:00]**

- Docs restructure under `docs/`:
  - Legal packs: **`Legal-En/` · `Legal-Ru/` · `Legal-Hu/`** (Privacy, Terms, Cookies).
  - Technical moved to **`docs/Technical/`**; separate **`DEVELOPER.md` removed** (iOS cheatsheet lives in Technical §14).
  - Canonical license **LGPL-3.0-only** in `docs/LICENSE` (root `LICENSE` mirrors).
- This **Dev Blog** added (EN + RU).

**[2026-09-13, ~05:15]**

- Calendar bug: modern `GetCalendarEvents` used **next Monday 23:59** as `endDate`, so next week’s Monday classes appeared after a fake **~163 h “szünet”** (and HU-hardcoded break UI). Fixed to **Sun end of week**, filter out-of-window events, same-day breaks only (5 min–12 h), localized EN/HU/RU/TR break strings.

**[2026-09-13, 05:14]**

- RU/TR language packs: added **39** keys that were on EN/HU but missing from GitHub-served JSON (font scale, calendar strips/filters/breaks, mail translate, settings section headers, notif titles, markbook/payment headers). Missing keys previously fell back to **English**.
- Bundled `Languages/LangExtentions/{Russian,Turkish}.json` as Flutter **assets**; `loadBundledLanguagePacks` merges into cached/downloaded packs so devices are not stuck on stale GitHub/cache until push.
- No calendar UI hardcoding found for TR — strip headers already used `AppStrings`; stale packs were the cause.
- Deploy to iPhone Nanda **skipped** (another `flutter run --release` active).

**[2026-09-13, ~05:16]**

- **10-minute session wall clock:** `SessionGuard.startSessionWallClock()` on `HomePage` entry → after 10 min calls `forceExpiredLogout` (keep username, snackbar `auth_sessionExpired_PleaseSignIn`, login). Cancel on manual logout; restart on re-login. Does **not** restart on JWT refresh. Aligns UI logout with short-lived Neptun access JWTs (~10–15 min), measured from **session entry**, not only 401.

**[2026-09-13, ~05:20]**

- **Drawer avatar works:** HAR shows photo already on `/api/UserInfo` as `data.userAvatar.image` (base64 JPEG) and larger `/api/General/GetUserAvatar?imageSizeType=Normal`. App caches base64 in `DataCache`, drawer uses `MemoryImage`, initials fallback. Prior “no photo in API” claim was wrong — nested field was missed.

**[2026-09-13, ~05:25]**

- **EN subject-detail chrome:** calendar class / task tap dialogs had HU-hardcoded labels (`Tárgykód`, `Típus`, `Tanár`, `Terem`, `Bezárás`, `Terem betöltése…`, task Subject/Type/Result). Wired to `courseDetail_*` + existing `popup_case4_5_SubjectCode` (EN/HU/RU/TR). App placeholders (`Nincs terem` / …) localize; **Neptun content** (titles, Előadás/Gyakorlat, room names) may stay HU.

**[2026-09-13, ~05:30]**

- **ELTE room-code tap decode:** codes like `LD-0-805` / `LD-0-805-01-11` toggle compact ↔ summary (`Southern Building, Floor: 0, Room: 805[, Stream: 01][, Group: 11]`). Semantics: campus–floor–room–**stream**–**group** (no inventing missing trailing segments). Prefix map LD/LE/LK; unknown prefix kept. `DecodableRoomText` on timetable list, class dialog, exam/legacy popups. Keys `roomCode_*` in HU/EN + RU/TR JSON.

**[2026-09-13, ~05:35]**

- Broader i18n audit fix: class/exam notification bodies, font-scale label, mail error/empty, 2FA popup, Android updater toasts/dialog, API fallbacks + DEMO labels — all via `LanguagePack` (HU/EN + RU/TR JSON). Room-code decode UI preserved.

**[2026-09-13, ~05:40]**

- Finished remaining Language Pack audit leftovers in `api_coms`: transport `ErrorMessage` (invalid URL/HTML, network), session-expired JSON via `auth_sessionExpired_PleaseSignIn`, mail preview tap-to-load body, empty Neptun / download-network mail errors (`api_error_*`, `mail_preview_TapToLoadBody` HU/EN + RU/TR). Protocol-matching payment status tokens (`aktív` / `teljesített`) left as API match keys (not UI chrome).

**[2026-09-13, ~08:58]**

- Wrote a prioritized **implementation plan** (docs only, no feature code): [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) / [`IMPLEMENTATION_PLAN.ru.md`](IMPLEMENTATION_PLAN.ru.md). Order: session+cache → honest markbook → calendar polish → mail search/unread → then parallel (ghost, today/ZH/ICS export/class notif granularity, payments, maps, What’s Changed, semester compare). HAR-gated: academic progress, student card. Widgets last. Indexed from README + TECHNICAL.

**[2026-09-13, ~09:05]**

- Implementation plan: added **1a** (Foundation / session+cache, before item 1 UX polish) — after logout, same-process login can show **false invalid credentials** until the app is killed. Code already clears the in-memory portal jar + `dataWipe`; remaining leftover to verify (device cookie, training-id cache, no portal Logout POST, `_looksLikeInvalidCredentials` matching `invalid` in HTML). Docs only; no Dart fix yet.

**[2026-09-13, ~09:10]**

- Implementation plan: **removed** exam / course registration (vizsgajelentkezés / tárgyjelentkezés) from the backlog. Not planned; do not add signup UI or a HAR walkthrough back. HAR-gated remains academic progress + student card. Former items 13–15 renumbered to 12–14. Docs only; no Dart change.

**[2026-09-13, ~09:20]**

- Inventoried 8 user HARs (not copied into git; secrets redacted) into [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) §4.2 / RU twin. **Bank + profile + student-card claim (NEK/FIR)** field names are now known. **No QR / card number / expiry.** **No tanterv graph** (`taken courses.har` was `RegisteredCourses`; `GetAverages` items empty). Mail extras (archive/sent/settings); finance extras (unpaid list empty, transaction detail); calendar official ICS/webcal URL. Signup XHRs seen in `finances.har` — **seen but not planned**. User did not click every control; missing POSTs expected. Docs only; no Dart.

**[2026-09-13, ~09:30]**

- Live walk of logged-in Chrome HWEB (Apple Events JS; no HAR copied). Confirmed: `/api/GetCurriculums` **404**; Advancement APIs; official average **field names** on `RegistrySheet/GetStudentTrainingTermData`; `TakenSubjects/Terms`; Student Card page has **no QR**; `GetLinksForCalendarExport`. Hard nav to registry-sheet **5002**, recovered via portal Student web. Docs only; no Dart.

**[2026-09-13, ~09:50]**

- Published **Figma UI mockups only** (not Flutter/Android/iOS code): [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups). Page **Android — polished target** = planned polish; page **iOS — current + polish** = today’s TopNavigator + 5-icon BottomNavigator shell with additive strips/labels/search/banner. Owner **Nanda**. Linked from README + TECHNICAL. Docs only.

**[2026-09-13, ~10:00]**

- Product decision (docs/plan only, **no Dart**): **Nav IA** — bottom **Calendar \| Markbook \| Mail**; **Payments** + **Periods** move to left drawer **above Settings**. Code **still has 5 tabs**; Figma may still show 5 — target is 3 + drawer (plan **1c**). **Session 1b:** background ≥10 min must `forceExpiredLogout` on resume — Flutter `Timer` pauses while suspended; store timestamp + check on `AppLifecycleState.resumed`. Synced README / TECHNICAL / IOS_VS_ANDROID / IMPLEMENTATION_PLAN EN+RU. Owner **Nanda**.

**[2026-09-13, ~10:10]**

- **Foundation slice shipped as app version 1.1.0+19** (GitHub baseline was **1.0**; later bugfixes → **1.1.x**, big features → **1.2+**). Dart + docs: **1a** same-process logout → re-login (portal Logout best-effort, wipe `devicecookie_*` + training-id cache, tighten `_looksLikeInvalidCredentials` so HTML `is-invalid` is not “wrong password”). **1b** persisted `SESSION_StartedAtMs` + `HomePage` `WidgetsBindingObserver` resume check → `forceExpiredLogout` if ≥10 min away; re-arm remaining Timer. **1c** bottom = Calendar \| Markbook \| Mail; Payments + Periods drawer entries above Settings (indices 3/4). Owner **Nanda**.

**[2026-09-13, ~10:16]**

- Documented versioning policy EN+RU (TECHNICAL § Versioning, README identity row, IMPLEMENTATION_PLAN release note). `pubspec` **1.1.0+19** (+1 build from **1.0.5+18**); iOS `MARKETING_VERSION` / Android fallback mirrored. Honesty: GitHub “1.0” is the published baseline statement; older checkouts may still show **1.0.x** until this bump lands. Owner **Nanda**.

**[2026-09-13, ~10:20]**

- **Nav IA revised (1c):** bottom = **Calendar \| Markbook \| Periods \| Mail** (`maxBottomNavWidgets = 4`). **Payments** stays drawer-only above Settings. **Contacts** moved from drawer into Settings (bottom); app version via `package_info_plus` shown under Contacts. Synced README / TECHNICAL / IMPLEMENTATION_PLAN / IOS_VS_ANDROID EN+RU. Session **1a**/**1b** unchanged. Owner **Nanda**.

**[2026-09-13, ~10:45]**

- **Foundation items 1–3 shipped:** (1) `sessionWipeKeepCache` on logout/expiry — academic cache kept; all home tabs cache-first + `cache_showingFromCache` banner; no empty-spinner wipe on dead session. (2) `MarkbookMath` — átlag vs **/30** labels; this-term + accumulated completed credits; app-computed note. (3) Calendar strips sorted; next-48h = classes+exams; upcoming tasks/exams from now; period banners strip-only; empty weeks cached. Docs EN+RU + plan status updated. Nav **1c** left intact. Owner **Nanda**.

**[2026-09-13, ~15:00]**

- **Bugfix:** After correct TOTP, ELTE **Student web full** (HWEB capacity) made `submitTwoFactorCode` return bare `false` → setup painted **“Invalid username or password!”**. Fixed: bridge returns `loginStudentWebFull` / `loginServerBusy`; snackbars `loginPage_setupPage_StudentWebFull` / busy; wrong TOTP uses `loginPage_setupPage_2faInvalidCode` without painting password fields. Wrong password still `loginInvalidCredentials`. Docs EN+RU honesty updated. Owner **Nanda**.

**[2026-09-13, ~15:05]**

- **UX:** After TOTP succeeds, show **“Connecting to Student web…”** and retry HWEB bridge ~**7 s** (success → Home immediately; failure → honest full/busy snackbar, not invalid password). Owner **Nanda**.

**[2026-09-13, ~15:15]**

- **Versioning policy revised:** stop meaningful `+N` build bumps as the user-facing story. Marketing / Settings / docs = **`1.x.y` only**. Scheme `1.<feature-line>.<patch>`; **2.0** = final / RC line. Current **`1.3.1`** (`pubspec` **1.3.1+1**): feature line **3** = plan items **1–3**; patch **1** = auth/2FA/Student-web-full fixes. Next big block → **1.4.0**. Settings shows `info.version` without `+build`. Synced TECHNICAL / README / IMPLEMENTATION_PLAN EN+RU + `.cursor/rules/versioning.mdc`. Owner **Nanda**.

**[2026-09-13, ~16:00]**

- **iOS IPA via Actions:** added `.github/workflows/ios-ipa.yml` — macOS unsigned release IPA (`--no-codesign`), artifact + attach to GitHub Release (e.g. **v1.3.1**). No Apple signing secrets in the repo yet; friends install with **Sideloadly** + their Apple ID. Docs EN+RU updated. Owner **Nanda**.

**[2026-09-13, ~17:35]**

- **Bugfix — black screen after 2FA:** post-login navigation now uses `lib/app_navigator.dart` (`navigateToHomeRoot` / `navigateToLoginRoot` via root `pushAndRemoveUntil`). Avoids empty navigator when a delayed popup pop or `popUntil` hit the sole Home route. 2FA popup opens without Home blur. Session wall-clock logout on reopen **unchanged** (by design). Owner **Nanda**.

**[2026-09-13, ~17:45]**

- **Release 1.3.2** (`pubspec` **1.3.2+1**): ships the post-2FA black-screen fix + root navigator helpers. GitHub Release **v1.3.2** + unsigned IPA via Actions. Owner **Nanda**.

**[2026-09-14]**

- **Bugfix — session expired right after 2FA:** stale `SESSION_StartedAtMs` or a race on resume / first API 401 could call `forceExpiredLogout` immediately on Home. `SessionGuard.prepareForLoginAttempt()` clears wall-clock at login start; `markParticipantSessionStarted()` persists a fresh stamp before `navigateToHomeRoot`; ~45 s post-login grace skips forced logout when an access token is still present. Owner **Nanda**.
- **Release 1.3.3** (`pubspec` **1.3.3+1**): ships the post-2FA session fix. GitHub Release **v1.3.3** + unsigned IPA via Actions. Owner **Nanda**.
- **Plan item 4 — mail search + unread filter:** local search over loaded pages (subject / sender / body preview) + unread-only `FilterChip`; pagination accumulates `mailEntries`; API stays `filterType=0` (HAR honesty). Offline/cache filters locally; search query never logged. Owner **Nanda**.
- **Release 1.3.4** (`pubspec` **1.3.4+1**): ships mail item **4**. GitHub Release **v1.3.4** + unsigned IPA via Actions. Owner **Nanda**.
- **Plan item 8 — maps deep-link on LD/LE/LK:** after tap-decode, **Open map** (`roomCode_OpenMap`) opens Apple/Google Maps with building search (`ELTE Déli Tömb` / `Északi Tömb` / `Kémiai tömb`, 1117 Budapest). Unknown prefix stays text-only. No version bump. Owner **Nanda**.
- **Plan item 7 — payments honesty + antispam:** `totalMoney` = completed outgoing (`ammount < 0`) from latest 50 txns — header “Fees paid (latest 50)”; payment notifs ≤ 1/day (soonest unpaid). No version bump. Owner **Nanda**.
- **Plan item 13 — app shortcuts:** Android static `shortcuts.xml` + iOS `UIApplicationShortcutItems` (Calendar / Mail / Payments). Cold start via `Splitter` + `SessionGuard.isColdStartSessionUsable()` → `HomePage(initialView:)` or login. Maps shortcut left for item **8**. No version bump. Owner **Nanda**.
- **Plan item 5 — ghost grade what-if:** ghost popup (mode 0) shows live átlag + /30 while picking 1–5; optional target átlag → “need ≥ N” via same `MarkbookMath.weightedAvg` / `index30`. Clear-ghost control. No version bump. Owner **Nanda**.

---

- **Plan item 6 — calendar polish:** today summary in header; ZH/deadline strip; ICS **export** share from `calendarEntries`; class-notif granularity 10/5/0 min in Settings. No version bump. Owner **Nanda**.
- **Plan item 9 — What’s Changed:** after refresh, snapshot mail `messageId`s + grade triples; drawer + calendar strip show new-mail / grade-change counts; first install silent (no false banner). No version bump. Owner **Nanda**.

---

## 2026-09-14 — student card claim / bank / profile (item 12)

**[2026-09-14]**

- **Plan item 12:** `StudentCardPage` (drawer + Settings) shows HAR-honest **claim status**, bank **visibility flags** (owner / bank name / default / foreign / valid / OTP — **never** IBAN/SWIFT), optional `GetGeneralUserData` + contacts. Cache `STUDENT_CardCacheJson` for offline non-secret flags + existing photo cache.
- **Honesty:** **no QR**, no invented card number / expiry (HWEB `/administrations/student-card` is claim-only). No version bump. Owner **Nanda**.
- **Release 1.4.0** (`pubspec` **1.4.0+1**): feature line **4** — ships plan items **5** (ghost what-if), **6** (today/ZH/ICS export/class-notif granularity), **7** (payments honesty + ≤1/day notifs), **8** (maps deep-link), **9** (What’s Changed), **12** (student card claim/bank/profile — **no QR**), **13** (home shortcuts Calendar/Mail/Payments). GitHub Release **v1.4.0** + unsigned IPA via Actions. Owner **Nanda**.

---

## 2026-09-14 — semester compare, widgets MVP, drop #11 → 1.5.0

**[2026-09-14, ~14:30]**

- **Plan item 10 — semester comparison (in progress → ship with 1.5.0):** API + cache landed — `MarkbookRequest.getSemesterComparison` / `TermComparisonStat` (per-term completed credits, átlag, **/30** via same `MarkbookMath.fromCompleted` as the markbook header). Cache-first `TakenSubjects` (`CachedMarkbookTerm_*`); fetch missing terms only when the session is usable; cap ~8 (newest first); demo returns two canned terms. i18n keys `markbook_semesterCompare_*` (HU/EN + RU/TR). Markbook side-by-side UI strip wiring with the same release. Flat “grades from other terms” history stays. **Not** a tanterv / diploma % view. Owner **Nanda**.

**[2026-09-14, ~14:35]**

- **Plan item 11 removed (Academic Progress / tanterv):** dropped from the implementation plan entirely (EN+RU priority tables + §11). Sep 2026 HARs never captured a tanterv graph; live HWEB has **no Tanterv menu** (`GetCurriculums` **404**; Advancement templates / `creditprogress` empty this term). We will **not** ship a fake progress bar from current-term credits alone. Curriculum leftovers stay honesty notes only — not a backlog item. Owner **Nanda**.

**[2026-09-14, ~14:40]**

- **Plan item 14 — homescreen widgets (honest MVP):** **iOS WidgetKit** extension `ios/TodayClassesWidget/` — today’s **classes** from calendar cache only (`CachedCalendar_w*` / current-week entries) via `lib/widget_bridge.dart` → App Group `group.com.nanda070.neptunmobile` (title / start / end / location). Synced from calendar refresh paths. **No JWT**, passwords, or tokens in the widget process. Missing cache → prompt to open the app; stale day labeled stale. Aligns with the 10-minute session wall (widget is offline snapshot, not live Neptun). **Android Glance** deferred — docs stay honest (former Flutter stub remains removed; no fake Android widget). Owner **Nanda**.

**[2026-09-14]**

- **Release 1.5.0** (`pubspec` **1.5.0+1**): feature line **5** — ships plan items **10** (semester comparison) + **14** (iOS WidgetKit MVP; Android widgets not yet). Plan item **11** removed (not shipped). Student card remains claim/bank/profile only (**no QR** — unchanged from **1.4.0**). GitHub Release **v1.5.0** + unsigned IPA via Actions when the bump lands. Owner **Nanda**.

---

## In progress / planned (honest)

**[ongoing]**

- **Session force logout** when refresh / silent re-auth fails — **in code** (`SessionGuard.forceExpiredLogout`); keep username + academic cache (**1**), show sign-in again. **1a** / **1b** / **1**–**10** / **12**–**14** shipped (item **14** = iOS WidgetKit MVP); item **11** **removed** from plan (no tanterv HAR — do not rebuild fake progress).
- **Nav IA (1c):** **shipped** — 4-tab bottom + Payments in drawer; Contacts + version in Settings.
- **Message translator** (HU → EN/RU for inbox bodies) — helper + popup actions present; treat as **in progress** until thoroughly verified offline / failure paths.
- **Large features:** student card **item 12 shipped** as claim/bank/profile only (still **no** QR/wallet). Tanterv / Academic Progress **dropped** (no menu / no HAR). Exam / course registration — **not built, not planned**. Android homescreen widgets — **not** in **1.5.0** (iOS-first MVP only).
- Email OTP full UI (`RequestEmailCode` / `CodePrefix`) — HAR-known; **not** primary path yet (TOTP first).

---

*Owner / developer: **Nanda**.*
