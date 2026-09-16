# Campus map package (Phase 5)

Ready-to-host / ready-to-bundle indoor routing package for ELTE Lágymányos **LD (South)** + **LE (North)**.

**Status:** Phase 5 deliverable · **2026-09-16** · Owner **Nanda**  
**Not Flutter.** App integration is Phase B after Phase 6 QA.  
**Basemap permission:** **PENDING** — see [ATTRIBUTION.md](ATTRIBUTION.md) (**block ship** to App Store / APK).

Plan: [CAMPUS_MAP_PLAN.md](../CAMPUS_MAP_PLAN.md) · Research sources: [campus_map_research/](../campus_map_research/README.md)

## Layout

```
campus_map_package/
  manifest.json          schemaVersion, buildings, asset map, package date
  graph_ld.json          LD building graph (floors −1…7)
  graph_le.json          LE building graph (floors −1…7)
  joins_ld.json          Neptun↔BIS joins (LD)
  joins_le.json          Neptun↔BIS joins (LE)
  aliases.json           Named-hall / search strings
  search_fixtures.json   Search QA fixtures (Phase 6 helper)
  basemaps/ld/f-1.jpg … f7.jpg
  basemaps/le/f-1.jpg … f7.jpg
  checksums.sha256
  ATTRIBUTION.md
  check_package.py       Non-Flutter checker (checksums + sample A→B)
  README.md
```

Stable basemap names: `basemaps/{ld|le}/f{level}.jpg` (`f-1`, `f0` … `f7`). Graph `basemapAsset` fields use these package-relative paths.

## Verify

```bash
python3 docs/Technical/campus_map_package/check_package.py
```

Exit 0 = checksums match and sample A→B paths exist for LD + LE.
