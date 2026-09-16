# Campus map Phase 6 — QA report

**Date:** 2026-09-16  
**Owner sign-off:** **Nanda** — Phase A **“map finished”** for MVP (LD + LE, floors −1…7).  
**Package:** [`campus_map_package/`](./) · Machine result: [`qa_matrix.json`](qa_matrix.json) · Runner: [`run_qa.py`](run_qa.py)

**Verdict:** **PASS** — `pass=41` · `fail=0` · `waive=2` (restricted/closed notes not modeled on MVP rooms).

**Honesty:** Credits in [ATTRIBUTION.md](ATTRIBUTION.md). App ships mall-style schematic (**1.7.1+**); Phase A QA baseline unchanged. Failures would be graph bugs (Phase 2/3), not app UI — none open.

## How to re-run

```bash
python3 docs/Technical/campus_map_package/check_package.py   # Phase 5 smoke
python3 docs/Technical/campus_map_package/run_qa.py           # Phase 6 matrix → qa_matrix.json
```

Exit `0` = no fails (waives allowed if documented here / in `qa_matrix.json`).

## Matrix (plan § Phase 6)

| Check | LD | LE |
|-------|----|----|
| Same-floor A→B (3 pairs) | pass | pass |
| Cross-floor via stair | pass | pass |
| Cross-floor via lift | pass | pass |
| Entrance → classroom | pass | pass |
| Named-hall search → pin | pass | pass |
| Neptun code join → pin | pass | pass |
| Restricted / closed note surfaced (if modeled) | **waive** | **waive** |
| No obvious wall / outdoor shortcut | pass | pass |

Also verified (not separate matrix rows): **checksums** (`checksums.sha256`, 30 package files; excludes regenerating `qa_matrix.json`) and all **`search_fixtures.json`** rows (11 positive + 3 educational-only negatives).

## Sample evidence

| Building | Check | Detail |
|----------|-------|--------|
| LD | same-floor | `0-821`→`0-805` hops=4 cost=259.8 |
| LD | stair (lifts forbidden) | `0-206`→`2-107` uses `verticalStair` |
| LD | lift (stairs forbidden) | `0-206`→`2-107` uses `verticalLift` |
| LD | entrance | west entrance → `0-412` |
| LD | named hall | Bolyai / Fejér Lipót / Rényi → expected nodes |
| LD | Neptun join | `LD 0.821`, `LD-0-805`, `LD 00.112` → pins |
| LE | same-floor | `0.81`→`0.83`, west→east, `039`→Ortvay |
| LE | stair / lift | `0.100A`→`2.104` forced vertical kinds OK |
| LE | entrance | Dunapart → Ortvay (`0.81`) |
| LE | named hall | Ortvay / Eötvös / Rybár István → pins |
| LE | Neptun join | `LE 0.81`, `LE-0-83`, `LE -1.53` → pins |
| both | topology | same-floor edges stay on floor; vertical Δlevel=1; no room↔room edges; no corridor weight >900 |

## Waives (explicit)

| ID | Why |
|----|-----|
| `ld-restricted` / `le-restricted` | Schema allows optional `restricted` / notes; MVP `rooms[]` do **not** copy public-table strings (`16 után zárt`, `zárt terem`, …). Surfacing is deferred until Phase B UI or a dedicated graph annotation pass — **not** a hidden fail. |

## Exit criteria

- [x] Matrix complete for **LD** and **LE** (floors −1…7).
- [x] Failures filed as graph bugs — **none** (0 fails).
- [x] Owner sign-off: **“map finished”** for Phase A (MVP package + QA).

## Success definition (Phase A)

1. LD + LE graphs cover −1…7 with corridors, vertical links, entrances — **yes**.  
2. Package has graphs, basemaps, checksums, attribution — **yes**.  
3. Joins + aliases support Neptun codes and named halls for fixtures — **yes**.  
4. Phase 6 QA passes (only documented waives) — **yes**.  
5. No Flutter map feature started — **yes**.

**Next:** Phase **B** (Flutter Map UI) only when product chooses; still blocked for binary ship until basemap permission clears.
