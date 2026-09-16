# Neptun ELTE

Современный мобильный клиент для **ELTE Neptun** (Университет Этвёша Лоранда) — расписание, оценки, сообщения, платежи и периоды.

| | |
|--|--|
| **Владелец и разработчик** | **Nanda** |
| **Хаб** | только ELTE (`https://neptun.elte.hu`) — без списка вузов |
| **Имя на экране** | Neptun ELTE |
| **Версия** | **1.8.3** (маркетинг) — схема `1.<feature-line>.<patch>`; feature-line **5** = пункты **10** (сравнение семестров) + **14** (виджеты). Feature-line **6** / **1.6.0** = фаза B indoor-карта MVP (pre-login Map, LD/LE, A→B; UX позже отвергнут). Feature-line **8** / **1.8.0** = **полигоны BIS FootPrint**; патч **1.8.1** = reanchor; патч **1.8.2** = hull + bbox; патч **1.8.3** = официальная светлая палитра BIS, без bbox, denser z19 (**2573/3112**). Feature-line **7** / **1.7.0** = Strategy D schematic (больше не primary). Патч **1.6.1** = LD centerline + honesty стратегии D. Патч **1.5.12** = фикс внешних Maps на iOS для LD/LE/LK (`maps:` URI, схемы Info.plist, **Открыть карту** всегда видно). **1.5.11** = docs/data фаза A карты кампуса (0–6) готова + синхронизация честности (пакет QA; Flutter Map UI отложен; ); тег для device/GitHub. **1.5.10** = надёжность keep-alive (снят idle у WorkManager; сразу GetNewTokens + календарь/почта при resume; remember-password сохраняет пароль при ручном logout). **1.5.9** = щадящий для батареи опциональный **фоновый hallgato keep-alive** (45 мин, coalesce, отмена в `resumed`). **1.5.8** = навигатор учебной недели (одна карточка) + фикс EN диапазона дат. **1.5.7** = фоновый keep-alive + **запомнить пароль** (оба default off). **1.5.6** = hallgato session v1 (без 10-мин wall-clock; проактивный JWT refresh каждые 3 мин 30 с). **1.5.5** = drawer icon/emoji + color-only splash. **1.5.4** = надёжность 10-мин wall-clock (снято в **1.5.6**) + фикс emoji ghost в Bug report. **1.5.3** = новая иконка приложения (Android + iOS) + splash branding. **1.5.2** = паритет Android (App Widget MVP + deep-link / maps queries / путь release APK; фикс белого экрана OTP тоже в той линии). **1.5.1** убрал полосу «Следующие 48 часов». П. **11** (Academic Progress / tanterv) **снят**. Предыдущая **1.5.0** = отгрузка линии 5; **1.4.0** = п. **5–9** + **12–13**. Финал → **2.0.0**. Settings показывает только три числа (без `+build`). ([полная политика](Technical/TECHNICAL.ru.md#версионирование)) |
| **Платформы** | Android · iOS |
| **Языки** | английский (по умолчанию) · венгерский · русский · турецкий |
| **Репозиторий** | [Nanda070/Neptun-ELTE](https://github.com/Nanda070/Neptun-ELTE) |

[![GitHub](https://img.shields.io/badge/GitHub-Nanda070-111?style=for-the-badge&logo=github)](https://github.com/Nanda070/Neptun-ELTE)
[![Bug reports](https://img.shields.io/badge/Баг--репорты-nanda.is--a.dev-0a7-?style=for-the-badge)](https://nanda.is-a.dev)

> 🇬🇧 [English README](README.md) · 📘 [Техническая (RU)](Technical/TECHNICAL.ru.md) · [EN](Technical/TECHNICAL.md) · 📝 [Dev Blog](Technical/DEV_BLOG.ru.md) · 🎨 [UI-макеты (Figma)](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups) · ⚖️ [Legal](#legal--юридические-документы)

Бэклог / остаток работы — в [технической](Technical/TECHNICAL.ru.md) (честность + решения) и в разделе «В работе» [Dev Blog](Technical/DEV_BLOG.ru.md). Нумерованные файлы `IMPLEMENTATION_PLAN` **удалены** (п. **11** снят раньше).

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
- **Карта кампуса (полигоны BIS FootPrint)** — кнопка на login-хабе **без** Neptun-логина; LD/LE **цветные FootPrint комнат BIS** (не ленты schematic / JPG), этажи, поиск, A→B поверх, карточка по тапу; чип IK; честно **2573/3112** (MVT FootPrint + hull underlay; светлая палитра; футер по этажу); внешний Open map сохранён
- **Расписание** — неделя **пн–вс** (без «протекания» следующего понедельника); **сводка «сегодня»** + полоса ZH/дедлайны; ICS **export** share; гранулярность нотификаций пар 10/5/0 мин; локализованные чипы перерыва в тот же день; баннеры периодов только в полосе периодов; фильтры календаря в настройках; переключатель обучения при нескольких training; тап по кодам аудиторий `LD`/`LE`/`LK` → расшифровка, **Открыть карту** (всегда видно для LD/LE/LK) открывает **внешние** Apple/Google Maps для корпусов Lágymányos (in-app indoor A→B — переходная Campus Map; внешний Open map остаётся для пинов корпусов)
- **Зачётная книжка (Предметы)** — взятые предметы с кодами, кредиты и оценки; **átlag** (взвешенный кредитами) и **/30** (тот же числитель÷30, не átlag÷30); кредиты семестра + накопленные сданные; **сравнение семестров** (átlag / /30 / кредиты по семестрам, cache-first); **ghost what-if** (живые átlag+/30 + опциональная цель); пометка «счёт приложения»; мои курсы + история оценок по семестрам
- **Сообщения** — входящие Neptun; локальный поиск (тема / отправитель / загруженное тело) + чип «только непрочитанные»; полная ветка; опциональный машинный перевод HU→EN/RU (`MessageTranslator` — **работает**; может быть неточным; offline/ошибка → исходный текст; disclaimer один раз)
- **«Что изменилось»** — после refresh простые баннеры новых писем / смен оценок (drawer + полоса календаря; первый запуск без баннера)
- **Платежи** — оплаты, сроки, collective invoices / баланс (drawer над Settings; UI локализован; часть серверных названий может оставаться на венгерском)
- **Периоды** — регистрация и учебные периоды (нижняя вкладка)
- **Студенческий / профиль** — статус заявки (NEK/FIR/процесс), банковские **флаги видимости** (IBAN/SWIFT не показываются и не логируются), опциональные личные данные + контакты. Drawer + Settings. **Нет wallet QR / номера карты / срока** (на HWEB тоже нет; п. плана **12**)
- **Навигация** — снизу **Calendar \| Markbook \| Periods \| Mail**. **Payments** в левом drawer **над Settings**. Студенческий / профиль тоже в drawer + Settings. Contacts + версия приложения — внизу Settings (п. **1c**). Макеты Figma могут ещё показывать 5 вкладок — в приложении IA: **4** снизу + Payments в drawer.
- **Shortcuts на рабочем столе** — долгий тап по иконке → **Календарь** / **Почта** / **Платежи** (п. **13**). Cold start открывает поверхность только при живой сессии; иначе логин (без пустого Home с мёртвым JWT). Shortcut карт не включён (п. 8).
- **Виджет на домашнем экране** — iOS WidgetKit + Android App Widget «Пары сегодня» **только из кэша календаря** (без JWT в виджете). Тап открывает Календарь (`neptunelte://shortcut/calendar`). Нет кэша → откройте приложение; устаревший день помечен (офлайн-снимок; без JWT refresh в процессе виджета).
- **Темы и языки** — Light / Dark; EN / HU встроены, RU / TR скачиваются с GitHub
- **Уведомления** — локальные (занятия, экзамены, платежи, периоды); без push-сервера автора
- **Сессия** — пока приложение открыто, проактивный `GetNewTokens` каждые **3 мин 30 с** (только foreground); опциональный **фоновый keep-alive** в Settings (default выкл; **45 мин** best-effort при вкл.); выход — **ручной logout** или **мёртвый refresh** (не фиксированные 10 мин wall-clock). Провал refresh → принудительный выход + повторный вход (логин сохраняется; **учебный кэш** — **1**; баннер «из кэша»). Opt-in **Запомнить пароль на этом устройстве** (default выкл) — pre-fill поля входа после истечения сессии **и** после **ручного Log out** при opt-in (**1.5.10**); **2FA вручную**. Без тихого portal re-auth. Logout → повторный вход в том же процессе (**1a**).
- **Профиль в drawer** — приветствие с полным именем из `UserInfo` + код Neptun; **фото профиля** из `userAvatar` / `GetUserAvatar` (base64 JPEG, локальный кэш; инициалы при отсутствии/ошибке); без training ID под именем; переключатель обучения при нескольких training; страница **студенческий / профиль** (заявка + флаги банка + опциональные личные данные — п. **12**, без QR)
- **Без собственного бэкенда** — устройство говорит с Neptun (+ опционально GitHub raw для языков/конфига)

---

## Как устроен вход (кратко)

1. Портальный логин на `https://neptun.elte.hu` (секреты — в защищённом хранилище устройства).
2. 2FA при необходимости (в UI — TOTP).
3. Bridge Student web / OuterLogin → JWT на назначенном `hallgatoN`.
4. Если Student web **full** — вход останавливается после 2FA с честным «полный / попробуйте позже» — **не** «неверный пароль».
5. REST для расписания, предметов, сообщений, платежей, периодов; ответы могут кэшироваться локально.

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
| Dev Blog (RU) | [`docs/Technical/DEV_BLOG.ru.md`](Technical/DEV_BLOG.ru.md) |
| Dev Blog (EN) | [`docs/Technical/DEV_BLOG.md`](Technical/DEV_BLOG.md) |
| План сессии hallgato | [`HALLGATO_SESSION_PLAN.ru.md`](Technical/HALLGATO_SESSION_PLAN.ru.md) · [EN](Technical/HALLGATO_SESSION_PLAN.md) |
| Карта кампуса (BIS FootPrint **1.8.3** / только IK) | План [`CAMPUS_MAP_PLAN.ru.md`](Technical/CAMPUS_MAP_PLAN.ru.md) · [EN](Technical/CAMPUS_MAP_PLAN.md) · пакет [`campus_map_package/`](Technical/campus_map_package/) · полигоны [`campus_map_research/bis/polygons/`](Technical/campus_map_research/bis/polygons/README.md). FootPrint BIS; hull underlay; граф для A→B; покрытие **2573/3112**; IK LD+LE. |
| Бэклог | Честность TECHNICAL + «В работе» в DEV_BLOG (нумерованные `IMPLEMENTATION_PLAN*` **удалены**) |
| UI-макеты (Figma) | [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups) — только Figma (не Flutter). Макеты могут ещё показывать **5** нижних вкладок; **в приложении IA** — **4** (Calendar \| Markbook \| Periods \| Mail) + Payments в drawer. Android = целевой polish; iOS = текущая оболочка + аддитивные поля. Владелец **Nanda** |
| Лицензия (канон) | [`docs/LICENSE`](LICENSE) |
| Короткий указатель в корне | [`README.md`](../README.md) |

Корневые `README.md` / `LICENSE` нужны GitHub; полный текст — в `docs/`.

---

## Legal / юридические документы

Политика конфиденциальности, условия и cookie / локальное хранение на трёх языках.

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
