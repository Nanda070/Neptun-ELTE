# Campus map — finish-the-map-first plan

**Status:** **Phase 0–2 done** (LD MVP graph). Next: **Phase 3** digitize LE. **Phase B (Flutter app)** deferred until LD (+ LE) graphs are packaged + QA’d.  
**Owner:** Nanda.  
**Decision (2026-09-16):** finish the indoor map completely first; only then implement in the app.  
**Canonical twin:** [CAMPUS_MAP_PLAN.ru.md](CAMPUS_MAP_PLAN.ru.md).

> Research dump: [`campus_map_research/`](campus_map_research/README.md) · Schema: [`campus_map_research/schema/SCHEMA.md`](campus_map_research/schema/SCHEMA.md) · BIS import: [BIS_IMPORT_REPORT.md](campus_map_research/BIS_IMPORT_REPORT.md)  
> Related shipped maps (external deep-link only): `lib/Misc/elte_room_code.dart` — **not** indoor A→B.

---

## Goal

Deliver a **complete, attributable, QA’d indoor routing package** for ELTE Lágymányos **South (LD / Déli)** and **North (LE / Északi)** that the Neptun ELTE app can later load without depending on live BIS login or live `routing.route`.

**Map finished** means: Phase **0–6** exit criteria all met (see [Success definition](#success-definition-map-finished)). Flutter screens, login-hub Map button, and schedule deep-links are **Phase B** — listed for clarity, **not started now**.

---

## Principles

| Rule | Meaning |
|------|---------|
| **Map before app** | No new Flutter map screens / graph loaders until Phase 5 deliverable exists and Phase 6 QA passes for the agreed buildings. |
| **Derived graph, not live API** | Digitize corridor nodes/edges ourselves (or from permitted exports). Do **not** block on BIS `routing.route` geometry (still null in research dump). |
| **LD first, LE next** | Complete South graph + validation, then run the same pipeline for North. |
| **Join later, schema early** | Lock Neptun↔BIS join fields in Phase 1; fill join tables in Phase 4. |
| **Attribution before ship** | No App Store / GitHub APK bundling of third-party artwork until checklist cleared. |

---

## Phase overview

| Phase | Name | App code? |
|------:|------|-----------|
| **0** | Inventory freeze | No |
| **1** | Data model | No |
| **2** | Digitize **LD** graph fully | No |
| **3** | Digitize **LE** graph fully | No |
| **4** | Join tables + search aliases | No |
| **5** | Package deliverable | No |
| **6** | QA matrix | No |
| **B** | App integration (later) | **Yes — only after 0–6** |

---

## Phase 0 — Inventory freeze

**Status:** **DONE** — decisions frozen **2026-09-16**.

**Purpose:** freeze what we already have so digitization does not rediscover sources mid-flight.

### Frozen inventory (2026-09-16)

Paths under `docs/Technical/campus_map_research/`:

| Asset | Path |
|-------|------|
| Research README | `README.md` |
| BIS import reports | `BIS_IMPORT_REPORT.md` · `BIS_IMPORT_REPORT.ru.md` |
| **Phase 1 schema** | `schema/SCHEMA.md` · `schema/schema.example.ld.floor0.json` · `schema/joins_ld.stub.*` |
| **Phase 2 LD graph** | `graph/graph_ld.json` · `graph/README.md` · `graph/samples/ld_routes.md` · `graph/build_graph_ld.py` |
| LD basemap JPGs | `ld_south/floors/` — `deli_-1_emelet.jpg`, `deli_foldszint.jpg`, `deli_1_emelet.jpg`…`deli_7_emelet.jpg`, `delitomb_0.jpg` |
| LD public room table | `ld_south/rooms.json` (~134 labeled rooms; corridor schema 1–8) |
| LE basemap JPGs | `le_north/floors/` — `eszaki_-1_emelet.jpg`, `eszaki_foldszint.jpg`, `eszaki_1_emelet.jpg`…`eszaki_7_emelet.jpg` |
| LE public room table | `le_north/rooms.json` |
| North A→B reference | `eszaki_route_planner/` (terkeptar / OpenLayers 2018) |
| BIS South catalog | `bis/south/` — **1696** rooms, floors `00`…`7`,`T`; educational `rooms_educational.json` (**849**) |
| BIS North catalog | `bis/north/` — **1974** rooms, floors `-4`…`11`; educational (**639**) |
| API archaeology | `bis/api/` (entities, filters, rooms-by-id, routing trials → **null** geometry) |

**Cookies / tokens:** **not in git** (and must stay out).

### Credits to preserve

- Floor artwork (sarkozigergo): **Héger Tamás**
- Aggregator page: **Sárközi Gergő**
- North planner: **Eszényi Krisztián** (ELTE Cartography & Geoinformatics, 2018)
- Official BIS: ELTE IIG (`bis.elte.hu`)

### Decisions frozen (2026-09-16)

| Decision | Choice |
|----------|--------|
| Basemap | sarkozigergo JPGs under `ld_south/floors/` + `le_north/floors/` — **permission still pending** (honesty) |
| Search nodes | BIS centroids/codes + public room tables |
| Routing geometry | Digitize our own graph — **do not** wait for BIS `routing.route` polylines |

### Exit criteria

- [x] Frozen inventory paths listed with date **2026-09-16**.
- [x] Basemap / search / no-wait-on-BIS-polylines decisions locked.
- [x] Cookies / tokens remain **out of git**.

---

## Phase 1 — Data model

**Status:** **DONE** — **2026-09-16**. Canonical: [`campus_map_research/schema/SCHEMA.md`](campus_map_research/schema/SCHEMA.md).

**Purpose:** one JSON-friendly schema for rooms, floors, graph nodes, edges, and Neptun↔BIS joins — before drawing edges.

### Entities (locked)

| Entity | Required fields |
|--------|-----------------|
| **Building** | `id` (`ld` \| `le`), `neptunPrefix` (`LD` \| `LE`), display names HU/EN |
| **Floor** | `buildingId`, `level` (int, e.g. −1…7), `bisSlug` (e.g. `00`,`0`…`7`), `basemapAsset`, `basemapWidth`/`Height` |
| **Room** | stable `id`, `codeBis`, `codeNeptun` (nullable until join), `name`, `floorId`, `centroid` (pixels), optional `centroidWgs`, `aliases[]`, `type` |
| **Node** | `id`, `floorId`, `kind` (`room` \| `corridor` \| `stair` \| `lift` \| `entrance` \| `poi`), `coord` (pixels), optional `roomId`, `verticalShaftId` |
| **Edge** | `from`, `to`, `weight` (length or cost), `bidirectional` (default true), optional `kind` / `restricted` / `floors` |
| **Join row** | `neptunCode` ↔ `bisRoomId` / `codeBis`, confidence (`exact` \| `heuristic` \| `manual`) |

### Coordinate policy (locked)

- **Primary (graph):** floor-local **basemap pixels** (`space: "basemapPx"`), origin top-left, tied to declared JPG size — routing without Mapbox.
- **Secondary:** optional WGS84 from BIS centroids (`space: "wgs84"`) for outdoor handoff / checks — not the walkable CRS.
- Sample: [`schema.example.ld.floor0.json`](campus_map_research/schema/schema.example.ld.floor0.json) (illustrative floor-0 fragment; **full** LD graph is Phase 2 [`graph/graph_ld.json`](campus_map_research/graph/graph_ld.json)).
- Join stub: [`joins_ld.stub.json`](campus_map_research/schema/joins_ld.stub.json) / `.csv`.

### Stairs / lifts

Stairs and lifts are **inter-floor edges**: one landing node per floor sharing `verticalShaftId`; vertical edges link consecutive landings (`verticalStair` / `verticalLift`). See SCHEMA.md.

### Exit criteria

- [x] Schema documented in `campus_map_research/schema/SCHEMA.md` with LD floor-0 example JSON.
- [x] Version field on package root (`schemaVersion`: **1**).
- [x] Explicit rule: stairs/lifts are **inter-floor edges** (same logical vertical shaft linked across floors).

---

## Phase 2 — Digitize LD graph fully

**Status:** **DONE** — MVP **2026-09-16**. Artifact: [`campus_map_research/graph/graph_ld.json`](campus_map_research/graph/graph_ld.json) · notes: [`graph/README.md`](campus_map_research/graph/README.md) · samples: [`graph/samples/ld_routes.md`](campus_map_research/graph/samples/ld_routes.md).

**Purpose:** walkable corridor graph for **South / Déli (LD)** on all student-relevant floors.

### Scope (LD)

| Item | Target |
|------|--------|
| Floors | **−1…7** (map label `00` = −1; ground = 0). Attic `T` optional / out of student path unless needed. |
| Corridors | Schema **1–8** + hubs (liftek, főlépcső, büfé, gates) per `delitomb_0.jpg` notes |
| Vertical | Stairs + lifts connecting consecutive floors; entrances as graph endpoints |
| Room pins | Educational / commonly booked rooms at minimum; prefer link to BIS educational subset |
| Basemap | `ld_south/floors/*.jpg` (or approved replacement) |

### Process

1. Trace corridors on each floor (Figma overlay, QGIS, or JSON editor — see [Tools](#tools)).
2. Place nodes at intersections, door mouths, stair/lift landings, entrances.
3. Connect rooms to nearest corridor node (short stub edges).
4. Add inter-floor edges for each vertical connector.
5. Run sample shortest paths A→B (tool or script) and record results.

### Validation samples (minimum)

Document at least **5** LD routes with expected floor changes, e.g.:

| # | From → To | Expect |
|---|-----------|--------|
| 1 | Same-floor corridor neighbors | No vertical edges |
| 2 | Ground entrance → mid-floor classroom | Uses lift **or** stair consistently |
| 3 | Floor −1 ↔ floor 1 via known stair | Correct shaft |
| 4 | Named hall (e.g. Bolyai) → another named hall | Alias resolves + path |
| 5 | Cross-corridor (e.g. 2 → 7) | Uses connecting corridor, not through walls |

### Exit criteria

- [x] Every floor −1…7 has a connected corridor component covering schema 1–8 (or documented dead-ends).
- [x] All lifts/stairs/entrances on those floors are nodes with inter-floor / outdoor links as applicable.
- [x] ≥5 A→B samples pass (path exists, sensible length, no wall-crossing).
- [x] Draft artifact `graph_ld.json` exists (may live under research until Phase 5 packaging).

**Honesty:** hub/door pixels are **semi-manual / approximate** (corridor-digit stubs + visual hubs), not CV-perfect doors. Attic `T` omitted. Refine pixels later; connectivity is complete for MVP.

---

## Phase 3 — Digitize LE graph fully

**Purpose:** same pipeline for **North / Északi (LE)**.

### Scope (LE)

| Item | Target |
|------|--------|
| Floors | Public JPG set **−1…7** as primary student surface. BIS floors outside that range (`-4`…`-2`, `8`…`11`) = **optional later**, not Phase 3 blockers. |
| LK | Usually folded into North on LE maps — treat as LE graph POIs / aliases, not a third building file unless needed. |
| Reference | Study `eszaki_route_planner/` UX/graph pattern; **do not** re-ship GeoJSON without Cartography permission. |

### Exit criteria

- [ ] Same connectivity bar as LD for floors −1…7.
- [ ] ≥5 A→B validation samples documented.
- [ ] Draft `graph_le.json` exists.
- [ ] Vertical connectors consistent with North floor plans.

---

## Phase 4 — Join tables + search aliases

**Purpose:** users type Neptun codes and hall names; graph resolves to nodes.

### Join

| Source A | Source B | Output |
|----------|----------|--------|
| Neptun-style (`LD 0.821`, `LD-0-805`, timetable strings) | BIS `LD-…` / room id | `joins_ld.json` / rows in package |
| Same for LE | BIS North codes | `joins_le.json` |

Confidence tags: automatic exact match vs manual override. Unmatched educational rooms stay searchable by BIS code only until joined.

### Aliases (named halls)

Seed from sarkozigergo / BIS names, e.g. Bolyai, Fejér Lipót, Rényi, Erdős Pál, Turán Pál, Déli Hali, … — map each alias → `roomId` or `nodeId`.

### Exit criteria

- [ ] Join coverage report: % of educational rooms with Neptun code match (target: document % honestly; aim high for LD educational subset).
- [ ] Alias list for known named halls on LD (+ LE).
- [ ] Search fixture list (query → expected node) for QA Phase 6.

---

## Phase 5 — Package deliverable

**Purpose:** one versioned folder (or release asset) ready to host or bundle — **still no Flutter UI**.

### Required files

| File | Role |
|------|------|
| `graph_ld.json` | LD nodes + edges + floor index |
| `graph_le.json` | LE nodes + edges + floor index |
| `joins_ld.json` / `joins_le.json` (or embedded) | Neptun↔BIS |
| `aliases.json` | Named-hall / search strings |
| Basemap assets | Floor JPGs (or WebP) per building/floor, stable names |
| `checksums.sha256` | Hashes of all package files |
| `ATTRIBUTION.md` | Credits + license status (see checklist) |
| `manifest.json` | `schemaVersion`, building list, asset map, package date |

### Distribution

- **Ready-to-bundle** under e.g. `docs/Technical/campus_map_package/` **or** GitHub Release asset / CDN — decide at packaging time.
- Prefer derived JSON + permitted basemaps over shipping BIS HTML/JS SPA.

### Exit criteria

- [ ] All files above present; checksums verify.
- [ ] `ATTRIBUTION.md` filled; unresolved licenses flagged **block ship**.
- [ ] Package loads in a **non-Flutter** checker (script or small HTML tool) and computes A→B for sample pairs.

---

## Phase 6 — QA matrix

**Purpose:** manual / tool route tests before declaring the map finished.

### Matrix (paper or checker tool)

| Check | LD | LE |
|-------|----|----|
| Same-floor A→B (3 pairs) | ☐ | ☐ |
| Cross-floor via stair | ☐ | ☐ |
| Cross-floor via lift | ☐ | ☐ |
| Entrance → classroom | ☐ | ☐ |
| Named-hall search → pin | ☐ | ☐ |
| Neptun code join → pin | ☐ | ☐ |
| Restricted / closed note surfaced (if modeled) | ☐ | ☐ |
| No obvious wall / outdoor shortcut | ☐ | ☐ |

### Exit criteria

- [ ] Matrix complete for **LD** and **LE** (agreed floor range).
- [ ] Failures filed as graph bugs (fix in Phase 2/3), not deferred to app UI.
- [ ] Owner sign-off: **“map finished”** for Phase A.

---

## Phase B — App integration (**later**, not started now)

Only after Phases **0–6** are done. Listed so product docs know the intended UI; **do not implement yet**.

| Item | Intent |
|------|--------|
| Login hub **Map** button | Open indoor map without requiring hallgato JWT (basemap + search). |
| A→B UI | Pick start/end (search / map tap); draw path on floor basemap; floor switcher. |
| Schedule deep-link | From timetable room code → map focused on that room (reuse `elte_room_code` semantics). |
| Packaging in app | Load Phase 5 JSON + assets from bundle or first-run download. |
| Optional | Deep-link / WebView to BIS for users with ELTE login — secondary, not a substitute for our graph. |

**Exit criteria for Phase B** (future): separate app release notes; version bump per `versioning.mdc` when shipping Android APK.

---

## Licensing / attribution checklist

Complete before any public binary includes map assets:

- [ ] **Héger Tamás** floor plans — written permission or confirmed public reuse terms; credit in-app + `ATTRIBUTION.md`.
- [ ] **Sárközi Gergő** aggregator — credit; confirm JPG redistribution.
- [ ] **Eszényi Krisztián / terkeptar** — credit; **no** wholesale GeoJSON reuse without Cartography dept OK.
- [ ] **BIS / ELTE IIG** — room catalogs used as derived data only; ask before shipping full inventories if redistribution is restricted; **no** cookies/tokens in package.
- [ ] Mapbox — only if we embed Mapbox ourselves (not required for Phase A pixel graphs).
- [ ] App Privacy / Terms — update Legal EN/RU/HU if map collects location (default: **no** GPS required for indoor graph).

---

## Out of scope (Phase A)

| Item | Why |
|------|-----|
| Live BIS API in the app | Auth wall (IdP); research-only dump |
| Waiting on `routing.route` polylines | Geometry not captured; digitize instead |
| Full 3D / VR | Product target is **2D** A→B |
| Offline-first sync policy | Optional later; package may ship in-bundle |
| LK as separate `graph_lk.json` | Fold into LE unless proven necessary |
| Flutter Map UI | Phase B only |
| Exam/course registration, tanterv, etc. | Unrelated product backlog |

---

## Tools

| Tool | Use |
|------|-----|
| **Figma** | Overlay corridors on floor JPGs; export node coords |
| **Polycam** (optional) | Capture reference photos / rough scans — **not** a substitute for the 2D graph |
| **JSON** (+ small Python/Dart script) | Author `graph_*.json`, shortest-path smoke tests |
| **QGIS / qgis2web** | Optional; study North planner layers |
| System Chrome + BIS | Optional second pass for centroid checks — not required for exit |

---

## Success definition — “map finished”

Phase A is **done** when **all** of the following are true:

1. **LD** and **LE** graphs cover agreed floors (−1…7) with corridors, vertical links, and entrances.
2. Package contains `graph_ld.json`, `graph_le.json`, basemaps, checksums, attribution.
3. Join + alias tables support Neptun-style codes and named halls for QA fixtures.
4. Phase 6 QA matrix passes (or only waived items are explicitly documented).
5. **No** Flutter map feature has been started under the guise of “just wiring” incomplete data.

Until then, the product remains on **external maps deep-link** only (`Open map` → Apple/Google building search).

---

## References

| Doc | Role |
|-----|------|
| [campus_map_research/README.md](campus_map_research/README.md) | Research dump index |
| [campus_map_research/schema/SCHEMA.md](campus_map_research/schema/SCHEMA.md) | Phase 1 data model (locked) |
| [BIS_IMPORT_REPORT.md](campus_map_research/BIS_IMPORT_REPORT.md) | BIS auth, catalogs, routing null |
| [TECHNICAL.md](TECHNICAL.md) | Product technical canon |
| [DEV_BLOG.md](DEV_BLOG.md) | Chronological diary |

---

*Owner / developer: **Nanda**.*
