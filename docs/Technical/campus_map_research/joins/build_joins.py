#!/usr/bin/env python3
"""Phase 4 — Neptun ↔ BIS joins + search aliases + fixtures.

Reads:
  ../graph/graph_ld.json, graph_le.json
  ../bis/south|north/rooms_educational.json
  ../ld_south/rooms.json, ../le_north/rooms.json (coverage cross-check)

Writes:
  joins_ld.json, joins_le.json
  aliases.json
  search_fixtures.json
  JOIN_COVERAGE.md
"""

from __future__ import annotations

import json
import re
import unicodedata
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESEARCH = ROOT.parent
GRAPH = RESEARCH / "graph"
BIS = RESEARCH / "bis"
TODAY = date.today().isoformat()

# Named-hall seeds that must appear even if alias extraction is thin.
MANUAL_ALIAS_SEEDS = [
    # LD
    ("Bolyai", "ld", "0-821"),
    ("Bolyai János", "ld", "0-821"),
    ("Bolyai Janos", "ld", "0-821"),
    ("Fejér Lipót", "ld", "0-805"),
    ("Fejer Lipot", "ld", "0-805"),
    ("Rényi", "ld", "0-412"),
    ("Rényi Alfréd", "ld", "0-412"),
    ("Renyi Alfred", "ld", "0-412"),
    ("Erdős Pál", "ld", "00-718"),
    ("Erdos Pal", "ld", "00-718"),
    ("Turán Pál", "ld", "3-219"),
    ("Turan Pal", "ld", "3-219"),
    # Colloquial "Déli Hali" has no BIS educational room — keep as free-text only (roomId null).
    ("Déli Hali", "ld", None),
    ("Deli Hali", "ld", None),
    ("Szabó József", "ld", "0-803"),
    ("Szabo Jozsef", "ld", "0-803"),
    ("Lóczy Lajos", "ld", "0-804"),
    ("Loczy Lajos", "ld", "0-804"),
    ("Kőnig", "ld", "0-311"),
    ("Konig", "ld", "0-311"),
    ("Gallai Tibor", "ld", "0-312"),
    ("Kárteszi Ferenc", "ld", "0-220"),
    ("Karteszi Ferenc", "ld", "0-220"),
    # LE
    ("Ortvay Rudolf", "le", "0.81"),
    ("Ortvay", "le", "0.81"),
    ("Eötvös", "le", "0.83"),
    ("Eotvos", "le", "0.83"),
    ("Rybár István", "le", "-1.64"),
    ("Rybar Istvan", "le", "-1.64"),
    ("Pócza Jenő", "le", "1.71"),
    ("Pocza Jeno", "le", "1.71"),
    # 0.100D is unlabeled on public table; keep seed for colloquial Északi Hali
    ("Északi Hali", "le", "0.100D"),
    ("Eszaki Hali", "le", "0.100D"),
]


def fold_ascii(s: str) -> str:
    s = (
        s.replace("ő", "o")
        .replace("ö", "o")
        .replace("ü", "u")
        .replace("ú", "u")
        .replace("á", "a")
        .replace("é", "e")
        .replace("í", "i")
        .replace("Ő", "O")
        .replace("Ö", "O")
        .replace("Ü", "U")
        .replace("Ú", "U")
        .replace("Á", "A")
        .replace("É", "E")
        .replace("Í", "I")
    )
    nfkd = unicodedata.normalize("NFKD", s)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


def neptun_canonical(prefix: str, code_bis: str) -> str:
    """LD 0.821 / LE -1.64 / LE 0.100A."""
    c = code_bis.strip()
    if "-" in c and "." not in c:
        # LD-style floor-room → floor.room
        parts = c.split("-", 1)
        if len(parts) == 2:
            c = f"{parts[0]}.{parts[1]}"
    return f"{prefix} {c}"


def neptun_aliases(prefix: str, code_bis: str, neptun: str) -> list[str]:
    raw = code_bis.strip()
    # dash form
    dash = raw.replace(".", "-")
    # ensure floor-room dash when LD-like already dashed
    al = [
        neptun,
        f"{prefix}-{dash}",
        f"{prefix} {dash}",
        f"{prefix}{raw}",
        f"{prefix}{dash}",
        raw,
        dash,
    ]
    # timetable spaced variants
    m = re.match(r"^(-?\d+)[.\-](.+)$", raw)
    if m:
        fl, rest = m.group(1), m.group(2)
        al.append(f"{prefix} {fl}.{rest}")
        al.append(f"{prefix}-{fl}-{rest}")
        al.append(f"{fl}.{rest}")
        al.append(f"{fl}-{rest}")
    # de-dupe preserve order
    seen = set()
    out = []
    for a in al:
        a = a.strip()
        if a and a not in seen:
            seen.add(a)
            out.append(a)
    return out


