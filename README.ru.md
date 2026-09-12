# Neptun Mobile

Современный мобильный клиент для **ELTE Neptun** (Университет Этвёша Лоранда) — расписание, оценки, сообщения, платежи и периоды.

**Хаб:** только ELTE (`https://neptun.elte.hu`) — без списка вузов  
**Платформы:** Android · iOS  
**Языки:** английский (по умолчанию) · венгерский · русский · турецкий

[![GitHub](https://img.shields.io/badge/GitHub-Nanda070-111?style=for-the-badge&logo=github)](https://github.com/Nanda070/Neptun-Mobile-fork)
[![Issues](https://img.shields.io/badge/Баг-репорты-Issues-d73a4a?style=for-the-badge&logo=github)](https://github.com/Nanda070/Neptun-Mobile-fork/issues/new/choose)

> 🇬🇧 [English README](README.md) · 📘 [Техническая документация](docs/TECHNICAL.ru.md) · [EN](docs/TECHNICAL.md) · [iOS-шпаргалка](docs/DEVELOPER.md)

---

## Возможности

- **Хаб только ELTE** — вход в центральный ELTE Neptun (не `/ujhallgato` как у Óbuda/BME)  
- **Расписание** — недельный вид, напоминания об занятиях и экзаменах  
- **Зачётная книжка** — предметы и оценки  
- **Сообщения** — входящие Neptun  
- **Платежи** — оплаты и сроки  
- **Периоды** — регистрация и учебные периоды  
- **Темы и языки** — палитры; EN / HU встроены, RU / TR скачиваются  
- **Уведомления** — занятия, экзамены, платежи, периоды (Android и iOS)  
- **2FA UI** — modern JWT может запросить код (в ELTE 2FA обязательна; live-проверка ещё нет; предупреждение в приложении оставлено)

---

## Запуск локально

### Требования

- [Flutter](https://docs.flutter.dev/get-started/install) (stable)  
- Android: Android SDK  
- iOS: macOS + Xcode + CocoaPods

```bash
git clone https://github.com/Nanda070/Neptun-Mobile-fork.git
cd Neptun-Mobile-fork
flutter pub get
```

### Android

```bash
flutter devices
flutter run -d <android-device-id>
# или
flutter build apk
```

### iOS

```bash
# При необходимости пересоздать ios/ (lib/ не затрагивается):
flutter create --platforms=ios --org com.nanda070 --project-name neptun_mobile .

flutter pub get
cd ios && pod install && cd ..
flutter devices
flutter run -d <ios-device-or-simulator-id>
```

**iOS Bundle ID:** `com.nanda070.neptunmobile`  
**Android applicationId:** `com.nanda070.neptun_mobile.app`  
**Имя на экране:** Neptun Mobile

На физическом устройстве: откройте `ios/Runner.xcworkspace` в Xcode, выберите Team (Apple ID), затем запустите снова. При необходимости доверьте профиль разработчика на телефоне.

---

## Контакты

| | |
|---|---|
| **GitHub** | [Nanda070](https://github.com/Nanda070) |
| **Discord** | nandak070 |
| **Telegram** | [nanda070](https://t.me/nanda070) |
| **Email** | [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com) |
| **Сайты** | [nanda.is-a.dev](https://nanda.is-a.dev/) · [cheterin.online](https://cheterin.online) · [chetmedia.com](https://chetmedia.com) |

Баги и идеи: [GitHub Issues](https://github.com/Nanda070/Neptun-Mobile-fork/issues/new/choose)

---

## Документация

- [README (English)](README.md)
- [Техническая документация (RU)](docs/TECHNICAL.ru.md) — архитектура, API, iOS/Android, auth
- [Technical documentation (EN)](docs/TECHNICAL.md)
- [iOS-шпаргалка](docs/DEVELOPER.md)

---

## Благодарности

Люди, ранее работавшие над связанным кодом (история, не «идентичность продукта»):

- **domedav** — основы оригинального Neptun 2  
- **zoligamer** — работа над более ранним форком  

Neptun Mobile — независимый проект **Nanda070**.

---

## Лицензия

См. [LICENSE](LICENSE).
