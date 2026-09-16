#!/usr/bin/env python3
"""Non-Flutter Phase 5 checker: verify checksums + sample A→B on packaged graphs."""

from __future__ import annotations

import hashlib
import json
import sys
from collections import defaultdict
from heapq import heappop, heappush
from pathlib import Path

PKG = Path(__file__).resolve().parent

# Sample pairs from Phase 2/3 route samples (node ids).
SAMPLES = [
    ("graph_ld.json", "ld-n-ld-f0-room-0-821", "ld-n-ld-f0-room-0-805", "LD same-floor"),
    ("graph_ld.json", "ld-n-ld-f0-entrance-west", "ld-n-ld-f0-room-0-412", "LD entrance→room"),
    ("graph_ld.json", "ld-n-ld-f-1-room-00-112", "ld-n-ld-f1-room-1-105", "LD cross-floor"),
    ("graph_le.json", "le-n-le-f0-room-0_81", "le-n-le-f0-room-0_83", "LE same-floor"),
    ("graph_le.json", "le-n-le-f0-entrance-dunapart", "le-n-le-f0-room-0_81", "LE entrance→room"),
    ("graph_le.json", "le-n-le-f-1-room-_1_53", "le-n-le-f1-room-1_71", "LE cross-floor"),
]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def verify_checksums() -> None:
    checksums = PKG / "checksums.sha256"
    if not checksums.is_file():
        raise SystemExit("missing checksums.sha256")
    lines = [ln.strip() for ln in checksums.read_text().splitlines() if ln.strip()]
    if not lines:
        raise SystemExit("checksums.sha256 is empty")
    for line in lines:
        digest, name = line.split(None, 1)
        name = name.lstrip("*").strip()
        path = PKG / name
        if not path.is_file():
            raise SystemExit(f"checksum lists missing file: {name}")
        got = sha256_file(path)
        if got != digest:
            raise SystemExit(f"checksum mismatch: {name}\n  expected {digest}\n  got      {got}")
    print(f"checksums: OK ({len(lines)} files)")


def shortest_path(package: dict, start_id: str, goal_id: str):
    adj = defaultdict(list)
    for e in package["edges"]:
        w = e["weight"]
        adj[e["from"]].append((e["to"], w, e["id"]))
        if e.get("bidirectional", True):
            adj[e["to"]].append((e["from"], w, e["id"]))

    pq = [(0.0, start_id)]
    best = {start_id: 0.0}
    prev = {}
    while pq:
        cost, u = heappop(pq)
        if u == goal_id:
            break
        if cost > best.get(u, 1e18):
            continue
        for v, w, eid in adj[u]:
            nc = cost + w
            if nc < best.get(v, 1e18):
                best[v] = nc
                prev[v] = (u, eid)
                heappush(pq, (nc, v))
    if goal_id not in prev and start_id != goal_id:
        return None, None
    path = [goal_id]
    cur = goal_id
    while cur != start_id:
        cur, _ = prev[cur]
        path.append(cur)
    path.reverse()
    return path, best[goal_id]


def check_routes() -> None:
    cache = {}
    for graph_name, start, goal, label in SAMPLES:
        if graph_name not in cache:
            cache[graph_name] = json.loads((PKG / graph_name).read_text())
        path, cost = shortest_path(cache[graph_name], start, goal)
        if not path:
            raise SystemExit(f"no path: {label} ({start} → {goal})")
        print(f"A→B OK [{label}]: hops={len(path)-1} cost={cost:.1f}")


def check_manifest_assets() -> None:
    manifest = json.loads((PKG / "manifest.json").read_text())
    for building, levels in manifest["assets"].items():
        for level, rel in levels.items():
            path = PKG / rel
            if not path.is_file():
                raise SystemExit(f"manifest asset missing: {rel} ({building} level {level})")
    for key in (
        "graph_ld.json",
        "graph_le.json",
        "joins_ld.json",
        "joins_le.json",
        "aliases.json",
        "ATTRIBUTION.md",
        "manifest.json",
    ):
        if not (PKG / key).is_file():
            raise SystemExit(f"required file missing: {key}")
    print("manifest assets + required files: OK")
    if (PKG / "ATTRIBUTION.md").is_file():
        print("ATTRIBUTION.md present")


def main() -> int:
    check_manifest_assets()
    verify_checksums()
    check_routes()
    print("Phase 5 package check: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