def prefix_from_bis_code(room_code: str | None, building: str) -> str:
    if room_code:
        m = re.match(r"^([A-Za-zÉéÁáÓóÖöŐőÚúÜüŰű]{1,3})-", room_code)
        if m:
            p = m.group(1).upper().replace("É", "E").replace("É", "E")
            # LÉ → LE
            p = fold_ascii(p).upper()
            if p in ("LD", "LE", "LK"):
                return p
    return "LD" if building == "ld" else "LE"


def extract_hall_names(room_name: str | None, code_bis: str) -> list[str]:
    if not room_name:
        return []
    name = room_name.strip()
    # strip leading code tokens
    for prefix in (code_bis, code_bis.replace(".", "-"), code_bis.replace("-", ".")):
        if name.startswith(prefix):
            name = name[len(prefix) :].strip(" -–")
            break
    # also strip leading D / floor-like
    name = re.sub(r"^[Dd]\s+", "", name)
    parts = []
    for part in re.split(r"[/(]", name):
        part = part.strip(" )")
        if not part or len(part) < 4:
            continue
        if re.match(r"^(PC|IK|TFK|\d)", part, re.I):
            continue
        low = part.lower()
        if low.startswith("zárt") or low in {
            "oktató",
            "oktatoi",
            "labor",
            "előadó",
            "eloado",
            "fotó",
            "foto",
        }:
            continue
        parts.append(part)
        asci = fold_ascii(part)
        if asci != part:
            parts.append(asci)
    seen = set()
    out = []
    for p in parts:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out[:10]


def index_graph_rooms(graph: dict) -> dict[str, dict]:
    """codeBis variants → room object."""
    by = {}
    for r in graph.get("rooms", []):
        code = r["codeBis"]
        keys = {
            code,
            code.replace(".", "-"),
            code.replace("-", "."),
            code.upper(),
            code.lower(),
        }
        # strip letter suffixes soft keys
        m = re.match(r"^(.+?)([A-Za-z])$", code)
        if m:
            keys.add(m.group(1))
        for k in keys:
            by.setdefault(k, r)
    return by


def index_bis_edu(path: Path) -> tuple[list[dict], dict[str, list[dict]]]:
    data = json.loads(path.read_text())
    rooms = data["rooms"]
    by_num: dict[str, list[dict]] = defaultdict(list)
    for r in rooms:
        rn = r.get("roomNumber") or ""
        by_num[rn].append(r)
        by_num[rn.replace(".", "-")].append(r)
        by_num[rn.replace("-", ".")].append(r)
        # parenthetical student-map code e.g. "F.64-66 B1 (0.100C)"
        m = re.search(r"\(([^)]+)\)\s*$", rn)
        if m:
            inner = m.group(1).strip()
            by_num[inner].append(r)
            by_num[inner.replace(".", "-")].append(r)
    return rooms, by_num


def pick_bis(candidates: list[dict], prefer_prefix: str | None) -> dict | None:
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]
    if prefer_prefix:
        pref = prefer_prefix.upper()
        scored = []
        for c in candidates:
            rc = (c.get("roomCode") or "").upper()
            rc = fold_ascii(rc)
            score = 0
            if rc.startswith(pref + "-"):
                score += 2
            if pref == "LE" and rc.startswith("LE-"):
                score += 2
            scored.append((score, c["id"], c))
        scored.sort(key=lambda x: (-x[0], x[1]))
        if scored[0][0] > 0:
            return scored[0][2]
    # lowest id stable
    return sorted(candidates, key=lambda c: c["id"])[0]


