# Campus indoor map — data schema

**Status:** Phase 1 locked **2026-09-16**.  
**Owner:** Nanda.  
**Plan:** [CAMPUS_MAP_PLAN.md](../../CAMPUS_MAP_PLAN.md) · [RU](../../CAMPUS_MAP_PLAN.ru.md).

This schema describes the **map data package** (buildings, floors, rooms, graph nodes/edges, Neptun↔BIS joins). It is **not** Flutter UI. Digitization of LD/LE MVP graphs is **done** (Phases 2–3); package + QA are Phases 5–6 under [`../../campus_map_package/`](../../campus_map_package/).

## Files in this folder

| File | Role |
|------|------|
| `SCHEMA.md` | This document (canonical field rules) |
| `schema.example.ld.floor0.json` | One LD ground-floor sample (illustrative graph + real room codes) |
| `joins_ld.stub.json` | Sample Neptun ↔ BIS join rows (Phase 1 stub) |
| `joins_ld.stub.csv` | Same joins as CSV for spreadsheet editing |

**Phase 4 full joins** live under [`../joins/`](../joins/) (`joins_ld.json`, `joins_le.json`, `aliases.json`, `search_fixtures.json`).

## Package root

Every graph / floor package JSON **must** include:

```json
{
  "schemaVersion": 1,
  "packageKind": "floorGraph" | "buildingGraph" | "joins",
  "generatedAt": "YYYY-MM-DD",
  "notes": "optional human string"
}
```

- **`schemaVersion`:** integer. Bump only when breaking field names/semantics. Current = **`1`**.
- Phase 5 `manifest.json` will also carry `schemaVersion` for the whole deliverable. **Shipped package:** [`../../campus_map_package/`](../../campus_map_package/) (`schemaVersion`: **1**).

---

## Entities

### Building

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string | yes | `"ld"` \| `"le"` |
| `neptunPrefix` | string | yes | `"LD"` \| `"LE"` |
| `nameHu` | string | yes | e.g. `Déli Épület` |
| `nameEn` | string | yes | e.g. `South Building` |
| `address` | string | no | Postal / street line |
| `bisBuildingSlug` | string | no | e.g. `deli`, `eszaki` |

### Floor

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string | yes | Stable, e.g. `ld-f0` |
| `buildingId` | string | yes | `ld` \| `le` |
| `level` | int | yes | Student map level: **−1…7** (`00` on artwork = −1; ground = **0**) |
| `bisSlug` | string | yes | BIS floor token as in dump: `"00"`, `"0"`…`"7"`, `"T"` (attic optional) |
| `labelHu` / `labelEn` | string | no | Display labels |
| `basemapAsset` | string | yes | Relative path to JPG/WebP under research or package |
| `basemapWidth` | int | yes | Pixel width of basemap |
| `basemapHeight` | int | yes | Pixel height of basemap |
| `attribution` | string | no | Short credit line |

**Honesty:** basemap artwork = sarkozigergo JPGs (**Héger Tamás** / aggregator **Sárközi Gergő**). Redistribution permission **still pending** — do not ship in App Store / APK until checklist cleared.

