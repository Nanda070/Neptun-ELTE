# Карта кампуса — план «сначала карта полностью»

**Статус (2026-09-16):** Research-пакет фаз **0–6** сохранён. Phase **B MVP (1.6.0)** фото-UX **отвергнут**. **1.7.x** schematic/ленты **заменены**. **1.8.0** = **полигоны BIS FootPrint**: цветные комнаты из MVT `bis.elte.hu/tiles/rooms` (бандл `polygons_ld/le.json`, **2571/3670** каталога); граф только для A→B (affine≈WGS); карточка по тапу; чип IK. JPG/schematic не primary.


**Владелец:** Nanda. 
**Решение (2026-09-16):** сначала полностью закончить indoor-карту; только потом внедрять в приложение. 
**Канонический близнец:** [CAMPUS_MAP_PLAN.md](CAMPUS_MAP_PLAN.md).

> Research-дамп: [`campus_map_research/`](campus_map_research/README.md) · Схема: [`campus_map_research/schema/SCHEMA.md`](campus_map_research/schema/SCHEMA.md) · импорт BIS: [BIS_IMPORT_REPORT.ru.md](campus_map_research/BIS_IMPORT_REPORT.ru.md) · Пакет: [`campus_map_package/`](campus_map_package/) 
> Уже в приложении (только внешний deep-link): `lib/Misc/elte_room_code.dart` — **не** indoor A→B.

---

## Сброс после MVP (2026-09-16) — пути + schematic UX

Владелец отверг фото-карту фазы B и вид **1.7.0** (свечение рёбер графа). Решения:

| Тема | Выбор |
|------|--------|
| **Пути** | Маршруты по **осевым коридоров**; сглаженный display (цепочка + Chaikin). |
| **Визуальная карта** | **Схема этажа в стиле ТЦ** — оболочка + **ленты** коридоров из vector JSON. **Не** рисовать рёбра графа как карту. **Не** JPG как primary (debug-подложка опциональна). |
| **Охват** | **Пока только IK / факультет информатики** — LD (Déli) + LE (Északi). |
| **Полилинии BIS** | В research всё ещё **null** — маршруты по derived-графу; не ship-blocker. |
| **UI фазы B** | **1.8.0** — schematic-полигоны + баннер «только IK»; поиск / этажи / A→B / pre-login сохранены. |

### Геометрия схемы

1. **LD −1…7:** `schematic_ld.json` — оболочка + двор + ленты по схеме коридоров **1–8** (`build_schematics.py`).
2. **LE −1…7:** `schematic_le.json` — оболочка + два двора + zone-ленты.
3. Комнаты остаются на centerline-графе; пины/лейблы на схеме.
4. Лейблы: скрывать плотные пересечения при малом зуме; показывать больше при зуме.

---
## Цель

Подготовить **полный, атрибутируемый, прошедший QA пакет indoor-маршрутизации** для ELTE Lágymányos **Юг (LD / Déli)** и **Север (LE / Északi)**, который Neptun ELTE сможет позже загрузить **без** живого логина BIS и **без** живого `routing.route`.