def build_joins_for_building(
    building_id: str,
    graph: dict,
    edu_rooms: list[dict],
    by_num: dict[str, list[dict]],
) -> tuple[list[dict], dict]:
    graph_by = index_graph_rooms(graph)
    node_by_room = {}
    for n in graph.get("nodes", []):
        if n.get("kind") == "room" and n.get("roomId"):
            node_by_room[n["roomId"]] = n["id"]

    joins: list[dict] = []
    seen_bis: set[int] = set()
    conf_counts = Counter()
    edu_ids = {er["id"] for er in edu_rooms}

    # 1) Graph rooms first (exact when BIS matched in Phase 2/3)
    for r in graph["rooms"]:
        code_bis = r["codeBis"]
        prefix = prefix_from_bis_code(r.get("bisRoomCode"), building_id)
        if r.get("codeNeptun"):
            # Prefer graph's LE/LD form but normalize prefix from BIS when LK
            neptun = r["codeNeptun"]
            if prefix == "LK" and neptun.startswith("LE "):
                neptun = "LK " + neptun[3:]
        else:
            neptun = neptun_canonical(prefix, code_bis)

        bis_id = r.get("bisRoomId")
        bis_code = r.get("bisRoomCode")
        conf = "exact" if bis_id else "heuristic"
        notes = None
        if not bis_id:
            # try live lookup
            cands = by_num.get(code_bis) or by_num.get(code_bis.replace(".", "-")) or []
            pick = pick_bis(cands, prefix)
            if pick:
                bis_id = pick["id"]
                bis_code = pick.get("roomCode")
                conf = "exact"
                notes = "matched educational catalog by roomNumber"
            else:
                notes = "on student map / graph; no educational BIS row"

        row = {
            "neptunCode": neptun,
            "neptunAliases": neptun_aliases(prefix, code_bis, neptun),
            "bisRoomId": bis_id,
            "codeBis": code_bis,
            "bisRoomCode": bis_code,
            "roomId": r["id"],
            "nodeId": node_by_room.get(r["id"]),
            "confidence": conf,
        }
        if notes:
            row["notes"] = notes
        joins.append(row)
        conf_counts[conf] += 1
        if bis_id:
            seen_bis.add(bis_id)

    # 2) Remaining educational rooms (searchable, not necessarily on graph)
    for er in edu_rooms:
        if er["id"] in seen_bis:
            continue
        rn = er.get("roomNumber") or ""
        if not rn or rn == "-":
            continue
        # Prefer parenthetical student code when present
        code_bis = rn
        m = re.search(r"\(([^)]+)\)\s*$", rn)
        if m:
            code_bis = m.group(1).strip()
        prefix = prefix_from_bis_code(er.get("roomCode"), building_id)
        # Skip pure LK rows in LE joins? Plan says LE joins include North; LK folded as aliases.
        # Keep LK rows in joins_le with LK prefix.
        neptun = neptun_canonical(prefix, code_bis.replace("-", ".") if re.match(r"^\d+-\d+", code_bis) else code_bis)
        # For LD roomNumbers already floor-room with dash
        if building_id == "ld" and re.match(r"^\d+-\d+", code_bis):
            neptun = neptun_canonical("LD", code_bis)

        # graph hit?
        gr = (
            graph_by.get(code_bis)
            or graph_by.get(code_bis.replace(".", "-"))
            or graph_by.get(code_bis.replace("-", "."))
        )
        conf = "exact" if gr else "heuristic"
        row = {
            "neptunCode": neptun if not gr else (gr.get("codeNeptun") or neptun),
            "neptunAliases": neptun_aliases(prefix, code_bis, neptun),
            "bisRoomId": er["id"],
            "codeBis": code_bis if not gr else gr["codeBis"],
            "bisRoomCode": er.get("roomCode"),
            "roomId": gr["id"] if gr else None,
            "nodeId": node_by_room.get(gr["id"]) if gr else None,
            "confidence": conf,
            "notes": "educational-only (not on public student room table / MVP graph)"
            if not gr
            else "educational catalog row linked to graph room",
        }
        # Avoid duplicate neptun+bis if already from graph pass
        if gr and er["id"] in seen_bis:
            continue
        joins.append(row)
        conf_counts[conf] += 1
        seen_bis.add(er["id"])

    edu_joined = [j for j in joins if j.get("bisRoomId") in edu_ids]
    edu_bis_unique = {j["bisRoomId"] for j in edu_joined}
    edu_on_graph = [j for j in edu_joined if j.get("roomId")]
    edu_on_graph_unique = {j["bisRoomId"] for j in edu_on_graph}
    stats = {
        "joinRows": len(joins),
        "confidence": dict(conf_counts),
        "graphRooms": len(graph["rooms"]),
        "graphRoomsWithBis": sum(1 for r in graph["rooms"] if r.get("bisRoomId")),
        "graphRoomsNotInEducational": sum(
            1
            for r in graph["rooms"]
            if r.get("bisRoomId") and r["bisRoomId"] not in edu_ids
        ),
        "educationalTotal": len(edu_rooms),
        "educationalWithJoinRow": len(edu_bis_unique),
        "educationalWithGraphRoom": len(edu_on_graph_unique),
        "educationalJoinedExact": len(
            {j["bisRoomId"] for j in edu_joined if j.get("confidence") == "exact"}
        ),
        "noteSlashSubrooms": (
            "Public table slash-subrooms (e.g. 00-803/2) may share one BIS id; "
            "percentages use unique bisRoomId."
        ),
    }
    stats["educationalWithNeptunPct"] = round(
        100.0 * len(edu_bis_unique) / max(1, len(edu_rooms)), 2
    )
    stats["graphCoverageOfEducationalPct"] = round(
        100.0 * len(edu_on_graph_unique) / max(1, len(edu_rooms)), 2
    )
    return joins, stats


