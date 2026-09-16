# Campus map package — attribution & license status

**Package:** `elte-lagymanyos-ld-le` (Phase 5)  
**Owner / packager:** Nanda  
**Date:** 2026-09-16  
**Ship status:** **block ship** to App Store / GitHub APK until basemap redistribution is cleared (see checklist).

This folder is a **research + Phase A packaging** deliverable for Neptun ELTE indoor A→B (LD / LE). It is **not** wired into Flutter yet.

## Credits

| Credit | Role | Status |
|--------|------|--------|
| **Héger Tamás** | Floor-plan artwork (LD / LE basemap JPGs, via student maps) | Credit required; **redistribution permission PENDING** |
| **Sárközi Gergő** | Aggregator / student map site (`sarkozigergo.web.elte.hu/terkep/`) | Credit required; **JPG redistribution PENDING** |
| **Eszényi Krisztián** | 2018 Északi route planner (terkeptar) — UX/reference only | Credit; **no** wholesale GeoJSON reuse without Cartography dept OK |
| **ELTE IIG / BIS** (`bis.elte.hu`) | Official room catalogs used as **derived** join/search data | Research-derived joins only; ask before shipping full inventories if restricted |
| **Nanda** | Corridor graph digitization, joins, aliases, this package | Project owner |

Public source pages used during research:

- https://sarkozigergo.web.elte.hu/terkep/ (LD + LE maps)
- http://terkeptar.elte.hu/~campusrouting/utvonal/ (North A→B reference)
- https://bis.elte.hu/ (authenticated research dump; **no cookies/tokens in this package**)

## What is in this package

| Asset | Origin | Redistribution |
|-------|--------|----------------|
| `graph_ld.json` / `graph_le.json` | Digitized corridor graphs (Nanda / Phase 2–3) | OK to keep in repo as derived data |
| `joins_*.json` / `aliases.json` | Derived Neptun↔BIS mappings (Phase 4) | Derived; treat as research until BIS redistribution clarified for full catalogs |
| `basemaps/ld/*.jpg` / `basemaps/le/*.jpg` | Copies of Héger / Sárközi student-map JPGs from research dump | **PENDING permission** — included for Phase A packaging / QA only |
| `manifest.json` / `checksums.sha256` / checker | Package metadata (Nanda) | OK |

## Honesty — basemap permission

- Basemap artwork redistribution permission is **still PENDING**.
- Assets are included here because the research dump already contains them and Phase 5 needs a hostable folder for QA — **not** because App Store / APK shipping is cleared.
- **Block ship:** do **not** bundle these JPGs (or the whole package) into a public App Store build or GitHub Release APK until written permission or confirmed public reuse terms exist.
- Repo docs packaging for Phase A / Phase 6 QA is allowed with this attribution note.

## Checklist (from CAMPUS_MAP_PLAN)

- [ ] Héger Tamás floor plans — written permission or confirmed public reuse terms
- [ ] Sárközi Gergő aggregator — confirm JPG redistribution
- [ ] Eszényi Krisztián / terkeptar — credit only; no wholesale GeoJSON without Cartography OK
- [ ] BIS / ELTE IIG — derived joins only; ask before shipping full inventories if restricted
- [x] No cookies, session tokens, or personal screenshots in this package
- [x] Legal EN/RU/HU update only if map later collects location — **N/A until Flutter map** (default: no GPS for indoor graph; waived for Phase A)

## Contact

Product / package owner: **Nanda** (see repo README / Technical docs).
