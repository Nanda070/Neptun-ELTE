#!/usr/bin/env python3
"""Build Phase 3 LE (North / Északi) corridor graph — semi-manual MVP.

Places a shared double-courtyard loop + south-wing (hajóorr) backbone and
vertical shafts on every student-floor JPG (800×800), stubs every
le_north/rooms.json entry to the nearest corridor zone, and writes
graph_le.json + sample routes. Pixel positions are approximate (visual hubs
+ room-number zone heuristics), not CV-traced. LK rooms folded into LE.
"""

from __future__ import annotations

import json
import math
import re
from collections import defaultdict
from heapq import heappop, heappush
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(__file__).resolve().parent
ROOMS_PATH = ROOT / "le_north" / "rooms.json"
EDU_PATH = ROOT / "bis" / "north" / "rooms_educational.json"
CATALOG_PATH = ROOT / "bis" / "north" / "rooms_catalog.json"

FLOORS = [
    {
        "level": -1,
        "bisSlug": "-1",
        "id": "le-f-1",
        "labelHu": "−1. emelet",
        "labelEn": "Floor −1",
        "basemapAsset": "le_north/floors/eszaki_-1_emelet.jpg",
    },
    {
        "level": 0,
        "bisSlug": "0",
        "id": "le-f0",
        "labelHu": "Földszint",
        "labelEn": "Ground floor",
        "basemapAsset": "le_north/floors/eszaki_foldszint.jpg",
    },
]
for n in range(1, 8):
    FLOORS.append(
        {
            "level": n,
            "bisSlug": str(n),
            "id": f"le-f{n}",
            "labelHu": f"{n}. emelet",
            "labelEn": f"Floor {n}",
            "basemapAsset": f"le_north/floors/eszaki_{n}_emelet.jpg",
        }
    )

# Image CRS: origin top-left on 800×800 JPGs. On LE artwork Dunapart is LEFT
# (west); Főbejárat I Északi toward bottom; Főbejárat III Dél toward top.
# x increases east (right), y increases down the image.
# Calibrated from eszaki_foldszint / −1 / 1 / 2 visual hubs (shared template).
HUBS = {
    "entrance-dunapart": (55, 400),
    "entrance-north": (560, 730),  # Főbejárat I Északi
    "entrance-south": (400, 70),  # Főbejárat III Dél
    # Outer / loop hubs around two courtyards
    "loop-nw": (170, 160),
    "loop-n": (400, 145),
    "loop-ne": (630, 160),
    "loop-e-n": (660, 280),
    "loop-e": (660, 400),
    "loop-e-s": (660, 520),
    "loop-se": (620, 575),
    "loop-s": (400, 575),
    "loop-sw": (170, 575),
    "loop-w-s": (145, 520),
    "loop-w": (145, 400),
    "loop-w-n": (145, 280),
    # Cross corridor between courtyards
    "cross-w": (260, 400),
    "cross-mid": (400, 400),
    "cross-e": (540, 400),
    # Verticals + POIs
    "lift-A": (360, 380),
    "lift-B": (440, 420),
    "stair-main": (500, 450),
    "stair-nw": (175, 200),
    "stair-ne": (620, 200),
    "stair-sw": (180, 540),
    "stair-wing": (400, 755),
    "bufe": (300, 330),
    "aula": (400, 320),
    # South wing (hajóorr / LK extension)
    "wing-n": (400, 620),
    "wing-mid": (400, 690),
    "wing-s": (400, 755),
}

# Zone → polyline for room stub placement (t in [0,1]).
ZONE_POLY = {
    "west": [(145, 200), (145, 400), (145, 560)],
    "north": [(200, 145), (400, 145), (600, 145)],
    "east": [(660, 200), (660, 400), (660, 560)],
    "east-s": [(660, 420), (660, 560), (580, 575)],
    "cross": [(200, 400), (400, 400), (600, 400)],
    "south": [(200, 575), (400, 575), (600, 575)],
    "wing": [(400, 600), (400, 690), (400, 760)],
}

