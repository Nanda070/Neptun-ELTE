#!/usr/bin/env python3
"""Rebuild polygons_ld/le.json: MVT FootPrint + catalog bbox fill + floor hulls (1.8.2)."""
from __future__ import annotations

import json
import math
import re
from collections import Counter, defaultdict
from pathlib import Path

import mapbox_vector_tile

ROOT = Path(__file__).resolve().parents[5]
POLY_DIR = Path(__file__).resolve().parent
ASSET = ROOT / "assets/campus_map"

SOUTH_CAT = json.loads(
    (ROOT / "docs/Technical/campus_map_research/bis/south/rooms_catalog.json").read_text()
)
NORTH_CAT = json.loads(
    (ROOT / "docs/Technical/campus_map_research/bis/north/rooms_catalog.json").read_text()
)
SOUTH_FLOORS = json.loads(
    (ROOT / "docs/Technical/campus_map_research/bis/south/floors.json").read_text()
)["floors"]
NORTH_FLOORS = json.loads(
    (ROOT / "docs/Technical/campus_map_research/bis/north/floors.json").read_text()
)["floors"]
SOUTH_BLD = json.loads(
    (ROOT / "docs/Technical/campus_map_research/bis/south/building.json").read_text()
)
NORTH_BLD = json.loads(
    (ROOT / "docs/Technical/campus_map_research/bis/north/building.json").read_text()
)

ld_old = json.loads((ASSET / "polygons_ld.json").read_text())
le_old = json.loads((ASSET / "polygons_le.json").read_text())


def tile_to_lnglat(px, py, z, tx, ty, extent=4096):
    n = 2.0**z
    lng = (tx + px / extent) / n * 360.0 - 180.0
    merc_y = (ty + py / extent) / n
    lat = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * merc_y))))
    return lng, lat


def parse_tile_name(name):
    m = re.match(r"rooms_(\d+)_(\d+)_(\d+)\.pbf", name)
    return tuple(map(int, m.groups())) if m else None


def ring_centroid(ring):
    if len(ring) < 2:
        return None
    pts = ring[:-1] if ring[0] == ring[-1] else ring
    if not pts:
        return None
    return sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)


def reanchor_ring(ring, target_lng, target_lat):
    c = ring_centroid(ring)
    if not c:
        return ring
    dx, dy = target_lng - c[0], target_lat - c[1]
    return [[p[0] + dx, p[1] + dy] for p in ring]


def geom_to_rings_wgs(geom, z, tx, ty):
    rings = []

    def conv_ring(coords):
        out = []
        for pt in coords:
            lng, lat = tile_to_lnglat(pt[0], pt[1], z, tx, ty)
            out.append([lng, lat])
        if len(out) >= 3:
            if out[0] != out[-1]:
                out.append(out[0][:])
            rings.append(out)

    gtype = geom["type"]
    coords = geom["coordinates"]
    if gtype == "Polygon":
        if coords:
            conv_ring(coords[0])
    elif gtype == "MultiPolygon":
        for poly in coords:
            if poly:
                conv_ring(poly[0])
    return rings


def bbox_ring(bbox):
    w, s, e, n = bbox
    return [[w, s], [e, s], [e, n], [w, n], [w, s]]


by_code = {}
for pbf in sorted((POLY_DIR / "tiles_raw").glob("*.pbf")):
    meta = parse_tile_name(pbf.name)
    if not meta:
        continue
    z, tx, ty = meta
    try:
        tile = mapbox_vector_tile.decode(pbf.read_bytes())
    except Exception as e:
        print("skip bad", pbf.name, e)
        continue
    for f in tile.get("rooms", {}).get("features", []):
        pr = f["properties"]
        code = pr.get("roomCode")
        if not code:
            continue
        rings = geom_to_rings_wgs(f["geometry"], z, tx, ty)
        if not rings:
            continue
        score = (z, sum(len(r) for r in rings))
        prev = by_code.get(code)
        if prev is None or score > prev["score"]:
            by_code[code] = {
                "props": pr,
                "rings": rings,
                "score": score,
                "tile": pbf.name,
            }

