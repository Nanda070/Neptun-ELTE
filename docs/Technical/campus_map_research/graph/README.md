# Corridor graphs (Phase 2 LD + Phase 3 LE)

**Status:** LD+LE centerline passes **2026-09-16** · app UX **Strategy D schematic (1.7.0)** · Owner **Nanda**.  
**Schema:** [`../schema/SCHEMA.md`](../schema/SCHEMA.md) (`schemaVersion` **1**).  
**Plan:** [CAMPUS_MAP_PLAN.md](../../CAMPUS_MAP_PLAN.md) (Strategy D schematic + centerline paths).

## Artifacts

| File | Role |
|------|------|
| [`graph_ld.json`](graph_ld.json) | Full LD building graph (floors −1…7) — **centerline-chained** door mouths |
| [`build_graph_ld.py`](build_graph_ld.py) | Reproducible LD builder (centerline densify + chain) |
| [`samples/ld_routes.md`](samples/ld_routes.md) | ≥5 Dijkstra A→B for LD QA |
| [`graph_le.json`](graph_le.json) | Full LE building graph (floors −1…7) — **centerline-chained** zone mouths |
| [`build_graph_le.py`](build_graph_le.py) | Reproducible LE builder (centerline densify + chain) |
| [`samples/le_routes.md`](samples/le_routes.md) | ≥5 Dijkstra A→B for LE QA |

Regenerate:

```bash
python3 docs/Technical/campus_map_research/graph/build_graph_ld.py
python3 docs/Technical/campus_map_research/graph/build_graph_le.py
```

---

## LD (South / Déli) — Phase 2 + centerline pass

### Approximation level (honesty)

Still **semi-manual / approximate** — **not** CV door tracing — but **1.6.1** fixes the worst crooked-path cause:

1. **Basemap size:** every student-floor JPG is **800×800**. Overview `delitomb_0.jpg` is 481×481 (schema reference only).
2. **CRS:** `basemapPx`, origin top-left; **x increases toward Dunapart (east)**, **y increases south**. Shared hub template across floors.
3. **Corridor hubs (1–8):** placed from visual inspection of `delitomb_0.jpg` + ground / −1 / 1 floor JPGs.
4. **Centerline chain (1.6.1):** densified waypoints on `CORRIDOR_POLY` + door mouths sorted by `t` and **chained along the corridor** (no hub-spoke V-detours). Diagonal courtyard backbone hops removed.
5. **Room stubs:** every entry in [`../ld_south/rooms.json`](../ld_south/rooms.json) (**134**) gets a door-mouth + room node. Position = corridor digit + ordinal along polyline — **estimated**.
6. **BIS:** optional `centroidWgs` / ids when `roomNumber` matches; **routing stays in pixel space**. Official BIS route polylines still **null**.
7. **Vertical:** shafts `ld-lift-A/B`, `ld-stair-main`, four courtyard-corner stairs — consecutive −1↔0↔…↔7. Stair weight **90**, lift **40**.
8. **Attic `T`:** omitted.

### Coverage (LD)

| Metric | Value |
|--------|------:|
| Floors | **9** (−1…7) |
| Rooms / stubs | **134** / **134** |
| Nodes | **~664** (after centerline densify) |
| Edges | **~819** |
| Same-floor components | **1 connected component per floor** |

### QA samples (LD)

See [`samples/ld_routes.md`](samples/ld_routes.md).

---

## LE (North / Északi) — Phase 3 + centerline pass

### Approximation level (honesty)

Still **semi-manual / approximate** — **not** CV door tracing — but **1.7.0** applies the same centerline chain as LD:

1. **Basemap size:** student-floor JPGs **800×800** under [`../le_north/floors/`](../le_north/floors/).
2. **CRS:** `basemapPx`, origin top-left. On LE artwork **Dunapart is LEFT (west)**; **x→east**, **y↓**. Shared hub template across floors −1…7.
3. **Corridor hubs:** double-courtyard **outer loop** + **cross corridor** + **south wing (hajóorr)** + entrances / lifts / stairs / POIs.
4. **Centerline chain (1.7.0):** densified waypoints on `ZONE_POLY` + door mouths sorted by `t` and **chained along the zone** (no hub-spoke V-detours).
5. **Room stubs:** every entry in [`../le_north/rooms.json`](../le_north/rooms.json) (**92**) stubbed. Level often inferred from code. Zone heuristic still approximate.
6. **LK:** bare codes folded into LE graph.
7. **BIS:** optional WGS / ids when catalog matches; routing stays in pixels. `routing.route` still **null**.
8. **Vertical:** consecutive −1↔0↔…↔7. Stair **90**, lift **40**.
9. **Out of Phase 3:** BIS floors `-4`…`-2` and `8`…`11` (no public JPG in this set).

### Coverage (LE)

| Metric | Value |
|--------|------:|
| Floors | **9** (−1…7) |
| Rooms / stubs | **92** / **92** |
| Nodes | **625** |
| Edges | **888** |
| Same-floor components | **1 connected component per floor** |

### QA samples (LE)

See [`samples/le_routes.md`](samples/le_routes.md). Expect:

| # | Pair | Expect |
|---|------|--------|
| 1 | `0.81` → `0.83` | Same floor, no vertical |
| 2 | Dunapart entrance → `0.81` | Ground only |
| 3 | `-1.53` → `1.71` | Uses vertical stair/lift |
| 4 | Ortvay → Eötvös | Named-hall neighbors |
| 5 | `0.100A` → `0.89` | Cross-zone west → east |
| 6 | `0.81` → `3.67` | Multi-floor, prefers lift |
| 7 | `039` → `115` | LK / hajóorr wing path |

## Remaining gaps

- Per-door pixel refinement on each floor JPG (optional polish).
- **Schematic UX (1.7.1):** mall-style floor polygons in `schematic_*.json`; graph for routing. BIS `routing.route` null in research.
- Confirm lift/stair landings per floor against artwork (MVP assumes all shafts on all floors).
- Join tables / aliases → **Phase 4 done** ([`../joins/`](../joins/)).
- Package + checksums → **Phase 5 done**; QA → **Phase 6 done** ([`../../campus_map_package/QA_REPORT.md`](../../campus_map_package/QA_REPORT.md)).
- JPG basemaps are legacy/debug (not product primary; FootPrint/MVT is).
- Repo **private** while strategy/assets unsettled.

*Owner / developer: **Nanda**.*
