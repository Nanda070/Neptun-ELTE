# iOS vs Android — сравнение платформ

> 🇬🇧 [English](IOS_VS_ANDROID.md) · 📘 [Technical (RU)](TECHNICAL.ru.md) · [EN](TECHNICAL.md)

Фактические отличия сборок **iOS** и **Android** для **Neptun ELTE** по коду: `lib/**`, `pubspec.yaml`, `ios/`, `android/` и честной таблице в [TECHNICAL.ru.md](TECHNICAL.ru.md).

**Владелец и разработчик:** **Nanda**

Здесь **не** выдумываем функции. Планируемое, непротестированное или мёртвый UI помечено явно.

---

## 1. Есть на iOS / нет или слабее на Android

| Тема | Что есть на iOS | Сторона Android |
|------|-----------------|-----------------|
| Разрешение на уведомления | `DarwinInitializationSettings` + `requestPermissions(alert/badge/sound)` в `lib/notifications.dart`; `NSUserNotificationsUsageDescription` в `ios/Runner/Info.plist` | Вместо этого — Android notification + **exact-alarm** API (см. §2) |
| Схемы внешних приложений | `LSApplicationQueriesSchemes`: `https`, `http`, `mailto`, `tg`, `telegram`, `discord` в Info.plist | В манифесте `<queries>` в основном для Custom Tabs; списка схем Telegram/Discord нет |
| Haptics API | `HapticFeedback.*` при `Platform.isIOS` (`lib/haptics.dart`) | Пакет `vibration` + разрешение `VIBRATE` (паттерны, не Taptic Engine API) |
| Нативная оболочка | `SceneDelegate` / UIScene; MethodChannel Quick Actions (**13**) в `AppDelegate` | `FlutterActivity` + MethodChannel static shortcuts (**13**) в `MainActivity` |
| Установка / подпись (документация) | Automatic Signing в Xcode; доверие профилю разработчика на устройстве; Bundle ID **без** `_` (`com.nanda070.neptunmobile`) — Technical §14 | Другой ID и модель подписи (см. §2) |
| Иконка на домашнем экране (debug) | **iOS 14+:** debug-сборка **не** открывается с иконки — для иконки нужен `--release` | Debug APK нормально ставится и запускается с лаунчера |

Отдельной **продуктовой** функции только для iOS (логин, вкладки, кэш, темы, языки), которой нет на Android, **нет**. Пробелы iOS — в основном **дистрибуция / апдейтер / toast / exact alarms** (ниже).

---

## 2. Есть на Android / нет или слабее на iOS

| Тема | Что есть на Android | Сторона iOS |
|------|---------------------|-------------|
| Автообновление GitHub APK | `AppUpdater` (`lib/Misc/auto_updater.dart`) — **сразу выходит, если не `Platform.isAndroid`**; скачивание `.apk` через `dio`, открытие через `open_filex`; нужно `REQUEST_INSTALL_PACKAGES` | Нет APK-пути; UI апдейтера скрыт; `checkAndInstallUpdate` — no-op |
| Play In-App Update | `in_app_update`, если `installerStore == com.android.vending` (`main_page.dart` + флаг GPlay в `startup_page.dart`) | Пакет не используется для обновлений; в коде нет пути Play/TestFlight in-app update |
| UI обновления | Пункты «Обновить» в Drawer и Settings с `if (Platform.isAndroid)` | Пунктов меню обновления нет |
| Exact alarms | В манифесте `SCHEDULE_EXACT_ALARM`; runtime `requestExactAlarmsPermission()`; режим `exactAllowWhileIdle` | Только Darwin schedule — в честной таблице: **нет Android-style exact alarm** |
| Boot / reschedule receivers | `RECEIVE_BOOT_COMPLETED` + `ScheduledNotificationBootReceiver` (и связанные) в `AndroidManifest.xml` | Эквивалентной wiring boot-receiver в iOS-проекте нет |
| Доп. разрешения под уведомления / APK | `USE_FULL_SCREEN_INTENT`, `VIBRATE`, storage read/write (в т.ч. под установку APK) | Только usage string + Darwin permission |
| Fluttertoast | Смена семестра, выход, копирование long-press, ошибки темы, апдейтер — часто `if (Platform.isAndroid)` | Действия (например clipboard) выполняются; **toast часто пропускается**; Technical: Fluttertoast часто невидим; есть `custom_snackbar.dart` |
| Флаг источника установки | `DataCache` / `PackageInfo.installerStore` → строки GPlay vs 3rd-party в футере настроек | Флаг при старте всё равно пишется (`installerStore == com.android.vending` или иначе); **нет** Play IAU / APK-апдейтера |
| Подпись release | Локальный `key.properties` (не в git) + signingConfigs в `android/app/build.gradle`; APK с именами по ABI | Xcode Team / профили — **не** в репо; App Store / TestFlight **не настроены** (Technical) |
| CI | `.github/workflows/betabuild.yml` собирает **debug APK** на Ubuntu | Job для **iOS нет** |

