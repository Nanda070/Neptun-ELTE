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

---

## In progress / planned (honest)

**[ongoing]**

- **Session force logout** when refresh / silent re-auth fails — **in code** (`SessionGuard.forceExpiredLogout`); keep username, show sign-in again. Still watch edge cases after portal cookie wipe.
- **Message translator** (HU → EN/RU for inbox bodies) — helper + popup actions present; treat as **in progress** until thoroughly verified offline / failure paths.
- **Large features** (student card, full profile+bank, exam/course registration) — need HAR; not built.
- Email OTP full UI (`RequestEmailCode` / `CodePrefix`) — HAR-known; **not** primary path yet (TOTP first).

---

*Owner / developer: **Nanda**. Full legal name appears only in Legal docs.*
