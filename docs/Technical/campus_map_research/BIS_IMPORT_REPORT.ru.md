# Отчёт об импорте BIS (ELTE Building Information System)

**Дата:** 2026-09-16  
**Путь в репозитории:** `docs/Technical/campus_map_research/`  
**Статус:** данные BIS **импортированы** из авторизованной сессии системного Google Chrome (не Cursor IDE browser). Версию приложения не поднимали. Cookies / токены сессии в git **не** попадали.

---

## 1. Краткий итог

| Пункт | Результат |
|------|-----------|
| Без входа `bis.elte.hu` | **Закрыто** — редирект на IdP ELTE |
| Chrome с сессией пользователя | **Работало** — вкладки South 3D и North 2D уже были открыты |
| Комнаты | **Да** — 1696 South (deli/LD) + 1974 North (eszaki/LE) = **3670** (код, имя, bbox, centroid) |
| Этажи / корпуса | **Да** — hull, список этажей, дерево кампуса через `/api/v2/entities` |
| Геометрия A→B | **Частично** — флаг `routing` и API `routing.route` есть; скриптовые вызовы вернули `null` |
| Ранее скачанное (sarkozigergo + terkeptar) | На месте: `ld_south/`, `le_north/`, `eszaki_route_planner/` |

**Вывод для Neptun ELTE A→B:** брать **каталог комнат BIS** (коды + centroids) и **JPG планы** sarkozigergo как подложку. Не ждать полилиний маршрута BIS, пока не поймаем успешный ответ UI или не получим export графа. Для Севера образец A→B — terkeptar 2018.

---

## 2. Барьер авторизации (без сессии)

Без cookies любой URL карты:

1. `https://bis.elte.hu/map/...` → `302` → `/auth/login?redirect=...`
2. `/auth/login` → `302` →  
   **IdP:** `https://idp.elte.hu/auth/saml2/idp/SSOService.php` (SAML2)  
3. Страница входа: `https://idp.elte.hu/auth/module.php/eltedbauth/authpage.php`  
   Заголовок: **«Központi bejelentkezés»**

Артефакты (заголовки с redact): `bis/api/*headers*.txt`, `bis/html/idp_or_login_final.html`.

IDE-браузер Cursor ранее упирался в этот экран. **Системный Chrome** с faculty-логином обошёл барьер.

---

## 3. Метод захвата (system Chrome)

| Вкладка | URL | Заголовок |
|---------|-----|-----------|
| South | `.../deli?locale=en&viewParadigm=3d` | South Building · ELTE Building Information System |
| North | `.../eszaki?viewParadigm=2d&locale=en` | North Building · ELTE Building Information System |

Использовались **JXA / AppleScript** `execute … javascript` и синхронный `XMLHttpRequest` в cookie-jar браузера. Remote debugging Chrome не понадобился. Cookies в репозиторий не писались.

---

## 4. Обнаруженный API

База: **`https://bis.elte.hu/api/v2/`** (tRPC-подобный batch GET).

| Процедура(ы) | Назначение |
|--------------|------------|
| `entities` | Города, кампусы, корпуса, этажи (+ bbox/hull) |
| `config` | Тема Mapbox, подписи, строки поиска |
| `features` | Модули: `search`, `vr`, `issue-reporting`, **`routing`** |
| `userProfile` | Профиль (сохранён только как **`userProfile_REDACTED.json`**) |
| `privileges`, `classifications`, `fields`, `orgUnits`, `filter` | Дерево scope + группы room id по функции |
| `search` | Поиск комнат / зданий / POI |
| `rooms.getRoomById` / `rooms.getRoomByScope` | Полная карточка комнаты |
| `routing.route` | Indoor A→B; формат `point:lng,lat` / `room:id` |
| `vrNodes` | VR-точки (часто пусто) |

Ответы — **компактный index-encoded JSON**. Распакованные копии: `bis/api/*_expanded.json`, `bis/south|north/rooms_catalog.json`.

