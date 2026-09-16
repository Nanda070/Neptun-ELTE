# Phase 4 — Join coverage report

**Generated:** 2026-09-16
**Owner:** Nanda

Honesty: Neptun codes for educational rooms are **derived** from BIS `roomNumber` / `roomCode` (and graph `codeNeptun` when the room is on the student map). We do **not** have a full timetable dump of every Neptun string; `exact` means roomNumber ↔ public/graph code match (or Phase 2/3 BIS id already on the graph room).

## LD (South / Déli)

| Metric | Value |
|--------|------:|
| Educational rooms (BIS) | 849 |
| Join rows | 860 |
| Graph rooms (MVP) | 134 |
| Graph rooms with `bisRoomId` | 132 |
| Educational rows with Neptun join (unique BIS id) | 100.0% |
| Educational rows pinned to graph `roomId` (unique BIS id) | 14.49% |
| Confidence `exact` (join rows) | 132 |
| Confidence `heuristic` (join rows) | 728 |
| Confidence `manual` (join rows) | 0 |

_Note:_ Public table slash-subrooms (e.g. 00-803/2) may share one BIS id; percentages use unique bisRoomId.

## LE (North / Északi + LK codes in North catalog)

| Metric | Value |
|--------|------:|
| Educational rooms (BIS) | 639 |
| Join rows | 649 |
| Graph rooms (MVP) | 92 |
| Graph rooms with `bisRoomId` | 90 |
| Educational rows with Neptun join (unique BIS id) | 99.84% |
| Educational rows pinned to graph `roomId` (unique BIS id) | 14.08% |
| Confidence `exact` (join rows) | 99 |
| Confidence `heuristic` (join rows) | 550 |
| Confidence `manual` (join rows) | 0 |

_Note:_ Public table slash-subrooms (e.g. 00-803/2) may share one BIS id; percentages use unique bisRoomId.

## Aliases

- Named-hall / search alias rows: **346**
- With graph `roomId`: **344**

## Search fixtures

- Fixture queries for Phase 6: **14** (`search_fixtures.json`)

## Files

| File | Role |
|------|------|
| `joins_ld.json` | Neptun ↔ BIS for South |
| `joins_le.json` | Neptun ↔ BIS for North (incl. LK-prefixed codes) |
| `aliases.json` | Named halls → room/node |
| `search_fixtures.json` | query → expected pin |
| `build_joins.py` | Regenerator |

*Owner / developer: **Nanda**.*
