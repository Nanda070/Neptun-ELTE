# Developer notes — Neptun Mobile

Short technical notes. Not a full architecture dump.

## Identity

| Item | Value |
|------|--------|
| Display name | Neptun Mobile |
| Bundle / application ID | `com.nanda070.neptun_mobile.app` |
| Dart package name (`pubspec`) | `neptun2` (imports use `package:neptun2/...`) |
| GitHub | https://github.com/Nanda070/Neptun-Mobile-fork |
| Default UI language | English (`en`); also built-in: `hu`. Downloadable: `ru`, `tr` |

## Platforms

- **Android** and **iOS** are first-class.
- Linux desktop folder was removed (mobile-focused).
- Home-screen widget stub / Android widget XML were removed (unused).

---

## iOS

### Generate / refresh

```bash
flutter create --platforms=ios --org com.nanda070 --project-name neptun_mobile .
```

This does **not** wipe `lib/`. After create, set bundle ID to `com.nanda070.neptun_mobile.app` if Flutter generated a different identifier (e.g. `com.nanda070.neptunMobile`).

### Run

```bash
flutter pub get
cd ios && pod install && cd ..
flutter devices
flutter run -d <device-id>
```

Prefer a connected iPhone; otherwise use the iOS Simulator.

### Signing

1. Open `ios/Runner.xcworkspace` in Xcode.  
2. Runner target → **Signing & Capabilities** → enable Automatic Signing.  
3. Team: your Apple ID (e.g. Nanda070 / adnan.huseynli1@gmail.com).  
4. On the phone: Settings → General → VPN & Device Management → trust the developer.  

Without a valid Apple development identity, physical-device installs fail; Simulator still works.

### Notifications

- `lib/notifications.dart` uses `DarwinInitializationSettings` and schedules on iOS.  
- `Info.plist` includes `NSUserNotificationsUsageDescription` and `LSApplicationQueriesSchemes` for https / mailto / telegram / discord.  
- Exact alarms / Play in-app update remain Android-only.

### Known Android-only bits

| Feature | Notes |
|---------|--------|
| APK / GitHub updater (`AppUpdater`) | Hidden on iOS (drawer + settings) |
| `in_app_update` (Play Store) | Gated with `Platform.isAndroid` |
| `Fluttertoast` | Android toasts only; iOS still runs the action |
| Haptics | iOS uses `HapticFeedback`; Android uses `vibration` |

---

## Languages & assets

- Built-in packs: EN + HU in `lib/language.dart`.  
- Remote list: `Languages/supportedLanguages.json` → only RU, TR.  
- Themes: `Themes/supportedThemes.json` (URLs point at this repo).  
- University list: `universityNameUrlPairs.json`.

---

## ICS calendar

Offline ICS import remains available from setup UI (`lib/API/ics_calendar.dart`, `lib/local_file_actions.dart`) for users who cannot log in normally. Keep it unless you intentionally remove that entry point.

---

## Contacts (app + docs)

- GitHub: Nanda070  
- Discord: nandak070  
- Telegram: nanda070  
- Email: adnan.huseynli1@gmail.com  
- Web: https://nanda.is-a.dev/ , cheterin.online, chetmedia.com  

Issues: https://github.com/Nanda070/Neptun-Mobile-fork/issues

---

## History (brief)

Earlier contributors (not upstream product identity): **domedav** (original foundations), **zoligamer** (prior fork). This repo is independent under **Nanda070**.