print(
    "unique roomCodes from MVT",
    len(by_code),
    "types",
    Counter(v["props"].get("roomType") for v in by_code.values()),
)


def index_cat(cat):
    return {r["roomCode"]: r for r in cat["rooms"] if r.get("roomCode")}


south_idx = index_cat(SOUTH_CAT)
north_idx = index_cat(NORTH_CAT)

LD_SN = {"00": -1, "0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7}
LE_SN = {"-1": -1, "0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7}


def floor_maps(floors, sn_map):
    fid_to_level = {}
    fid_to_hull = {}
    fid_to_label = {}
    level_to_fid = {}
    for f in floors:
        sn = str(f["shortName"])
        if sn not in sn_map:
            continue
        lvl = sn_map[sn]
        fid_to_level[f["id"]] = lvl
        fid_to_hull[f["id"]] = f.get("hull") or []
        fid_to_label[f["id"]] = sn
        level_to_fid[lvl] = f["id"]
    return fid_to_level, fid_to_hull, fid_to_label, level_to_fid


ld_fid_lvl, ld_hulls, ld_labels, ld_lvl_fid = floor_maps(SOUTH_FLOORS, LD_SN)
le_fid_lvl, le_hulls, le_labels, le_lvl_fid = floor_maps(NORTH_FLOORS, LE_SN)


def seed_from_asset(asset):
    rooms = {}
    for fl in asset["floors"]:
        for r in fl["rooms"]:
            rooms[r["code"]] = {
                "id": r.get("id"),
                "code": r["code"],
                "number": r.get("number") or "",
                "name": r.get("name") or "",
                "type": r.get("type") or "misc",
                "rings": r["rings"],
                "level": fl["level"],
                "bisFloorId": fl.get("bisFloorId"),
                "source": "asset",
            }
    return rooms


def build_building(
    building_id, asset_old, cat_idx, fid_lvl, hulls, labels, lvl_fid, bld, rotation
):
    rooms = seed_from_asset(asset_old)
    stats = Counter()
    for code, mvt in by_code.items():
        cat = cat_idx.get(code)
        if not cat:
            continue
        fid = cat["floorId"]
        if fid not in fid_lvl:
            continue
        lvl = fid_lvl[fid]
        clng, clat = cat["centroid"]
        rings = [reanchor_ring(r, clng, clat) for r in mvt["rings"]]
        rings = [r for r in rings if len(r) >= 4]
        if not rings:
            continue
        typ = (
            (cat.get("properties") or {}).get("roomType")
            or mvt["props"].get("roomType")
            or "misc"
        )
        if code not in rooms:
            rooms[code] = {
                "id": cat.get("id"),
                "code": code,
                "number": cat.get("roomNumber") or mvt["props"].get("roomNumber") or "",
                "name": cat.get("roomName") or mvt["props"].get("roomName") or "",
                "type": typ,
                "rings": rings,
                "level": lvl,
                "bisFloorId": fid,
                "source": "mvt",
            }
            stats["mvt_new"] += 1

    for code, cat in cat_idx.items():
        fid = cat["floorId"]
        if fid not in fid_lvl:
            continue
        if code in rooms:
            continue
        if not cat.get("bbox") or not cat.get("centroid"):
            continue
        lvl = fid_lvl[fid]
        clng, clat = cat["centroid"]
        ring = reanchor_ring(bbox_ring(cat["bbox"]), clng, clat)
        typ = (cat.get("properties") or {}).get("roomType") or "misc"
        rooms[code] = {
            "id": cat.get("id"),
            "code": code,
            "number": cat.get("roomNumber") or "",
            "name": cat.get("roomName") or "",
            "type": typ,
            "rings": [ring],
            "level": lvl,
            "bisFloorId": fid,
            "source": "catalog-bbox",
        }
        stats["bbox_fill"] += 1
        stats[f"bbox_{typ}"] += 1

    by_level = defaultdict(list)
    for r in rooms.values():
        by_level[r["level"]].append(r)

    floors_out = []
    all_lng = []
    all_lat = []
    for lvl in sorted(by_level.keys()):
        rs = by_level[lvl]
        fid = lvl_fid.get(lvl)
        hull = hulls.get(fid) or []
        hull_ring = None
        if hull and len(hull) >= 3:
            hull_ring = [list(p) for p in hull]
            if hull_ring[0] != hull_ring[-1]:
                hull_ring.append(hull_ring[0][:])
        room_objs = []
        for r in sorted(rs, key=lambda x: x["code"]):
            for ring in r["rings"]:
                for p in ring:
                    all_lng.append(p[0])
                    all_lat.append(p[1])
            obj = {
                "id": r["id"],
                "code": r["code"],
                "number": r["number"],
                "name": r["name"],
                "type": r["type"],
                "rings": r["rings"],
            }
            if r["source"] == "catalog-bbox":
                obj["fillSource"] = "catalog-bbox"
            room_objs.append(obj)
        floors_out.append(
            {
                "level": lvl,
                "bisFloorId": fid,
                "label": labels.get(fid, str(lvl)),
                "roomCount": len(room_objs),
                "hull": hull_ring,
                "rooms": room_objs,
            }
        )

    bbox = (
        [min(all_lng), min(all_lat), max(all_lng), max(all_lat)]
        if all_lng
        else bld.get("bbox")
    )
    n_bbox = sum(1 for r in rooms.values() if r["source"] == "catalog-bbox")
    n_mvtish = sum(1 for r in rooms.values() if r["source"] in ("asset", "mvt"))
    out = {
        "schemaVersion": 2,
        "buildingId": building_id,
        "crs": "wgs84",
        "source": (
            "bis.elte.hu/tiles/rooms MVT FootPrint + catalog-bbox fill for missing "
            "(technical absent from MVT); hull from BIS floors entities; "
            "catalog-centroid-reanchor"
        ),
        "polygonCount": len(rooms),
        "catalogCount": len(cat_idx),
        "footprintFromMvt": n_mvtish,
        "bboxFillCount": n_bbox,
        "skippedOutsideSwitcher": len(cat_idx) - len(rooms),
        "bbox": bbox,
        "rotationAngle": rotation,
        "buildingHull": bld.get("hull"),
        "crsNote": (
            "WGS84; MVT rings reanchored to catalog centroids; missing roomTypes "
            "(esp. technical) filled with catalog bbox rectangles; view uses floor "
            "hull fitBounds + underlay"
        ),
        "floors": floors_out,
    }
    print(
        building_id,
        "rooms",
        len(rooms),
        "mvtish",
        n_mvtish,
        "bboxFill",
        n_bbox,
        "stats",
        dict(stats),
    )
    print("  by level", {f["level"]: f["roomCount"] for f in floors_out})
    print("  types", Counter(r["type"] for r in rooms.values()))
    return out


rot_ld = ld_old.get("rotationAngle") or 78.5
rot_le = le_old.get("rotationAngle") or 78.5

ld_new = build_building(
    "ld", ld_old, south_idx, ld_fid_lvl, ld_hulls, ld_labels, ld_lvl_fid, SOUTH_BLD, rot_ld
)
le_new = build_building(
    "le", le_old, north_idx, le_fid_lvl, le_hulls, le_labels, le_lvl_fid, NORTH_BLD, rot_le
)

(ASSET / "polygons_ld.json").write_text(json.dumps(ld_new, separators=(",", ":")))
(ASSET / "polygons_le.json").write_text(json.dumps(le_new, separators=(",", ":")))

for data, name in (
    (ld_new, "deli_rooms_filled.geojson"),
    (le_new, "eszaki_rooms_filled.geojson"),
):
    feats = []
    for fl in data["floors"]:
        for r in fl["rooms"]:
            feats.append(
                {
                    "type": "Feature",
                    "properties": {
                        "id": r.get("id"),
                        "roomCode": r["code"],
                        "roomNumber": r["number"],
                        "roomName": r["name"],
                        "roomType": r["type"],
                        "floorId": fl.get("bisFloorId"),
                        "level": fl["level"],
                        "fillSource": r.get("fillSource", "mvt"),
                    },
                    "geometry": {"type": "Polygon", "coordinates": r["rings"][:1]},
                }
            )
    (POLY_DIR / name).write_text(json.dumps({"type": "FeatureCollection", "features": feats}))

summary = {
    "generatedAt": "2026-09-16",
    "totalPolygons": ld_new["polygonCount"] + le_new["polygonCount"],
    "catalogTotal": ld_new["catalogCount"] + le_new["catalogCount"],
    "footprintFromMvt": ld_new["footprintFromMvt"] + le_new["footprintFromMvt"],
    "bboxFillCount": ld_new["bboxFillCount"] + le_new["bboxFillCount"],
    "buildings": {
        "ld": {
            "file": "assets/campus_map/polygons_ld.json",
            "bytes": (ASSET / "polygons_ld.json").stat().st_size,
            "polygons": ld_new["polygonCount"],
            "catalog": ld_new["catalogCount"],
            "mvt": ld_new["footprintFromMvt"],
            "bboxFill": ld_new["bboxFillCount"],
            "floors": {str(f["level"]): f["roomCount"] for f in ld_new["floors"]},
            "rotationAngle": ld_new["rotationAngle"],
            "bbox": ld_new["bbox"],
            "hasFloorHulls": all(f.get("hull") for f in ld_new["floors"]),
        },
        "le": {
            "file": "assets/campus_map/polygons_le.json",
            "bytes": (ASSET / "polygons_le.json").stat().st_size,
            "polygons": le_new["polygonCount"],
            "catalog": le_new["catalogCount"],
            "mvt": le_new["footprintFromMvt"],
            "bboxFill": le_new["bboxFillCount"],
            "floors": {str(f["level"]): f["roomCount"] for f in le_new["floors"]},
            "rotationAngle": le_new["rotationAngle"],
            "bbox": le_new["bbox"],
            "hasFloorHulls": all(f.get("hull") for f in le_new["floors"]),
        },
    },
    "uiMode": "bis-footprint-polygons",
    "routeCrs": "graph-basemapPx affine→WGS84 using room centroidWgs control points (approximate)",
    "polygonCrs": (
        "WGS84; MVT reanchored to catalog centroids; technical/missing filled via "
        "catalog bbox; floor hull underlay+fitBounds"
    ),
    "fixNote": (
        "BIS MVT rooms layer has 0 technical FootPrints. Step C denser z17/z18 tiles "
        "added no technical. Catalog bbox rectangles fill those holes; floor entity "
        "hull used for view fit + underlay (1.8.2)."
    ),
}
(ASSET / "polygons_summary.json").write_text(json.dumps(summary, indent=2))

prev = {}
cap = POLY_DIR / "CAPTURE_SUMMARY.json"
if cap.exists():
    prev = json.loads(cap.read_text())
prev["updatedAt"] = "2026-09-16"
prev["stepC"] = {
    "denserTiles": sorted(p.name for p in (POLY_DIR / "tiles_raw").glob("*.pbf")),
    "mvtRoomTypesObserved": dict(
        Counter(v["props"].get("roomType") for v in by_code.values())
    ),
    "technicalInMvt": 0,
    "bboxFillLd": ld_new["bboxFillCount"],
    "bboxFillLe": le_new["bboxFillCount"],
    "bundledTotal": summary["totalPolygons"],
}
cap.write_text(json.dumps(prev, indent=2))
print("DONE total", summary["totalPolygons"], "of", summary["catalogTotal"])
print(
    "sizes",
    (ASSET / "polygons_ld.json").stat().st_size,
    (ASSET / "polygons_le.json").stat().st_size,
)
