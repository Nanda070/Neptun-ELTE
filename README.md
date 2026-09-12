# Neptun ELTE

A modern mobile client for **ELTE Neptun** (Eötvös Loránd University) — timetable, grades, messages, payments, and periods.

**Hub:** ELTE only (`https://neptun.elte.hu`) — no multi-university list  
**Display name:** Neptun ELTE  
**Platforms:** Android · iOS  
**Languages:** English (default) · Hungarian · Russian · Turkish

[![GitHub](https://img.shields.io/badge/GitHub-Nanda070-111?style=for-the-badge&logo=github)](https://github.com/Nanda070/Neptun-ELTE)
[![Issues](https://img.shields.io/badge/Bug%20reports-Issues-d73a4a?style=for-the-badge&logo=github)](https://github.com/Nanda070/Neptun-ELTE/issues/new/choose)

> 🇷🇺 [Русская версия](README.ru.md) · 📘 [Technical docs](docs/TECHNICAL.md) · [RU](docs/TECHNICAL.ru.md) · [iOS cheatsheet](docs/DEVELOPER.md)

---

## Features

- **ELTE-only hub** — sign-in to central ELTE Neptun (portal at `neptun.elte.hu`, not Obuda/BME `/ujhallgato`)  
- **Login like the website** — Neptun ID + password → 2FA (authenticator **or** email code) → student data APIs (mobile stand-in for “Open Student web”)  
- **Timetable** — week view with class and exam reminders  
- **Markbook** — subjects and grades  
- **Messages** — Neptun inbox  
- **Payments** — fees and due dates  
- **Periods** — registration and study periods  
- **Themes & languages** — custom palettes; EN / HU built-in, RU / TR downloadable  
- **Notifications** — class, exam, payment, and period alerts (Android & iOS)  
- **2FA warning banner** — kept until a live ELTE login is confirmed

---

## Run locally

### Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) (stable)  
- For Android: Android SDK  
- For iOS: macOS + Xcode + CocoaPods

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

### iOS

```bash
# Generate/refresh iOS folder if needed (does not wipe lib/):
flutter create --platforms=ios --org com.nanda070 --project-name neptun2 .

flutter pub get
cd ios && pod install && cd ..
flutter devices
flutter run -d <ios-device-or-simulator-id>
```

**iOS Bundle ID:** `com.nanda070.neptunmobile`  
**Android applicationId:** `com.nanda070.neptun_mobile.app`  
**Display name:** Neptun ELTE

Physical device: open `ios/Runner.xcworkspace` in Xcode, select your Team (Apple ID), then run again. Trust the developer profile on the phone if prompted.

---

## Contacts

| | |
|---|---|
| **GitHub** | [Nanda070](https://github.com/Nanda070) |
| **Discord** | nandak070 |
| **Telegram** | [nanda070](https://t.me/nanda070) |
| **Email** | [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com) |
| **Web** | [nanda.is-a.dev](https://nanda.is-a.dev/) · [cheterin.online](https://cheterin.online) · [chetmedia.com](https://chetmedia.com) |

Bug reports & ideas: [GitHub Issues](https://github.com/Nanda070/Neptun-ELTE/issues/new/choose)

---

## Docs

- [README (Russian)](README.ru.md)
- [Technical documentation (EN)](docs/TECHNICAL.md) — architecture, APIs, iOS/Android, auth
- [Техническая документация (RU)](docs/TECHNICAL.ru.md)
- [iOS cheatsheet](docs/DEVELOPER.md)

---

## Credits

People who previously worked on related code (historical, not product identity):

- **domedav** — original Neptun 2 foundations  
- **zoligamer** — earlier fork work  

Neptun ELTE is an independent project by **Nanda070**.

---

## License

See [LICENSE](LICENSE).
