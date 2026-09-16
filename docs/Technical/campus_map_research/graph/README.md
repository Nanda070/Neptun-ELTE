# Corridor graphs (Phase 2 LD + Phase 3 LE)

**Status:** LD centerline pass **2026-09-16 (1.6.1)** · LE still hub-heuristic MVP · Owner **Nanda**.  
**Schema:** [`../schema/SCHEMA.md`](../schema/SCHEMA.md) (`schemaVersion` **1**).  
**Plan:** [CAMPUS_MAP_PLAN.md](../../CAMPUS_MAP_PLAN.md) (post-MVP reset: centerline paths + Strategy D).

## Artifacts

| File | Role |
|------|------|
| [`graph_ld.json`](graph_ld.json) | Full LD building graph (floors −1…7) — **centerline-chained** door mouths |
| [`build_graph_ld.py`](build_graph_ld.py) | Reproducible LD builder (centerline densify + chain) |
| [`samples/ld_routes.md`](samples/ld_routes.md) | ≥5 Dijkstra A→B for LD QA |
| [`graph_le.json`](graph_le.json) | Full LE building graph (floors −1…7) — hub-heuristic until next pass |
| [`build_graph_le.py`](build_graph_le.py) | Reproducible LE builder |
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

## LE (North / Északi) — Phase 3

### Approximation level (honesty)

Same original MVP bar as LD **before** the centerline pass — **semi-manual / approximate** hub-spoke (LE centerline still **TODO**):

1. **Basemap size:** student-floor JPGs **800×800** under [`../le_north/floors/`](../le_north/floors/).
2. **CRS:** `basemapPx`, origin top-left. On LE artwork **Dunapart is LEFT (west)**; **x→east**, **y↓**. Shared hub template across floors −1…7 (footprint consistent enough for routing).
3. **Corridor hubs:** double-courtyard **outer loop** + **cross corridor** + **south wing (hajóorr)** + entrances (Dunapart / Északi / Dél), lifts, stairs, büfé/aula POIs — from visual inspection of `eszaki_foldszint` / −1 / 1 / 2 JPGs.
4. **Room stubs:** every entry in [`../le_north/rooms.json`](../le_north/rooms.json) (**92**) stubbed. Public `floor` field is often `?` — **level inferred from code** (`-1.53`, `0.81`, bare `039` / `115`). Zone = room-number heuristic (west / north / east / cross / wing) + ordinal along zone polyline — **estimated**, not pixel-perfect doors.
5. **LK:** bare codes (`039`, `058`…, `115` hajóorr, …) folded into the LE graph as room stubs (not a separate `graph_lk.json`).
6. **BIS:** optional WGS / ids when catalog `roomNumber` / `LÉ-` / `LK-` codes match; routing stays in pixels.
7. **Vertical:** `le-lift-A/B`, `le-stair-main`, NW/NE/SW + wing stairs — consecutive −1↔0↔…↔7. Stair **90**, lift **40**.
8. **Out of Phase 3:** BIS floors `-4`…`-2` and `8`…`11` (no public JPG in this set).

Prefer **complete connectivity** now; apply the same centerline chain as LD next. Do **not** re-ship terkeptar GeoJSON without Cartography permission.

### Coverage (LE)

| Metric | Value |
|--------|------:|
| Floors | **9** (−1…7) |
| Rooms / stubs | **92** / **92** |
| Nodes | **454** |
| Edges | **600** |
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

- **LE centerline pass** (same as LD 1.6.1).
- Per-door pixel refinement on each floor JPG (optional polish).
- **Strategy D** official/authorized 2D basemap (photo JPG not final product map).
- Confirm lift/stair landings per floor against artwork (MVP assumes all shafts on all floors).
- Join tables / aliases → **Phase 4 done** ([`../joins/`](../joins/)).
- Package + checksums → **Phase 5 done**; QA → **Phase 6 done** ([`../../campus_map_package/QA_REPORT.md`](../../campus_map_package/QA_REPORT.md)).
- Basemap redistribution permission still **pending** (**block ship** as final artwork).
- Repo **private** while strategy/assets unsettled.

*Owner / developer: **Nanda**.*
