# Campus map — finish-the-map-first plan

**Status (2026-09-16):** Phase **0–6** research package remains. Phase **B MVP (1.6.0)** photo UX **rejected**. **1.7.x** schematic / ribbon UX **superseded**. **1.8.0** = **BIS FootPrint polygon map**; **1.8.1** = catalog-centroid reanchor + ≈78.5° plan rotation; **1.8.2** = floor-hull fitBounds/underlay + denser tiles + catalog-bbox fill (**2972/3670**). Graph A→B affine≈WGS; IT faculty chip.


**Owner:** Nanda.  
**Decision (2026-09-16):** finish the indoor map completely first; only then implement in the app.  
**Canonical twin:** [CAMPUS_MAP_PLAN.ru.md](CAMPUS_MAP_PLAN.ru.md).

> Research dump: [`campus_map_research/`](campus_map_research/README.md) · Schema: [`campus_map_research/schema/SCHEMA.md`](campus_map_research/schema/SCHEMA.md) · BIS import: [BIS_IMPORT_REPORT.md](campus_map_research/BIS_IMPORT_REPORT.md) · Package: [`campus_map_package/`](campus_map_package/)  
> Related shipped maps (external deep-link only): `lib/Misc/elte_room_code.dart` — **not** indoor A→B.

---

## Post-MVP reset (2026-09-16) — paths + schematic UX

Owner rejected Phase B photo map and the **1.7.0** graph-edge glow look. Decisions:

| Topic | Choice |
|-------|--------|
| **Paths** | Routes follow **corridor centerlines**; smooth display (along-corridor chain + Chaikin). |
| **Visual map** | **BIS FootPrint polygons** (WGS84 room fills by type). Do **not** use graph ribbons or floor JPG as primary. |
| **Scope** | **IT faculty only (for now)** — LD (Déli / South) + LE (Északi / North) Lágymányos IK buildings. |
| **BIS polylines** | Still **null** in research dump — routes use derived graph; not a ship blocker. |
| **Phase B UI** | **1.8.0** ships BIS FootPrint polygons + IT faculty chip; search / floors / A→B / pre-login kept. |

### Schematic geometry

1. **LD floors −1…7:** `schematic_ld.json` — shell + courtyard hole + ribbons from corridor schema **1–8** (builder `build_schematics.py`).
2. **LE floors −1…7:** `schematic_le.json` — shell + two courtyard holes + zone ribbons (west/north/east/cross/south/wing).
3. Room nodes stay on the centerline graph; projected onto the schematic for pins/labels.
4. Labels: hide dense overlaps at low zoom; show more when zoomed.

---
## Goal

Deliver a **complete, attributable, QA’d indoor routing package** for ELTE Lágymányos **South (LD / Déli)** and **North (LE / Északi)** that the Neptun ELTE app can later load without depending on live BIS login or live `routing.route`.