ZONE_HUB = {
    "west": "loop-w",
    "north": "loop-n",
    "east": "loop-e",
    "east-s": "loop-e-s",
    "cross": "cross-mid",
    "south": "loop-s",
    "wing": "wing-mid",
}

BACKBONE_EDGES = [
    # west spine
    ("entrance-dunapart", "loop-w"),
    ("loop-w-n", "loop-w"),
    ("loop-w", "loop-w-s"),
    ("loop-nw", "loop-w-n"),
    ("loop-sw", "loop-w-s"),
    # north
    ("loop-nw", "loop-n"),
    ("loop-n", "loop-ne"),
    ("loop-n", "entrance-south"),
    # east spine
    ("loop-ne", "loop-e-n"),
    ("loop-e-n", "loop-e"),
    ("loop-e", "loop-e-s"),
    ("loop-e-s", "loop-se"),
    # south of courtyards
    ("loop-se", "loop-s"),
    ("loop-s", "loop-sw"),
    # cross corridor
    ("loop-w", "cross-w"),
    ("cross-w", "cross-mid"),
    ("cross-mid", "cross-e"),
    ("cross-e", "loop-e"),
    ("cross-mid", "lift-A"),
    ("cross-mid", "lift-B"),
    ("cross-e", "stair-main"),
    ("lift-A", "lift-B"),
    ("lift-B", "stair-main"),
    # POIs
    ("cross-w", "bufe"),
    ("bufe", "aula"),
    ("aula", "cross-mid"),
    ("aula", "loop-n"),
    # stairs into loop
    ("stair-nw", "loop-nw"),
    ("stair-nw", "loop-w-n"),
    ("stair-ne", "loop-ne"),
    ("stair-ne", "loop-e-n"),
    ("stair-sw", "loop-sw"),
    ("stair-sw", "loop-w-s"),
    # south wing
    ("loop-s", "wing-n"),
    ("wing-n", "wing-mid"),
    ("wing-mid", "wing-s"),
    ("wing-s", "stair-wing"),
    ("wing-n", "entrance-north"),
    # lifts / stairs to nearby loop
    ("lift-A", "cross-w"),
    ("stair-main", "loop-e"),
]

HUB_KIND = {
    "entrance-dunapart": "entrance",
    "entrance-north": "entrance",
    "entrance-south": "entrance",
    "bufe": "poi",
    "aula": "poi",
    "lift-A": "lift",
    "lift-B": "lift",
    "stair-main": "stair",
    "stair-nw": "stair",
    "stair-ne": "stair",
    "stair-sw": "stair",
    "stair-wing": "stair",
}

SHAFT = {
    "lift-A": "le-lift-A",
    "lift-B": "le-lift-B",
    "stair-main": "le-stair-main",
    "stair-nw": "le-stair-nw",
    "stair-ne": "le-stair-ne",
    "stair-sw": "le-stair-sw",
    "stair-wing": "le-stair-wing",
}

VERTICAL_COST = {
    "lift": 40.0,
    "stair": 90.0,
}

ATTR = (
    "Floor plan artwork: Héger Tamás; aggregator: Sárközi Gergő "
    "(sarkozigergo) — redistribution permission pending"
)


def dist(a, b) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def px(coord):
    return {"x": round(coord[0], 1), "y": round(coord[1], 1), "space": "basemapPx"}


