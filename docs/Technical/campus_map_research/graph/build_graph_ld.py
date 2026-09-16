#!/usr/bin/env python3
"""Build Phase 2 LD (South / Déli) corridor graph — semi-manual MVP.

Places a shared corridor-1–8 backbone + vertical shafts on every floor JPG
(800×800), stubs every rooms.json entry to the nearest corridor node, and
writes graph_ld.json + sample routes. Pixel positions are approximate
(visual hubs + corridor-digit heuristics), not CV-traced.
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
ROOMS_PATH = ROOT / "ld_south" / "rooms.json"
EDU_PATH = ROOT / "bis" / "south" / "rooms_educational.json"
CATALOG_PATH = ROOT / "bis" / "south" / "rooms_catalog.json"

FLOORS = [
    {
        "level": -1,
        "bisSlug": "00",
        "id": "ld-f-1",
        "labelHu": "−1. emelet (00)",
        "labelEn": "Floor −1 (map label 00)",
        "basemapAsset": "ld_south/floors/deli_-1_emelet.jpg",
    },
    {
        "level": 0,
        "bisSlug": "0",
        "id": "ld-f0",
        "labelHu": "Földszint",
        "labelEn": "Ground floor",
        "basemapAsset": "ld_south/floors/deli_foldszint.jpg",
    },
]
for n in range(1, 8):
    FLOORS.append(
        {
            "level": n,
            "bisSlug": str(n),
            "id": f"ld-f{n}",
            "labelHu": f"{n}. emelet",
            "labelEn": f"Floor {n}",
            "basemapAsset": f"ld_south/floors/deli_{n}_emelet.jpg",
        }
    )

# Image CRS: origin top-left, x→east (Dunapart), y→south. Calibrated from
# delitomb_0.jpg corridor schema + visual hubs on deli_foldszint / −1 / 1.
# Units: basemapPx on 800×800 JPGs.
HUBS = {
    "entrance-west": (50, 400),
    "entrance-dunapart": (760, 400),
    "entrance-north": (480, 55),
    "c8-hub": (155, 400),
    "c8-n": (155, 280),
    "c8-s": (155, 545),
    "bufe": (130, 575),
    "lift-A": (295, 375),
    "lift-B": (305, 435),
    "stair-main": (255, 430),
    "c2-hub": (345, 255),
    "c3-hub": (480, 155),
    "c4-hub": (655, 255),
    "c1-w": (375, 400),
    "c1-hub": (480, 400),
    "c1-e": (590, 400),
    "c7-hub": (345, 545),
    "c6-hub": (480, 655),
    "c5-hub": (655, 545),
    "stair-nw": (375, 215),
    "stair-ne": (585, 215),
    "stair-sw": (375, 585),
    "stair-se": (585, 585),
}

# Corridor digit → polyline along which room stubs are placed (t in [0,1]).
CORRIDOR_POLY = {
    1: [(375, 400), (480, 400), (655, 400)],
    2: [(345, 380), (345, 255), (345, 175)],
    3: [(375, 155), (480, 155), (620, 155)],
    4: [(655, 175), (655, 255), (655, 380)],
    5: [(655, 420), (655, 545), (655, 640)],
    6: [(375, 655), (480, 655), (620, 655)],
    7: [(345, 420), (345, 545), (345, 640)],
    8: [(80, 280), (155, 400), (155, 545), (200, 600)],
}

# Same-floor backbone edges between named hubs (undirected).
BACKBONE_EDGES = [
    ("entrance-west", "c8-hub"),
    ("c8-hub", "c8-n"),
    ("c8-hub", "c8-s"),
    ("c8-s", "bufe"),
    ("c8-hub", "stair-main"),
    ("c8-hub", "lift-A"),
    ("c8-hub", "lift-B"),
    ("c8-hub", "c1-w"),
    ("c8-n", "c2-hub"),
    ("c8-s", "c7-hub"),
    ("c2-hub", "c1-w"),
    ("c7-hub", "c1-w"),
    ("c1-w", "c1-hub"),
    ("c1-hub", "c1-e"),
    ("c1-e", "entrance-dunapart"),
    ("c2-hub", "c3-hub"),
    ("c3-hub", "c4-hub"),
    ("c4-hub", "c1-e"),
    ("c7-hub", "c6-hub"),
    ("c6-hub", "c5-hub"),
    ("c5-hub", "c1-e"),
    ("c4-hub", "c5-hub"),  # east spine
    ("c2-hub", "c7-hub"),  # west of courtyards via C1-w already; extra direct
    ("c3-hub", "entrance-north"),
    ("stair-nw", "c2-hub"),
    ("stair-nw", "c3-hub"),
    ("stair-ne", "c3-hub"),
    ("stair-ne", "c4-hub"),
    ("stair-sw", "c7-hub"),
    ("stair-sw", "c6-hub"),
    ("stair-se", "c6-hub"),
    ("stair-se", "c5-hub"),
    ("lift-A", "c1-w"),
    ("lift-B", "c1-w"),
    ("stair-main", "c1-w"),
]

HUB_KIND = {
    "entrance-west": "entrance",
    "entrance-dunapart": "entrance",
    "entrance-north": "entrance",
    "bufe": "poi",
    "lift-A": "lift",
    "lift-B": "lift",
    "stair-main": "stair",
    "stair-nw": "stair",
    "stair-ne": "stair",
    "stair-sw": "stair",
    "stair-se": "stair",
}

SHAFT = {
    "lift-A": "ld-lift-A",
    "lift-B": "ld-lift-B",
    "stair-main": "ld-stair-main",
    "stair-nw": "ld-stair-nw",
    "stair-ne": "ld-stair-ne",
    "stair-sw": "ld-stair-sw",
    "stair-se": "ld-stair-se",
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


def parse_room_code(raw: str):
    """Return (codeBis, corridor_digit, ordinal) from rooms.json code.

    Keeps letter / slash suffixes unique, e.g. ``00-66b``, ``00-803/2``.
    """
    m = re.match(
        r"^(\d+)-(\d+)([a-zA-Z])?(?:/(\d+))?",
        raw.strip(),
    )
    if not m:
        return None, None, None
    floor_tok, num, letter, slash = (
        m.group(1),
        m.group(2),
        m.group(3) or "",
        m.group(4),
    )
    code_bis = f"{floor_tok}-{num}{letter}"
    if slash:
        code_bis = f"{code_bis}/{slash}"
    corridor = int(num[0]) if num else None
    ordinal = int(num[1:] or "0")
    if slash:
        ordinal = ordinal * 10 + int(slash)
    return code_bis, corridor, ordinal


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
    # Spread rooms along corridor using last digits (heuristic).
    return (ordinal % 100) / 99.0 if ordinal else 0.5


def offset_toward_room(pt, corridor: int, ordinal: int):
    """Nudge room node off the corridor centerline (~door stub)."""
    # Alternate sides by ordinal parity; magnitude ~35–50 px.
    side = 1 if (ordinal % 2 == 0) else -1
    mag = 40.0
    # Perpendicular depends on corridor orientation (EW vs NS-ish).
    if corridor in (1, 3, 6):  # mostly EW → offset N/S
        return (pt[0], pt[1] + side * mag)
    if corridor in (2, 4, 5, 7):  # mostly NS → offset E/W
        return (pt[0] + side * mag, pt[1])
    # corridor 8 west wing — offset west/east
    return (pt[0] + side * mag * 0.8, pt[1] + (1 if ordinal % 3 else -1) * 15)


def load_bis_index():
    edu = json.load(open(EDU_PATH))["rooms"]
    cat = json.load(open(CATALOG_PATH))["rooms"]
    by_num = {}
    for r in cat + edu:
        by_num[r["roomNumber"]] = r
    return by_num


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
    }
    return m.get(hu, re.sub(r"[^a-z0-9]+", "_", hu.lower()).strip("_"))


def named_aliases(code_bis: str, name: str | None, neptun: str | None):
    aliases = []
    if neptun:
        aliases.append(neptun)
    if name:
        # strip code prefix from name if present
        clean = re.sub(r"^\d+-?\d*\s*", "", name).strip(" -–")
        # keep human hall names
        for part in re.split(r"[/(]", clean):
            part = part.strip(" )")
            if not part:
                continue
            if re.match(r"^(PC|IK|TFK|\d)", part):
                continue
            if len(part) >= 4 and not part.lower().startswith("zárt"):
                aliases.append(part)
                # ASCII-ish variant
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
    # dedupe preserve order
    seen = set()
    out = []
    for a in aliases:
        if a not in seen:
            seen.add(a)
            out.append(a)
    return out[:8]


def build():
    public = json.load(open(ROOMS_PATH))
    bis = load_bis_index()
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

    # --- per-floor hubs ---
    for fl in FLOORS:
        fid = fl["id"]
        for key, (x, y) in HUBS.items():
            kind = HUB_KIND.get(key, "corridor")
            nid = f"ld-n-{fid}-{key}"
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
                    "id": f"ld-e-{fid}-{a}-{b}",
                    "from": f"ld-n-{fid}-{a}",
                    "to": f"ld-n-{fid}-{b}",
                    "weight": round(dist(pa, pb), 1),
                    "bidirectional": True,
                    "kind": "corridor" if not (
                        a.startswith("entrance") or b.startswith("entrance")
                    ) else "entrance",
                }
            )

    # --- rooms + stubs ---
    corridor_hub_key = {
        1: "c1-hub",
        2: "c2-hub",
        3: "c3-hub",
        4: "c4-hub",
        5: "c5-hub",
        6: "c6-hub",
        7: "c7-hub",
        8: "c8-hub",
    }

    stub_count = 0
    for r in public["rooms"]:
        code_bis, corridor, ordinal = parse_room_code(r["code"])
        if not code_bis:
            continue
        level = int(r["floor"])
        fl = floor_by_level[level]
        fid = fl["id"]
        corridor = corridor or 8
        poly = CORRIDOR_POLY.get(corridor, CORRIDOR_POLY[8])
        along = point_on_poly(poly, room_t(ordinal or 0))
        door = offset_toward_room(along, corridor, ordinal or 0)
        # clamp into image
        door = (
            max(20, min(780, door[0])),
            max(20, min(780, door[1])),
        )
        along = (
            max(20, min(780, along[0])),
            max(20, min(780, along[1])),
        )

        room_id = f"ld-room-{code_bis.replace('/', '_')}"
        id_token = code_bis.replace("/", "_")
        bis_row = bis.get(code_bis)
        if not bis_row and "/" in code_bis:
            bis_row = bis.get(code_bis.split("/")[0])
        name = None
        if bis_row:
            name = bis_row.get("roomName") or None
        # prefer public code text after number as name hint
        public_name = None
        mname = re.match(r"^\S+\s+(.+)$", r["code"])
        if mname:
            public_name = mname.group(1).strip()
        display_name = public_name or name or code_bis

        neptun = None
        parts = code_bis.split("-", 1)
        if len(parts) == 2:
            neptun = f"LD {parts[0]}.{parts[1]}"

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
        if bis_row and bis_row.get("centroid"):
            lng, lat = bis_row["centroid"]
            room_obj["centroidWgs"] = {
                "lng": lng,
                "lat": lat,
                "space": "wgs84",
            }
        rooms_out.append(room_obj)

        # corridor attachment node (door mouth on centerline)
        attach_key = f"door-{id_token}"
        attach_id = f"ld-n-{fid}-{attach_key}"
        add_node(
            {
                "id": attach_id,
                "floorId": fid,
                "kind": "corridor",
                "coord": px(along),
                "label": f"door mouth {code_bis}",
            }
        )
        hub_key = corridor_hub_key.get(corridor, "c8-hub")
        hub_id = f"ld-n-{fid}-{hub_key}"
        add_edge(
            {
                "id": f"ld-e-{fid}-hub-{attach_key}",
                "from": hub_id,
                "to": attach_id,
                "weight": round(dist(HUBS[hub_key], along), 1),
                "bidirectional": True,
                "kind": "corridor",
            }
        )

        room_node_id = f"ld-n-{fid}-room-{id_token}"
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
                "id": f"ld-e-{fid}-stub-{id_token}",
                "from": attach_id,
                "to": room_node_id,
                "weight": round(dist(along, door), 1),
                "bidirectional": True,
                "kind": "roomStub",
            }
        )
        stub_count += 1

    # --- vertical edges between consecutive floors ---
    levels = [f["level"] for f in FLOORS]
    for i in range(len(levels) - 1):
        lo, hi = levels[i], levels[i + 1]
        flo, fhi = floor_by_level[lo], floor_by_level[hi]
        for key, shaft in SHAFT.items():
            kind = "verticalLift" if key.startswith("lift") else "verticalStair"
            cost = VERTICAL_COST["lift" if key.startswith("lift") else "stair"]
            add_edge(
                {
                    "id": f"ld-e-vert-{shaft}-{flo['id']}-{fhi['id']}",
                    "from": f"ld-n-{flo['id']}-{key}",
                    "to": f"ld-n-{fhi['id']}-{key}",
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
            "Phase 2 LD MVP graph. Corridor hubs visually placed on 800×800 "
            "basemap CRS (x→Dunapart/east, y→south). Room stubs estimated from "
            "corridor digit in room code + ordinal along corridor polyline — "
            "semi-manual / approximate, not CV-traced. Attic T omitted. "
            "Basemap permission still pending."
        ),
        "building": {
            "id": "ld",
            "neptunPrefix": "LD",
            "nameHu": "Déli Épület",
            "nameEn": "South Building",
            "address": "Pázmány Péter sétány 1/C",
            "bisBuildingSlug": "deli",
        },
        "floors": [
            {
                **{k: fl[k] for k in (
                    "id", "level", "bisSlug", "labelHu", "labelEn", "basemapAsset"
                )},
                "buildingId": "ld",
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
    rid = f"ld-room-{code_bis.replace('/', '_')}"
    for n in package["nodes"]:
        if n.get("kind") == "room" and n.get("roomId") == rid:
            return n["id"]
    return None


def main():
    package = build()
    out_path = OUT / "graph_ld.json"
    out_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote {out_path}")
    print("stats", package["stats"])

    comps = connected_components_per_floor(package)
    print("components (largest first):")
    for fid, sizes in sorted(comps.items()):
        print(f"  {fid}: {sizes[:5]}{'...' if len(sizes)>5 else ''}")

    samples = [
        ("1 same-floor corridor neighbors", "0-821", "0-805"),
        ("2 ground entrance → mid classroom", None, "0-412"),
        ("3 basement ↔ floor 1 (vertical)", "00-112", "1-105"),
        ("4 named halls Bolyai → Rényi", "0-821", "0-412"),
        ("5 cross-corridor 2 → 4", "0-220", "0-412"),
        ("6 cross-floor lift/stair 0 → 3", "0-821", "3-219"),
    ]

    node_floor = {n["id"]: n["floorId"] for n in package["nodes"]}
    routes = []
    for title, a, b in samples:
        if a is None:
            start = "ld-n-ld-f0-entrance-west"
            start_label = "entrance-west@f0"
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

    samples_path = OUT / "samples" / "ld_routes.md"
    lines = [
        "# LD sample routes (Phase 2 QA)",
        "",
        "Generated by `build_graph_ld.py` against `graph_ld.json`.",
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
