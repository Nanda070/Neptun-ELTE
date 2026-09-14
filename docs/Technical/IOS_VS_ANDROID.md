# iOS vs Android — platform comparison

> 🇷🇺 [Русская версия](IOS_VS_ANDROID.ru.md) · 📘 [Technical (EN)](TECHNICAL.md) · [RU](TECHNICAL.ru.md)

Factual differences between the **iOS** and **Android** builds of **Neptun ELTE**, derived from `lib/**`, `pubspec.yaml`, `ios/`, `android/`, and the honesty notes in [TECHNICAL.md](TECHNICAL.md).

**Owner / developer:** **Nanda**

Do **not** invent features here. If something is only planned, untested, or dead UI, it is marked as such.

---

## 1. iOS has / Android lacks (or weaker)

| Topic | What iOS has | Android side |
|-------|----------------|--------------|
| Notification permission UX | `DarwinInitializationSettings` + `requestPermissions(alert/badge/sound)` in `lib/notifications.dart`; `NSUserNotificationsUsageDescription` in `ios/Runner/Info.plist` | Uses Android notification + **exact-alarm** permission APIs instead (see §2) |
| External app URL schemes | `LSApplicationQueriesSchemes`: `https`, `http`, `mailto`, `tg`, `telegram`, `discord` in Info.plist | Manifest `<queries>` mainly for Custom Tabs; no Telegram/Discord scheme list |
| Haptics API | `HapticFeedback.*` when `Platform.isIOS` (`lib/haptics.dart`) | Uses `vibration` package + `VIBRATE` permission (patterns, not Taptic Engine API) |
| Native shell | `SceneDelegate` / UIScene lifecycle; MethodChannel for Quick Actions (**13**) in `AppDelegate` | `FlutterActivity` + MethodChannel for static shortcuts (**13**) in `MainActivity` |
| Device install / signing docs | Automatic Signing in Xcode; trust developer profile on device; Bundle ID **without** `_` (`com.nanda070.neptunmobile`) — see Technical §14 | Different ID and signing model (see §2) |
| Debug home-screen icon | **iOS 14+:** debug build does **not** open from the home-screen icon — need `--release` for icon launch | Debug APK installs/launch normally from the launcher |

There is **no** iOS-only product feature (login, tabs, cache, themes, languages) that Android lacks. Gaps on iOS are mostly **distribution / updater / toast / exact alarms** (below).

---

## 2. Android has / iOS lacks (or weaker)

| Topic | What Android has | iOS side |
|-------|------------------|----------|
| GitHub APK auto-update | `AppUpdater` (`lib/Misc/auto_updater.dart`) — **early-returns unless `Platform.isAndroid`**; downloads `.apk` via `dio`, opens with `open_filex`; needs `REQUEST_INSTALL_PACKAGES` | No APK path; updater UI hidden; `checkAndInstallUpdate` is a no-op |
| Play In-App Update | `in_app_update` when `installerStore == com.android.vending` (`main_page.dart` + `startup_page.dart` GPlay flag) | Package not used for updates; no Play/TestFlight in-app update path in code |
| Update UI | Drawer + Settings “Update now” tiles gated with `if (Platform.isAndroid)` | No update menu entries |
| Exact alarms | Manifest `SCHEDULE_EXACT_ALARM`; runtime `requestExactAlarmsPermission()`; schedule mode `exactAllowWhileIdle` | Darwin schedule only — Technical honesty: **no Android-style exact alarm** |
| Boot / reschedule receivers | `RECEIVE_BOOT_COMPLETED` + `ScheduledNotificationBootReceiver` (and related) in `AndroidManifest.xml` | No equivalent boot-receiver wiring in the iOS project |
| Extra notification-related permissions | `USE_FULL_SCREEN_INTENT`, `VIBRATE`, storage read/write (also used for APK install flow) | Usage string + Darwin permission only |
| Fluttertoast feedback | Semester change, logout, copy-on-long-press, theme-download failures, updater toasts — often `if (Platform.isAndroid)` | Clipboard / actions still run; **toast often skipped**; Technical notes Fluttertoast as often invisible; `custom_snackbar.dart` exists as alternative |
| Install-origin flag | `DataCache` / `PackageInfo.installerStore` → GPlay vs 3rd-party strings in settings footer | Flag still written at startup (`installerStore == com.android.vending` → else “not Play”); **no** Play IAU / APK updater |
| Release signing | Local `key.properties` (gitignored) + release signingConfigs in `android/app/build.gradle`; ABI-named APKs | Xcode Team / profiles — **not** in repo; App Store / TestFlight **not set up** (Technical) |
| CI | `.github/workflows/betabuild.yml` builds **debug APK** on Ubuntu | **No** iOS CI job |

