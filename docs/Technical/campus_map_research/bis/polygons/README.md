# BIS room polygons (true FootPrint rings)

## Source

Same-origin Mapbox Vector Tiles (auth via ELTE login cookie in browser session):

`https://bis.elte.hu/tiles/rooms/{z}/{x}/{y}.pbf`

Discovered in Diorama `webpackChunk_diorama_web` style module: PostGIS `rooms` table, IFC `IfcSpace` → `FootPrint`, MVT layer `rooms` (also `room_centroids`, `room_label_lines`, `floors`).

**Do not commit cookies or Mapbox `pk.` tokens.** Tile host is `bis.elte.hu` (no token in URL).

## Counts (app bundle 1.8.2)

| Set | Polygons | Of which MVT FootPrint | Catalog bbox fill | Catalog (codes) |
|-----|----------|------------------------|-------------------|-----------------|
| South / LD | 1576 | 1375 | 201 (technical) | 1696 |
| North / LE | 1396 | 1198 | 198 (mostly technical) | 1974 |
| Combined | **2972** | 2573 | 399 | 3670 |

BIS MVT `rooms` layer exposes **0** `technical` FootPrints (checked denser z15–z18 tiles). Missing switcher-floor rooms are filled with **catalog bbox rectangles** (`fillSource: catalog-bbox`) so floors −1…7 are contiguous; shapes for those cells are approximate.

## Properties (sample)

`id` (catalog), `roomCode`, `roomNumber`, `roomName`, `roomType`, `floorId`, `buildingId`, `scope`, `__mvtId`, `__zoom`, `__tile`

App JSON also carries per-floor `hull` (BIS floor entity) and building `rotationAngle` ≈78.5°.

## Files

- `deli_rooms.geojson`, `eszaki_rooms.geojson`, `lagymanyos_rooms.geojson` — original MVT capture
- `deli_rooms_filled.geojson`, `eszaki_rooms_filled.geojson` — MVT + catalog-bbox (1.8.2)
- `deli_floor_<floorId>_rooms.geojson`, `eszaki_floor_<floorId>_rooms.geojson`
- `tiles_raw/*.pbf` — raw MVT (incl. denser z17/z18 from step C)
- `CAPTURE_SUMMARY.json`, `_tileset_probe.json`
- `VERIFY_STEP_A.md`, `VERIFY_LD_GROUND_A.svg` — silhouette verify notes
- `rebuild_polygons_182.py` — rebuild script for app assets

## Coordinate fix (1.8.1)

Raw MVT decode placed many rings with wrong absolute **latitude** (LD showed two clusters ~300 m apart). Room **shapes** matched catalog bboxes; only position was wrong. App assets and these GeoJSONs were **reanchored** so each ring’s centroid equals the BIS catalog `centroid`. Viewer also applies building `rotationAngle` ≈78.5° for plan-aligned display.

## View + coverage (1.8.2)

- **fitBounds** uses floor hull (not outlier room AABB).
- **Hull underlay** drawn under room fills (BIS-like floor plate).
- Footer: `Ground · LD 172 rooms` primary; global `2972/3670` secondary.
