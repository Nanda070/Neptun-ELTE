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

- Написан приоритетный **план реализации** (только docs, без кода фич): former IMPLEMENTATION_PLAN.ru (deleted) / former IMPLEMENTATION_PLAN (deleted). Порядок: сессия+кэш → честная зачётка → календарь → поиск/unread почты → затем параллельно (ghost, сегодня/ZH/ICS export/гранулярность пар, платежи, карты, «Что изменилось», сравнение семестров). За HAR: academic progress, студенческий. Виджеты последними. Индекс из README + TECHNICAL.

**[2026-09-13, ~09:05]**

- План реализации: добавлен **п. 1a** (фундамент / сессия+кэш, до полировки UX п. 1) — после logout повторный вход в том же процессе может показать **ложные неверные данные**, пока приложение не убьют. Код уже чистит in-memory jar портала + `dataWipe`; что ещё проверить (device cookie, кэш training id, нет POST portal Logout, `_looksLikeInvalidCredentials` ловит `invalid` в HTML). Только docs; фикса в Dart нет.

**[2026-09-13, ~09:10]**

- План реализации: **убрана** запись на экзамен / курс (vizsgajelentkezés / tárgyjelentkezés) из бэклога. Не планируем; UI записи и HAR-гайд не возвращать. За HAR остаются academic progress + студенческий. Бывшие п. 13–15 перенумерованы в 12–14. Только docs; в Dart ничего не меняли.

**[2026-09-13, ~09:20]**

- Разобраны 8 пользовательских HAR (в git не копировали; секреты замазаны) в former IMPLEMENTATION_PLAN.ru (deleted) §4.2 / EN-близнец. Известны имена полей **банка + профиля + заявки на студенческий (NEK/FIR)**. **Нет QR / номера / срока карты.** **Нет графа tanterv** (`taken courses.har` = `RegisteredCourses`; items `GetAverages` пустые). Extras почты (архив/исходящие/настройки); extras финансов (неоплаченные пустые, детали транзакции); официальный ICS/webcal URL календаря. XHR записи в `finances.har` — **видно, но не планируем**. Кликнуты не все кнопки; отсутствующие POST ожидаемы. Только docs; Dart не меняли.

**[2026-09-13, ~09:30]**

- Живой проход залогиненного Chrome HWEB (JS из Apple Events; HAR не копировали). Подтверждено: `/api/GetCurriculums` **404**; API Advancement; официальные *имена* средних на `RegistrySheet/GetStudentTrainingTermData`; `TakenSubjects/Terms`; на странице Student Card **нет QR**; `GetLinksForCalendarExport`. Жёсткий переход на registry-sheet **5002**, вернулись через Student web портала. Только docs; Dart не меняли.

**[2026-09-13, ~09:50]**

