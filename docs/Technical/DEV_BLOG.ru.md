# Neptun ELTE — Dev Blog

Короткий дневник разработки **Neptun ELTE** (владелец: **Nanda**).  
Время — **Europe/Budapest (UTC+2)**. Факты по репозиторию и живой работе — не маркетинговый changelog.

> 🇬🇧 [English](DEV_BLOG.md) · 📘 [Техническая](TECHNICAL.ru.md) · [Product README](../README.ru.md)

---

## 2026-09-09

**[2026-09-09, 23:06]**

- Базовая линия Android-релиза **1.0.5+18** ещё под брендом Neptun Mobile.
- До «только ELTE»: в дереве ещё список вузов и старые языковые пакеты.

---

## 2026-09-13 — iOS, языки, хаб ELTE

**[2026-09-13, 00:18]**

- Поднят проект **iOS** (`ios/`, CocoaPods, Automatic Signing / Team).
- Физический iPhone: **`flutter run --release`**, чтобы иконка появилась на домашнем экране (ограничение debug на iOS 14+).
- Bundle ID **`com.nanda070.neptunmobile`** (без `_` — иначе ломается signing); Android остаётся `com.nanda070.neptun_mobile.app`.
- Языки: встроенные **EN / HU** + пакеты **RU / TR** с GitHub.
- Удалены шуточные / неиспользуемые пакеты (Pirate, Chinese, German, Spanish, Romanian, Ukrainian, UAE и т.д.).

**[2026-09-13, 00:29]**

- Расширен путь логина / **2FA** для modern Neptun API (ввод кода после пароля).
- Первые правки входа на iOS; дальше — реальный портальный поток ELTE.

**[2026-09-13, 00:38 – 00:42]**

- Расширены developer / technical docs (EN + RU): запуск iOS, signing, честные оговорки.

**[2026-09-13, 01:45]**

- Продукт сужен до **только ELTE**.
- Хаб: одна кнопка института — без списка вузов и без произвольного URL.
- `universityNameUrlPairs.json` → одна запись: ELTE → **`https://neptun.elte.hu`**.
- Явно **не** путь Óbuda/BME **`/ujhallgato`**.

**[2026-09-13, 01:50]**

- Переименование display / docs: **Neptun ELTE** (целевой репо **Neptun-ELTE**).
- Каталог тем и строки языков под новое имя.
- Android label / iOS display name выровнены.

**[2026-09-13, 02:12]**

- Зафиксирован student-web bridge: после портала Student web попадает на **`hallgatoN.neptun.elte.hu`** (балансировка узлов `1…N`).
- **Не** хардкодить один `hallgato` — узел назначает портал (в live HAR: `hallgato3` / `ELTE_HW3`).

**[2026-09-13, 04:20]**

- Главная правка логина: **`POST https://neptun.elte.hu/api/Account/Authenticate` для ELTE мёртв** (пустой HTTP 400).
- Верный путь как на сайте: портал **Potlap** `Login` → **`Login2FA`** (TOTP) → **`ToNeptunHWeb`** → **`OuterLogin`** JWT на назначенном `hallgatoN`.
- Разделение **неверный пароль** vs **сервер занят** / перегрузка (больше не маскируется под bad password).
- Формат email OTP из HAR задокументирован как **`XXX-XXXXXX`** (префикс 3 цифры + 6); в UI приоритет у **Authenticator TOTP**.
- Устаревшая плашка «с 2FA войти нельзя» **удалена** — на ELTE 2FA обязательна, приложение принимает код.

---

## 2026-09-13 — полировка, UX, docs (та же ночь → утро)

**[2026-09-13, ~04:45]**