Рендер: **Mapbox GL**, в HTML публичный клиентский `pk.` токен.

---

## 5. Что импортировано из BIS

### 5.1 South / Déli (LD) — `bis/south/`

- `building.json`, `floors.json` (10 этажей: `00`…`7`, `T`)
- `rooms_catalog.json` — **1696** комнат  
- `rooms_educational.json` — **849** учебных  
- Типы: educational 849, corridor 238, social 237, technical 258, administrative 70, …

Коды вида `LD-{этаж}-{номер}-…`.

### 5.2 North / Északi (LE) — `bis/north/`

- 16 этажей (`-4`…`11`) — шире, чем публичные JPG (−1…7)
- **1974** комнаты; educational **639**

### 5.3 Общие дампы — `bis/api/`, HTML/JS/иконки

См. английский отчёт §5.3–5.4 — те же файлы.

---

## 6. Ситуация A→B

Флаг routing включён, API живой. Скриптовые вызовы `routing.route` для пар комнат / point→room на 0 этаже South вернули `[null]`. Ошибка валидации подтверждает API: *«A route cannot end at a point»*.

**Геометрию маршрута в этом проходе не сохранили.** Второй проход: вручную построить маршрут в UI Chrome и снова снять Network/`routing.route`.

---

## 7. Уже было (публичные источники)

| Путь | Источник | Зачем |
|------|----------|-------|
| `ld_south/` | sarkozigergo `ld.html` | JPG этажей + 134 комнаты + схема коридоров |
| `le_north/` | sarkozigergo `le.html` | JPG + таблица |
| `eszaki_route_planner/` | terkeptar | Рабочий A→B (только Север, 2018) |

Авторы: карты **Héger Tamás**; агрегатор **Sárközi Gergő**; планировщик **Eszényi Krisztián**.

---

## 8. South vs North

| | South (LD) | North (LE) |
|--|------------|------------|
| Комнаты BIS | 1696 | 1974 |
| Этажи BIS | 10 | 16 |
| Публичные JPG | сильные | сильные |
| Публичный A→B | нет | terkeptar |
| Геометрия BIS A→B | не снята | не снята |

---

## 9. Инвентарь файлов

~12–14 МиБ:

```
campus_map_research/
  README.md
  BIS_IMPORT_REPORT.md · BIS_IMPORT_REPORT.ru.md
  ld_south/ · le_north/ · eszaki_route_planner/
  bis/  (api, south, north, html, js, assets, screenshots/README)
```

---

## 10. Рекомендуемый путь, если routing BIS останется пустым

1. Поиск → пин комнаты из `rooms_educational.json` (+ North).  
2. Подложка LD: `ld_south/floors/*.jpg`, оцифровка графа коридоров 1–8.  
3. UX/граф: смотреть `eszaki_route_planner/`; спросить кафедру картографии перед reuse GeoJSON.  
4. Опционально: второй проход BIS после ручного A→B в UI.  
5. Не тащить целиком HTML/JS BIS в App Store без разрешения ELTE.

---

## 11. Лицензия / честность

- BIS — официальный продукт ELTE IIG за логином; дамп для внутреннего планирования Neptun ELTE. Публичная раздача геометрии требует разрешения.  
- Токен Mapbox `pk.` в HTML — клиентский, уже виден браузеру.  
- sarkozigergo / terkeptar — сторонние страницы: атрибуция и разрешение перед бандлом.  
- Профиль пользователя отредактирован (redact). Cookies и desktop-скриншоты **не** коммитились.

---

## 12. Чеклист второго прохода

- [~] В Chrome построить видимый A→B на BIS — **отложено / не блокирует фазу A** (MVP-графы оцифрованы сами).
- [~] Снять успешный `routing.route` (+ тайлы/GeoJSON) — **отложено / не блокирует фазу A**.
- [~] Экспорт графа коридоров, если появится в Network — **отложено / не блокирует фазу A**.
- [ ] Кроп map-only скриншотов без панели закладок.