- Опубликованы **только Figma UI-макеты** (не код Flutter/Android/iOS): [Neptun ELTE — UI Mockups](https://www.figma.com/design/IXXxEJWpswZW19IR05nDQ2/Neptun-ELTE-%E2%80%94-UI-Mockups). Страница **Android — polished target** = целевой polish; **iOS — current + polish** = сегодняшний TopNavigator + 5-icon BottomNavigator с аддитивными стрипами/подписями/поиском/баннером. Владелец **Nanda**. Ссылки в README + TECHNICAL. Только docs.

**[2026-09-13, ~10:00]**

- Решение продукта (только docs/план, **без Dart**): **Nav IA** — снизу **Calendar \| Markbook \| Mail**; **Payments** + **Periods** в левый drawer **над Settings**. В коде **по-прежнему 5 вкладок**; Figma может ещё показывать 5 — цель 3 + drawer (п. **1c**). **Сессия 1b:** фон ≥10 мин → на resume `forceExpiredLogout` — Flutter `Timer` замирает в suspend; timestamp + проверка на `AppLifecycleState.resumed`. Синхронизированы README / TECHNICAL / IOS_VS_ANDROID / former IMPLEMENTATION_PLAN EN+RU (deleted). Владелец **Nanda**.

**[2026-09-13, ~10:10]**

- **Foundation slice как релиз приложения 1.1.0+19** (базовая линия GitHub была **1.0**; дальше багфиксы → **1.1.x**, крупные фичи → **1.2+**). Dart + docs: **1a** logout → повторный вход в том же процессе (portal Logout best-effort, wipe `devicecookie_*` + кэш training id, ужесточённый `_looksLikeInvalidCredentials` — HTML `is-invalid` ≠ «неверный пароль»). **1b** сохранённый `SESSION_StartedAtMs` + `WidgetsBindingObserver` на `HomePage` → на resume `forceExpiredLogout` если ≥10 мин вне приложения; иначе перезавести Timer на остаток. **1c** снизу Calendar \| Markbook \| Mail; Payments + Periods в drawer над Settings (индексы 3/4). Владелец **Nanda**.

**[2026-09-13, ~10:16]**

- Задокументирована политика версий EN+RU (TECHNICAL § Версионирование, строка в README, релиз-заметка в former IMPLEMENTATION_PLAN — файл позже удалён). `pubspec` **1.1.0+19** (build +1 от **1.0.5+18**); зеркала iOS `MARKETING_VERSION` / Android fallback. Честно: GitHub «1.0» — утверждение о опубликованной базовой линии; старые checkout’ы могут ещё показывать **1.0.x**, пока этот bump не попадёт в дерево. Владелец **Nanda**.

**[2026-09-13, ~10:20]**

- **Nav IA пересмотрена (1c):** снизу **Calendar \| Markbook \| Periods \| Mail** (`maxBottomNavWidgets = 4`). **Payments** только в drawer над Settings. **Contacts** перенесены из drawer в Settings (внизу); версия приложения через `package_info_plus` под Contacts. Синхронизированы README / TECHNICAL / former IMPLEMENTATION_PLAN (deleted) / IOS_VS_ANDROID EN+RU. Сессия **1a**/**1b** без изменений. Владелец **Nanda**.

**[2026-09-13, ~10:45]**

- **Пункты фундамента 1–3 сделаны:** (1) `sessionWipeKeepCache` при logout/expiry — учебный кэш остаётся; все home-вкладки cache-first + баннер `cache_showingFromCache`. (2) `MarkbookMath` — átlag vs **/30**; кредиты семестра + накопленные сданные; пометка «счёт приложения». (3) Полосы календаря отсортированы; 48 ч = пары+экзамены; ZH/экзамены от сейчас; баннеры периодов только в полосе; пустые недели в кэше. Docs EN+RU + статус плана обновлены. Nav **1c** без отката. Владелец **Nanda**.

**[2026-09-13, ~15:00]**

- **Багфикс:** После верного TOTP переполнение **Student web** (ёмкость HWEB) давало голый `false` из `submitTwoFactorCode` → setup красил **«Invalid username or password!»**. Исправлено: мост возвращает `loginStudentWebFull` / `loginServerBusy`; snackbar `loginPage_setupPage_StudentWebFull` / busy; неверный TOTP — `loginPage_setupPage_2faInvalidCode` без красных полей пароля. Неверный пароль по-прежнему `loginInvalidCredentials`. Docs EN+RU. Владелец **Nanda**.

**[2026-09-13, ~15:05]**

- **UX:** После успеха TOTP — спиннер **«Подключение к студенческому вебу…»** и ретраи HWEB ~**7 с** (успех → сразу Home; провал → честный full/busy, не «неверный пароль»). Владелец **Nanda**.

**[2026-09-13, ~15:15]**

- **Политика версий пересмотрена:** больше не рассказывать пользователю историю через `+N` build. Маркетинг / Settings / docs = только **`1.x.y`**. Схема `1.<feature-line>.<patch>`; **2.0** = финальная / RC линия. Сейчас **`1.3.1`** (`pubspec` **1.3.1+1**): линия **3** = пункты плана **1–3**; патч **1** = auth/2FA/Student-web-full. Следующий крупный блок → **1.4.0**. Settings показывает `info.version` без `+build`. Синхронизированы TECHNICAL / README / former IMPLEMENTATION_PLAN EN+RU (deleted) + `.cursor/rules/versioning.mdc`. Владелец **Nanda**.

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
- **П. 5 — ghost / what-if:** в popup (mode 0) живые átlag + /30 при выборе 1–5; опциональная цель átlag → «нужна ≥ N» той же формулой `MarkbookMath.weightedAvg` / `index30`. Сброс ghost. Версию не поднимали. Владелец **Nanda**.

---

- **П. 6 — полировка календаря:** сводка «сегодня» в шапке; полоса ZH/дедлайны; ICS **export** share из `calendarEntries`; гранулярность нотификаций пар 10/5/0 мин в Settings. Без bump версии. Владелец **Nanda**.
- **П. 9 — «Что изменилось»:** после refresh снимок `messageId` писем + троек оценок; drawer + полоса календаря показывают счётчики новых писем / смен оценок; первый запуск без баннера. Без bump версии. Владелец **Nanda**.

---

## 2026-09-14 — студенческий: заявка / банк / профиль (п. 12)

**[2026-09-14]**

- **П. 12:** `StudentCardPage` (drawer + Settings) показывает HAR-честный **статус заявки**, банковские **флаги видимости** (владелец / банк / default / foreign / valid / OTP — **никогда** IBAN/SWIFT), опционально `GetGeneralUserData` + контакты. Кэш `STUDENT_CardCacheJson` для офлайн несекретных флагов + уже существующий кэш фото.
- **Честность:** **нет QR**, нет выдуманного номера / срока (HWEB `/administrations/student-card` — только заявка). Без bump версии. Владелец **Nanda**.
- **Релиз 1.4.0** (`pubspec` **1.4.0+1**): feature-line **4** — пункты плана **5** (ghost what-if), **6** (сегодня/ZH/ICS export/гранулярность пар), **7** (честность платежей + ≤1/день), **8** (deep-link карт), **9** («Что изменилось»), **12** (студенческий заявка/банк/профиль — **без QR**), **13** (home shortcuts Календарь/Почта/Платежи). GitHub Release **v1.4.0** + unsigned IPA через Actions. Владелец **Nanda**.

---

## 2026-09-14 — сравнение семестров, MVP виджетов, снятие п. 11 → 1.5.0

**[2026-09-14, ~14:30]**

- **П. 10 — сравнение семестров:** `MarkbookRequest.getSemesterComparison` / `TermComparisonStat` (сданные кредиты, átlag, **/30** той же `MarkbookMath.fromCompleted`, что у шапки зачётки). Cache-first `TakenSubjects` (`CachedMarkbookTerm_*`); недостающие термы только при живой сессии; потолок ~8 (сначала новые); в demo — два заготовленных терма. Карточки side-by-side в зачётке + i18n `markbook_semesterCompare_*` (HU/EN + RU/TR). Плоская история «оценки из других семестров» остаётся. Это **не** tanterv / % к диплому. Владелец **Nanda**.

**[2026-09-14, ~14:35]**

- **П. 11 убран (Academic Progress / tanterv):** полностью снят с плана реализации (таблицы приоритетов EN+RU + §11). В HAR сент. 2026 нет графа tanterv; на живом HWEB **нет меню Tanterv** (`GetCurriculums` **404**; шаблоны Advancement / `creditprogress` в этом семестре пустые). **Не** делаем фейковый progress bar из кредитов текущего семестра. Остатки curriculum — только honesty-заметки, не бэклог. Владелец **Nanda**.

**[2026-09-14, ~14:40]**

- **П. 14 — виджеты на домашнем экране (честный MVP):** расширение **iOS WidgetKit** `ios/TodayClassesWidget/` — пары **на сегодня** только из кэша календаря через `lib/widget_bridge.dart` → App Group `group.com.nanda070.neptunmobile` (title / start / end / location). Синхронизация из путей refresh календаря. В процессе виджета **нет JWT**, паролей и токенов. Нет кэша → «Open Neptun ELTE»; stale помечен; пустой день → «No classes today». Тап → `neptunelte://shortcut/calendar`. Согласовано с 10-минутной сессией (снимок офлайн). **Android Glance** отложен — в docs честно. Владелец **Nanda**.

**[2026-09-14]**

- **Релиз 1.5.0** (`pubspec` **1.5.0+1**): feature-line **5** — пункты **10** (сравнение семестров) + **14** (iOS WidgetKit MVP; Android-виджетов ещё нет). П. **11** снят (не шиппился). Студенческий по-прежнему только заявка/банк/профиль (**без QR** — как в **1.4.0**). GitHub Release **v1.5.0** + unsigned IPA через Actions. Владелец **Nanda**.

---

## 2026-09-14 — синхронизация docs после 1.5.0 (plan-файлы удалены)

**[2026-09-14, docs]**

- Полное обновление docs под отгруженный **1.5.0**: убраны живые ссылки на удалённые `IMPLEMENTATION_PLAN*` (бэклог = честность TECHNICAL + «В работе» DEV_BLOG); исправлены устаревшие «нет iOS CI» / «нет тестов» (`ios-ipa.yml` unsigned IPA; `test/elte_room_code_test.dart` + placeholder `widget_test.dart`); TOC/якоря вкладок; строки версий (feature-line **5**, п. **11** снят, **2.0.0** = финал); студенческий заявка/банк/профиль **без QR**; iOS WidgetKit MVP / Android Glance отложен; переводчик почты всё ещё «проверить offline/failure»; честность Student web full + 10-мин сессия + 4 вкладки. Правила Cursor `keep-docs-current` / `versioning` больше не требуют IMPLEMENTATION_PLAN. Владелец **Nanda**. Только docs; версию приложения не поднимали.

**[2026-09-14, ~20:56]**

- Календарь: убрана полоса **«Следующие 48 часов»** (список пар+экзаменов над вкладками недели). Оставлены сводка «сегодня», полоса ZH/дедлайны, баннеры периодов, неделя, ICS export, What’s Changed. Удалён неиспользуемый `calendar_next48h_Header` (EN/HU + RU/TR). Docs EN+RU. Владелец **Nanda**.

---

## 2026-09-14 — релиз 1.5.1 (полоса «Следующие 48 часов»)

**[2026-09-14, ~21:11]**

- **Релиз 1.5.1** (`pubspec` **1.5.1+1**): патч пользовательского календаря — отгрузка снятия полосы **«Следующие 48 часов»** из **72b5aea**. Других фич в этом срезе нет.
- **Политика сессии без изменений:** по-прежнему **10 минут** + существующий `SessionGuard` / auto-login — **без** правок SessionGuard или idle-timeout в этом релизе.
- GitHub Release **v1.5.1** + unsigned IPA через Actions. Владелец **Nanda**.

---

## 2026-09-15 — релиз 1.5.2 (паритет Android)

**[2026-09-15]**

- **Паритет Android с iOS (поверхность ~1.5.1):** общие Flutter-фичи уже совпадали (auth portal+2FA+OuterLogin+JWT, shortcuts, maps, поиск почты, сравнение семестров, студенческий, календарь без «Следующие 48ч»). **Отдельных** Android-блокеров auth не найдено (тот же Dart `HttpClient` / portal; нет cleartext / WebView-гейта).
- **Android App Widget MVP** (`TodayClassesWidgetProvider`): пары сегодня из кэша календаря через `WidgetBridge` → SharedPreferences JSON — **без JWT**. Тап → `neptunelte://shortcut/calendar`. Deep-link в манифесте + `<queries>` maps/mailto. RemoteViews (не Glance Compose) — та же честность, что iOS WidgetKit.
- Release APK: `flutter build apk --release`; без `key.properties` — fallback на debug keystore. GitHub Release **v1.5.2** с APK (+ unsigned IPA через Actions).
- **Политика сессии без изменений:** по-прежнему **10 минут** + существующий `SessionGuard` — не трогали.
- **Релиз 1.5.2** (`pubspec` **1.5.2+1**). Владелец **Nanda**.

### 2026-09-15 — белый экран OTP на Android (всё ещё 1.5.2)

**[2026-09-15]**

- **Баг (только Android):** после пароля шаг OTP/2FA давал **белый экран** (на iOS TOTP UI был в порядке). Причина: 2FA шёл через прозрачный popup mode 9 (`opaque: false`) после async `PackageInfo` + **`Language.getAllLanguages()`** (HTTP на GitHub). На Android задержка / фон окна Activity оставляли пустой белый экран без поля кода.
- **Исправление:** непрозрачный полноэкранный `TwoFactorCodePage` через корневой `appNavigatorKey` (`lib/Pages/two_factor_page.dart`); открытие popup больше не ждёт HTTP списка языков. Политика сессии **без изменений** (**10 мин**). APK перезалит в GitHub Release **v1.5.2** (`--clobber`). Владелец **Nanda**.

---


## 2026-09-15 — политика ship: новый тег для Android updater

**[2026-09-15]**

- **Политика (только docs/rules, без бампа приложения):** с этого момента каждый **отгруженный Android APK / GitHub Release** должен иметь **новую маркетинговую `1.x.y`** и **новый** git-тег `v1.x.y`. Перезаливка APK на тот же тег (clobber) **не** включает автообновление в приложении (`AppUpdater` требует, чтобы `tag_name` был строго новее установленного `versionName`). Cursor-правило: `.cursor/rules/android-github-release-tags.mdc`. Чистые docs/chore коммиты без APK можно не тегировать. Владелец **Nanda**.

---

## 2026-09-15 — релиз 1.5.3 (новая иконка)

**[2026-09-15]**

- **Новый брендинг launcher:** квадратный master (`assets/app_icon.png`) — книга + circuit **N** (+ герб) из обновлённого логотипа; Android adaptive foreground + белый фон; полный набор iOS `AppIcon` через `flutter_launcher_icons`. Splash / branding `assets/neptun2_logo.png` обновлён из того же источника (уже использовался в `flutter_native_splash`).
- Исходник в `assets/branding/`. Политика сессии **без изменений** (по-прежнему **10 мин** / `SessionGuard` не трогали).
- **Заметка:** фикс белого экрана OTP на Android раньше ушёл как перезаливка APK **1.5.2** (`--clobber` на **v1.5.2**); тег **1.5.3** нужен, чтобы sideload-пользователи получили обновление через in-app GitHub updater (новый `tag_name` > установленный `versionName`).
- **Релиз 1.5.3** (`pubspec` **1.5.3+1**). GitHub Release **v1.5.3** + APK (+ unsigned IPA через Actions). Владелец **Nanda**.

---

## 2026-09-15 — релиз 1.5.4 (wall-clock сессии + emoji)

**[2026-09-15]**

- **Баг — Android logout через 10 мин:** `SessionGuard.startSessionWallClock()` сбрасывал stamp при каждом входе на Home и гонял prefs (`cancel` писал `SESSION_StartedAtMs=0` vs новый старт). Длинные one-shot `Timer` на Android ненадёжны. **Фикс:** продолжать существующий stamp в окне; generation-guard на prefs; тикер **15 с** + lifecycle re-check на `resumed`/`inactive`. Политика по-прежнему **10 мин** wall-clock (не idle). Фон: если ОС убила процесс — expiry на следующем cold start/resume по сохранённому stamp.
- **Баг — двойной emoji в Bug report:** `EmojiRichText` / tint `TextStyle.color` на Noto Color Emoji рисовал ghost-монохром под настоящим emoji (`🐞 Bug report`). **Фикс:** emoji-spans без tint в `EmojiRichText`; drawer Bug report / Settings / Logout через `EmojiRichText`.
- **Релиз 1.5.4** (`pubspec` **1.5.4+1**). GitHub Release **v1.5.4** + APK (+ unsigned IPA через Actions). Владелец **Nanda**.

---

## 2026-09-15 — релиз 1.5.5 (drawer icons + splash)

**[2026-09-15]**

- **Баг — двойные символы в drawer:** Settings / Bug report / Logout имели Material leading icon плюс emoji в переводе. Фикс: `stripLeadingEmoji` + обычный `Text` рядом с Material icons.
- **Баг — launcher-иконка при входе в приложение:** `flutter_native_splash` всё ещё использовал обновлённый logo/icon asset как splash image. Splash теперь color-only; Android 12 использует solid tile, поэтому launcher-иконка остаётся только launcher-иконкой. Launcher AppIcon / adaptive icons без изменений.
- **Релиз 1.5.5** (`pubspec` **1.5.5+1**). GitHub Release **v1.5.5** + APK (+ unsigned IPA через Actions, если доступно). Владелец **Nanda**.

---

## 2026-09-16 — docs: честность session / API

**[2026-09-16]**

- **TECHNICAL EN+RU сверены с кодом** (без правок приложения, без bump `1.x.y`, без тега/APK): после логина ELTE student-data REST — **GET + Bearer JWT** на назначенном `hallgatoN` (cookie портала не на этих GET); **POST** = портал Login / Login2FA / OuterLogin / `GetNewTokens` / mark-read; **нет PUT/DELETE**; `trySilentReauth()` для ELTE false; SessionGuard **10 мин wall-clock от старта сессии** (не idle, не зависит от refresh JWT; `exp` не парсится; ~10–15 мин access — наблюдение); retry 401 только на GET; helper email OTP в коде, UI не вызывает; нет Workmanager / background_fetch. Владелец **Nanda**.

---

## 2026-09-16 — docs: план поддержки сессии hallgato

**[2026-09-16]**

- Добавлен только дизайн **HALLGATO_SESSION_PLAN** EN+RU (`docs/Technical/`) — проактивный `GetNewTokens` каждые 3–4 мин на foreground, запланированное снятие 10-мин wall-clock `SessionGuard`; **без правок кода**, без bump версии / тега / APK. Указатель в TECHNICAL EN+RU в секции сессии. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.5.6 (hallgato session v1 core)

**[2026-09-16]**

- **HALLGATO_SESSION_PLAN v1 core:** снят клиентский **10-минутный** wall-clock `SessionGuard`; cold start без stamp; выход — ручной logout или мёртвый refresh.
- **Foreground JWT maintenance:** таймер **3 мин 30 с** в `resumed` → `GetNewTokens`; пауза в фоне; общий `_isRefreshingToken` с 401 GET; grace ~45 с без изменений.
- **Почта + календарь (тот же тег):** битый кэш почты больше не рисует epoch/`ERROR` на cold Mail (`_cachedMailEntryValid`); polish заголовка education week и диапазона дат.
- **Не в 1.5.6:** фоновый keep-alive, сохранение пароля, portal/HWEB — **1.5.7** или только план.
- **Релиз 1.5.6** (`pubspec` **1.5.6+1**). GitHub Release **v1.5.6** + APK + unsigned IPA (`Neptun-ELTE-1.5.6-unsigned.ipa`). Владелец **Nanda**.

---

## 2026-09-16 — plan: mail + calendar bugs

**[2026-09-16, 08:45]**

- Расширены [HALLGATO_SESSION_PLAN.md](HALLGATO_SESSION_PLAN.md) + RU-пара: **запланированные багфиксы** (epoch/`ERROR` на Mail; layout/формат недели календаря). **Отгружено в 1.5.6** (тот же тег, что session v1); план EN+RU синхронизирован 16 сен 2026. Владелец **Nanda**.

---

## 2026-09-16 — plan: опциональный фон, portal, пароль

**[2026-09-16]**

- Расширены **HALLGATO_SESSION_PLAN** EN+RU: опциональный **фоновый keep-alive** в Настройках (WorkManager / BGTask, default выкл, щадящий режим батареи); **активность portal/HWEB** как не доказанное исследование с низким приоритетом; **opt-in сохранение пароля** (`neptun_password`, 2FA по-прежнему вручную). Чеклист шаги 11–16. Только docs; без Dart / SessionGuard / bump версии. Владелец **Nanda**.

---

## 2026-09-16 — Настройки: opt-in сохранение пароля

**[2026-09-16]**

- **Запомнить пароль на этом устройстве** (`SETTING_RememberPasswordOnDevice`, default выкл) в Настройках → Működés; строки EN/HU/RU. `sessionWipeKeepCache(wipePassword:)` + матрица `SessionGuard`: ручной logout всегда стирает пароль; `forceExpiredLogout` сохраняет `neptun_password` при opt-in; pre-fill входа без auto-2FA. TECHNICAL + HALLGATO EN+RU. Без bump маркетинговой версии (1.5.6 — Agent #3). Владелец **Nanda**.

---

## 2026-09-16 — Настройки: опциональный фоновый hallgato keep-alive

**[2026-09-16]**

- **Поддерживать сессию в фоне** (`SETTING_BackgroundHallgatoKeepAlive`, default **выкл**): Android `workmanager` **15 мин**; iOS `background_fetch` (система **15+ мин**). `HallgatoBackgroundKeepAlive` + `runBackgroundTokenMaintenance()` — тот же `GetNewTokens` и mutex refresh; headless **401/403** без UI до foreground. Выкл / logout → отмена задач. EN/HU/RU; TECHNICAL + HALLGATO EN+RU. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.5.10 (надёжность session keep-alive)

**[2026-09-16]**

- **Релиз 1.5.10** (`pubspec` **1.5.10+1**): три фикса сессии после **1.5.8/1.5.9**. (1) Фоновый keep-alive: снят `requiresDeviceIdle` (почти блокировал все запуски); сеть + battery-not-low + период **45 мин** + Android initial delay **15 мин**; re-arm в фоне; `WAKE_LOCK`. (2) На `resumed`: **сразу** `GetNewTokens`, затем refresh календаря+почты (не ждать первый тик 3м30); auth failure → `forceExpiredLogout`. (3) Remember-password ВКЛ сохраняет `neptun_password` и при **ручном** Log out (JWT/HasLogin всё равно стираются). Docs EN+RU. GitHub Release **v1.5.10** + APK + unsigned IPA. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.5.9 (щадящий для батареи фоновый keep-alive)

**[2026-09-16]**

- **Релиз 1.5.9** (`pubspec` **1.5.9+1**): опциональный фоновый hallgato keep-alive меньше жрёт батарею — Android WorkManager **45 мин** (было 15) + сеть + battery-not-low + device-idle (без обязательной зарядки); iOS Background Fetch минимум **45 мин**; отмена OS-задач в `resumed`; skip фона, если последний успешный `GetNewTokens` был в течение **25 мин**. Toggle по-прежнему default **выкл**; без регистрации без login. GitHub Release **v1.5.9** + APK + unsigned IPA. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.5.8 (навигатор недели календаря + диапазон дат)

**[2026-09-16]**

- **Релиз 1.5.8** (`pubspec` **1.5.8+1**): заголовок и подпись учебной недели — одна карточка (`WeekoffseterElementWidget`); EN диапазон в одном месяце — `${to.day}` (было `$to.day` → `DateTime.toString()` + `.day`). `calendarWeekDateRange` — только дата. GitHub Release **v1.5.8** + APK + unsigned IPA. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.5.7 (фоновый keep-alive + запомнить пароль)

**[2026-09-16]**

- **Релиз 1.5.7** (`pubspec` **1.5.7+1**): опциональный фоновый hallgato JWT keep-alive + **Запомнить пароль на этом устройстве** (оба default off). Dart пароля кратко был на `main`, **откачен в 1.5.6**; **1.5.7** восстанавливает toggle + `sessionWipeKeepCache(wipePassword:)` + матрицу `SessionGuard` (ручной logout всегда стирает; expiry/cold-start сохраняют при opt-in; pre-fill; без auto-2FA). Logout отменяет фоновые задачи через `SessionGuard.registerAuthWipedHook`. GitHub Release **v1.5.7** + APK + unsigned IPA (`Neptun-ELTE-1.5.7-unsigned.ipa`). Владелец **Nanda**.

---

## 2026-09-16 — docs: удаление матрицы IOS_VS_ANDROID

**[2026-09-16, 08:15]**

- Удалены `docs/Technical/IOS_VS_ANDROID.md` + `.ru.md` после функционального паритета Android APK — отдельная матрица платформ больше не нужна.
- Кросс-ссылки убраны из README / TECHNICAL EN+RU; краткие platform-only bullets (updater / signing / CI / haptics / toast / ID) перенесены в TECHNICAL §14–15.
- `.cursor/rules/keep-docs-current.mdc` больше не требует `IOS_VS_ANDROID*` в обязательном списке. Только docs; без bump версии / тега / APK. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.7.2 (строки «только IK» + docs)

**[2026-09-16]**

- **Релиз 1.7.2** (`pubspec` **1.7.2+1**): патч линии **7**. Чистые лейблы комнат (offset, zoom, tap — без sticker bomb); этаж-зависимые коридоры; убран tech honesty banner и «(for now)» / «2D schematic»; короткий чип IK; docs без ship-blocker pending. GitHub Release **v1.7.2**. Владелец **Nanda**.

## 2026-09-16 — релиз 1.7.1 (mall-style schematic polygons)

**[2026-09-16, ~20:15]**

- **Релиз 1.7.1** (`pubspec` **1.7.1+1**): доводит Strategy D до mall-style — оболочка здания + дворы + заполненные ленты коридоров из `schematic_ld.json` / `schematic_le.json` (форма здания не из «свечения» рёбер графа). Граф — routing/пины/маршрут. JPG только debug. Тег **v1.7.1**. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.7.0 (Strategy D schematic UX карты)

**[2026-09-16, ~20:00]**

- **Релиз 1.7.0** (`pubspec` **1.7.0+1**): feature-line **7** — **Strategy D product UX**. Карта кампуса по умолчанию — **2D-схема из графа** (`CampusSchematicPainter`: полосы коридоров, пины/лейблы комнат, маркеры лифт/лестница, Chaikin-маршрут) — **не** фото плана этажа. JPG-подложка только debug (выкл.). Centerline-граф LE тоже отгружен. Pre-login Map / этажи / поиск / A→B сохранены. Honesty: schematic MVP из campus-графа; официальный BIS artwork ещё pending; `routing.route` всё ещё **null**; репо **private**. Docs EN+RU + CAMPUS_MAP_PLAN синхронизированы. GitHub Release **v1.7.0**. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.6.1 (LD centerline-пути + стратегия D + private repo)

**[2026-09-16, ~19:30]**

- **Релиз 1.6.1** (`pubspec` **1.6.1+1**): владелец отверг UX Phase B MVP (фото этажа + кривые hub-spoke пути). **Пути:** граф LD пересобран — door mouths цепочкой вдоль осевых коридоров (не V через hub); убраны диагональные courtyard-hops; Flutter path painter сглаживает Chaikin. LE пока hub-heuristic (далее). **Basemap стратегия D:** JPG sarkozigergo не финальная карта продукта — искать официальную/разрешённую 2D-схему (ELTE IIG/BIS); фото-пакет transitional; permission pending. Геометрия BIS `routing.route` всё ещё **null**. **Репо:** `Nanda070/Neptun-ELTE` сделан **private** (публичный sideload `AppUpdater` может не работать для не-collaborators). Docs EN+RU синхронизированы. GitHub Release **v1.6.1**. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.6.0 (карта кампуса фаза B MVP)

**[2026-09-16, ~19:15]**

- **Релиз 1.6.0** (`pubspec` **1.6.0+1**): feature-line **6** — **фаза B** indoor-карты кампуса MVP. Кнопка **Карта кампуса** на login-хабе (без JWT), пункт в drawer, корпуса LD/LE, этажи + pan/zoom, поиск joins/aliases, A→B Dijkstra, honesty-баннер (приблизительный граф; basemap permission pending). Пакет в `assets/campus_map/`. Внешний Open map для LD/LE/LK сохранён. GitHub Release **v1.6.0**. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.5.12 (внешние Maps на iOS)

**[2026-09-16, ~19:00]**

- **Релиз 1.5.12** (`pubspec` **1.5.12+1**): фикс внешних Maps для LD/LE/LK на **iOS** — основной `maps:?q=…` (https://maps.apple.com часто открывал Safari), fallback https Apple + Google, Info.plist `maps` + `comgooglemaps`, **Открыть карту** всегда под кодом аудитории (не только после decode), `TextButton` чтобы тап строки календаря не перехватывал. По-прежнему **не** in-app indoor A→B (фаза B отложена). GitHub Release **v1.5.12** + APK + установка на iPhone. Владелец **Nanda**.

---

## 2026-09-16 — релиз 1.5.11 (фаза A карты кампуса + ship)

**[2026-09-16]**

- **Релиз 1.5.11** (`pubspec` **1.5.11+1**): тег после закрытия **фазы A (0–6)** карты кампуса — MVP-пакет + QA (**41 / 0 / 2**), синхронизация честности README/TECHNICAL/планов (в приложении нет indoor A→B; Flutter фаза B отложена; basemap permission **pending**). Рантайм приложения по-прежнему линия надёжности сессии **1.5.10**; этот патч — продуктовый/docs ship на device + GitHub. Подробный дневник фаз 0–6 — следующая запись ниже. GitHub Release **v1.5.11** + APK (+ unsigned IPA если собран). Владелец **Nanda**.

---

## 2026-09-16 — дневник: карта кампуса фаза A (0–6) готова — синхронизация + перепроверка

**[2026-09-16]** — **подробная / развёрнутая запись (только в этот раз)**

### Зачем эта запись длинная

Фаза A («сначала закончить данные карты, потом любой Flutter Map UI») закрыта для MVP. Короткие буллеты того же дня по фазам 0–6 остаются хронологическими крошками; **эта** запись — полный дневник: что сдано, где лежит, как доказан QA, что честно ещё не сделано, и что будет значить фаза B позже. Только docs/data — **без** Flutter-экранов карты, **без** bump маркетинговой версии, **без** бандлинга basemap в APK/App Store. Владелец **Nanda**.

### Решение, задавшее день

Правило продукта (см. [CAMPUS_MAP_PLAN.ru.md](CAMPUS_MAP_PLAN.ru.md)): **сначала карта, потом приложение**. Indoor A→B для ELTE Lágymányos Юг (**LD / Déli**) и Север (**LE / Északi**) должен существовать как атрибутируемый, checksummed, прошедший QA пакет **до** любой кнопки Map на login-хабе, deep-link из расписания в indoor-путь или загрузчика графа в Dart. Поведение карт в уже выпущенном приложении остаётся **только внешним**: тап по коду аудитории → расшифровка → пин корпуса в Apple/Google Maps через `lib/Misc/elte_room_code.dart` (LD / LE / LK). Этот путь перепроверен `flutter test test/elte_room_code_test.dart` (все тесты зелёные) и его нельзя путать с indoor-маршрутизацией.

### Сдача по фазам (0 → 6)

| Фаза | Что появилось | Канонические пути |
|-----:|---------------|-------------------|
| **0** | Заморозка инвентаря: публичные JPG+таблицы LD/LE, пределы дампа BIS, планировщик Északi только как UX-референс, **не ждать** полилинии BIS `routing.route` (null в research), разрешение basemap = ship-blocker | [CAMPUS_MAP_PLAN](CAMPUS_MAP_PLAN.ru.md) фаза 0 · [campus_map_research/README](campus_map_research/README.md) |
| **1** | Зафиксированная схема: Building / Floor / Room / Node / Edge / Join; CRS = `basemapPx` (top-left); пример LD floor-0 + join-заглушки | [`schema/SCHEMA.md`](campus_map_research/schema/SCHEMA.md) |
| **2** | MVP графа коридоров LD: этажи **−1…7**, общий шаблон хабов, room/door stubs, входы, вертикальные **лифт + лестница**; сэмплы Dijkstra | [`graph/graph_ld.json`](campus_map_research/graph/graph_ld.json) · [`samples/ld_routes.md`](campus_map_research/graph/samples/ld_routes.md) · builder `build_graph_ld.py` |
| **3** | MVP графа коридоров LE: тот же набор этажей; хабы double-courtyard + южное крыло; CRS с Dunapart слева; тот же вертикальный паттерн | [`graph/graph_le.json`](campus_map_research/graph/graph_le.json) · [`samples/le_routes.md`](campus_map_research/graph/samples/le_routes.md) · builder `build_graph_le.py` |
| **4** | Neptun↔BIS joins + алиасы именных залов + search fixtures + честность покрытия | [`joins/`](campus_map_research/joins/) (`joins_ld.json`, `joins_le.json`, `aliases.json`, `search_fixtures.json`, `JOIN_COVERAGE.md`) |
| **5** | Ready-to-bundle пакет: графы + joins + алиасы + fixtures + стабильные `basemaps/{ld\|le}/f*.jpg` + `manifest.json` + `checksums.sha256` + `ATTRIBUTION.md` + `check_package.py` | [`campus_map_package/`](campus_map_package/) |
| **6** | Полный QA-runner + машинный JSON + человеческий отчёт + sign-off владельца **«карта закончена»** для MVP | [`run_qa.py`](campus_map_package/run_qa.py) · [`qa_matrix.json`](campus_map_package/qa_matrix.json) · [`QA_REPORT.md`](campus_map_package/QA_REPORT.md) |

**Счётчики пакета (manifest):** LD **475** nodes / **639** edges / **134** rooms; LE **454** nodes / **600** edges / **92** rooms; этажи **−1…7** у обоих. Research- и package-графы совпадают по топологии; пакет только переписывает `basemapAsset` на package-relative `basemaps/…` (в research остаются `ld_south/floors/…` / `le_north/floors/…`).

### Раскладка пакета (что есть «deliverable»)

```
docs/Technical/campus_map_package/
  manifest.json, graph_ld.json, graph_le.json
  joins_ld.json, joins_le.json, aliases.json, search_fixtures.json
  basemaps/ld|le/f-1.jpg … f7.jpg
  checksums.sha256, ATTRIBUTION.md
  check_package.py          # smoke фазы 5
  run_qa.py → qa_matrix.json
  QA_REPORT.md, README.md
```

Проверка в любой момент:

```bash
python3 docs/Technical/campus_map_package/check_package.py
python3 docs/Technical/campus_map_package/run_qa.py
```

### Цифры QA (перезапуск в этом проходе)

- **Smoke фазы 5:** assets манифеста + нужные файлы OK; checksums OK (**30** файлов); sample A→B OK для LD same-floor / entrance→room / cross-floor и той же тройки LE.
- **Матрица фазы 6:** **`pass=41` · `fail=0` · `waive=2` · total=43**.
- **В том числе pass:** тройки same-floor LD+LE; cross-floor с forced **stair** и forced **lift**; entrance→аудитория; именные залы (LD: Bolyai, Fejér Lipót, Rényi — LE: Ortvay, Eötvös, Rybár István); строки Neptun join; все позитивы `search_fixtures` + три educational-only негатива (`LD 5.210` / `5.615` / `5.713` корректно **без** graph pin); checksums; эвристики no-shortcut.
- **Waive (явные, не скрытые fail):** `ld-restricted` / `le-restricted` — схема допускает optional restricted/closed, но MVP `rooms[]` **не** копирует строки публичных таблиц (`16 után zárt`, `zárt terem`, …). Показ ждёт UI фазы B или отдельный annotation pass ([QA_REPORT](campus_map_package/QA_REPORT.md)).
- **Connectivity spot-check:** от входа в подвале достижимы все room nodes LD (**134**) и LE (**92**); joins с graph pin резолвятся; fixtures не ссылаются на отсутствующие nodes.
- **Bugbot-style review** пакета/скриптов фазы 0–6 + `elte_room_code`: **багов не найдено**. Flutter Map UI не изобретали.

### Честность (должна быть видна везде)

1. **Графы — приблизительная MVP-оцифровка** — хабы коридоров расставлены визуально на CRS basemap ~800×800; это не survey-grade BIM и не живые полилинии BIS. Достаточно для демо A→B фазы A и QA; уточнение — когда/если поедет фаза B.
2. Кредиты basemap в [ATTRIBUTION.md](campus_map_package/ATTRIBUTION.md); product map использует схему (JPG не primary).
3. **Нет Flutter indoor Map UI** — фаза **B** отложена. Product README не должен обещать in-app indoor A→B; «Открыть карту» в расписании — только внешние Maps.
4. **Join coverage на графе частичный:** почти у всех educational-комнат есть Neptun join-строка; только ~14–15% уже сидят на MVP graph pin (полная матрица в [`JOIN_COVERAGE.md`](campus_map_research/joins/JOIN_COVERAGE.md)). Educational-only комнаты — факты каталога, не walkable pin.
5. **BIS**-дамп: rooms/floors/entities импортированы; cookies/токены **не** в git; геометрия `routing.route` по-прежнему null.
6. **Legal:** Privacy/Terms в этом проходе не трогали — приложение по-прежнему не собирает GPS для indoor-графа (и нет экрана indoor-карты).

### Docs, синхронизированные в этом проходе

Product + technical docs приведены к фактам «фазы 0–6 готовы / фаза A карта закончена / фаза B отложена / basemap pending / путь пакета»: README EN+RU (честность фич + ссылка на пакет в карте docs), короткий root README, TECHNICAL EN+RU (уже указывал на пакет + QA), CAMPUS_MAP_PLAN EN+RU, research + package README, пометка в schema что графы фаз 2–3 существуют, этот подробный Dev Blog EN+RU. Планы HALLGATO без изменений (нет устаревших cross-link на карту). Legal не трогали.

### Что дальше (фаза B — не начата)

Только когда продукт решит: офлайн-загрузка пакета, Map на login-хабе без hallgato JWT, поиск + оверлей A→B на basemap этажа, переключатель этажей, опциональный deep-link из расписания на indoor pin — **всё ещё** нельзя класть в бинарники, пока не будет разрешения на basemap. Для этого docs/data close-out bump версии не нужен.

*Владелец / разработчик: **Nanda**.*

---

## 2026-09-16 — docs: карта кампуса фаза 6 (QA-матрица)

**[2026-09-16]**

- Фаза 6 QA по [`campus_map_package/`](campus_map_package/): [`run_qa.py`](campus_map_package/run_qa.py) → [`qa_matrix.json`](campus_map_package/qa_matrix.json) + [`QA_REPORT.md`](campus_map_package/QA_REPORT.md). Итог **pass=41 / fail=0 / waive=2** (restricted/closed не на MVP-комнатах). Sign-off владельца: фаза A **карта закончена** для MVP. Flutter фаза B по-прежнему отложена; разрешение basemap **pending**. Только docs/data; без Dart / bump версии. Владелец **Nanda**. *(Полный дневник: запись выше.)*

## 2026-09-16 — docs: карта кампуса фаза 5 (пакет deliverable)

**[2026-09-16]**

- Фаза 5 ready-to-bundle пакет: [`campus_map_package/`](campus_map_package/) (`graph_ld/le`, joins, алиасы, стабильные `basemaps/{ld|le}/f*.jpg`, `manifest.json`, `checksums.sha256`, `ATTRIBUTION.md`, `check_package.py`). Перераспространение JPG basemap **pending** (**block ship** App Store/APK). Только docs/data; без Dart / bump версии. Владелец **Nanda**.

---

## 2026-09-16 — docs: карта кампуса фаза 4 (joins + алиасы)

**[2026-09-16]**

- Фаза 4 Neptun↔BIS joins + именные залы: [`campus_map_research/joins/`](campus_map_research/joins/) (`joins_ld.json`, `joins_le.json`, `aliases.json`, `search_fixtures.json`, отчёт покрытия). Только docs/data; без Dart / bump версии. Владелец **Nanda**.

---

## 2026-09-16 — docs: карта кампуса фаза 3 (MVP-граф LE)

**[2026-09-16]**

- Фаза 3 MVP графа коридоров LE: [`campus_map_research/graph/graph_le.json`](campus_map_research/graph/graph_le.json) (этажи −1…7, 92 room stub, вертикальные лифты/лестницы) + сэмплы + builder. Только docs/data; без Dart / bump версии. Владелец **Nanda**.

---

## 2026-09-16 — docs: карта кампуса фаза 2 (MVP-граф LD)

**[2026-09-16]**

- Фаза 2 MVP графа коридоров LD: [`campus_map_research/graph/graph_ld.json`](campus_map_research/graph/graph_ld.json) (этажи −1…7, 134 room stub, вертикальные лифты/лестницы) + сэмплы + builder. Только docs/data; без Dart / bump версии. Владелец **Nanda**.

---

## 2026-09-16 — docs: карта кампуса фазы 0+1 (схема)

**[2026-09-16]**

- Закрыта фаза 0 (замороженный инвентарь + решения basemap/поиск/не ждать полилинии BIS). Модель данных фазы 1 в [`campus_map_research/schema/`](campus_map_research/schema/SCHEMA.md) (`SCHEMA.md`, пример LD floor-0, join-заглушки). Далее: фаза 2 — оцифровка LD. Только docs/data; без Dart / bump версии. Владелец **Nanda**.

---

## 2026-09-16 — docs: план карты кампуса (сначала карта)

**[2026-09-16]**

- Добавлены [CAMPUS_MAP_PLAN.md](CAMPUS_MAP_PLAN.md) / [`.ru.md`](CAMPUS_MAP_PLAN.ru.md): сначала пакет графа LD/LE + QA, **потом** Flutter UI карты (фаза B отложена). Кросс-ссылки из `campus_map_research/README.md`, TECHNICAL EN+RU, `keep-docs-current.mdc`. Только docs; без Dart / bump версии. Владелец **Nanda**.

---

## 2026-09-16 — docs: research-дамп карты кампуса

**[2026-09-16]**

- В git — authenticated research-дамп **BIS** в [`campus_map_research/`](campus_map_research/README.md) (комнаты/этажи/entities через system Chrome; геометрия `routing.route` в этом проходе **null**; cookies/токены не в git) + публичные JPG LD/LE + образец планировщика Északi + отчёты импорта BIS EN+RU. В приложение **не** подключено. Владелец **Nanda**.

---

## 2026-09-16 — docs: честность (переводчик + бэклог)

**[2026-09-16]**

- Честность docs: переводчик почты/сообщений помечен как **работает** (не «проверить на устройстве»); строка сессии в README совпадает с **1.5.10** (пароль при ручном logout при opt-in); восстановлены tracked **HALLGATO_SESSION_PLAN** EN+RU (были удалены в `remove plans`, статус до **1.5.10**). Обновлён раздел «В работе» Dev Blog. Без bump маркетинговой версии. Владелец **Nanda**.

---

## В работе / запланировано (честно)

**[ongoing]**

### Сделано / работает на main (~1.6.1)

- Hallgato **session v1** (без 10-мин wall-clock; foreground `GetNewTokens` каждые **3 мин 30 с**; сразу refresh при resume).
- Опциональный **фоновый keep-alive** в Settings (default выкл; **45 мин**; idle снят в **1.5.10**) + **Запомнить пароль** (default выкл; сохраняется при ручном logout при вкл.).
- UI навигатора учебной недели (**1.5.8**) + фикс битого кэша почты / epoch-`ERROR` (**1.5.6**).
- **Переводчик** почты HU→EN/RU — **работает** (failure → оригинал; disclaimer один раз).
- Пункты плана **1** / **1a–1c** / **5–10** / **12–14** как раньше; п. **11** (tanterv) **снят**.
- Карта кампуса: пакет фазы A + UI фазы B; **1.6.1** LD centerline-пути; стратегия D + private repo. См. дневник 2026-09-16.

### Ещё не сделано / исследование

- **Indoor-карта** — **1.7.1** mall-style схема (IK LD+LE); дальнейшая оцифровка опциональна. Полилинии BIS routing в research всё ещё **null**.
- Остатки HALLGATO: проактивный `GetNewTokens` на cold start; парсинг JWT `exp`; исследование portal/HWEB; live-test matrix ([HALLGATO_SESSION_PLAN](HALLGATO_SESSION_PLAN.ru.md)).
- Полный UI email OTP (`elteRequestEmailOtp` есть; UI не вызывает — сначала TOTP).
- Студенческий **без** QR/wallet; запись на экзамен/курс **не планируем**.
- Signed IPA / TestFlight / App Store / Play — **не** текущая цель. CI: unsigned IPA + Android debug APK (нет analyze/test job).

---

*Владелец / разработчик: **Nanda**.*
