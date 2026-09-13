# Neptun ELTE

Современный мобильный клиент для **ELTE Neptun** (Университет Этвёша Лоранда) — расписание, оценки, сообщения, платежи и периоды.

| | |
|--|--|
| **Владелец и разработчик** | **Nanda** |
| **Хаб** | только ELTE (`https://neptun.elte.hu`) — без списка вузов |
| **Имя на экране** | Neptun ELTE |
| **Версия** | **1.3.1** (маркетинг) — схема `1.<feature-line>.<patch>`; линия **3** = пункты плана 1–3; патч **1** = auth/2FA/Student-web-full; следующий крупный блок → **1.4.0**; финал → **2.0.0**. Settings показывает только три числа (без `+build`). ([полная политика](Technical/TECHNICAL.ru.md#версионирование)) |
| **Платформы** | Android · iOS |
| **Языки** | английский (по умолчанию) · венгерский · русский · турецкий |
| **Репозиторий** | [Nanda070/Neptun-ELTE](https://github.com/Nanda070/Neptun-ELTE) |

[![GitHub](https://img.shields.io/badge/GitHub-Nanda070-111?style=for-the-badge&logo=github)](https://github.com/Nanda070/Neptun-ELTE)
[![Bug reports](https://img.shields.io/badge/Баг--репорты-nanda.is--a.dev-0a7-?style=for-the-badge)](https://nanda.is-a.dev)

> 🇬🇧 [English README](README.md) · 📘 [Техническая (RU)](Technical/TECHNICAL.ru.md) · [EN](Technical/TECHNICAL.md) · 📋 [План реализации](Technical/IMPLEMENTATION_PLAN.ru.md) · 📱 [iOS vs Android](Technical/IOS_VS_ANDROID.ru.md) · 📝 [Dev Blog](Technical/DEV_BLOG.ru.md) · 🎨 [UI-макеты (Figma)](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups) · ⚖️ [Legal](#legal--юридические-документы)

---

## Оглавление

1. [Возможности](#возможности)
2. [Как устроен вход (кратко)](#как-устроен-вход-кратко)
3. [Запуск локально](#запуск-локально)
4. [Карта документации](#карта-документации)
5. [Legal / юридические документы](#legal--юридические-документы)
6. [Контакты](#контакты)
7. [Благодарности](#благодарности)
8. [Лицензия](#лицензия)

---

## Возможности

- **Хаб только ELTE** — вход на портал `neptun.elte.hu` (HWEB SPA — `hallgatoN.neptun.elte.hu` после Student web; не `/ujhallgato` как у Óbuda/BME)
- **Логин как на сайте** — Neptun ID + пароль → 2FA (TOTP; email OTP на сайте может быть тоньше в приложении) → student API
- **Расписание** — неделя **пн–вс** (без «протекания» следующего понедельника); локализованные чипы перерыва в тот же день; полоса 48 ч = пары+экзамены; ZH и экзамены — ближайшие от сейчас; баннеры периодов только в полосе периодов; фильтры календаря в настройках; переключатель обучения при нескольких training
- **Зачётная книжка (Предметы)** — взятые предметы с кодами, кредиты и оценки; **átlag** (взвешенный кредитами) и **/30** (тот же числитель÷30, не átlag÷30); кредиты семестра + накопленные сданные; пометка «счёт приложения»; мои курсы + история оценок по семестрам
- **Сообщения** — входящие Neptun; полная ветка; опциональный машинный перевод HU→EN/RU (может быть неточным)
- **Платежи** — оплаты, сроки, collective invoices / баланс (drawer над Settings; UI локализован; часть серверных названий может оставаться на венгерском)
- **Периоды** — регистрация и учебные периоды (нижняя вкладка)
- **Навигация** — снизу **Calendar \| Markbook \| Periods \| Mail**. **Payments** в левом drawer **над Settings**. Contacts + версия приложения — внизу Settings (п. **1c**). Макеты Figma могут ещё показывать 5 вкладок — в приложении IA: **4** снизу + Payments в drawer.
- **Темы и языки** — Light / Dark; EN / HU встроены, RU / TR скачиваются с GitHub
- **Уведомления** — локальные (занятия, экзамены, платежи, периоды); без push-сервера автора
- **Сессия** — автовыход по **10-минутному** wall-clock после входа в основную (participant) сессию (foreground `Timer` + сохранённый timestamp на `AppLifecycleState.resumed`, фон ≥10 мин тоже выкидывает — **1b**), плюс истечение JWT / провал refresh → принудительный выход + повторный вход (логин сохраняется; **учебный кэш сохраняется** — вкладки сразу из кэша — **1**; баннер «из кэша» при stale/offline). Без тихого portal re-auth. Logout → повторный вход с верным паролем в том же процессе без убийства приложения (**1a**).
- **Профиль в drawer** — приветствие с полным именем из `UserInfo` + код Neptun; **фото профиля** из `userAvatar` / `GetUserAvatar` (base64 JPEG, локальный кэш; инициалы при отсутствии/ошибке); без training ID под именем; переключатель обучения при нескольких training
- **Без собственного бэкенда** — устройство говорит с Neptun (+ опционально GitHub raw для языков/конфига)

---

## Как устроен вход (кратко)

1. Портальный логин на `https://neptun.elte.hu` (секреты — в защищённом хранилище устройства).
2. 2FA при необходимости (в UI — TOTP).
3. Bridge Student web / OuterLogin → JWT на назначенном `hallgatoN`.
4. REST для расписания, предметов, сообщений, платежей, периодов; ответы могут кэшироваться локально.

Полная таблица «честности» и карта API: [техническая документация](Technical/TECHNICAL.ru.md).

---

## Запуск локально

### Требования

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
# или
flutter build apk
```

**Android applicationId:** `com.nanda070.neptun_mobile.app`

### iOS

```bash
# При необходимости пересоздать ios/ (lib/ не затрагивается):
flutter create --platforms=ios --org com.nanda070 --project-name neptun2 .

flutter pub get
cd ios && pod install && cd ..
flutter devices
flutter run -d <ios-device-or-simulator-id>

# Физическое устройство, иконка (iOS 14+): release
flutter run --release -d <device>
```

**iOS Bundle ID:** `com.nanda070.neptunmobile`  
**Имя на экране:** Neptun ELTE

Signing: `ios/Runner.xcworkspace` → Automatically manage signing → Team. При необходимости доверьте профиль разработчика на телефоне.

**IPA с GitHub Release:** в [Releases](https://github.com/Nanda070/Neptun-ELTE/releases) может быть **неподписанный** `.ipa` из Actions (`ios-ipa.yml`). Ставьте через **Sideloadly** (или аналог) со своим Apple ID — это не App Store / TestFlight.

iOS-шпаргалка — в Technical §14 (отдельного `DEVELOPER.md` нет).

---

## Карта документации

| Документ | Путь |
|----------|------|
| Этот README (RU) | [`docs/README.ru.md`](README.ru.md) |
| README (EN) | [`docs/README.md`](README.md) |
| Техническая (RU) | [`docs/Technical/TECHNICAL.ru.md`](Technical/TECHNICAL.ru.md) |
| Technical (EN) | [`docs/Technical/TECHNICAL.md`](Technical/TECHNICAL.md) |
| iOS vs Android (RU) | [`docs/Technical/IOS_VS_ANDROID.ru.md`](Technical/IOS_VS_ANDROID.ru.md) |
| iOS vs Android (EN) | [`docs/Technical/IOS_VS_ANDROID.md`](Technical/IOS_VS_ANDROID.md) |
| План реализации (RU) | [`docs/Technical/IMPLEMENTATION_PLAN.ru.md`](Technical/IMPLEMENTATION_PLAN.ru.md) |
| Implementation plan (EN) | [`docs/Technical/IMPLEMENTATION_PLAN.md`](Technical/IMPLEMENTATION_PLAN.md) |
| Dev Blog (RU) | [`docs/Technical/DEV_BLOG.ru.md`](Technical/DEV_BLOG.ru.md) |
| Dev Blog (EN) | [`docs/Technical/DEV_BLOG.md`](Technical/DEV_BLOG.md) |
| UI-макеты (Figma) | [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups) — только Figma (не Flutter). Макеты могут ещё показывать **5** нижних вкладок; **в приложении IA** — **4** (Calendar \| Markbook \| Periods \| Mail) + Payments в drawer. Android = целевой polish; iOS = текущая оболочка + аддитивные поля. Владелец **Nanda** |
| Лицензия (канон) | [`docs/LICENSE`](LICENSE) |
| Короткий указатель в корне | [`README.md`](../README.md) |

Корневые `README.md` / `LICENSE` нужны GitHub; полный текст — в `docs/`.

---

## Legal / юридические документы

Политика конфиденциальности, условия и cookie / локальное хранение на трёх языках. **Полное юридическое имя создателя — только внутри Legal-файлов**; в остальных документах — **Nanda**.

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

Также: [лицензия LGPL-3.0](LICENSE).

---

## Контакты

**Владелец и разработчик:** **Nanda**

| | |
|---|---|
| **GitHub** | [Nanda070](https://github.com/Nanda070) |
| **Discord** | nandak070 |
| **Telegram** | [nanda070](https://t.me/nanda070) |
| **Email** | [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com) |
| **Сайты** | [nanda.is-a.dev](https://nanda.is-a.dev/) · [cheterin.online](https://cheterin.online) · [chetmedia.com](https://chetmedia.com) |

Баги и идеи: [nanda.is-a.dev](https://nanda.is-a.dev) (не форма GitHub Issues).

---

## Благодарности

Люди, ранее работавшие над связанным кодом (история, не идентичность продукта):

- **domedav** — основы оригинального Neptun 2
- **zoligamer** — работа над более ранним форком

Neptun ELTE — независимый проект **Nanda** ([Nanda070](https://github.com/Nanda070)).

---

## Лицензия

GNU Lesser General Public License v3 (**LGPL-3.0-only**). См. [LICENSE](LICENSE) (идентичная копия в корне репозитория для GitHub).
