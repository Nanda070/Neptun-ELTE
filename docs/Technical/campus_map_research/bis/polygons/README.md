# BIS room polygons (true FootPrint rings)

## Source

Same-origin Mapbox Vector Tiles (auth via ELTE login cookie in browser session):

`https://bis.elte.hu/tiles/rooms/{z}/{x}/{y}.pbf`

Discovered in Diorama `webpackChunk_diorama_web` style module: PostGIS `rooms` table, IFC `IfcSpace` → `FootPrint`, MVT layer `rooms` (also `room_centroids`, `room_label_lines`, `floors`).

**Do not commit cookies or Mapbox `pk.` tokens.** Tile host is `bis.elte.hu` (no token in URL).

## Counts (deduped by `scope`)

| Set | Polygons | Catalog join (`roomCode`/`scope` → catalog `id`) |
|-----|----------|--------------------------------------------------|
| South / deli | 1403 | 1403 / 1403 |
| North / eszaki | 1218 | 1218 / 1218 |
| Combined | 2621 | 2621 |

Catalogs are larger (south 1696, north 1974) — leftover rooms likely lack FootPrint geom or sit outside fetched tiles/ACL.

## Properties (sample)

`id` (catalog), `roomCode`, `roomNumber`, `roomName`, `roomType`, `floorId`, `buildingId`, `scope`, `__mvtId`, `__zoom`, `__tile`

## Files

- `deli_rooms.geojson`, `eszaki_rooms.geojson`, `lagymanyos_rooms.geojson`
- `deli_floor_<floorId>_rooms.geojson`, `eszaki_floor_<floorId>_rooms.geojson`
- `tiles_raw/*.pbf` — raw MVT
- `CAPTURE_SUMMARY.json`, `_tileset_probe.json`

## Note on `queryRenderedFeatures`

Mapbox map facade was found (`value.maps.map.getMap()`), but `getStyle` / `queryRenderedFeatures` failed (`Style is not done loading` / `featuresets`). Tile endpoint capture succeeded instead.

## Coordinate fix (1.8.1)

Raw MVT decode placed many rings with wrong absolute **latitude** (LD showed two clusters ~300 m apart). Room **shapes** matched catalog bboxes; only position was wrong. App assets and these GeoJSONs were **reanchored** so each ring’s centroid equals the BIS catalog `centroid`. Viewer also applies building `rotationAngle` ≈78.5° for plan-aligned display.
