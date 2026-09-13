# Neptun ELTE

A modern mobile client for **ELTE Neptun** (Eötvös Loránd University) — timetable, grades, messages, payments, and periods.

| | |
|--|--|
| **Owner / Developer** | **Nanda** |
| **Hub** | ELTE only (`https://neptun.elte.hu`) — no multi-university list |
| **Display name** | Neptun ELTE |
| **Platforms** | Android · iOS |
| **Languages** | English (default) · Hungarian · Russian · Turkish |
| **Repo** | [Nanda070/Neptun-ELTE](https://github.com/Nanda070/Neptun-ELTE) |

[![GitHub](https://img.shields.io/badge/GitHub-Nanda070-111?style=for-the-badge&logo=github)](https://github.com/Nanda070/Neptun-ELTE)
[![Bug reports](https://img.shields.io/badge/Bug%20reports-nanda.is--a.dev-0a7-?style=for-the-badge)](https://nanda.is-a.dev)

> 🇷🇺 [Русская версия](README.ru.md) · 📘 [Technical (EN)](Technical/TECHNICAL.md) · [RU](Technical/TECHNICAL.ru.md) · 📝 [Dev Blog](Technical/DEV_BLOG.md) · ⚖️ [Legal](#legal)

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
- **Timetable** — week view (Mon–Sun only; no next-Monday bleed); same-day break chips localized; next-48h / tasks / exams / period-banner strips; calendar filters in Settings; training switcher when multiple trainings exist
- **Markbook (Subjects)** — taken subjects with codes, credits, grades; my courses + grade history across terms
- **Messages** — Neptun inbox; full thread; optional HU→EN/RU machine translate (may be inaccurate)
- **Payments** — fees, due dates, collective invoices / balance (UI chrome localized; some server titles may stay Hungarian)
- **Periods** — registration and study periods
- **Themes & languages** — Light / Dark; EN / HU built-in, RU / TR downloadable from GitHub
- **Notifications** — local class, exam, payment, and period alerts (Android & iOS; no creator push server)
- **Session** — **10-minute** wall-clock auto-logout after entering the main (participant) session, plus JWT expiry / failed refresh → force logout + re-login prompt (keeps username; no silent ELTE portal re-auth; refresh may still run until the wall clock fires)
- **Drawer profile** — greets with full name from `UserInfo` + Neptun code; **profile photo** from `userAvatar` / `GetUserAvatar` (base64 JPEG, cached locally; initials if missing/fail); no training ID under the name; training switcher when multiple trainings exist
- **No first-party backend** — device talks to Neptun (+ optional GitHub raw for language/config JSON)

---

## How login works (short)

1. Portal login on `https://neptun.elte.hu` (credentials stay on device in secure storage after login).
2. 2FA when required (TOTP field in app).
3. Bridge via Student web / OuterLogin → JWT on the assigned `hallgatoN` host.
4. REST calls for calendar, subjects, messages, payments, periods; responses may be cached locally.

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

iOS checklist lives in Technical §14 (not a separate developer file).

---

## Documentation map

| Document | Path |
|----------|------|
| This README (EN) | [`docs/README.md`](README.md) |
| README (RU) | [`docs/README.ru.md`](README.ru.md) |
| Technical (EN) | [`docs/Technical/TECHNICAL.md`](Technical/TECHNICAL.md) |
| Technical (RU) | [`docs/Technical/TECHNICAL.ru.md`](Technical/TECHNICAL.ru.md) |
| Dev Blog (EN) | [`docs/Technical/DEV_BLOG.md`](Technical/DEV_BLOG.md) |
| Dev Blog (RU) | [`docs/Technical/DEV_BLOG.ru.md`](Technical/DEV_BLOG.ru.md) |
| License (canonical) | [`docs/LICENSE`](LICENSE) |
| Short root pointer | [`README.md`](../README.md) at repo root |

Repo root `README.md` / `LICENSE` point here so GitHub still has a landing page; full product text lives under `docs/`.

---

## Legal

Privacy, Terms, and Cookie / local-storage notices in three languages. **Full legal name of the creator appears only inside these Legal files** — product/docs elsewhere use **Nanda**.

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
