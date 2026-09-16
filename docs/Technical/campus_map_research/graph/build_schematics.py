#!/usr/bin/env python3
"""Build mall-style 2D floor schematics for LD / LE (vector JSON).

Corridor ribbons are buffered from known centerline polylines (LD corridor
schema 1–8 / LE zone wings). Outer shells + courtyard holes give a building-
shaped floor plan. Graph remains for routing only — these polygons are the
visual map. Output also copied into assets/campus_map/.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PKG = ROOT.parents[1] / "campus_map_package"
ASSETS = ROOT.parents[3] / "assets" / "campus_map"

FLOORS = [-1, 0, 1, 2, 3, 4, 5, 6, 7]
SIZE = 800

# --- LD (South / Déli) — corridor schema 1–8 ---
LD_CORRIDORS = {
    "c1": [(375, 400), (480, 400), (655, 400)],
    "c2": [(345, 380), (345, 255), (345, 175)],
    "c3": [(375, 155), (480, 155), (620, 155)],
    "c4": [(655, 175), (655, 255), (655, 380)],
    "c5": [(655, 420), (655, 545), (655, 640)],
    "c6": [(375, 655), (480, 655), (620, 655)],
    "c7": [(345, 420), (345, 545), (345, 640)],
    "c8": [(80, 280), (155, 400), (155, 545), (200, 600)],
}
LD_RING_LINKS = [
    [(345, 175), (375, 155)],
    [(620, 155), (655, 175)],
    [(655, 380), (655, 420)],
    [(620, 655), (655, 640)],
    [(345, 640), (375, 655)],
    [(345, 380), (375, 400)],
    [(345, 420), (375, 400)],
    [(655, 380), (590, 400)],
    [(655, 420), (590, 400)],
]
LD_WEST_LINKS = [
    [(155, 400), (255, 400), (375, 400)],
    [(155, 280), (255, 280), (345, 255)],
    [(155, 545), (255, 545), (345, 545)],
]
LD_SHELL = [
    (40, 80), (220, 50), (480, 35), (720, 55), (780, 200), (790, 400),
    (780, 600), (700, 720), (480, 760), (250, 740), (90, 680), (35, 520), (30, 300),
]
LD_COURTYARD = [(390, 220), (610, 220), (610, 580), (390, 580)]

LE_ZONES = {
    "west": [(145, 200), (145, 400), (145, 560)],
    "north": [(200, 145), (400, 145), (600, 145)],
    "east": [(660, 200), (660, 400), (660, 560)],
    "east-s": [(660, 420), (660, 560), (580, 575)],
    "cross": [(200, 400), (400, 400), (600, 400)],
    "south": [(200, 575), (400, 575), (600, 575)],
    "wing": [(400, 600), (400, 690), (400, 760)],
}
LE_LINKS = [
    [(145, 200), (170, 160), (200, 145)],
    [(600, 145), (630, 160), (660, 200)],
    [(145, 560), (170, 575), (200, 575)],
    [(600, 575), (620, 575), (660, 560)],
    [(145, 400), (200, 400)],
    [(600, 400), (660, 400)],
    [(400, 575), (400, 600)],
]
LE_SHELL = [
    (50, 90), (200, 45), (400, 30), (620, 45), (740, 120), (770, 280),
    (780, 420), (760, 560), (680, 640), (520, 720), (400, 790), (280, 720),
    (140, 640), (55, 520), (40, 320), (45, 180),
]
LE_COURTYARD_N = [(220, 200), (560, 200), (560, 340), (220, 340)]
LE_COURTYARD_S = [(220, 450), (560, 450), (560, 540), (220, 540)]


def densify(pts, step=18.0):
    if len(pts) < 2:
        return list(pts)
    out = [pts[0]]
    for i in range(len(pts) - 1):
        ax, ay = pts[i]
        bx, by = pts[i + 1]
        d = math.hypot(bx - ax, by - ay)
        n = max(1, int(d / step))
        for k in range(1, n + 1):
            t = k / n
            out.append((ax + (bx - ax) * t, ay + (by - ay) * t))
    return out


def buffer_polyline(pts, half_w):
    pts = densify(pts)
    if len(pts) < 2:
        return []
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        if i == 0:
            dx, dy = pts[1][0] - x, pts[1][1] - y
        elif i == len(pts) - 1:
            dx, dy = x - pts[i - 1][0], y - pts[i - 1][1]
        else:
            dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L, dx / L
        left.append((x + nx * half_w, y + ny * half_w))
        right.append((x - nx * half_w, y - ny * half_w))
    ring = left + list(reversed(right))
    return [[round(p[0], 1), round(p[1], 1)] for p in ring]


def poly_points(pts):
    return [[round(p[0], 1), round(p[1], 1)] for p in pts]


def floor_schematic(building, level, shell, holes, centerlines, half_w):
    corridors = []
    for cid, line in centerlines:
        ribbon = buffer_polyline(line, half_w)
        if len(ribbon) >= 3:
            corridors.append({
                "id": cid,
                "centerline": poly_points(line),
                "polygon": ribbon,
            })
    fid = f"{building}-f{level}"
    return {
        "floorId": fid,
        "level": level,
        "basemapWidth": SIZE,
        "basemapHeight": SIZE,
        "shell": poly_points(shell),
        "holes": [poly_points(h) for h in holes],
        "corridors": corridors,
    }


def build_ld():
    lines = [(k, v) for k, v in LD_CORRIDORS.items()]
    for i, link in enumerate(LD_RING_LINKS + LD_WEST_LINKS):
        lines.append((f"link-{i}", link))
    floors = [floor_schematic("ld", lv, LD_SHELL, [LD_COURTYARD], lines, 30.0) for lv in FLOORS]
    return {
        "schemaVersion": 1,
        "packageKind": "campusFloorSchematic",
        "buildingId": "ld",
        "nameEn": "South Building (LD)",
        "nameHu": "Déli Épület (LD)",
        "generatedAt": "2026-09-16",
        "notes": "Mall-style schematic: shell + courtyard + corridor ribbons from LD schema 1–8. Graph for routing only.",
        "floors": floors,
    }


def build_le():
    lines = [(k, v) for k, v in LE_ZONES.items()]
    for i, link in enumerate(LE_LINKS):
        lines.append((f"link-{i}", link))
    floors = [floor_schematic("le", lv, LE_SHELL, [LE_COURTYARD_N, LE_COURTYARD_S], lines, 28.0) for lv in FLOORS]
    return {
        "schemaVersion": 1,
        "packageKind": "campusFloorSchematic",
        "buildingId": "le",
        "nameEn": "North Building (LE)",
        "nameHu": "Északi Épület (LE)",
        "generatedAt": "2026-09-16",
        "notes": "Mall-style schematic: shell + two courtyards + zone ribbons. Graph for routing only.",
        "floors": floors,
    }


def write(name, data):
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    for dest in (ROOT / name, PKG / name, ASSETS / name):
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding="utf-8")
        print(f"wrote {dest}")


if __name__ == "__main__":
    write("schematic_ld.json", build_ld())
    write("schematic_le.json", build_le())
