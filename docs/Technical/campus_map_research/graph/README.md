# LD corridor graph (Phase 2)

**Status:** MVP done **2026-09-16**.  
**Owner:** Nanda.  
**Schema:** [`../schema/SCHEMA.md`](../schema/SCHEMA.md) (`schemaVersion` **1**).  
**Plan:** [CAMPUS_MAP_PLAN.md](../../CAMPUS_MAP_PLAN.md).

## Artifacts

| File | Role |
|------|------|
| [`graph_ld.json`](graph_ld.json) | Full LD building graph (floors −1…7) |
| [`build_graph_ld.py`](build_graph_ld.py) | Reproducible builder (hubs + stubs + verticals + samples) |
| [`samples/ld_routes.md`](samples/ld_routes.md) | ≥5 Dijkstra A→B node-id lists for QA |

Regenerate:

```bash
python3 docs/Technical/campus_map_research/graph/build_graph_ld.py
```

## Approximation level (honesty)

This is a **semi-manual / approximate** MVP — **not** computer-vision tracing of every door:

1. **Basemap size:** every student-floor JPG is **800×800** (`sips` / inventory). Overview `delitomb_0.jpg` is 481×481 (schema reference only).
2. **CRS:** `basemapPx`, origin top-left; **x increases toward Dunapart (east)**, **y increases south**. Shared hub template across floors (footprint is consistent enough for routing).
3. **Corridor hubs (1–8):** placed from visual inspection of `delitomb_0.jpg` + ground / −1 / 1 floor JPGs (west gate, corridor-8 wing, főlépcső, liftek, north/south courtyard loops, east spine).
4. **Room stubs:** every entry in [`../ld_south/rooms.json`](../ld_south/rooms.json) (**134**) gets a door-mouth + room node. Position = corridor digit from code (e.g. `0-821` → corridor **8**) along a corridor polyline + small offset — **estimated**, not pixel-perfect doors.
5. **BIS:** optional `centroidWgs` / ids filled when `roomNumber` matches educational or catalog dump; **routing stays in pixel space**.
6. **Vertical:** shafts `ld-lift-A/B`, `ld-stair-main`, four courtyard-corner stairs — consecutive floors −1↔0↔…↔7. Stair weight **90**, lift **40** (prefer lift).
7. **Attic `T`:** omitted (not in public JPG set / not needed for student path MVP).

Prefer **complete connectivity** now; refine door pixels later (overlay in Figma / QGIS).

## Coverage (builder stats)

| Metric | Value |
|--------|------:|
| Floors | **9** (−1…7) |
| Rooms / stubs | **134** / **134** |
| Nodes | **475** |
| Edges | **639** |
| Same-floor components | **1 connected component per floor** |

## QA samples

See [`samples/ld_routes.md`](samples/ld_routes.md). Expect:

| # | Pair | Expect |
|---|------|--------|
| 1 | `0-821` → `0-805` | Same floor, no vertical |
| 2 | west entrance → `0-412` | Ground only |
| 3 | `00-112` → `1-105` | Uses vertical stair/lift |
| 4 | Bolyai → Rényi | Cross-corridor via backbone |
| 5 | `0-220` → `0-412` | Corridors 2 → 4 |
| 6 | `0-821` → `3-219` | Multi-floor, prefers lift |

## Remaining gaps (before / during Phase 3 LE)

- Per-door pixel refinement on each floor JPG (esp. corridor-8 lecture row, named halls).
- Confirm lift/stair landings per floor against artwork (some floors may omit a shaft — currently assume all shafts on all floors).
- Entrances: west / Dunapart / north modeled on every floor template; only ground west gate is a primary outdoor endpoint for samples.
- Join tables / aliases → **Phase 4**.
- LE North graph → **Phase 3**.
- Basemap redistribution permission still **pending**.

*Owner / developer: **Nanda**.*
