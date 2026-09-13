# Developer notes — Neptun ELTE

Full technical docs: **[`docs/TECHNICAL.md`](TECHNICAL.md)** (EN) · **[`docs/TECHNICAL.ru.md`](TECHNICAL.ru.md)** (RU).

Short iOS checklist. Identity, API, 2FA, cache, languages — in TECHNICAL.

## Identity (кратко)

| Item | Value |
|------|--------|
| Display name | **Neptun ELTE** |
| iOS Bundle ID | `com.nanda070.neptunmobile` (без `_` — иначе Xcode ломает provisioning) |
| Android `applicationId` | `com.nanda070.neptun_mobile.app` |
| Dart package | `neptun2` |
| Default language | English |
| Scope | **ELTE only** — portal/API `https://neptun.elte.hu`; HWEB SPA `hallgatoN.neptun.elte.hu` |

## iOS — запуск

```bash
flutter pub get
cd ios && pod install && cd ..
flutter devices

# Симулятор
flutter run -d "iPhone 17 Pro"

# Телефон: с иконки нужен release (iOS 14+ debug так не открывается)
flutter run --release -d Nanda
```

Signing: `ios/Runner.xcworkspace` → Automatically manage signing → Team.  
На телефоне: Settings → General → VPN & Device Management → доверить разработчику.

Подробности (Info.plist, уведомления, Android-only): раздел **14. iOS** в `TECHNICAL.md`.
