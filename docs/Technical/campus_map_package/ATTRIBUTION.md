# Campus map package — attribution

**Package:** `elte-lagymanyos-ld-le`  
**Owner / packager:** Nanda  
**Date:** 2026-09-16

This folder is the indoor A→B package for Neptun ELTE (LD / LE — IT faculty Lágymányos).

## Credits

| Credit | Role |
|--------|------|
| **Héger Tamás** | Floor-plan artwork (LD / LE basemap JPGs, via student maps) |
| **Sárközi Gergő** | Aggregator / student map site (`sarkozigergo.web.elte.hu/terkep/`) |
| **Eszényi Krisztián** | 2018 Északi route planner (terkeptar) — UX/reference |
| **ELTE IIG / BIS** (`bis.elte.hu`) | Official room catalogs used as derived join/search data |
| **Nanda** | Corridor graph, floor schematics, joins, aliases, this package |

Public source pages used during research:

- https://sarkozigergo.web.elte.hu/terkep/ (LD + LE maps)
- http://terkeptar.elte.hu/~campusrouting/utvonal/ (North A→B reference)
- https://bis.elte.hu/ (research dump; **no cookies/tokens in this package**)

## What is in this package

| Asset | Origin |
|-------|--------|
| `graph_ld.json` / `graph_le.json` | Digitized corridor graphs (routing) |
| `schematic_ld.json` / `schematic_le.json` | Mall-style floor polygons (shell + corridor ribbons) — visual map |
| `joins_*.json` / `aliases.json` | Derived Neptun↔BIS mappings |
| `basemaps/ld/*.jpg` / `basemaps/le/*.jpg` | Floor artwork (optional debug underlay in app) |
| `manifest.json` / `checksums.sha256` / checker | Package metadata |

## Honesty

- Product map UI draws **schematic polygons**, not the JPG as primary view, and **not** graph-edge topology as the building shape.
- Scope in app: **IT faculty** buildings LD (South) + LE (North) for now.
- BIS `routing.route` geometry was null in research; routes use the derived centerline graph.