def parse_le_room(raw: str):
    """Return (codeBis, level, room_num, display_name, bare_lk).

    Handles ``-1.53``, ``0.100A``, ``1.71 Pócza…``, ``039 - NMR…``,
    ``115 (hajóorr)``, ``109-114 laborok``, ``416-os labor``, ``334 (349)``.
    """
    s = raw.strip()
    # dotted floor.number
    m = re.match(
        r"^(-?\d+)\.(\d+[A-Za-z]?(?:/\d+[A-Za-z]?)?)\s*(.*)$",
        s,
    )
    if m:
        level = int(m.group(1))
        num_tok = m.group(2)
        rest = m.group(3).strip(" -–.?")
        code_bis = f"{level}.{num_tok}"
        num_core = int(re.match(r"(\d+)", num_tok).group(1))
        return code_bis, level, num_core, rest or None, False

    # range like 109-114
    m = re.match(r"^(\d{2,3})-(\d{2,3})\b\s*(.*)$", s)
    if m:
        a, b, rest = m.group(1), m.group(2), m.group(3).strip()
        num = int(a)
        level = num // 100 if num >= 100 else 0
        code_bis = f"{a}-{b}"
        return code_bis, level, num, rest or None, True

    # bare 3-digit / 2-digit (+ optional -os)
    m = re.match(r"^(\d{2,3})(?:-os)?\b\s*(.*)$", s)
    if m:
        tok, rest = m.group(1), m.group(2).strip(" -–")
        num = int(tok)
        if num >= 100:
            level = num // 100
        else:
            level = 0
        code_bis = tok
        return code_bis, level, num, rest or None, True

    return None, None, None, None, False


def point_on_poly(poly, t: float):
    t = max(0.0, min(1.0, t))
    if len(poly) == 1:
        return poly[0]
    lengths = [dist(poly[i], poly[i + 1]) for i in range(len(poly) - 1)]
    total = sum(lengths) or 1.0
    target = t * total
    acc = 0.0
    for i, seg_len in enumerate(lengths):
        if acc + seg_len >= target:
            local = 0 if seg_len == 0 else (target - acc) / seg_len
            x0, y0 = poly[i]
            x1, y1 = poly[i + 1]
            return (x0 + (x1 - x0) * local, y0 + (y1 - y0) * local)
        acc += seg_len
    return poly[-1]


def room_t(ordinal: int) -> float:
    return (ordinal % 100) / 99.0 if ordinal else 0.5


def zone_for(num: int, name: str | None, bare: bool) -> str:
    low = (name or "").lower()
    if "hajóorr" in low or "hajoorr" in low or "hajó" in low:
        return "wing"
    if bare and num >= 100:
        return "wing"
    if bare and num < 100:
        return "east-s"  # LK chem block e.g. 039, 058–065
    if num >= 100:
        return "west"
    if num >= 90:
        return "north"
    if num >= 70:
        return "east"
    if num >= 50:
        return "east-s"
    if num >= 30:
        return "cross"
    if num >= 15:
        return "south"
    return "west"


def offset_toward_room(pt, zone: str, ordinal: int):
    side = 1 if (ordinal % 2 == 0) else -1
    mag = 40.0
    if zone in ("west", "east", "east-s", "wing"):
        # mostly NS corridors → offset E/W
        return (pt[0] + side * mag, pt[1])
    if zone in ("north", "south", "cross"):
        return (pt[0], pt[1] + side * mag)
    return (pt[0] + side * mag * 0.8, pt[1] + (1 if ordinal % 3 else -1) * 15)


def load_bis_index():
    edu = json.load(open(EDU_PATH))["rooms"]
    cat = json.load(open(CATALOG_PATH))["rooms"]
    by_num = {}
    by_code_parts = {}
    for r in cat + edu:
        by_num[r["roomNumber"]] = r
        # LÉ-0-081-01-11 → keys 0.81, 0.081, 081
        rc = r.get("roomCode") or ""
        m = re.match(r"L[ÉE]-(-?\d+)-(\d+[A-Za-z]?(?:/\d+[A-Za-z]?)?)-", rc)
        if m:
            fl, num = m.group(1), m.group(2)
            by_code_parts[f"{fl}.{num}"] = r
            by_code_parts[f"{fl}.{num.lstrip('0') or '0'}"] = r
            by_code_parts[num] = r
            by_code_parts[num.lstrip("0") or "0"] = r
        m2 = re.match(r"LK-(-?\d+)-(\d+[A-Za-z]?(?:/\d+[A-Za-z]?)?)-", rc)
        if m2:
            fl, num = m2.group(1), m2.group(2)
            by_code_parts[f"{fl}.{num}"] = r
            by_code_parts[num] = r
            by_code_parts[num.zfill(3)] = r
    return by_num, by_code_parts