### Room

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string | yes | Package-stable id, e.g. `ld-room-0-821` |
| `floorId` | string | yes | |
| `codeBis` | string | yes | Short BIS-style number, e.g. `0-821` |
| `bisRoomId` | int \| null | no | Numeric BIS `id` when known |
| `bisRoomCode` | string \| null | no | Full BIS code, e.g. `LD-0-821-01-12` |
| `codeNeptun` | string \| null | no | Canonical Neptun form, e.g. `LD 0.821` (filled via Join) |
| `name` | string | no | Prefer BIS / public table name |
| `type` | string | no | `tanterem`, `eloado`, `labor`, … (lowercase slug) |
| `aliases` | string[] | no | Named-hall search strings |
| `centroid` | object | yes | See [Coordinate system](#coordinate-system) |
| `centroidWgs` | object \| null | no | Optional WGS84 parallel |

### Node

Walkable graph vertex. Rooms attach via a **room** node (or a short stub edge from corridor → room).

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string | yes | e.g. `ld-n-f0-c8-hub` |
| `floorId` | string | yes | Same floor as the landing / pin |
| `kind` | string | yes | `room` \| `corridor` \| `stair` \| `lift` \| `entrance` \| `poi` |
| `coord` | object | yes | **Primary** graph coordinate (pixels) — see below |
| `roomId` | string \| null | no | Set when `kind` is `room` (or POI tied to a room) |
| `verticalShaftId` | string \| null | no | Required for `stair` / `lift` — shared across floors |
| `label` | string | no | Debug / digitizer label |

### Edge

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string | yes | |
| `from` | string | yes | Node id |
| `to` | string | yes | Node id |
| `weight` | number | yes | Length in **pixels** (or cost); for vertical edges use stair/lift cost policy |
| `bidirectional` | bool | no | Default **`true`** |
| `kind` | string | no | `corridor` \| `roomStub` \| `verticalStair` \| `verticalLift` \| `entrance` |
| `restricted` | bool \| string | no | e.g. after-hours note |
| `floors` | string[] | no | For vertical edges: the two `floorId`s involved |

### Join (Neptun ↔ BIS)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `neptunCode` | string | yes | Normalized display form, e.g. `LD 0.821` |
| `neptunAliases` | string[] | no | `LD-0-821`, `LD0.821`, timetable variants |
| `bisRoomId` | int \| null | no | |
| `codeBis` | string | yes | `0-821` |
| `bisRoomCode` | string \| null | no | `LD-0-821-01-12` |
| `roomId` | string \| null | no | Package Room.id when present |
| `confidence` | string | yes | `exact` \| `heuristic` \| `manual` |
| `notes` | string | no | |

Full join tables are Phase **4** — see [`../joins/`](../joins/). Stubs under this folder are samples only.

---

## Coordinate system

### Primary (graph / routing): floor-local **pixels**

- Origin: **top-left** of the floor basemap JPG (`basemapWidth` × `basemapHeight`).
- Axes: `x` right, `y` down (image convention).
- Node `coord` and Room `centroid` use:

```json
{ "x": 412.5, "y": 280.0, "space": "basemapPx" }
```

- Edge `weight` for same-floor edges ≈ Euclidean pixel distance (digitizer may round).
- Why primary: routing and path drawing work **without** Mapbox / WGS projection; matches Figma overlay on JPG.

### Secondary (search / outdoor handoff): **WGS84** from BIS

- Store optional:

```json
{ "lng": 19.062226632, "lat": 47.471869725, "space": "wgs84" }
```

- Source: BIS room `centroid` `[lng, lat]` in educational / catalog dumps.
- **Do not** use WGS as the walkable graph CRS for Phase A. Pixel graph is authoritative for A→B indoors.
- If both exist, pixel is for routing + basemap overlay; WGS is for future outdoor links / sanity checks only.

### Honesty on sample coords

`schema.example.ld.floor0.json` uses **placeholder** pixel positions for corridors/stairs (not yet digitized). Room `centroidWgs` values are **real** BIS centroids. Phase 2 replaces placeholder pixels by tracing on `ld_south/floors/deli_foldszint.jpg` (800×800).

---

## Stairs / lifts = inter-floor edges

**Rule (locked):** a vertical connector is modeled as:

1. One **landing node per floor** with the same `verticalShaftId` (`kind` = `stair` or `lift`).
2. **Inter-floor edges** between consecutive landings of that shaft (`kind` = `verticalStair` or `verticalLift`).
3. Same-floor corridor edges connect the landing to the corridor network — **not** a single multi-floor node.

```
floor 0:  … — corridor — [lift:ld-lift-A @ f0] — …
                              |  edge verticalLift
floor 1:  … — corridor — [lift:ld-lift-A @ f1] — …
```

- Do **not** put rooms from different floors on one node.
- Skip floors only if the shaft physically skips (document in `notes`); default is consecutive levels −1↔0↔1↔…↔7.
- Prefer lift vs stair via `weight` (e.g. higher cost for stairs) — policy can be tuned later; schema only requires the edge link.

---

## Basemap inventory (frozen Phase 0)

| Building | Path | Files |
|----------|------|-------|
| LD South | `../ld_south/floors/` | `deli_-1_emelet.jpg`, `deli_foldszint.jpg` (level 0), `deli_1_emelet.jpg`…`deli_7_emelet.jpg`, plus `delitomb_0.jpg` (corridor schema 1–8 overview) |
| LE North | `../le_north/floors/` | `eszaki_-1_emelet.jpg`, `eszaki_foldszint.jpg`, `eszaki_1_emelet.jpg`…`eszaki_7_emelet.jpg` |

Typical floor JPG size (LD/LE student floors): **800×800**. Overview `delitomb_0.jpg`: 481×481.

Search / labels: `../ld_south/rooms.json`, `../le_north/rooms.json`, BIS `../bis/south/rooms_educational.json`, `../bis/north/rooms_educational.json`.

**Not waiting on:** BIS `routing.route` polylines (null in research dump) — we digitize our own graph.

**Cookies / tokens:** never committed; remain out of git.

---

## Example

See [`schema.example.ld.floor0.json`](schema.example.ld.floor0.json) for one LD floor fragment (rooms + corridor stubs + lift/stair landings + one vertical edge tip). Join samples: [`joins_ld.stub.json`](joins_ld.stub.json).

---

*Owner / developer: **Nanda**.*