**Map finished** means: Phase **0–6** exit criteria all met (see [Success definition](#success-definition-map-finished)). Flutter screens / login-hub Map / A→B are **Phase B** — **MVP shipped in 1.6.0**.

---

## Principles

> Historical Phase A rules — **Completed 2026-09-16 for Phase A MVP** (package + QA). Phase B (Flutter) MVP — **1.6.0**.

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
| **Phase 3 LE graph** | `graph/graph_le.json` · `graph/samples/le_routes.md` · `graph/build_graph_le.py` |
| **Phase 4 joins** | `joins/joins_ld.json` · `joins/joins_le.json` · `joins/aliases.json` · `joins/search_fixtures.json` · `joins/JOIN_COVERAGE.md` · `joins/build_joins.py` |
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
| Basemap | sarkozigergo JPGs under `ld_south/floors/` + `le_north/floors/` (research + optional debug underlay; credits in `ATTRIBUTION.md`) |
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

**Honesty:** hub/door pixels remain **semi-manual / approximate**. **1.6.1** LD builder chains door mouths along corridor centerlines (not hub-spoke). Attic `T` omitted. LE still on older hub-heuristic until the same pass. Full LD+LE pixel re-digitize is large and ongoing.

---

## Phase 3 — Digitize LE graph fully

**Status:** **DONE** — MVP **2026-09-16**. Artifact: [`campus_map_research/graph/graph_le.json`](campus_map_research/graph/graph_le.json) · notes: [`graph/README.md`](campus_map_research/graph/README.md) · samples: [`graph/samples/le_routes.md`](campus_map_research/graph/samples/le_routes.md).

**Purpose:** same pipeline for **North / Északi (LE)**.

### Scope (LE)

| Item | Target |
|------|--------|
| Floors | Public JPG set **−1…7** as primary student surface. BIS floors outside that range (`-4`…`-2`, `8`…`11`) = **optional later**, not Phase 3 blockers. |
| LK | Usually folded into North on LE maps — treat as LE graph POIs / aliases, not a third building file unless needed. |
| Reference | Study `eszaki_route_planner/` UX/graph pattern; **do not** re-ship GeoJSON without Cartography permission. |

### Exit criteria

- [x] Same connectivity bar as LD for floors −1…7.
- [x] ≥5 A→B validation samples documented.
- [x] Draft `graph_le.json` exists.
- [x] Vertical connectors consistent with North floor plans.

**Honesty:** hub/door pixels are **semi-manual / approximate** (zone stubs from room-number heuristic + visual double-loop / wing hubs), not CV-perfect doors. `rooms.json` `floor` often `?` — level inferred from code. LK bare codes folded into LE. BIS floors outside −1…7 omitted. Refine pixels later; connectivity is complete for MVP.

---

## Phase 4 — Join tables + search aliases

**Status:** **DONE** — **2026-09-16**. Canonical: [`campus_map_research/joins/`](campus_map_research/joins/README.md).

**Purpose:** users type Neptun codes and hall names; graph resolves to nodes.

### Join

| Source A | Source B | Output |
|----------|----------|--------|
| Neptun-style (`LD 0.821`, `LD-0-805`, timetable strings) | BIS `LD-…` / room id | [`joins/joins_ld.json`](campus_map_research/joins/joins_ld.json) |
| Same for LE (incl. LK-prefixed North codes) | BIS North codes | [`joins/joins_le.json`](campus_map_research/joins/joins_le.json) |

Confidence: `exact` = public/graph `codeBis` matched educational `roomNumber` (or Phase 2/3 `bisRoomId`); `heuristic` = derived Neptun form / educational-only (often `roomId` null). Regenerator: `joins/build_joins.py`.

**Coverage (honest):** LD educational **100%** have a Neptun join row; **~14.5%** already pin to MVP graph `roomId`. LE educational **~99.8%** joined; **~14.1%** on graph. Full matrix: [`JOIN_COVERAGE.md`](campus_map_research/joins/JOIN_COVERAGE.md).

### Aliases (named halls)

[`joins/aliases.json`](campus_map_research/joins/aliases.json) — Bolyai, Fejér Lipót, Rényi, Erdős Pál, Turán Pál, Ortvay, Eötvös, … → `roomId`/`nodeId`. Colloquial **Déli Hali** kept with `roomId` null (no BIS educational room).

### Search fixtures

[`joins/search_fixtures.json`](campus_map_research/joins/search_fixtures.json) — query → expected pin for Phase 6 QA (includes educational-only negatives).

### Exit criteria

- [x] Join coverage report: % of educational rooms with Neptun code match (documented honestly).
- [x] Alias list for known named halls on LD (+ LE).
- [x] Search fixture list (query → expected node) for QA Phase 6.

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

- **Chosen:** ready-to-bundle under [`docs/Technical/campus_map_package/`](campus_map_package/) (graphs, joins, aliases, basemaps, checksums, attribution, `check_package.py`).
- Prefer derived JSON + packaged basemaps over shipping BIS HTML/JS SPA. Credits: package `ATTRIBUTION.md`.

### Exit criteria

- [x] All files above present; checksums verify (`docs/Technical/campus_map_package/`).
- [x] `ATTRIBUTION.md` filled with credits.
- [x] Package loads in a **non-Flutter** checker (`check_package.py`) and computes A→B for sample pairs.

**Honesty:** package lives under [`campus_map_package/`](campus_map_package/) and is bundled in-app under `assets/campus_map/`.

---

## Phase 6 — QA matrix

**Status:** **DONE** — **2026-09-16**. Report: [`campus_map_package/QA_REPORT.md`](campus_map_package/QA_REPORT.md) · machine: [`qa_matrix.json`](campus_map_package/qa_matrix.json) · runner: [`run_qa.py`](campus_map_package/run_qa.py).

**Purpose:** manual / tool route tests before declaring the map finished.

### Matrix (paper or checker tool)

| Check | LD | LE |
|-------|----|----|
| Same-floor A→B (3 pairs) | ☑ pass | ☑ pass |
| Cross-floor via stair | ☑ pass | ☑ pass |
| Cross-floor via lift | ☑ pass | ☑ pass |
| Entrance → classroom | ☑ pass | ☑ pass |
| Named-hall search → pin | ☑ pass | ☑ pass |
| Neptun code join → pin | ☑ pass | ☑ pass |
| Restricted / closed note surfaced (if modeled) | ☑ **waive** | ☑ **waive** |
| No obvious wall / outdoor shortcut | ☑ pass | ☑ pass |

**Summary:** pass=41 · fail=0 · waive=2 (MVP rooms omit optional `restricted` / closed notes — documented, not deferred as a silent fail). Checksums + `search_fixtures.json` also verified by `run_qa.py`.

### Exit criteria

- [x] Matrix complete for **LD** and **LE** (agreed floor range −1…7).
- [x] Failures filed as graph bugs (fix in Phase 2/3), not deferred to app UI — **none open**.
- [x] Owner sign-off: **“map finished”** for Phase A (Nanda, 2026-09-16).

---

## Phase B — App integration (**MVP 1.6.0; transitional after reset**)

Phases **0–6** done as research. **MVP shipped** in **1.6.0** (photo UX rejected). **1.6.1** centerline. **1.7.0** graph-glow schematic **rejected**. **1.8.0** mall-style floor schematic + IT-only scope.

| Item | Intent |
|------|--------|
| Login hub **Map** button | Open indoor map without requiring hallgato JWT (basemap + search). |
| A→B UI | Pick start/end (search / map tap); draw path on floor basemap; floor switcher. |
| Schedule deep-link | From timetable room code → map focused on that room (reuse `elte_room_code` semantics). |
| Packaging in app | Load Phase 5 JSON + assets from bundle or first-run download. |
| Optional | Deep-link / WebView to BIS for users with ELTE login — secondary, not a substitute for our graph. |

**Exit criteria for Phase B MVP** (met in **1.6.0**; **not** accepted as product UX): pre-login Map, LD/LE, floor switcher, search, A→B path draw, honesty banner. Tag **v1.6.0**. Product direction after reset: see [Post-MVP reset](#post-mvp-reset-2026-09-16--paths--strategy-d--private-repo).

---

## Attribution

Credits for floor artwork and research sources: [`campus_map_package/ATTRIBUTION.md`](campus_map_package/ATTRIBUTION.md) (Héger Tamás, Sárközi Gergő, Eszényi Krisztián, ELTE IIG/BIS, Nanda). **No** cookies/tokens in package. Indoor map uses **no** GPS.

---

## Out of scope (Phase A)

| Item | Why |
|------|-----|
| Live BIS API in the app | Auth wall (IdP); research-only dump |
| Waiting on `routing.route` polylines | Geometry not captured; digitize instead |
| Full 3D / VR | Product target is **2D** A→B |
| Offline-first sync policy | Optional later; package may ship in-bundle |
| LK as separate `graph_lk.json` | Fold into LE unless proven necessary |
| Flutter Map UI | **Phase B MVP in 1.6.0** |
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

Phase A is **done** (**completed 2026-09-16**) when **all** of the following are true:

1. **LD** and **LE** graphs cover agreed floors (−1…7) with corridors, vertical links, and entrances.
2. Package contains `graph_ld.json`, `graph_le.json`, basemaps, checksums, attribution.
3. Join + alias tables support Neptun-style codes and named halls for QA fixtures.
4. Phase 6 QA matrix passes (or only waived items are explicitly documented).
5. **No** Flutter map feature has been started under the guise of “just wiring” incomplete data.

External maps deep-link remains for timetable room codes; indoor A→B is additional via Campus Map.

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