**Карта закончена** = выполнены критерии выхода фаз **0–6** (см. [Определение успеха](#определение-успеха--карта-закончена)). Экраны Flutter, кнопка Map на login-хабе и deep-link из расписания — **фаза B**: перечислены для ясности, **MVP отгружен** в **1.6.0** (`CampusMapPage`, `assets/campus_map/`).

---

## Принципы

> Исторические правила Phase A — **Выполнено 2026-09-16 для Phase A MVP** (пакет + QA). Phase B (Flutter) MVP — **1.6.0**.

| Правило | Смысл |
|---------|--------|
| **Сначала карта, потом приложение** | Нет новых Flutter-экранов карты / загрузчиков графа, пока нет deliverable фазы 5 и QA фазы 6 по согласованным корпусам. |
| **Свой граф, не live API** | Оцифровываем узлы/рёбра коридоров сами (или из разрешённых export). **Не** блокируемся на геометрию BIS `routing.route` (в research-дампе — null). |
| **Сначала LD, потом LE** | Полный граф Юга + валидация, затем тот же пайплайн для Севера. |
| **Join позже, схема сразу** | Поля Neptun↔BIS фиксируем в фазе 1; таблицы join заполняем в фазе 4. |
| **Атрибуция до ship** | Не бандлить чужой artwork в App Store / GitHub APK, пока чеклист не закрыт. |

---

## Обзор фаз

| Фаза | Название | Код приложения? |
|-----:|----------|-----------------|
| **0** | Заморозка инвентаря | Нет |
| **1** | Модель данных | Нет |
| **2** | Полная оцифровка графа **LD** | Нет |
| **3** | Полная оцифровка графа **LE** | Нет |
| **4** | Join-таблицы + поисковые алиасы | Нет |
| **5** | Упаковка deliverable | Нет |
| **6** | QA-матрица | Нет |
| **B** | Интеграция в приложение (позже) | **Да — только после 0–6** |

---

## Фаза 0 — Заморозка инвентаря

**Статус:** **ГОТОВО** — решения зафиксированы **2026-09-16**.

**Зачем:** зафиксировать уже имеющееся, чтобы оцифровка не «переоткрывала» источники на полпути.

### Замороженный инвентарь (2026-09-16)

Пути под `docs/Technical/campus_map_research/`:

| Актив | Путь |
|-------|------|
| Research README | `README.md` |
| Отчёты импорта BIS | `BIS_IMPORT_REPORT.md` · `BIS_IMPORT_REPORT.ru.md` |
| **Схема фазы 1** | `schema/SCHEMA.md` · `schema/schema.example.ld.floor0.json` · `schema/joins_ld.stub.*` |
| **Граф LD фазы 2** | `graph/graph_ld.json` · `graph/README.md` · `graph/samples/ld_routes.md` · `graph/build_graph_ld.py` |
| **Граф LE фазы 3** | `graph/graph_le.json` · `graph/samples/le_routes.md` · `graph/build_graph_le.py` |
| **Joins фазы 4** | `joins/joins_ld.json` · `joins/joins_le.json` · `joins/aliases.json` · `joins/search_fixtures.json` · `joins/JOIN_COVERAGE.md` · `joins/build_joins.py` |
| Basemap JPG LD | `ld_south/floors/` — `deli_-1_emelet.jpg`, `deli_foldszint.jpg`, `deli_1_emelet.jpg`…`deli_7_emelet.jpg`, `delitomb_0.jpg` |
| Публичная таблица комнат LD | `ld_south/rooms.json` (~134 подписанных комнат; схема коридоров 1–8) |
| Basemap JPG LE | `le_north/floors/` — `eszaki_-1_emelet.jpg`, `eszaki_foldszint.jpg`, `eszaki_1_emelet.jpg`…`eszaki_7_emelet.jpg` |
| Публичная таблица LE | `le_north/rooms.json` |
| Образец A→B Севера | `eszaki_route_planner/` (terkeptar / OpenLayers 2018) |
| Каталог BIS Юг | `bis/south/` — **1696** комнат, этажи `00`…`7`,`T`; educational `rooms_educational.json` (**849**) |
| Каталог BIS Север | `bis/north/` — **1974** комнат, этажи `-4`…`11`; educational (**639**) |
| API-археология | `bis/api/` (entities, filters, rooms-by-id, routing trials → геометрия **null**) |

**Cookies / токены:** **не в git** (и должны оставаться вне git).

### Кредиты, которые сохраняем

- Планы этажей (sarkozigergo): **Héger Tamás**
- Страница-агрегатор: **Sárközi Gergő**
- Планировщик Севера: **Eszényi Krisztián** (ELTE Cartography & Geoinformatics, 2018)
- Официальный BIS: ELTE IIG (`bis.elte.hu`)

### Зафиксированные решения (2026-09-16)

| Решение | Выбор |
|---------|--------|
| Basemap | JPG sarkozigergo в `ld_south/floors/` + `le_north/floors/` — **разрешение ещё pending** (honesty) |
| Поисковые узлы | Centroids/коды BIS + публичные таблицы комнат |
| Геометрия маршрутов | Оцифровываем свой граф — **не** ждём полилинии BIS `routing.route` |

### Критерии выхода

- [x] Замороженный инвентарь путей с датой **2026-09-16**.
- [x] Решения basemap / поиск / не ждать полилинии BIS зафиксированы.
- [x] Cookies / токены по-прежнему **не в git**.

---

## Фаза 1 — Модель данных

**Статус:** **ГОТОВО** — **2026-09-16**. Канон: [`campus_map_research/schema/SCHEMA.md`](campus_map_research/schema/SCHEMA.md).

**Зачем:** одна JSON-дружелюбная схема для комнат, этажей, узлов, рёбер и join Neptun↔BIS — до рисования рёбер.

### Сущности (зафиксированы)

| Сущность | Обязательные поля |
|----------|-------------------|
| **Building** | `id` (`ld` \| `le`), `neptunPrefix` (`LD` \| `LE`), display names HU/EN |
| **Floor** | `buildingId`, `level` (int, напр. −1…7), `bisSlug` (напр. `00`,`0`…`7`), `basemapAsset`, `basemapWidth`/`Height` |
| **Room** | стабильный `id`, `codeBis`, `codeNeptun` (nullable до join), `name`, `floorId`, `centroid` (пиксели), опционально `centroidWgs`, `aliases[]`, `type` |
| **Node** | `id`, `floorId`, `kind` (`room` \| `corridor` \| `stair` \| `lift` \| `entrance` \| `poi`), `coord` (пиксели), опционально `roomId`, `verticalShaftId` |
| **Edge** | `from`, `to`, `weight` (длина или cost), `bidirectional` (по умолчанию true), опционально `kind` / `restricted` / `floors` |
| **Join row** | `neptunCode` ↔ `bisRoomId` / `codeBis`, confidence (`exact` \| `heuristic` \| `manual`) |

### Политика координат (зафиксирована)

- **Primary (граф):** локальные **пиксели basemap** (`space: "basemapPx"`), origin top-left, привязка к размеру JPG — маршрутизация без Mapbox.
- **Secondary:** опциональный WGS84 из centroids BIS (`space: "wgs84"`) для outdoor handoff / проверок — не CRS проходимости.
- Образец: [`schema.example.ld.floor0.json`](campus_map_research/schema/schema.example.ld.floor0.json) (фрагмент floor-0; **полный** граф LD — фаза 2 [`graph/graph_ld.json`](campus_map_research/graph/graph_ld.json)).
- Join-заглушка: [`joins_ld.stub.json`](campus_map_research/schema/joins_ld.stub.json) / `.csv`.

### Лестницы / лифты

Лестницы и лифты — **межэтажные рёбра**: один landing-узел на этаж с общим `verticalShaftId`; вертикальные рёбра связывают соседние площадки (`verticalStair` / `verticalLift`). См. SCHEMA.md.

### Критерии выхода

- [x] Схема в `campus_map_research/schema/SCHEMA.md` с примером JSON этажа LD floor-0.
- [x] Поле версии на корне пакета (`schemaVersion`: **1**).
- [x] Явное правило: лестницы/лифты — **межэтажные рёбра** (один вертикальный ствол связан между этажами).

---

## Фаза 2 — Полная оцифровка графа LD

**Статус:** **ГОТОВО** — MVP **2026-09-16**. Артефакт: [`campus_map_research/graph/graph_ld.json`](campus_map_research/graph/graph_ld.json) · заметки: [`graph/README.md`](campus_map_research/graph/README.md) · сэмплы: [`graph/samples/ld_routes.md`](campus_map_research/graph/samples/ld_routes.md).

**Зачем:** проходимый граф коридоров для **Юга / Déli (LD)** на всех студенчески значимых этажах.

### Объём (LD)

| Пункт | Цель |
|-------|------|
| Этажи | **−1…7** (метка карты `00` = −1; цоколь/земля = 0). Чердак `T` — опционально / вне student path, если не нужен. |
| Коридоры | Схема **1–8** + хабы (liftek, főlépcső, büfé, ворота) по заметкам `delitomb_0.jpg` |
| Вертикаль | Лестницы + лифты между соседними этажами; входы как конечные узлы |
| Пины комнат | Как минимум educational / часто бронируемые; предпочтительно связь с educational-подмножеством BIS |
| Basemap | `ld_south/floors/*.jpg` (или одобренная замена) |

### Процесс

1. Трассировка коридоров на каждом этаже (оверлей Figma, QGIS или JSON-редактор — см. [Инструменты](#инструменты)).
2. Узлы на пересечениях, у дверей, площадках лестниц/лифтов, входах.
3. Комнаты → ближайший corridor-узел (короткие stub-рёбра).
4. Межэтажные рёбра для каждого вертикального коннектора.
5. Выборочные кратчайшие пути A→B (инструмент или скрипт) и фиксация результатов.

### Валидационные сэмплы (минимум)

Задокументировать ≥ **5** маршрутов LD с ожидаемыми сменами этажа, напр.:

| # | Откуда → куда | Ожидание |
|---|---------------|----------|
| 1 | Соседи одного этажа по коридору | Без вертикальных рёбер |
| 2 | Вход с земли → аудитория на среднем этаже | Стабильно лифт **или** лестница |
| 3 | Этаж −1 ↔ этаж 1 через известную лестницу | Верный ствол |
| 4 | Именной зал (напр. Bolyai) → другой именной зал | Алиас резолвится + путь |
| 5 | Кросс-коридор (напр. 2 → 7) | Через соединяющий коридор, не сквозь стены |

### Критерии выхода

- [x] Каждый этаж −1…7 имеет связный corridor-компонент по схеме 1–8 (или задокументированные тупики).
- [x] Все лифты/лестницы/входы на этих этажах — узлы с межэтажными / outdoor-связями где применимо.
- [x] ≥5 сэмплов A→B проходят (путь есть, длина разумна, нет «сквозь стену»).
- [x] Черновик артефакта `graph_ld.json` существует (может лежать в research до упаковки фазы 5).

**Честность:** пиксели хабов/дверей остаются **полуручными / приблизительными**. В **1.6.1** LD-builder цепляет door mouths вдоль осевых коридоров (не hub-spoke). Чердак `T` опущен. LE пока на старом hub-heuristic до того же pass. Полная переоцифровка LD+LE — большой объём, в работе.

---

## Фаза 3 — Полная оцифровка графа LE

**Статус:** **ГОТОВО** — MVP **2026-09-16**. Артефакт: [`campus_map_research/graph/graph_le.json`](campus_map_research/graph/graph_le.json) · заметки: [`graph/README.md`](campus_map_research/graph/README.md) · сэмплы: [`graph/samples/le_routes.md`](campus_map_research/graph/samples/le_routes.md).

**Зачем:** тот же пайплайн для **Севера / Északi (LE)**.

### Объём (LE)

| Пункт | Цель |
|-------|------|
| Этажи | Публичный набор JPG **−1…7** как основная student-поверхность. Этажи BIS вне диапазона (`-4`…`-2`, `8`…`11`) = **опционально позже**, не блокеры фазы 3. |
| LK | Обычно входит в карту LE — POI / алиасы в графе LE, не третий файл здания, пока не доказано иное. |
| Референс | Изучить UX/граф `eszaki_route_planner/`; **не** переиздавать GeoJSON без разрешения Cartography. |

### Критерии выхода

- [x] Та же планка связности, что у LD, для этажей −1…7.
- [x] ≥5 задокументированных сэмплов A→B.
- [x] Черновик `graph_le.json` существует.
- [x] Вертикальные коннекторы согласованы с планами Севера.

**Честность:** пиксели хабов/дверей — **полуручные / приблизительные** (stub по зоне номера комнаты + визуальный double-loop / крыло), не CV-точные двери. В `rooms.json` поле `floor` часто `?` — этаж выводится из кода. Bare-коды LK включены в LE. Этажи BIS вне −1…7 опущены. Пиксели уточним позже; связность для MVP полная.

---

## Фаза 4 — Join-таблицы + поисковые алиасы

**Статус:** **ГОТОВО** — **2026-09-16**. Канон: [`campus_map_research/joins/`](campus_map_research/joins/README.md).

**Зачем:** пользователь вводит коды Neptun и имена залов; граф резолвит в узлы.

### Join

| Источник A | Источник B | Выход |
|------------|------------|-------|
| Neptun-стиль (`LD 0.821`, `LD-0-805`, строки расписания) | BIS `LD-…` / room id | [`joins/joins_ld.json`](campus_map_research/joins/joins_ld.json) |
| То же для LE (вкл. LK-префиксы Севера) | Коды BIS Север | [`joins/joins_le.json`](campus_map_research/joins/joins_le.json) |

Confidence: `exact` = публичный/graph `codeBis` совпал с educational `roomNumber` (или `bisRoomId` фаз 2/3); `heuristic` = выведенный Neptun / educational-only (часто `roomId` null). Регенератор: `joins/build_joins.py`.

**Покрытие (честно):** LD educational **100%** имеют Neptun join-строку; **~14.5%** уже на MVP-графе. LE educational **~99.8%** joined; **~14.1%** на графе. Полная матрица: [`JOIN_COVERAGE.md`](campus_map_research/joins/JOIN_COVERAGE.md).

### Алиасы (именные залы)

[`joins/aliases.json`](campus_map_research/joins/aliases.json) — Bolyai, Fejér Lipót, Rényi, Erdős Pál, Turán Pál, Ortvay, Eötvös, … → `roomId`/`nodeId`. Разговорное **Déli Hali** с `roomId` null (нет educational-комнаты BIS).

### Search-фикстуры

[`joins/search_fixtures.json`](campus_map_research/joins/search_fixtures.json) — запрос → ожидаемый pin для QA фазы 6 (вкл. educational-only негативы).

### Критерии выхода

- [x] Отчёт покрытия join: % educational-комнат с матчем Neptun-кода (честно задокументирован).
- [x] Список алиасов известных именных залов LD (+ LE).
- [x] Список search-фикстур (запрос → ожидаемый узел) для QA фазы 6.

---

## Фаза 5 — Упаковка deliverable

**Зачем:** одна версионированная папка (или release-asset), готовая к хостингу или бандлу — **всё ещё без Flutter UI**.

### Обязательные файлы

| Файл | Роль |
|------|------|
| `graph_ld.json` | Узлы + рёбра LD + индекс этажей |
| `graph_le.json` | Узлы + рёбра LE + индекс этажей |
| `joins_ld.json` / `joins_le.json` (или встроенные) | Neptun↔BIS |
| `aliases.json` | Именные залы / строки поиска |
| Basemap-ассеты | JPG (или WebP) этажей по корпусу/этажу, стабильные имена |
| `checksums.sha256` | Хеши всех файлов пакета |
| `ATTRIBUTION.md` | Кредиты + статус лицензий (см. чеклист) |
| `manifest.json` | `schemaVersion`, список корпусов, карта ассетов, дата пакета |

### Дистрибуция

- **Выбрано:** ready-to-bundle в [`docs/Technical/campus_map_package/`](campus_map_package/) (графы, joins, алиасы, basemap, checksums, атрибуция, `check_package.py`).
- Предпочитать производный JSON + разрешённые basemap вместо бандла BIS HTML/JS SPA. Разрешение на JPG basemap всё ещё **pending** — см. `ATTRIBUTION.md` пакета.

### Критерии выхода

- [x] Все файлы выше на месте; checksums сходятся (`docs/Technical/campus_map_package/`).
- [x] `ATTRIBUTION.md` заполнен (кредиты).
- [x] Пакет грузится в **не-Flutter** checker (`check_package.py`) и считает A→B для сэмплов.

**Честность:** пакет лежит в [`campus_map_package/`](campus_map_package/) для Phase A / QA. Перераспространение basemap всё ещё **pending** — не бандлить в App Store / APK, пока чеклист не закрыт.

---

## Фаза 6 — QA-матрица

**Статус:** **ГОТОВО** — **2026-09-16**. Отчёт: [`campus_map_package/QA_REPORT.md`](campus_map_package/QA_REPORT.md) · машина: [`qa_matrix.json`](campus_map_package/qa_matrix.json) · runner: [`run_qa.py`](campus_map_package/run_qa.py).

**Зачем:** ручные / tool-тесты маршрутов до объявления карты законченной.

### Матрица (на бумаге или в checker)

| Проверка | LD | LE |
|----------|----|----|
| A→B на одном этаже (3 пары) | ☑ pass | ☑ pass |
| Межэтажно через лестницу | ☑ pass | ☑ pass |
| Межэтажно через лифт | ☑ pass | ☑ pass |
| Вход → аудитория | ☑ pass | ☑ pass |
| Поиск именного зала → пин | ☑ pass | ☑ pass |
| Join кода Neptun → пин | ☑ pass | ☑ pass |
| Пометка restricted / closed (если моделируется) | ☑ **waive** | ☑ **waive** |
| Нет явного «сквозь стену» / outdoor shortcut | ☑ pass | ☑ pass |

**Итог:** pass=41 · fail=0 · waive=2 (на MVP-комнатах нет optional `restricted` / closed — задокументировано, не скрытый fail). Checksums + `search_fixtures.json` тоже проверены `run_qa.py`.

### Критерии выхода

- [x] Матрица закрыта для **LD** и **LE** (этажи −1…7).
- [x] Провалы — баги графа (фикс в фазах 2/3), не откладываются на UI — **открытых нет**.
- [x] Sign-off владельца: **«карта закончена»** для фазы A (Nanda, 2026-09-16).

---

## Фаза B — Интеграция в приложение (**MVP 1.6.0; после сброса — transitional**)

Фазы **0–6** — research. **MVP отгружен** в **1.6.0**, затем **UX отвергнут**. **1.6.1** = LD centerline-пути + honesty/repo strategy. UI может остаться как **переходный**, пока не будет basemap стратегии D + полных centerline-графов LD+LE.

| Пункт | Намерение |
|-------|-----------|
| Кнопка **Map** на login-хабе | Открыть indoor-карту без hallgato JWT (basemap + поиск). |
| UI A→B | Выбор старта/финиша (поиск / тап); путь на basemap этажа; переключатель этажей. |
| Deep-link из расписания | Из кода аудитории → карта с фокусом на комнате (семантика `elte_room_code`). |
| Бандл в приложении | Загрузка JSON + ассетов фазы 5 из бандла или first-run download. |
| Опционально | Deep-link / WebView в BIS для пользователей с ELTE-логином — вторично, не замена нашему графу. |

**Критерии выхода MVP фазы B** (выполнены в **1.6.0**; **не** приняты как продуктовый UX): pre-login Map, LD/LE, этажи, поиск, A→B, honesty-баннер. Тег **v1.6.0**. Направление после сброса: см. [Сброс после MVP](#сброс-после-mvp-2026-09-16--пути--стратегия-d--private-repo).

---

## Чеклист лицензий / атрибуции

Закрыть до попадания map-ассетов в публичный бинарь:

- [ ] Планы **Héger Tamás** — письменное разрешение или подтверждённые условия публичного reuse; кредит in-app + `ATTRIBUTION.md`.
- [ ] Агрегатор **Sárközi Gergő** — кредит; подтвердить перераспространение JPG.
- [ ] **Eszényi Krisztián / terkeptar** — кредит; **без** wholesale GeoJSON без OK кафедры Cartography.
- [ ] **BIS / ELTE IIG** — каталоги комнат только как derived data; спросить перед ship полных инвентарей, если redistribution ограничен; **без** cookies/токенов в пакете.
- [~] Mapbox — только если сами встраиваем Mapbox (**N/A / waived для фазы A** pixel-графов; вернуться при Flutter map).
- [~] Privacy / Terms — обновить Legal EN/RU/HU, если карта собирает location (**N/A до Flutter map**; по умолчанию GPS для indoor-графа **не** нужен).

---

## Вне объёма (фаза A)

| Пункт | Почему |
|-------|--------|
| Live BIS API в приложении | Auth-стена (IdP); dump только для research |
| Ожидание полилиний `routing.route` | Геометрия не захвачена; оцифровываем сами |
| Полный 3D / VR | Целевой продукт — **2D** A→B |
| Политика offline-first sync | Опционально позже; пакет может идти in-bundle |
| Отдельный `graph_lk.json` для LK | Складываем в LE, пока не доказано иное |
| Flutter UI карты | Только фаза B |
| Запись на экзамен/курс, tanterv и т.п. | Другой продуктовый бэклог |

---

## Инструменты

| Инструмент | Применение |
|------------|------------|
| **Figma** | Оверлей коридоров на JPG этажей; экспорт координат узлов |
| **Polycam** (опционально) | Референс-фото / грубые сканы — **не** замена 2D-графу |
| **JSON** (+ небольшой Python/Dart-скрипт) | Авторство `graph_*.json`, smoke-тесты кратчайшего пути |
| **QGIS / qgis2web** | Опционально; изучение слоёв планировщика Севера |
| System Chrome + BIS | Опциональный второй проход для проверки centroids — не обязателен для выхода |

---

## Определение успеха — «карта закончена»

Фаза A **готова** (**завершена 2026-09-16**), когда верно **всё** ниже:

1. Графы **LD** и **LE** покрывают согласованные этажи (−1…7) с коридорами, вертикальными связями и входами.
2. В пакете есть `graph_ld.json`, `graph_le.json`, basemap, checksums, атрибуция.
3. Join + алиасы поддерживают Neptun-коды и именные залы для QA-фикстур.
4. QA-матрица фазы 6 пройдена (или waived-пункты явно задокументированы).
5. **Никакая** Flutter-фича карты не начата под видом «просто подключить» неполные данные.

До этого продукт остаётся на **внешнем maps deep-link** (`Open map` → поиск корпуса в Apple/Google Maps).

---

## Ссылки

| Документ | Роль |
|----------|------|
| [campus_map_research/README.md](campus_map_research/README.md) | Индекс research-дампа |
| [campus_map_research/schema/SCHEMA.md](campus_map_research/schema/SCHEMA.md) | Модель данных фазы 1 (зафиксирована) |
| [BIS_IMPORT_REPORT.ru.md](campus_map_research/BIS_IMPORT_REPORT.ru.md) | Auth BIS, каталоги, routing null |
| [TECHNICAL.ru.md](TECHNICAL.ru.md) | Технический канон продукта |
| [DEV_BLOG.ru.md](DEV_BLOG.ru.md) | Хронологический дневник |

---

*Владелец / разработчик: **Nanda**.*
