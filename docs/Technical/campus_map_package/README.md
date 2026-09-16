# Campus map package (Phase 5–6)

Ready-to-host / ready-to-bundle indoor routing package for ELTE Lágymányos **LD (South)** + **LE (North)**.

**Status:** Phase **0–6** research package + QA **2026-09-16** · Phase B photo MVP UX **rejected** · App primary = **BIS FootPrint** (**1.8.3**, **2573/3112**) + LD+LE centerline graphs · IT faculty LD+LE · indoor map **still WIP** (polish paused) · Owner **Nanda**  
**Credits:** [ATTRIBUTION.md](ATTRIBUTION.md) (JPG not product primary).  
**Honesty:** Product map draws BIS FootPrint room polygons (not schematic ribbons / JPG). Graph for approximate A→B routing overlay. Not a finished official-BIS 1:1.

Plan: [CAMPUS_MAP_PLAN.md](../CAMPUS_MAP_PLAN.md) · Research: [campus_map_research/](../campus_map_research/README.md) · QA: [QA_REPORT.md](QA_REPORT.md)

## Layout

```
campus_map_package/
  manifest.json          schemaVersion, buildings, asset map, package date
  graph_ld.json          LD building graph (floors −1…7)
  graph_le.json          LE building graph (floors −1…7)
  joins_ld.json          Neptun↔BIS joins (LD)
  joins_le.json          Neptun↔BIS joins (LE)
  aliases.json           Named-hall / search strings
  search_fixtures.json   Search QA fixtures
  basemaps/ld/f-1.jpg … f7.jpg
  basemaps/le/f-1.jpg … f7.jpg
  checksums.sha256
  ATTRIBUTION.md
  check_package.py       Phase 5 smoke (checksums + sample A→B)
  run_qa.py              Phase 6 QA matrix → qa_matrix.json
  qa_matrix.json         Last machine QA result
  QA_REPORT.md           Human QA report + owner sign-off
  README.md
```

Stable basemap names: `basemaps/{ld|le}/f{level}.jpg` (`f-1`, `f0` … `f7`). Graph `basemapAsset` fields use these package-relative paths.

## Verify

```bash
python3 docs/Technical/campus_map_package/check_package.py
python3 docs/Technical/campus_map_package/run_qa.py
```

- `check_package.py` exit 0 = checksums + sample A→B for LD + LE.
- `run_qa.py` exit 0 = Phase 6 matrix has **no fails** (waives OK if documented in [QA_REPORT.md](QA_REPORT.md)).

**Last QA:** pass=41 · fail=0 · waive=2 (restricted/closed notes not on MVP rooms).