def build_aliases(graphs: dict[str, dict], joins_by_bldg: dict[str, list]) -> list[dict]:
    """alias → roomId / nodeId / codeBis."""
    node_by_room = {}
    room_by_code = {}
    for bid, g in graphs.items():
        for n in g.get("nodes", []):
            if n.get("kind") == "room" and n.get("roomId"):
                node_by_room[n["roomId"]] = n["id"]
        for r in g.get("rooms", []):
            room_by_code[(bid, r["codeBis"])] = r
            room_by_code[(bid, r["codeBis"].replace(".", "-"))] = r
            room_by_code[(bid, r["codeBis"].replace("-", "."))] = r

    rows = []
    seen = set()

    def add(alias: str, room: dict | None, building_id: str, source: str, conf: str):
        if not alias or len(alias) < 3:
            return
        key = (alias.casefold(), building_id)
        if key in seen:
            return
        seen.add(key)
        rows.append(
            {
                "alias": alias,
                "buildingId": building_id,
                "roomId": room["id"] if room else None,
                "nodeId": node_by_room.get(room["id"]) if room else None,
                "codeBis": room["codeBis"] if room else None,
                "confidence": conf,
                "source": source,
            }
        )

    # From graph room names / aliases
    for bid, g in graphs.items():
        for r in g["rooms"]:
            for a in r.get("aliases") or []:
                # skip pure Neptun codes here — joins handle those
                if re.match(r"^(LD|LE|LK)\b", a, re.I):
                    continue
                if re.match(r"^-?\d+[.\-]", a):
                    continue
                add(a, r, bid, "graph.room.aliases", "exact")
            halls = extract_hall_names(r.get("name"), r["codeBis"])
            for h in halls:
                add(h, r, bid, "graph.room.name", "exact")

    # Manual seeds
    for alias, bid, code in MANUAL_ALIAS_SEEDS:
        room = None
        if code:
            room = room_by_code.get((bid, code)) or room_by_code.get(
                (bid, code.replace(".", "-"))
            )
        add(alias, room, bid, "manual_seed", "manual" if room else "heuristic")

    rows.sort(key=lambda x: (x["buildingId"], x["alias"].casefold()))
    return rows