---

## 3. Shared (both platforms)

Short list — same Flutter product surface unless gated above:

- **ELTE-only** login hub, modern JWT + TOTP 2FA path; bottom **Calendar \| Markbook \| Periods \| Mail**; Payments in drawer (**1c**)
- Settings: theme (Light/Dark), language (EN/HU/RU/TR), font scale, notification toggles, haptics toggle, week offset
- Local notifications for classes / exams / payments / periods (`flutter_local_notifications` + timezone) — **not** remote push
- Session wall-clock: **10 min** via `SessionGuard` (`Timer` + persisted timestamp on resume — **1b** shipped; Timer alone pauses in background)
- Cache + secrets: `shared_preferences`, `flutter_secure_storage`
- Network: `http` (primary); `connectivity_plus`; GitHub raw for languages/themes
- Links: `url_launcher` (Android-only gate **removed**)
- ICS parser + `file_picker` / `SetupPageCalendarLogin` code exists; **setup hub has no ICS entry** (dead UI on both)
- Home-screen shortcuts (plan **13**): Android `shortcuts.xml` + iOS `UIApplicationShortcutItems`; Dart `lib/app_shortcuts.dart` via MethodChannel in `MainActivity` / `AppDelegate`
- **No** `local_auth` / biometrics in `pubspec.yaml`
- Homescreen widget **removed** (was a stub)
- Display name **Neptun ELTE**; owner **Nanda**
- Different identifiers by design: iOS `com.nanda070.neptunmobile` · Android `com.nanda070.neptun_mobile.app`

---

## 4. Untested / planned / known gaps (from TECHNICAL)

| Item | Status |
|------|--------|
| Live ELTE login on every build/device | Treat honesty table as source of truth; do not assume CI covers login |
| Local iOS notifications | Working MVP; simulator can mislead — test on a **device** |
| Exact alarms on iOS | Weaker than Android; no `SCHEDULE_EXACT_ALARM` equivalent |
| ICS from first setup screen | **Not wired** (class remains for old `getHasICSFile()` users) |
| APK / Play update | **Android only**; hidden / no-op on iOS |
| App Store / Play production | **Not the current goal**; App Store **not set up** |
| TestFlight / IPA auto-update | **Not implemented** (no iOS twin of `AppUpdater`) |
| Analytics | File not in git |
| SPM warnings | `flutter_secure_storage`, `open_filex` — noted, not a current blocker |
| CI | Android debug APK only — no analyze/test/iOS |

Full honesty table: [TECHNICAL.md §11](TECHNICAL.md#11-honesty-full-vs-thin) · iOS cheatsheet [§14](TECHNICAL.md#14-ios) · Android [§15](TECHNICAL.md#15-android).

---

## 5. Key source files

| Path | Relevance |
|------|-----------|
| `lib/Misc/auto_updater.dart` | Android-only GitHub APK updater |
| `lib/Pages/main_page.dart` | Android updater + Play IAU |
| `lib/Misc/app_drawer.dart` / `lib/Pages/settings_page.dart` | Android “Update” tiles |
| `lib/notifications.dart` | Shared schedule; platform permission differences |
| `lib/haptics.dart` | iOS `HapticFeedback` vs Android `Vibration` |
| `android/app/src/main/AndroidManifest.xml` | Android permissions + notification receivers |
| `ios/Runner/Info.plist` | Notification usage string + URL schemes + `UIApplicationShortcutItems` |
| `pubspec.yaml` | `in_app_update`, `vibration`, `open_filex`, `dio`, etc. |
| `.github/workflows/betabuild.yml` | Android CI only |
