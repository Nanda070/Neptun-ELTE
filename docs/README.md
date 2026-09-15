# Neptun ELTE

A modern mobile client for **ELTE Neptun** (Eötvös Loránd University) — timetable, grades, messages, payments, and periods.

| | |
|--|--|
| **Owner / Developer** | **Nanda** |
| **Hub** | ELTE only (`https://neptun.elte.hu`) — no multi-university list |
| **Display name** | Neptun ELTE |
| **Version** | **1.5.3** (marketing) — scheme `1.<feature-line>.<patch>`; feature line **5** = plan items **10** (semester comparison) + **14** (homescreen widgets). Patch **1.5.3** = new app icon (Android + iOS) + splash branding. **1.5.2** = Android parity (App Widget MVP + deep-link / maps queries / release APK path; OTP white-screen fix also shipped under that line). **1.5.1** removed Calendar “Next 48 hours”. Item **11** (Academic Progress / tanterv) **dropped**. Previous **1.5.0** = line-5 ship; **1.4.0** = items **5–9** + **12–13**. Final product → **2.0.0**. Settings shows three numbers only (no `+build`). ([full policy](Technical/TECHNICAL.md#versioning)) |
| **Platforms** | Android · iOS |
| **Languages** | English (default) · Hungarian · Russian · Turkish |
| **Repo** | [Nanda070/Neptun-ELTE](https://github.com/Nanda070/Neptun-ELTE) |

[![GitHub](https://img.shields.io/badge/GitHub-Nanda070-111?style=for-the-badge&logo=github)](https://github.com/Nanda070/Neptun-ELTE)
[![Bug reports](https://img.shields.io/badge/Bug%20reports-nanda.is--a.dev-0a7-?style=for-the-badge)](https://nanda.is-a.dev)

> 🇷🇺 [Русская версия](README.ru.md) · 📘 [Technical (EN)](Technical/TECHNICAL.md) · [RU](Technical/TECHNICAL.ru.md) · 📱 [iOS vs Android](Technical/IOS_VS_ANDROID.md) · 📝 [Dev Blog](Technical/DEV_BLOG.md) · 🎨 [UI mockups (Figma)](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups) · ⚖️ [Legal](#legal)

Backlog / remaining work lives in [Technical](Technical/TECHNICAL.md) (honesty + decisions) and the [Dev Blog](Technical/DEV_BLOG.md) “In progress” section. Numbered `IMPLEMENTATION_PLAN` files were **deleted** (item **11** dropped earlier).

---

## Contents

1. [Features](#features)
2. [How login works (short)](#how-login-works-short)
3. [Run locally](#run-locally)
4. [Documentation map](#documentation-map)
5. [Legal](#legal)
6. [Contacts](#contacts)
7. [Credits](#credits)
8. [License](#license)

---

## Features

- **ELTE-only hub** — sign-in to portal `neptun.elte.hu` (HWEB SPA is `hallgatoN.neptun.elte.hu` after Student web; not Obuda/BME `/ujhallgato`)
- **Login like the website** — Neptun ID + password → 2FA (authenticator TOTP; email OTP on web may be thinner in-app) → student data APIs
- **Timetable** — week view (Mon–Sun only; no next-Monday bleed); **today summary** + ZH/deadline strip; ICS **export** share; class-notif granularity 10/5/0 min; same-day break chips localized; period banners only in the period strip; calendar filters in Settings; training switcher when multiple trainings exist; tap room codes `LD`/`LE`/`LK` to decode, then **Open map** for Lágymányos buildings
- **Markbook (Subjects)** — taken subjects with codes, credits, grades; **átlag** (credit-weighted) and **/30** (same numerator÷30, not átlag÷30); this-term + accumulated completed credits; **semester comparison** (per-term átlag / /30 / credits, cache-first); **ghost grade what-if** (live átlag+/30 + optional target); app-computed honesty note; my courses + grade history across terms
- **Messages** — Neptun inbox; local search (subject / sender / loaded body) + unread-only chip; full thread; optional HU→EN/RU machine translate (`MessageTranslator`; may be inaccurate; offline/failure keeps original — still treat as verify-on-device)
- **What’s Changed** — after refresh, simple banners for new mails / grade changes (drawer + calendar strip; first install silent)
- **Payments** — fees, due dates, collective invoices / balance (drawer above Settings; UI chrome localized; some server titles may stay Hungarian)
- **Periods** — registration and study periods (bottom tab)
- **Student card / profile** — claim status (NEK/FIR/process), bank **visibility flags** (no IBAN/SWIFT shown or logged), optional personal data + contacts. Drawer + Settings. **No wallet QR / card number / expiry** (HWEB has none either; plan item **12**)
- **Navigation** — Bottom tabs: **Calendar \| Markbook \| Periods \| Mail**. **Payments** in the left drawer **above Settings**. Student card / profile also in drawer + Settings. Contacts + app version live at the bottom of Settings (plan **1c**). Figma mockups may still show 5 tabs — app IA is **4** bottom + Payments in drawer.
- **Home-screen shortcuts** — long-press app icon → **Calendar** / **Mail** / **Payments** (plan **13**). Cold start opens that surface only with a usable session; otherwise login (no blank Home with a dead JWT). Maps shortcut not included (item 8).
- **Homescreen widget** — iOS WidgetKit + Android App Widget “Today’s classes” from **calendar cache only** (no JWT in the widget). Tap opens Calendar (`neptunelte://shortcut/calendar`). Missing cache → open the app; stale day labeled. Honest with the **10-minute** session (widget is an offline snapshot).
- **Themes & languages** — Light / Dark; EN / HU built-in, RU / TR downloadable from GitHub
- **Notifications** — local class, exam, payment, and period alerts (Android & iOS; no creator push server)
- **Session** — **10-minute** wall-clock auto-logout after entering the main (participant) session (foreground `Timer` + persisted timestamp on `AppLifecycleState.resumed` so background ≥10 min also kicks — **1b**), plus JWT expiry / failed refresh → force logout + re-login (keeps username; **keeps academic cache** so tabs paint instantly — **1**; banner “from cache” when serving stale/offline). No silent ELTE portal re-auth. Same-process logout → valid-password re-login works without killing the app (**1a**).
- **Drawer profile** — greets with full name from `UserInfo` + Neptun code; **profile photo** from `userAvatar` / `GetUserAvatar` (base64 JPEG, cached locally; initials if missing/fail); no training ID under the name; training switcher when multiple trainings exist; **Student card / profile** page (claim + bank flags + optional personal data — item **12**, no QR)
- **No first-party backend** — device talks to Neptun (+ optional GitHub raw for language/config JSON)

---

## How login works (short)

1. Portal login on `https://neptun.elte.hu` (credentials stay on device in secure storage after login).
2. 2FA when required (TOTP field in app).
3. Bridge via Student web / OuterLogin → JWT on the assigned `hallgatoN` host.
4. If Student web is **full**, login stops after 2FA with an honest “full / try later” message — **not** “invalid password”.
5. REST calls for calendar, subjects, messages, payments, periods; responses may be cached locally.

Full honesty table and API map: [Technical documentation](Technical/TECHNICAL.md).

---

## Run locally

### Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) (stable)
- Android: Android SDK
- iOS: macOS + Xcode + CocoaPods

```bash
git clone https://github.com/Nanda070/Neptun-ELTE.git
cd Neptun-ELTE
flutter pub get
```

### Android

```bash
flutter devices
flutter run -d <android-device-id>
# or
flutter build apk
```

**Android applicationId:** `com.nanda070.neptun_mobile.app`

### iOS

```bash
# Generate/refresh iOS folder if needed (does not wipe lib/):
flutter create --platforms=ios --org com.nanda070 --project-name neptun2 .

flutter pub get
cd ios && pod install && cd ..
flutter devices
flutter run -d <ios-device-or-simulator-id>

# Physical device home-screen icon (iOS 14+): use release
flutter run --release -d <device>
```

**iOS Bundle ID:** `com.nanda070.neptunmobile`  
**Display name:** Neptun ELTE

Signing: open `ios/Runner.xcworkspace` → Automatically manage signing → Team. Trust the developer profile on the phone if prompted.

**GitHub Release IPA:** [Releases](https://github.com/Nanda070/Neptun-ELTE/releases) may include an **unsigned** `.ipa` from Actions (`ios-ipa.yml`). Install with **Sideloadly** (or similar) using your own Apple ID — it is not App Store / TestFlight signed.

iOS checklist lives in Technical §14 (not a separate developer file).

---

## Documentation map

| Document | Path |
|----------|------|
| This README (EN) | [`docs/README.md`](README.md) |
| README (RU) | [`docs/README.ru.md`](README.ru.md) |
| Technical (EN) | [`docs/Technical/TECHNICAL.md`](Technical/TECHNICAL.md) |
| Technical (RU) | [`docs/Technical/TECHNICAL.ru.md`](Technical/TECHNICAL.ru.md) |
| iOS vs Android (EN) | [`docs/Technical/IOS_VS_ANDROID.md`](Technical/IOS_VS_ANDROID.md) |
| iOS vs Android (RU) | [`docs/Technical/IOS_VS_ANDROID.ru.md`](Technical/IOS_VS_ANDROID.ru.md) |
| Dev Blog (EN) | [`docs/Technical/DEV_BLOG.md`](Technical/DEV_BLOG.md) |
| Dev Blog (RU) | [`docs/Technical/DEV_BLOG.ru.md`](Technical/DEV_BLOG.ru.md) |
| Backlog | TECHNICAL honesty + DEV_BLOG “In progress” (numbered `IMPLEMENTATION_PLAN*` **deleted**) |
| UI mockups (Figma) | [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups) — Figma only (not Flutter). Mockups may still show **5** bottom tabs; **app IA** is **4** (Calendar \| Markbook \| Periods \| Mail) + Payments in drawer. Android = polished target; iOS = current shell + additive polish. Owner **Nanda** |
| License (canonical) | [`docs/LICENSE`](LICENSE) |
| Short root pointer | [`README.md`](../README.md) at repo root |

Repo root `README.md` / `LICENSE` point here so GitHub still has a landing page; full product text lives under `docs/`.

---

## Legal

Privacy, Terms, and Cookie / local-storage notices in three languages.

### English — [`Legal-En/`](Legal-En/)

| Document | File |
|----------|------|
| Privacy Policy | [PRIVACY.md](Legal-En/PRIVACY.md) |
| Terms of Use | [TERMS.md](Legal-En/TERMS.md) |
| Cookie & local storage | [COOKIES.md](Legal-En/COOKIES.md) |

### Русский — [`Legal-Ru/`](Legal-Ru/)

| Документ | Файл |
|----------|------|
| Конфиденциальность | [PRIVACY.md](Legal-Ru/PRIVACY.md) |
| Условия использования | [TERMS.md](Legal-Ru/TERMS.md) |
| Cookie / локальное хранение | [COOKIES.md](Legal-Ru/COOKIES.md) |

### Magyar — [`Legal-Hu/`](Legal-Hu/)

| Dokumentum | Fájl |
|------------|------|
| Adatvédelmi tájékoztató | [PRIVACY.md](Legal-Hu/PRIVACY.md) |
| Felhasználási feltételek | [TERMS.md](Legal-Hu/TERMS.md) |
| Süti / helyi tárolás | [COOKIES.md](Legal-Hu/COOKIES.md) |

Also: [LGPL-3.0 License](LICENSE).

---

## Contacts

**Owner / Developer:** **Nanda**

| | |
|---|---|
| **GitHub** | [Nanda070](https://github.com/Nanda070) |
| **Discord** | nandak070 |
| **Telegram** | [nanda070](https://t.me/nanda070) |
| **Email** | [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com) |
| **Web** | [nanda.is-a.dev](https://nanda.is-a.dev/) · [cheterin.online](https://cheterin.online) · [chetmedia.com](https://chetmedia.com) |

Bug reports & ideas: [nanda.is-a.dev](https://nanda.is-a.dev) (not the GitHub Issues form).

---

## Credits

People who previously worked on related code (historical, not product identity):

- **domedav** — original Neptun 2 foundations
- **zoligamer** — earlier fork work

Neptun ELTE is an independent project by **Nanda** ([Nanda070](https://github.com/Nanda070)).

---

## License

GNU Lesser General Public License v3 (**LGPL-3.0-only**). See [LICENSE](LICENSE) (identical copy at repo root for GitHub).