def build_fixtures(joins_ld, joins_le, aliases) -> list[dict]:
    """query → expected node/room for Phase 6 QA."""
    fixtures = []

    def add(query, building, join_or_alias, why):
        fixtures.append(
            {
                "query": query,
                "buildingId": building,
                "expectedRoomId": join_or_alias.get("roomId"),
                "expectedNodeId": join_or_alias.get("nodeId"),
                "expectedCodeBis": join_or_alias.get("codeBis"),
                "why": why,
            }
        )

    # Stub famous LD halls
    want_ld = [
        "LD 0.821",
        "LD-0-805",
        "0-412",
        "Bolyai",
        "Fejér Lipót",
        "Rényi",
    ]
    by_nep = {j["neptunCode"]: j for j in joins_ld if j.get("roomId")}
    by_code = {j["codeBis"]: j for j in joins_ld if j.get("roomId")}
    alias_index_ld = []
    for j in joins_ld:
        if not j.get("roomId"):
            continue
        for a in j.get("neptunAliases") or []:
            alias_index_ld.append((a, j))
    for q in want_ld:
        hit = by_nep.get(q) or by_code.get(q)
        if not hit:
            for a, j in alias_index_ld:
                if a == q:
                    hit = j
                    break
        if not hit:
            for a in aliases:
                if a["buildingId"] == "ld" and a["alias"].casefold() == q.casefold():
                    hit = a
                    break
        if hit:
            add(q, "ld", hit, "search")

    want_le = {
        "LE 0.81": "Ortvay",
        "LE-0-83": "Eötvös",
        "Ortvay": None,
        "Eötvös": None,
        "Rybár István": None,
    }
    by_nep = {j["neptunCode"]: j for j in joins_le if j.get("roomId")}
    by_code = {j["codeBis"]: j for j in joins_le if j.get("roomId")}
    # also match aliases list on neptunAliases
    alias_index = []
    for j in joins_le:
        if not j.get("roomId"):
            continue
        for a in j.get("neptunAliases") or []:
            alias_index.append((a, j))

    for q, _ in want_le.items():
        hit = by_nep.get(q) or by_code.get(q)
        if not hit:
            for a, j in alias_index:
                if a == q:
                    hit = j
                    break
        if not hit:
            for a in aliases:
                if a["buildingId"] == "le" and a["alias"].casefold() == q.casefold():
                    hit = a
                    break
        if hit:
            add(q, "le", hit, "search")

    # A few educational-only LD codes (no graph room) for honesty fixtures
    edu_only = [j for j in joins_ld if not j.get("roomId") and j.get("bisRoomId")][:3]
    for j in edu_only:
        add(j["neptunCode"], "ld", j, "educational-only (no graph pin)")

    return fixtures


def write_coverage(stats_ld, stats_le, aliases, fixtures) -> str:
    lines = [
        "# Phase 4 — Join coverage report",
        "",
        f"**Generated:** {TODAY}",
        "**Owner:** Nanda",
        "",
        "Honesty: Neptun codes for educational rooms are **derived** from BIS `roomNumber` / `roomCode` "
        "(and graph `codeNeptun` when the room is on the student map). We do **not** have a full "
        "timetable dump of every Neptun string; `exact` means roomNumber ↔ public/graph code match "
        "(or Phase 2/3 BIS id already on the graph room).",
        "",
        "## LD (South / Déli)",
        "",
        f"| Metric | Value |",
        f"|--------|------:|",
        f"| Educational rooms (BIS) | {stats_ld['educationalTotal']} |",
        f"| Join rows | {stats_ld['joinRows']} |",
        f"| Graph rooms (MVP) | {stats_ld['graphRooms']} |",
        f"| Graph rooms with `bisRoomId` | {stats_ld['graphRoomsWithBis']} |",
        f"| Educational rows with Neptun join (unique BIS id) | {stats_ld['educationalWithNeptunPct']}% |",
        f"| Educational rows pinned to graph `roomId` (unique BIS id) | {stats_ld['graphCoverageOfEducationalPct']}% |",
        f"| Confidence `exact` (join rows) | {stats_ld['confidence'].get('exact', 0)} |",
        f"| Confidence `heuristic` (join rows) | {stats_ld['confidence'].get('heuristic', 0)} |",
        f"| Confidence `manual` (join rows) | {stats_ld['confidence'].get('manual', 0)} |",
        "",
        f"_Note:_ {stats_ld.get('noteSlashSubrooms', '')}",
        "",
        "## LE (North / Északi + LK codes in North catalog)",
        "",
        f"| Metric | Value |",
        f"|--------|------:|",
        f"| Educational rooms (BIS) | {stats_le['educationalTotal']} |",
        f"| Join rows | {stats_le['joinRows']} |",
        f"| Graph rooms (MVP) | {stats_le['graphRooms']} |",
        f"| Graph rooms with `bisRoomId` | {stats_le['graphRoomsWithBis']} |",
        f"| Educational rows with Neptun join (unique BIS id) | {stats_le['educationalWithNeptunPct']}% |",
        f"| Educational rows pinned to graph `roomId` (unique BIS id) | {stats_le['graphCoverageOfEducationalPct']}% |",
        f"| Confidence `exact` (join rows) | {stats_le['confidence'].get('exact', 0)} |",
        f"| Confidence `heuristic` (join rows) | {stats_le['confidence'].get('heuristic', 0)} |",
        f"| Confidence `manual` (join rows) | {stats_le['confidence'].get('manual', 0)} |",
        "",
        f"_Note:_ {stats_le.get('noteSlashSubrooms', '')}",
        "",
        "## Aliases",
        "",
        f"- Named-hall / search alias rows: **{len(aliases)}**",
        f"- With graph `roomId`: **{sum(1 for a in aliases if a.get('roomId'))}**",
        "",
        "## Search fixtures",
        "",
        f"- Fixture queries for Phase 6: **{len(fixtures)}** (`search_fixtures.json`)",
        "",
        "## Files",
        "",
        "| File | Role |",
        "|------|------|",
        "| `joins_ld.json` | Neptun ↔ BIS for South |",
        "| `joins_le.json` | Neptun ↔ BIS for North (incl. LK-prefixed codes) |",
        "| `aliases.json` | Named halls → room/node |",
        "| `search_fixtures.json` | query → expected pin |",
        "| `build_joins.py` | Regenerator |",
        "",
        "*Owner / developer: **Nanda**.*",
        "",
    ]
    return "\n".join(lines)


