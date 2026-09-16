# BIS room polygons (true FootPrint rings)

## Source

Same-origin Mapbox Vector Tiles (auth via ELTE login cookie in browser session):

`https://bis.elte.hu/tiles/rooms/{z}/{x}/{y}.pbf`

Discovered in Diorama `webpackChunk_diorama_web` style module: PostGIS `rooms` table, IFC `IfcSpace` → `FootPrint`, MVT layer `rooms` (also `room_centroids`, `room_label_lines`, `floors`).

**Do not commit cookies or Mapbox `pk.` tokens.** Tile host is `bis.elte.hu` (no token in URL). Newer captures may arrive **gzip-wrapped** — gunzip before `mapbox_vector_tile.decode`.

## Counts (app bundle 1.8.3)

| Set | Polygons (MVT FootPrint) | Catalog bbox fill | Catalog (codes) | Skipped (no FootPrint) |
|-----|--------------------------|-------------------|-----------------|------------------------|
| South / LD | **1375** | **0** | 1661 | 201 (all technical) |
| North / LE | **1198** | **0** | 1451 | 198 (197 technical + 1 other) |
| Combined | **2573** | **0** | 3112 | 399 |

BIS MVT `rooms` layer exposes **0** `technical` FootPrints (checked denser z15–z19). **1.8.3 drops catalog-bbox fake rooms** (they formed ugly diagonal square chains). Continuous plan silhouette comes from the **floorPlate hull underlay** + true FootPrint fills.

### LD ground (floor 0) before → after

| Metric | 1.8.2 | 1.8.3 |
|--------|-------|-------|
| Bundled polys | 172 (143 MVT + 29 bbox) | **143 MVT** |
| Catalog-bbox | 29 technical squares | **0** |
| Continuous fill | hull + bbox squares | **hull floorPlate** only |

## Official light palette (app painter)

From BIS legend HTML: Educational `#FFFFBE`, Hallway `#E0DBD1`, Social `#A0A0FF`, Administrative `#EDA8A7`, Misc `#6E9B8C`, Outdoor `#FF6419`, floorPlate ≈ `#EADCD1`. Thin dark strokes; `roomNumber` centered in polygon when space allows; tap → name card.

## Properties (sample)

`id` (catalog), `roomCode`, `roomNumber`, `roomName`, `roomType`, `floorId`, `buildingId`, `scope`, `__mvtId`, `__zoom`, `__tile`

App JSON also carries per-floor `hull` (BIS floor entity) and building `rotationAngle` ≈78.5°.

## Files

- `deli_rooms.geojson`, `eszaki_rooms.geojson`, `lagymanyos_rooms.geojson` — original MVT capture
- `deli_rooms_filled.geojson`, `eszaki_rooms_filled.geojson` — MVT-only (1.8.3; no bbox)
- `deli_floor_<floorId>_rooms.geojson`, `eszaki_floor_<floorId>_rooms.geojson`
- `tiles_raw/*.pbf` — raw MVT (incl. denser z17–z19 from step D)
- `CAPTURE_SUMMARY.json`, `_tileset_probe.json`
- `VERIFY_STEP_A.md`, `VERIFY_LD_GROUND_A.svg` — silhouette / coverage notes
- `rebuild_polygons_182.py` — prior bbox-fill rebuild
- `rebuild_polygons_183.py` — MVT-only rebuild (1.8.3)

## Coordinate fix (1.8.1)

Raw MVT decode placed many rings with wrong absolute **latitude**. App assets reanchored so each ring’s centroid equals the BIS catalog `centroid`. Viewer applies building `rotationAngle` ≈78.5° for plan-aligned display.

## View + coverage (1.8.3)

- **fitBounds** uses floor hull (not outlier room AABB).
- **Hull underlay** (`floorPlateColor`) drawn under room fills.
- Footer: `Ground · LD 143 rooms` primary; global `2573/3112` secondary.