---

## 3. Общее (обе платформы)

Кратко — одна Flutter-поверхность продукта, кроме гейтов выше:

- Хаб **только ELTE**, modern JWT + TOTP 2FA; снизу **Calendar \| Markbook \| Periods \| Mail**; Payments в drawer (п. **1c**)
- Настройки: тема (Light/Dark), язык (EN/HU/RU/TR), масштаб шрифта, типы уведомлений, haptics, сдвиг недели
- Локальные уведомления: пары / экзамены / оплаты / периоды (`flutter_local_notifications` + timezone) — **не** remote push
- Wall-clock сессии: **10 мин** через `SessionGuard` (`Timer` + сохранённый timestamp на resume — п. **1b** сделан; один Timer в фоне часто замирает)
- Кэш и секреты: `shared_preferences`, `flutter_secure_storage`
- Сеть: `http` (основной); `connectivity_plus`; GitHub raw для языков/тем
- Ссылки: `url_launcher` (Android-only гейт **снят**)
- ICS-парсер + `file_picker` / класс `SetupPageCalendarLogin` есть; **на хабе setup кнопки ICS нет** (dead UI на обеих)
- Нативные плагины через Flutter plugins; плюс MethodChannel shortcuts (п. **13**) в `AppDelegate` / `MainActivity`
- **Нет** `local_auth` / биометрии в `pubspec.yaml`
- Homescreen widget: **iOS WidgetKit MVP** (пары сегодня из кэша); Android Glance отложен
- Display name **Neptun ELTE**; владелец **Nanda**
- Разные ID намеренно: iOS `com.nanda070.neptunmobile` · Android `com.nanda070.neptun_mobile.app`

---

## 4. Непротестированное / планы / известные пробелы (из TECHNICAL)

| Пункт | Статус |
|-------|--------|
| Живой ELTE-логин на каждой сборке/устройстве | Ориентир — честная таблица; CI логин не покрывает |
| Локальные уведомления на iOS | Working MVP; симулятор врёт — проверять на **устройстве** |
| Exact alarms на iOS | Слабее Android; нет аналога `SCHEDULE_EXACT_ALARM` |
| ICS с первого экрана setup | **Не подключён** (класс остаётся для старых `getHasICSFile()`) |
| APK / Play update | **Только Android**; на iOS скрыто / no-op |
| App Store / Play production | **Не цель текущего состояния**; App Store **не настроен** |
| TestFlight / автообновление IPA | **Не реализовано** (нет iOS-близнеца `AppUpdater`) |
| Аналитика | Файла нет в git |
| SPM warnings | `flutter_secure_storage`, `open_filex` — отмечено, пока не блокер |
| CI | Только Android debug APK — без analyze/test/iOS |

Полная честная таблица: [TECHNICAL.ru.md §11](TECHNICAL.ru.md#11-честность-full-vs-thin) · iOS [§14](TECHNICAL.ru.md#14-ios) · Android [§15](TECHNICAL.ru.md#15-android).

---

## 5. Ключевые файлы-источники

| Путь | Зачем |
|------|-------|
| `lib/Misc/auto_updater.dart` | GitHub APK-апдейтер только Android |
| `lib/Pages/main_page.dart` | Android апдейтер + Play IAU |
| `lib/Misc/app_drawer.dart` / `lib/Pages/settings_page.dart` | Пункты «Update» на Android |
| `lib/notifications.dart` | Общий schedule; разные permissions |
| `lib/haptics.dart` | iOS `HapticFeedback` vs Android `Vibration` |
| `android/app/src/main/AndroidManifest.xml` | Разрешения Android + notification receivers |
| `ios/Runner/Info.plist` | Usage string уведомлений + URL schemes + `UIApplicationShortcutItems` |
| `pubspec.yaml` | `in_app_update`, `vibration`, `open_filex`, `dio` и др. |
| `.github/workflows/betabuild.yml` | Только Android CI |
