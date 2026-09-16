# Step A — LD ground vs BIS hull (2026-09-16)

## Verdict

**Contiguous Déli silhouette: YES** after 1.8.1 reanchor. Room rings form one cluster (~107×114 m) matching official ground hull (~115×129 m). No second ~300 m north cluster / blank projection gap.

## What’s still wrong

| Issue | Evidence |
|-------|----------|
| **Holes inside footprint** | Grid fill of hull ≈ **57%** (bbox-cell proxy). Black gaps between rooms. |
| **Not a projection bug** | Poly span ≈ hull span; centroids lie in hull. |
| **Missing roomTypes** | Ground catalog **177**, bundled polys **143**. Gap **34** = **29 technical** + **5** null/`?` (ramps, outdoor bins). Captured MVT/`deli_rooms.geojson` has **0** `technical` rooms. |
| **Official BIS** | Uses `floorPlateColor` underlay under rooms (style) — plan holds shape even when rooms sparse. |

## Artifact

`VERIFY_LD_GROUND_A.svg` — gray = BIS floor hull, colored = app polys, red dots = missing catalog centroids.

## Next (ladder)

B view transform → C fetch technical/all types → D hull underlay → E per-floor footer.
