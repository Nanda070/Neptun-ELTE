# Step A — LD ground vs BIS hull (updated 1.8.3)

## Verdict

**Contiguous Déli silhouette: YES** (plan rotation + hull fitBounds). Room rings form one cluster matching official ground hull.

## Coverage (LD floor 0)

| Metric | 1.8.2 (before) | 1.8.3 (after) |
|--------|----------------|---------------|
| Catalog rooms (switcher) | 177 | 177 |
| Bundled polygons | 172 (143 MVT + 29 bbox) | **143 MVT only** |
| Catalog-bbox fakes | 29 technical squares | **0** (dropped) |
| Missing vs catalog | 5 null/`?` + 0 with bbox | **34** (29 technical + 5 other) — no fake rooms |
| Continuous fill | hull underlay + bbox squares | **hull underlay** (floorPlate) only |

## Why bbox dropped

BIS MVT `rooms` layer exposes **0** `technical` FootPrints even after denser z17–19 refetch. Catalog bbox rectangles formed ugly diagonal square chains; official look uses true FootPrints + warm `floorPlateColor` underlay.

## Official palette (app 1.8.3)

From BIS legend HTML: Educational `#FFFFBE`, Hallway `#E0DBD1`, Social `#A0A0FF`, Administrative `#EDA8A7`, Misc `#6E9B8C`, Outdoor `#FF6419`, floorPlate `#EADCD1`.

## Artifact

`VERIFY_LD_GROUND_A.svg` — prior silhouette check still valid for cluster/hull alignment.