- Исправлен **чёрный экран после успешного 2FA**: сначала закрыть popup 2FA, затем `pushAndRemoveUntil(HomePage)`, чтобы отложенный `pop` не обнулил навигатор.
- Нумерация учебной недели: предпочитать **учебный / лекционный период** (`szorgalmi`, study period, …), а не окна **записи на предметы**, которые начинаются раньше и раздували номер недели (~36). Всё ещё итерация к осмысленным **неделям 1–2** в начале сентября.
- UX: сохраняются только темы **Light / Dark**; баг-репорт / контакты → **[nanda.is-a.dev](https://nanda.is-a.dev)**; при выходе остаётся **логин**, очищаются **пароль** / сессия + cookie jar портала.
- i18n хрома Payments / Contacts; заголовки прямо из API Neptun могут оставаться на венгерском.

**[2026-09-13, ~05:00]**

- Реструктуризация docs в `docs/`:
  - Legal: **`Legal-En/` · `Legal-Ru/` · `Legal-Hu/`** (Privacy, Terms, Cookies).
  - Technical → **`docs/Technical/`**; отдельный **`DEVELOPER.md` удалён** (iOS-шпаргалка — Technical §14).
  - Канон лицензии **LGPL-3.0-only** в `docs/LICENSE` (корневой `LICENSE` зеркалирует).
- Добавлен этот **Dev Blog** (EN + RU).

**[2026-09-13, ~05:15]**

- Баг календаря: modern `GetCalendarEvents` брал **следующий понедельник 23:59** как `endDate` → занятия следующего пн после ложного **~163 ч «szünet»** (и HU-хардкод UI перерыва). Исправлено: **конец воскресенья**, отсев вне окна, перерывы только в тот же день (5 мин–12 ч), локализация EN/HU/RU/TR.

**[2026-09-13, 05:14]**

- Языковые пакеты RU/TR: добавлены **39** ключей, которые были в EN/HU, но отсутствовали в JSON с GitHub (масштаб шрифта, полосы/фильтры/перерывы календаря, перевод почты, секции настроек, заголовки уведомлений, markbook/payment). Недостающие ключи раньше падали в **английский**.
- `Languages/LangExtentions/{Russian,Turkish}.json` bundled как Flutter **assets**; `loadBundledLanguagePacks` мержит в кэш/скачанные пакеты, чтобы устройство не зависело от устаревшего GitHub/cache до push.
- Хардкода английского в UI календаря для TR **не найдено** — заголовки уже через `AppStrings`; причина — устаревшие пакеты.
- Деплой на iPhone Nanda **пропущен** (активен другой `flutter run --release`).

**[2026-09-13, ~05:16]**

- **10-минутный wall-clock сессии:** `SessionGuard.startSessionWallClock()` при входе на `HomePage` → через 10 мин `forceExpiredLogout` (логин сохраняется, snackbar `auth_sessionExpired_PleaseSignIn`, экран входа). Отмена при ручном выходе; перезапуск при повторном логине. **Не** продлевается refresh JWT. Выравнивает UI-logout с короткоживущими access JWT Neptun (~10–15 мин) от **входа в сессию**, а не только от 401.

**[2026-09-13, ~05:20]**

- **Аватар в drawer работает:** в HAR фото уже есть в `/api/UserInfo` как `data.userAvatar.image` (base64 JPEG) и крупнее в `/api/General/GetUserAvatar?imageSizeType=Normal`. Кэш base64 в `DataCache`, drawer — `MemoryImage`, fallback на инициалы. Прежнее «в API нет фото» было ошибкой — пропустили вложенное поле.

**[2026-09-13, ~05:25]**

- **EN chrome деталей предмета:** диалоги тапа по занятию / задаче в календаре имели HU-хардкод (`Tárgykód`, `Típus`, `Tanár`, `Terem`, `Bezárás`, `Terem betöltése…`, Subject/Type/Result задачи). Переведено на `courseDetail_*` + `popup_case4_5_SubjectCode` (EN/HU/RU/TR). Плейсхолдеры приложения локализуются; **контент Neptun** (названия, Előadás/Gyakorlat, аудитории) может остаться на HU.

**[2026-09-13, ~05:30]**

- **Тап-расшифровка кодов аудиторий ELTE:** `LD-0-805` / `LD-0-805-01-11` переключают короткий код ↔ сводку (кампус–этаж–аудитория–**поток**–**группа**; отсутствующие хвосты не выдумываются). Префиксы LD/LE/LK. `DecodableRoomText` в списке, диалоге и popup. Ключи `roomCode_*` в HU/EN + RU/TR JSON.

**[2026-09-13, ~05:35]**

- Расширенный i18n-аудит: тела уведомлений занятий/экзаменов, подпись масштаба шрифта, ошибки почты, 2FA popup, Android updater, API fallback + DEMO — всё через `LanguagePack` (HU/EN + RU/TR JSON). UI декода кода аудитории сохранён.

**[2026-09-13, ~05:40]**

- Добиты остатки Language Pack аудита в `api_coms`: транспортный `ErrorMessage` (неверный URL/HTML, сеть), JSON истечения сессии через `auth_sessionExpired_PleaseSignIn`, превью письма «нажмите чтобы загрузить», пустой ответ Neptun / сетевая ошибка загрузки (`api_error_*`, `mail_preview_TapToLoadBody` HU/EN + RU/TR). Токены статуса оплаты для matching API (`aktív` / `teljesített`) оставлены как ключи протокола (не UI).

**[2026-09-13, ~08:58]**

- Написан приоритетный **план реализации** (только docs, без кода фич): [`IMPLEMENTATION_PLAN.ru.md`](IMPLEMENTATION_PLAN.ru.md) / [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md). Порядок: сессия+кэш → честная зачётка → календарь → поиск/unread почты → затем параллельно (ghost, сегодня/ZH/ICS export/гранулярность пар, платежи, карты, «Что изменилось», сравнение семестров). За HAR: academic progress, студенческий. Виджеты последними. Индекс из README + TECHNICAL.

**[2026-09-13, ~09:05]**

- План реализации: добавлен **п. 1a** (фундамент / сессия+кэш, до полировки UX п. 1) — после logout повторный вход в том же процессе может показать **ложные неверные данные**, пока приложение не убьют. Код уже чистит in-memory jar портала + `dataWipe`; что ещё проверить (device cookie, кэш training id, нет POST portal Logout, `_looksLikeInvalidCredentials` ловит `invalid` в HTML). Только docs; фикса в Dart нет.

**[2026-09-13, ~09:10]**

- План реализации: **убрана** запись на экзамен / курс (vizsgajelentkezés / tárgyjelentkezés) из бэклога. Не планируем; UI записи и HAR-гайд не возвращать. За HAR остаются academic progress + студенческий. Бывшие п. 13–15 перенумерованы в 12–14. Только docs; в Dart ничего не меняли.

**[2026-09-13, ~09:20]**

- Разобраны 8 пользовательских HAR (в git не копировали; секреты замазаны) в [`IMPLEMENTATION_PLAN.ru.md`](IMPLEMENTATION_PLAN.ru.md) §4.2 / EN-близнец. Известны имена полей **банка + профиля + заявки на студенческий (NEK/FIR)**. **Нет QR / номера / срока карты.** **Нет графа tanterv** (`taken courses.har` = `RegisteredCourses`; items `GetAverages` пустые). Extras почты (архив/исходящие/настройки); extras финансов (неоплаченные пустые, детали транзакции); официальный ICS/webcal URL календаря. XHR записи в `finances.har` — **видно, но не планируем**. Кликнуты не все кнопки; отсутствующие POST ожидаемы. Только docs; Dart не меняли.

**[2026-09-13, ~09:30]**

- Живой проход залогиненного Chrome HWEB (JS из Apple Events; HAR не копировали). Подтверждено: `/api/GetCurriculums` **404**; API Advancement; официальные *имена* средних на `RegistrySheet/GetStudentTrainingTermData`; `TakenSubjects/Terms`; на странице Student Card **нет QR**; `GetLinksForCalendarExport`. Жёсткий переход на registry-sheet **5002**, вернулись через Student web портала. Только docs; Dart не меняли.

**[2026-09-13, ~09:50]**

- Опубликованы **только Figma UI-макеты** (не код Flutter/Android/iOS): [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups). Страница **Android — polished target** = целевой polish; **iOS — current + polish** = сегодняшний TopNavigator + 5-icon BottomNavigator с аддитивными стрипами/подписями/поиском/баннером. Владелец **Nanda**. Ссылки в README + TECHNICAL. Только docs.

**[2026-09-13, ~10:00]**

- Решение продукта (только docs/план, **без Dart**): **Nav IA** — снизу **Calendar \| Markbook \| Mail**; **Payments** + **Periods** в левый drawer **над Settings**. В коде **по-прежнему 5 вкладок**; Figma может ещё показывать 5 — цель 3 + drawer (п. **1c**). **Сессия 1b:** фон ≥10 мин → на resume `forceExpiredLogout` — Flutter `Timer` замирает в suspend; timestamp + проверка на `AppLifecycleState.resumed`. Синхронизированы README / TECHNICAL / IOS_VS_ANDROID / IMPLEMENTATION_PLAN EN+RU. Владелец **Nanda**.

**[2026-09-13, ~10:10]**

- **Foundation slice как релиз приложения 1.1.0+19** (базовая линия GitHub была **1.0**; дальше багфиксы → **1.1.x**, крупные фичи → **1.2+**). Dart + docs: **1a** logout → повторный вход в том же процессе (portal Logout best-effort, wipe `devicecookie_*` + кэш training id, ужесточённый `_looksLikeInvalidCredentials` — HTML `is-invalid` ≠ «неверный пароль»). **1b** сохранённый `SESSION_StartedAtMs` + `WidgetsBindingObserver` на `HomePage` → на resume `forceExpiredLogout` если ≥10 мин вне приложения; иначе перезавести Timer на остаток. **1c** снизу Calendar \| Markbook \| Mail; Payments + Periods в drawer над Settings (индексы 3/4). Владелец **Nanda**.

**[2026-09-13, ~10:16]**

- Задокументирована политика версий EN+RU (TECHNICAL § Версионирование, строка в README, релиз-заметка в IMPLEMENTATION_PLAN). `pubspec` **1.1.0+19** (build +1 от **1.0.5+18**); зеркала iOS `MARKETING_VERSION` / Android fallback. Честно: GitHub «1.0» — утверждение о опубликованной базовой линии; старые checkout’ы могут ещё показывать **1.0.x**, пока этот bump не попадёт в дерево. Владелец **Nanda**.

**[2026-09-13, ~10:20]**

- **Nav IA пересмотрена (1c):** снизу **Calendar \| Markbook \| Periods \| Mail** (`maxBottomNavWidgets = 4`). **Payments** только в drawer над Settings. **Contacts** перенесены из drawer в Settings (внизу); версия приложения через `package_info_plus` под Contacts. Синхронизированы README / TECHNICAL / IMPLEMENTATION_PLAN / IOS_VS_ANDROID EN+RU. Сессия **1a**/**1b** без изменений. Владелец **Nanda**.

**[2026-09-13, ~10:45]**

- **Пункты фундамента 1–3 сделаны:** (1) `sessionWipeKeepCache` при logout/expiry — учебный кэш остаётся; все home-вкладки cache-first + баннер `cache_showingFromCache`. (2) `MarkbookMath` — átlag vs **/30**; кредиты семестра + накопленные сданные; пометка «счёт приложения». (3) Полосы календаря отсортированы; 48 ч = пары+экзамены; ZH/экзамены от сейчас; баннеры периодов только в полосе; пустые недели в кэше. Docs EN+RU + статус плана обновлены. Nav **1c** без отката. Владелец **Nanda**.

**[2026-09-13, ~15:00]**

- **Багфикс:** После верного TOTP переполнение **Student web** (ёмкость HWEB) давало голый `false` из `submitTwoFactorCode` → setup красил **«Invalid username or password!»**. Исправлено: мост возвращает `loginStudentWebFull` / `loginServerBusy`; snackbar `loginPage_setupPage_StudentWebFull` / busy; неверный TOTP — `loginPage_setupPage_2faInvalidCode` без красных полей пароля. Неверный пароль по-прежнему `loginInvalidCredentials`. Docs EN+RU. Владелец **Nanda**.

**[2026-09-13, ~15:05]**

- **UX:** После успеха TOTP — спиннер **«Подключение к студенческому вебу…»** и ретраи HWEB ~**7 с** (успех → сразу Home; провал → честный full/busy, не «неверный пароль»). Владелец **Nanda**.

**[2026-09-13, ~15:15]**

- **Политика версий пересмотрена:** больше не рассказывать пользователю историю через `+N` build. Маркетинг / Settings / docs = только **`1.x.y`**. Схема `1.<feature-line>.<patch>`; **2.0** = финальная / RC линия. Сейчас **`1.3.1`** (`pubspec` **1.3.1+1**): линия **3** = пункты плана **1–3**; патч **1** = auth/2FA/Student-web-full. Следующий крупный блок → **1.4.0**. Settings показывает `info.version` без `+build`. Синхронизированы TECHNICAL / README / IMPLEMENTATION_PLAN EN+RU + `.cursor/rules/versioning.mdc`. Владелец **Nanda**.

**[2026-09-13, ~16:00]**

- **iOS IPA через Actions:** добавлен `.github/workflows/ios-ipa.yml` — macOS unsigned release IPA (`--no-codesign`), артефакт + прикрепление к GitHub Release (напр. **v1.3.1**). Секретов Apple signing в репо пока нет; друзья ставят через **Sideloadly** + свой Apple ID. Docs EN+RU. Владелец **Nanda**.

**[2026-09-13, ~17:35]**

- **Багфикс — чёрный экран после 2FA:** навигация после логина через `lib/app_navigator.dart` (`navigateToHomeRoot` / `navigateToLoginRoot`, корневой `pushAndRemoveUntil`). Не даёт пустой навигатор при отложенном `pop` popup или `popUntil` единственного Home. Popup 2FA без Home blur. Logout по wall-clock при перезаходе **без изменений** (как задумано). Владелец **Nanda**.

**[2026-09-13, ~17:45]**

- **Релиз 1.3.2** (`pubspec` **1.3.2+1**): фикс чёрного экрана после 2FA + корневой navigator. GitHub Release **v1.3.2** + unsigned IPA через Actions. Владелец **Nanda**.

**[2026-09-14]**

- **Багфикс — «сессия истекла» сразу после 2FA:** устаревший `SESSION_StartedAtMs` или гонка resume / первого API 401 могли вызвать `forceExpiredLogout` на Home сразу после входа. `SessionGuard.prepareForLoginAttempt()` сбрасывает wall-clock в начале логина; `markParticipantSessionStarted()` сохраняет новый старт до `navigateToHomeRoot`; grace ~45 с после входа не форсирует logout, если access token ещё есть. Владелец **Nanda**.
- **Релиз 1.3.3** (`pubspec` **1.3.3+1**): фикс сессии после 2FA. GitHub Release **v1.3.3** + unsigned IPA через Actions. Владелец **Nanda**.
- **П. 4 — поиск почты + фильтр непрочитанных:** локальный поиск по загруженным страницам (тема / отправитель / превью тела) + чип unread; пагинация копит `mailEntries`; API остаётся `filterType=0` (честность HAR). Офлайн/кэш фильтрует локально; строка поиска в логи не пишется. Владелец **Nanda**.
- **Релиз 1.3.4** (`pubspec` **1.3.4+1**): п. плана **4**. GitHub Release **v1.3.4** + unsigned IPA через Actions. Владелец **Nanda**.
- **П. 8 — deep-link карт на LD/LE/LK:** после тап-расшифровки — **Открыть карту** (`roomCode_OpenMap`) → Apple/Google Maps с поиском корпуса (`ELTE Déli Tömb` / `Északi Tömb` / `Kémiai tömb`, 1117 Budapest). Неизвестный префикс — только текст. Без bump версии. Владелец **Nanda**.
- **П. 7 — честность платежей + антиспам:** `totalMoney` = оплаченные исходящие (`ammount < 0`) из последних 50 транзакций — шапка «Оплаченные взносы (последние 50)»; нотификации оплаты ≤ 1/день (ближайший неоплаченный). Без bump версии. Владелец **Nanda**.
- **П. 13 — app shortcuts:** Android static `shortcuts.xml` + iOS `UIApplicationShortcutItems` (Календарь / Почта / Платежи). Cold start через `Splitter` + `SessionGuard.isColdStartSessionUsable()` → `HomePage(initialView:)` или логин. Shortcut карт — для п. **8**. Без bump версии. Владелец **Nanda**.

---

## 2026-09-14 — студенческий: заявка / банк / профиль (п. 12)

**[2026-09-14]**

- **П. 12:** `StudentCardPage` (drawer + Settings) показывает HAR-честный **статус заявки**, банковские **флаги видимости** (владелец / банк / default / foreign / valid / OTP — **никогда** IBAN/SWIFT), опционально `GetGeneralUserData` + контакты. Кэш `STUDENT_CardCacheJson` для офлайн несекретных флагов + уже существующий кэш фото.
- **Честность:** **нет QR**, нет выдуманного номера / срока (HWEB `/administrations/student-card` — только заявка). Без bump версии. Владелец **Nanda**.

---

## В работе / запланировано (честно)

**[ongoing]**

- **Принудительный logout сессии** при провале refresh / silent re-auth — **в коде** (`SessionGuard.forceExpiredLogout`); логин + учебный кэш сохраняются (**1**). **1a** / **1b** / **1** / **2** / **3** / **4** / **7** / **8** / **12** / **13** сделаны; дальше бэклог с п. **5** (параллельно: **5–6, 9–11**, **14**).
- **Nav IA (1c):** **сделано** — 4 вкладки снизу + Payments в drawer; Contacts + версия в Settings.
- **Переводчик сообщений** (HU → EN/RU для тел писем) — helper + действия в popup есть; считать **in progress**, пока offline / failure не проверены тщательно.
- **Крупные фичи:** студенческий **п. 12 сделан** как заявка/банк/профиль (по-прежнему **нет** QR/wallet). Меню Tanterv **нет**; Advancement + `RegistrySheet/GetStudentTrainingTermData` дают *схему* официальных средних (в этом семестре значения пустые). Запись на экзамен / курс — **не сделана, не планируем**.
- Полный UI email OTP (`RequestEmailCode` / `CodePrefix`) — известен по HAR; **не** основной путь (сначала TOTP).

---

*Владелец / разработчик: **Nanda**. Полное юридическое имя — только в Legal.*