def type_slug(hu: str | None) -> str | None:
    if not hu:
        return None
    m = {
        "Tanterem": "tanterem",
        "Eloadó": "eloado",
        "Előadó": "eloado",
        "Laboratórium": "labor",
        "Számítógépes labor": "szamitogepes_labor",
        "Szaktanterem": "szaktanterem",
        "Tanácsterem": "tanacsterem",
        "Dolgozó szoba": "dolgozo",
        "Északi Hali": "eszaki_hali",
    }
    return m.get(hu, re.sub(r"[^a-z0-9]+", "_", hu.lower()).strip("_"))


def named_aliases(code_bis: str, name: str | None, neptun: str | None):
    aliases = []
    if neptun:
        aliases.append(neptun)
    if name:
        clean = name.strip(" -–")
        for part in re.split(r"[/(]", clean):
            part = part.strip(" )")
            if not part:
                continue
            if re.match(r"^(PC|IK|TFK|\d)", part):
                continue
            if len(part) >= 4 and not part.lower().startswith("zárt"):
                aliases.append(part)
                asci = (
                    part.replace("ő", "o")
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
                if asci != part:
                    aliases.append(asci)
    seen = set()
    out = []
    for a in aliases:
        if a not in seen:
            seen.add(a)
            out.append(a)
    return out[:8]


def bis_lookup(by_num, by_parts, code_bis: str):
    for key in (code_bis, code_bis.replace(".", "-")):
        if key in by_num:
            return by_num[key]
        if key in by_parts:
            return by_parts[key]
    # 0.081 ↔ 0.81
    m = re.match(r"^(-?\d+)\.(\d+)([A-Za-z]?)$", code_bis)
    if m:
        fl, num, let = m.group(1), m.group(2), m.group(3)
        variants = [
            f"{fl}.{num}{let}",
            f"{fl}.{num.zfill(3)}{let}",
            f"{fl}.{num.lstrip('0') or '0'}{let}",
            f"{num}{let}",
            f"{num.zfill(3)}{let}",
        ]
        for v in variants:
            if v in by_num:
                return by_num[v]
            if v in by_parts:
                return by_parts[v]
    if code_bis.isdigit():
        for v in (code_bis, code_bis.zfill(3), code_bis.lstrip("0") or "0"):
            if v in by_num:
                return by_num[v]
            if v in by_parts:
                return by_parts[v]
    return None


def build():
    public = json.load(open(ROOMS_PATH))
    by_num, by_parts = load_bis_index()
    floor_by_level = {f["level"]: f for f in FLOORS}

    nodes = []
    edges = []
    rooms_out = []
    node_ids = set()

    def add_node(n):
        if n["id"] in node_ids:
            return
        node_ids.add(n["id"])
        nodes.append(n)

    def add_edge(e):
        edges.append(e)

    for fl in FLOORS:
        fid = fl["id"]
        for key, (x, y) in HUBS.items():
            kind = HUB_KIND.get(key, "corridor")
            nid = f"le-n-{fid}-{key}"
            node = {
                "id": nid,
                "floorId": fid,
                "kind": kind,
                "coord": px((x, y)),
                "label": key,
            }
            if key in SHAFT:
                node["verticalShaftId"] = SHAFT[key]
            add_node(node)

        for a, b in BACKBONE_EDGES:
            pa, pb = HUBS[a], HUBS[b]
            add_edge(
                {
                    "id": f"le-e-{fid}-{a}-{b}",
                    "from": f"le-n-{fid}-{a}",
                    "to": f"le-n-{fid}-{b}",
                    "weight": round(dist(pa, pb), 1),
                    "bidirectional": True,
                    "kind": "corridor"
                    if not (a.startswith("entrance") or b.startswith("entrance"))
                    else "entrance",
                }
            )

    stub_count = 0
    skipped = []
    for r in public["rooms"]:
        code_bis, level, ordinal, display_rest, bare = parse_le_room(r["code"])
        if not code_bis or level is None:
            skipped.append(r["code"])
            continue
        if level not in floor_by_level:
            skipped.append(r["code"])
            continue
        fl = floor_by_level[level]
        fid = fl["id"]
        zone = zone_for(ordinal or 0, display_rest or r["code"], bare)
        poly = ZONE_POLY[zone]
        along = point_on_poly(poly, room_t(ordinal or 0))
        door = offset_toward_room(along, zone, ordinal or 0)
        door = (max(20, min(780, door[0])), max(20, min(780, door[1])))
        along = (max(20, min(780, along[0])), max(20, min(780, along[1])))

        id_token = (
            code_bis.replace("/", "_")
            .replace(".", "_")
            .replace("-", "_")
            .replace(" ", "_")
        )
        room_id = f"le-room-{id_token}"

        bis_row = bis_lookup(by_num, by_parts, code_bis)
        name = bis_row.get("roomName") if bis_row else None
        display_name = display_rest or name or code_bis

        neptun = f"LE {code_bis}"

        room_obj = {
            "id": room_id,
            "floorId": fid,
            "codeBis": code_bis,
            "bisRoomId": bis_row["id"] if bis_row else None,
            "bisRoomCode": bis_row["roomCode"] if bis_row else None,
            "codeNeptun": neptun,
            "name": display_name,
            "type": type_slug(r.get("type")),
            "aliases": named_aliases(code_bis, display_name, neptun),
            "centroid": px(door),
        }
        if bare:
            room_obj["notes"] = "LK/bare public code folded into LE graph"
        if bis_row and bis_row.get("centroid"):
            lng, lat = bis_row["centroid"]
            room_obj["centroidWgs"] = {
                "lng": lng,
                "lat": lat,
                "space": "wgs84",
            }
        rooms_out.append(room_obj)

        attach_key = f"door-{id_token}"
        attach_id = f"le-n-{fid}-{attach_key}"
        add_node(
            {
                "id": attach_id,
                "floorId": fid,
                "kind": "corridor",
                "coord": px(along),
                "label": f"door mouth {code_bis}",
            }
        )
        hub_key = ZONE_HUB[zone]
        hub_id = f"le-n-{fid}-{hub_key}"
        add_edge(
            {
                "id": f"le-e-{fid}-hub-{attach_key}",
                "from": hub_id,
                "to": attach_id,
                "weight": round(dist(HUBS[hub_key], along), 1),
                "bidirectional": True,
                "kind": "corridor",
            }
        )

        room_node_id = f"le-n-{fid}-room-{id_token}"
        add_node(
            {
                "id": room_node_id,
                "floorId": fid,
                "kind": "room",
                "roomId": room_id,
                "coord": px(door),
                "label": code_bis,
            }
        )
        add_edge(
            {
                "id": f"le-e-{fid}-stub-{id_token}",
                "from": attach_id,
                "to": room_node_id,
                "weight": round(dist(along, door), 1),
                "bidirectional": True,
                "kind": "roomStub",
            }
        )
        stub_count += 1

    levels = [f["level"] for f in FLOORS]
    for i in range(len(levels) - 1):
        lo, hi = levels[i], levels[i + 1]
        flo, fhi = floor_by_level[lo], floor_by_level[hi]
        for key, shaft in SHAFT.items():
            kind = "verticalLift" if key.startswith("lift") else "verticalStair"
            cost = VERTICAL_COST["lift" if key.startswith("lift") else "stair"]
            add_edge(
                {
                    "id": f"le-e-vert-{shaft}-{flo['id']}-{fhi['id']}",
                    "from": f"le-n-{flo['id']}-{key}",
                    "to": f"le-n-{fhi['id']}-{key}",
                    "weight": cost,
                    "bidirectional": True,
                    "kind": kind,
                    "floors": [flo["id"], fhi["id"]],
                }
            )

    package = {
        "schemaVersion": 1,
        "packageKind": "buildingGraph",
        "generatedAt": "2026-09-16",
        "notes": (
            "Phase 3 LE MVP graph. Double-courtyard loop + south-wing (hajóorr) "
            "hubs visually placed on 800×800 basemap CRS (Dunapart LEFT/west, "
            "x→east, y↓). Room stubs estimated from room-number zone heuristic "
            "+ ordinal along zone polyline — semi-manual / approximate, not "
            "CV-traced. LK bare codes folded into LE. BIS floors outside −1…7 "
            "omitted. Basemap permission still pending. rooms.json floor field "
            "often '?' — level inferred from code."
        ),
        "building": {
            "id": "le",
            "neptunPrefix": "LE",
            "nameHu": "Északi Épület",
            "nameEn": "North Building",
            "address": "Pázmány Péter sétány 1/A",
            "bisBuildingSlug": "eszaki",
        },
        "floors": [
            {
                **{
                    k: fl[k]
                    for k in (
                        "id",
                        "level",
                        "bisSlug",
                        "labelHu",
                        "labelEn",
                        "basemapAsset",
                    )
                },
                "buildingId": "le",
                "basemapWidth": 800,
                "basemapHeight": 800,
                "attribution": ATTR,
            }
            for fl in FLOORS
        ],
        "rooms": rooms_out,
        "nodes": nodes,
        "edges": edges,
        "stats": {
            "floorCount": len(FLOORS),
            "roomCount": len(rooms_out),
            "roomStubCount": stub_count,
            "nodeCount": len(nodes),
            "edgeCount": len(edges),
            "verticalShafts": sorted(set(SHAFT.values())),
            "skippedPublicCodes": skipped,
        },
    }
    return package


def shortest_path(package, start_id, goal_id):
    adj = defaultdict(list)
    for e in package["edges"]:
        w = e["weight"]
        adj[e["from"]].append((e["to"], w, e["id"]))
        if e.get("bidirectional", True):
            adj[e["to"]].append((e["from"], w, e["id"]))

    pq = [(0.0, start_id, None)]
    best = {start_id: 0.0}
    prev = {}
    while pq:
        cost, u, _ = heappop(pq)
        if u == goal_id:
            break
        if cost > best.get(u, 1e18):
            continue
        for v, w, eid in adj[u]:
            nc = cost + w
            if nc < best.get(v, 1e18):
                best[v] = nc
                prev[v] = (u, eid)
                heappush(pq, (nc, v, eid))
    if goal_id not in prev and start_id != goal_id:
        return None, None
    path = [goal_id]
    cur = goal_id
    while cur != start_id:
        cur, _ = prev[cur]
        path.append(cur)
    path.reverse()
    return path, best[goal_id]


def connected_components_per_floor(package):
    floor_of = {n["id"]: n["floorId"] for n in package["nodes"]}
    by_floor = defaultdict(list)
    for nid, fid in floor_of.items():
        by_floor[fid].append(nid)
    adj = defaultdict(list)
    for e in package["edges"]:
        if e.get("kind") in ("verticalLift", "verticalStair"):
            continue
        a, b = e["from"], e["to"]
        if floor_of.get(a) != floor_of.get(b):
            continue
        adj[a].append(b)
        if e.get("bidirectional", True):
            adj[b].append(a)
    report = {}
    for fid, ids in by_floor.items():
        idset = set(ids)
        seen = set()
        comps = []
        for nid in ids:
            if nid in seen:
                continue
            stack = [nid]
            seen.add(nid)
            size = 0
            while stack:
                u = stack.pop()
                size += 1
                for v in adj[u]:
                    if v in idset and v not in seen:
                        seen.add(v)
                        stack.append(v)
            comps.append(size)
        report[fid] = sorted(comps, reverse=True)
    return report


def find_room_node(package, code_bis: str):
    id_token = (
        code_bis.replace("/", "_")
        .replace(".", "_")
        .replace("-", "_")
        .replace(" ", "_")
    )
    rid = f"le-room-{id_token}"
    for n in package["nodes"]:
        if n.get("kind") == "room" and n.get("roomId") == rid:
            return n["id"]
    return None


def main():
    package = build()
    out_path = OUT / "graph_le.json"
    out_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote {out_path}")
    print("stats", package["stats"])

    comps = connected_components_per_floor(package)
    print("components (largest first):")
    for fid, sizes in sorted(comps.items()):
        print(f"  {fid}: {sizes[:5]}{'...' if len(sizes) > 5 else ''}")

    samples = [
        ("1 same-floor east neighbors", "0.81", "0.83"),
        ("2 ground Dunapart entrance → Ortvay", None, "0.81"),
        ("3 basement ↔ floor 1 (vertical)", "-1.53", "1.71"),
        ("4 named halls Ortvay → Eötvös", "0.81", "0.83"),
        ("5 cross-zone west → east", "0.100A", "0.89"),
        ("6 cross-floor lift/stair 0 → 3", "0.81", "3.67"),
        ("7 LK/hajóorr wing stub", "039", "115"),
    ]

    node_floor = {n["id"]: n["floorId"] for n in package["nodes"]}
    routes = []
    for title, a, b in samples:
        if a is None:
            start = "le-n-le-f0-entrance-dunapart"
            start_label = "entrance-dunapart@f0"
        else:
            start = find_room_node(package, a)
            start_label = a
        goal = find_room_node(package, b) if b else None
        if not start or not goal:
            routes.append({"title": title, "error": f"missing nodes {a}->{b}"})
            continue
        path, cost = shortest_path(package, start, goal)
        floors_used = [node_floor[nid] for nid in (path or [])]
        path_set = set(path or [])
        vertical = []
        for e in package["edges"]:
            if not str(e.get("kind", "")).startswith("vertical"):
                continue
            if e["from"] in path_set and e["to"] in path_set:
                vertical.append(e["kind"])
        routes.append(
            {
                "title": title,
                "from": start_label,
                "to": b,
                "startNodeId": start,
                "goalNodeId": goal,
                "costPx": round(cost, 1) if cost is not None else None,
                "nodeIds": path,
                "floorsVisited": floors_used,
                "verticalKindsUsed": vertical,
                "hopCount": len(path) - 1 if path else None,
            }
        )
        print(title, "hops", len(path) - 1 if path else None, "cost", cost)

    samples_path = OUT / "samples" / "le_routes.md"
    lines = [
        "# LE sample routes (Phase 3 QA)",
        "",
        "Generated by `build_graph_le.py` against `graph_le.json`.",
        "Paths are Dijkstra on pixel weights (stairs costlier than lifts).",
        "",
    ]
    for r in routes:
        lines.append(f"## {r['title']}")
        lines.append("")
        if r.get("error"):
            lines.append(f"- **Error:** {r['error']}")
            lines.append("")
            continue
        lines.append(f"- **From → To:** `{r['from']}` → `{r['to']}`")
        lines.append(f"- **Cost (px-equiv):** {r['costPx']}")
        lines.append(f"- **Hops:** {r['hopCount']}")
        lines.append(f"- **Vertical kinds:** {r['verticalKindsUsed'] or 'none'}")
        lines.append(f"- **Floors visited:** `{r['floorsVisited']}`")
        lines.append("- **Node id list:**")
        lines.append("")
        lines.append("```")
        lines.append("\n".join(r["nodeIds"]))
        lines.append("```")
        lines.append("")
    samples_path.write_text("\n".join(lines) + "\n")
    print(f"Wrote {samples_path}")


if __name__ == "__main__":
    main()