def main():
    g_ld = json.loads((GRAPH / "graph_ld.json").read_text())
    g_le = json.loads((GRAPH / "graph_le.json").read_text())
    south, by_s = index_bis_edu(BIS / "south" / "rooms_educational.json")
    north, by_n = index_bis_edu(BIS / "north" / "rooms_educational.json")

    joins_ld, stats_ld = build_joins_for_building("ld", g_ld, south, by_s)
    joins_le, stats_le = build_joins_for_building("le", g_le, north, by_n)

    aliases = build_aliases({"ld": g_ld, "le": g_le}, {"ld": joins_ld, "le": joins_le})
    fixtures = build_fixtures(joins_ld, joins_le, aliases)

    def package(kind, building, joins, stats):
        return {
            "schemaVersion": 1,
            "packageKind": "joins",
            "buildingId": building,
            "generatedAt": TODAY,
            "notes": (
                "Phase 4 Neptun↔BIS joins. "
                "`exact` = graph/public code matched educational roomNumber (or bisRoomId from Phase 2/3). "
                "`heuristic` = derived Neptun form without graph pin or without educational match. "
                "Educational-only rows have roomId null until the room is on the MVP graph."
            ),
            "stats": stats,
            "joins": joins,
        }

    (ROOT / "joins_ld.json").write_text(
        json.dumps(package("joins", "ld", joins_ld, stats_ld), ensure_ascii=False, indent=2)
        + "\n"
    )
    (ROOT / "joins_le.json").write_text(
        json.dumps(package("joins", "le", joins_le, stats_le), ensure_ascii=False, indent=2)
        + "\n"
    )
    (ROOT / "aliases.json").write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "packageKind": "aliases",
                "generatedAt": TODAY,
                "notes": "Named-hall and free-text search strings → roomId/nodeId. Neptun codes live in joins_*.json.",
                "aliasCount": len(aliases),
                "aliases": aliases,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n"
    )
    (ROOT / "search_fixtures.json").write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "packageKind": "searchFixtures",
                "generatedAt": TODAY,
                "notes": "Phase 6 QA: query → expected room/node (null node = educational-only).",
                "fixtures": fixtures,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n"
    )
    (ROOT / "JOIN_COVERAGE.md").write_text(
        write_coverage(stats_ld, stats_le, aliases, fixtures)
    )
    (ROOT / "README.md").write_text(
        "\n".join(
            [
                "# Phase 4 — Joins & search aliases",
                "",
                f"**Generated:** {TODAY} · Owner: **Nanda**",
                "",
                "Neptun-style codes and named halls → BIS / graph pins. Regenerator: `python3 build_joins.py`.",
                "",
                "| File | Role |",
                "|------|------|",
                "| [joins_ld.json](joins_ld.json) | South Neptun ↔ BIS |",
                "| [joins_le.json](joins_le.json) | North Neptun ↔ BIS (incl. LK) |",
                "| [aliases.json](aliases.json) | Named halls |",
                "| [search_fixtures.json](search_fixtures.json) | QA queries |",
                "| [JOIN_COVERAGE.md](JOIN_COVERAGE.md) | Honest % report |",
                "| [build_joins.py](build_joins.py) | Builder |",
                "",
                "Plan: [CAMPUS_MAP_PLAN.md](../../CAMPUS_MAP_PLAN.md). Stubs remain under `../schema/joins_ld.stub.*`.",
                "",
            ]
        )
    )

    print("LD", stats_ld)
    print("LE", stats_le)
    print("aliases", len(aliases), "fixtures", len(fixtures))


if __name__ == "__main__":
    main()
