import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/services.dart';

/// Offline campus map package loader (Phase B). Assets under `assets/campus_map/`.
class CampusMapPackage {
  CampusMapPackage._({
    required this.manifest,
    required this.graphs,
    required this.schematics,
    required this.joinsByBuilding,
    required this.aliases,
  });

  final Map<String, dynamic> manifest;
  final Map<String, CampusBuildingGraph> graphs; // ld / le
  /// Mall-style floor polygons (shell + corridor ribbons). Visual map only.
  final Map<String, CampusBuildingSchematic> schematics;
  final Map<String, List<CampusJoin>> joinsByBuilding;
  final List<CampusAlias> aliases;

  static const assetRoot = 'assets/campus_map';

  static Future<CampusMapPackage> load() async {
    final manifest = jsonDecode(
      await rootBundle.loadString('$assetRoot/manifest.json'),
    ) as Map<String, dynamic>;

    final graphs = <String, CampusBuildingGraph>{};
    final schematics = <String, CampusBuildingSchematic>{};
    final joinsByBuilding = <String, List<CampusJoin>>{};

    for (final b in (manifest['buildings'] as List).cast<Map>()) {
      final id = b['id'] as String;
      final graphFile = b['graph'] as String;
      final joinsFile = b['joins'] as String;
      graphs[id] = CampusBuildingGraph.fromJson(
        jsonDecode(await rootBundle.loadString('$assetRoot/$graphFile'))
            as Map<String, dynamic>,
      );
      final schematicFile = (b['schematic'] as String?) ?? 'schematic_$id.json';
      try {
        schematics[id] = CampusBuildingSchematic.fromJson(
          jsonDecode(await rootBundle.loadString('$assetRoot/$schematicFile'))
              as Map<String, dynamic>,
        );
      } catch (_) {
        // Optional: older packages without schematic JSON still load graphs.
      }
      final joinsRaw = jsonDecode(
        await rootBundle.loadString('$assetRoot/$joinsFile'),
      ) as Map<String, dynamic>;
      joinsByBuilding[id] = (joinsRaw['joins'] as List)
          .cast<Map>()
          .map((e) => CampusJoin.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final aliasesRaw = jsonDecode(
      await rootBundle.loadString('$assetRoot/aliases.json'),
    ) as Map<String, dynamic>;
    final aliases = (aliasesRaw['aliases'] as List)
        .cast<Map>()
        .map((e) => CampusAlias.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return CampusMapPackage._(
      manifest: manifest,
      graphs: graphs,
      schematics: schematics,
      joinsByBuilding: joinsByBuilding,
      aliases: aliases,
    );
  }

  CampusFloorSchematic? floorSchematic(String buildingId, int level) {
    return schematics[buildingId]?.floorByLevel(level);
  }

  String basemapAsset(String buildingId, int level) {
    final assets = (manifest['assets'] as Map)[buildingId] as Map;
    final rel = assets['$level'] as String? ?? assets[level.toString()] as String?;
    if (rel == null) {
      throw StateError('No basemap for $buildingId floor $level');
    }
    return '$assetRoot/$rel';
  }
}

class CampusBuildingGraph {
  CampusBuildingGraph({
    required this.buildingId,
    required this.nameEn,
    required this.nameHu,
    required this.floors,
    required this.rooms,
    required this.nodes,
    required this.edges,
    required this.adj,
    required this.roomNodeByRoomId,
  });

  final String buildingId;
  final String nameEn;
  final String nameHu;
  final List<CampusFloor> floors;
  final Map<String, CampusRoom> rooms;
  final Map<String, CampusNode> nodes;
  final List<CampusEdge> edges;
  final Map<String, List<CampusGraphLink>> adj;
  final Map<String, String> roomNodeByRoomId;

  factory CampusBuildingGraph.fromJson(Map<String, dynamic> j) {
    final building = j['building'] as Map<String, dynamic>;
    final floors = (j['floors'] as List)
        .cast<Map>()
        .map((e) => CampusFloor.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.level.compareTo(b.level));
    final rooms = <String, CampusRoom>{};
    for (final e in (j['rooms'] as List).cast<Map>()) {
      final room = CampusRoom.fromJson(Map<String, dynamic>.from(e));
      rooms[room.id] = room;
    }
    final nodes = <String, CampusNode>{};
    final roomNodeByRoomId = <String, String>{};
    for (final e in (j['nodes'] as List).cast<Map>()) {
      final node = CampusNode.fromJson(Map<String, dynamic>.from(e));
      nodes[node.id] = node;
      if (node.roomId != null) {
        roomNodeByRoomId[node.roomId!] = node.id;
      }
    }
    final edges = (j['edges'] as List)
        .cast<Map>()
        .map((e) => CampusEdge.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final adj = <String, List<CampusGraphLink>>{};
    for (final e in edges) {
      adj.putIfAbsent(e.from, () => []).add(CampusGraphLink(e.to, e.weight));
      if (e.bidirectional) {
        adj.putIfAbsent(e.to, () => []).add(CampusGraphLink(e.from, e.weight));
      }
    }
    return CampusBuildingGraph(
      buildingId: building['id'] as String,
      nameEn: building['nameEn'] as String? ?? building['id'] as String,
      nameHu: building['nameHu'] as String? ?? building['id'] as String,
      floors: floors,
      rooms: rooms,
      nodes: nodes,
      edges: edges,
      adj: adj,
      roomNodeByRoomId: roomNodeByRoomId,
    );
  }

  CampusFloor? floorByLevel(int level) {
    for (final f in floors) {
      if (f.level == level) return f;
    }
    return null;
  }

  CampusFloor? floorById(String id) {
    for (final f in floors) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Dijkstra shortest path between node ids. Returns null if unreachable.
  List<String>? shortestPath(String startId, String goalId) {
    if (startId == goalId) return [startId];
    if (!nodes.containsKey(startId) || !nodes.containsKey(goalId)) return null;

    final best = <String, double>{startId: 0};
    final prev = <String, String>{};
    final pq = PriorityQueue<_CostNode>((a, b) => a.cost.compareTo(b.cost));
    pq.add(_CostNode(0, startId));

    while (pq.isNotEmpty) {
      final cur = pq.removeFirst();
      final cost = cur.cost;
      final u = cur.id;
      if (u == goalId) break;
      if (cost > (best[u] ?? double.infinity)) continue;
      final neighbors = adj[u];
      if (neighbors == null) continue;
      for (final edge in neighbors) {
        final v = edge.to;
        final w = edge.w;
        final nc = cost + w;
        if (nc < (best[v] ?? double.infinity)) {
          best[v] = nc;
          prev[v] = u;
          pq.add(_CostNode(nc, v));
        }
      }
    }

    if (!prev.containsKey(goalId) && startId != goalId) return null;
    final path = <String>[goalId];
    var cur = goalId;
    while (cur != startId) {
      final p = prev[cur];
      if (p == null) return null;
      cur = p;
      path.add(cur);
    }
    return path.reversed.toList();
  }
}

class CampusGraphLink {
  CampusGraphLink(this.to, this.w);
  final String to;
  final double w;
}

class _CostNode {
  _CostNode(this.cost, this.id);
  final double cost;
  final String id;
}

class CampusBuildingSchematic {
  CampusBuildingSchematic({
    required this.buildingId,
    required this.floors,
  });

  final String buildingId;
  final List<CampusFloorSchematic> floors;

  factory CampusBuildingSchematic.fromJson(Map<String, dynamic> j) {
    final floors = (j['floors'] as List)
        .cast<Map>()
        .map((e) => CampusFloorSchematic.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return CampusBuildingSchematic(
      buildingId: j['buildingId'] as String? ?? '',
      floors: floors,
    );
  }

  CampusFloorSchematic? floorByLevel(int level) {
    for (final f in floors) {
      if (f.level == level) return f;
    }
    return null;
  }
}

class CampusFloorSchematic {
  CampusFloorSchematic({
    required this.floorId,
    required this.level,
    required this.shell,
    required this.holes,
    required this.corridors,
  });

  final String floorId;
  final int level;
  final List<Offset> shell;
  final List<List<Offset>> holes;
  final List<CampusCorridorRibbon> corridors;

  factory CampusFloorSchematic.fromJson(Map<String, dynamic> j) {
    List<Offset> pts(dynamic raw) => (raw as List)
        .map((e) {
          final p = e as List;
          return Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
        })
        .toList();
    return CampusFloorSchematic(
      floorId: j['floorId'] as String? ?? '',
      level: (j['level'] as num).toInt(),
      shell: pts(j['shell'] ?? const []),
      holes: ((j['holes'] as List?) ?? const [])
          .map((h) => pts(h))
          .toList(),
      corridors: ((j['corridors'] as List?) ?? const [])
          .cast<Map>()
          .map((e) => CampusCorridorRibbon.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class CampusCorridorRibbon {
  CampusCorridorRibbon({
    required this.id,
    required this.centerline,
    required this.polygon,
  });

  final String id;
  final List<Offset> centerline;
  final List<Offset> polygon;

  factory CampusCorridorRibbon.fromJson(Map<String, dynamic> j) {
    List<Offset> pts(dynamic raw) => ((raw as List?) ?? const [])
        .map((e) {
          final p = e as List;
          return Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
        })
        .toList();
    return CampusCorridorRibbon(
      id: j['id'] as String? ?? '',
      centerline: pts(j['centerline']),
      polygon: pts(j['polygon']),
    );
  }
}

class CampusFloor {
  CampusFloor({
    required this.id,
    required this.level,
    required this.labelEn,
    required this.labelHu,
    required this.basemapAsset,
    required this.basemapWidth,
    required this.basemapHeight,
  });

  final String id;
  final int level;
  final String labelEn;
  final String labelHu;
  final String basemapAsset;
  final int basemapWidth;
  final int basemapHeight;

  factory CampusFloor.fromJson(Map<String, dynamic> j) => CampusFloor(
        id: j['id'] as String,
        level: (j['level'] as num).toInt(),
        labelEn: j['labelEn'] as String? ?? 'Floor ${j['level']}',
        labelHu: j['labelHu'] as String? ?? '${j['level']}. emelet',
        basemapAsset: j['basemapAsset'] as String,
        basemapWidth: (j['basemapWidth'] as num).toInt(),
        basemapHeight: (j['basemapHeight'] as num).toInt(),
      );
}

class CampusRoom {
  CampusRoom({
    required this.id,
    required this.floorId,
    required this.codeBis,
    required this.codeNeptun,
    required this.name,
    required this.x,
    required this.y,
    required this.aliases,
  });

  final String id;
  final String floorId;
  final String codeBis;
  final String? codeNeptun;
  final String name;
  final double x;
  final double y;
  final List<String> aliases;

  factory CampusRoom.fromJson(Map<String, dynamic> j) {
    final c = j['centroid'] as Map<String, dynamic>;
    return CampusRoom(
      id: j['id'] as String,
      floorId: j['floorId'] as String,
      codeBis: j['codeBis'] as String? ?? '',
      codeNeptun: j['codeNeptun'] as String?,
      name: j['name'] as String? ?? j['codeBis'] as String? ?? j['id'] as String,
      x: (c['x'] as num).toDouble(),
      y: (c['y'] as num).toDouble(),
      aliases: ((j['aliases'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  String get displayLabel =>
      (codeNeptun != null && codeNeptun!.trim().isNotEmpty)
          ? codeNeptun!
          : name;
}

class CampusNode {
  CampusNode({
    required this.id,
    required this.floorId,
    required this.kind,
    required this.x,
    required this.y,
    this.roomId,
  });

  final String id;
  final String floorId;
  final String kind;
  final double x;
  final double y;
  final String? roomId;

  factory CampusNode.fromJson(Map<String, dynamic> j) {
    final c = j['coord'] as Map<String, dynamic>;
    return CampusNode(
      id: j['id'] as String,
      floorId: j['floorId'] as String,
      kind: j['kind'] as String? ?? 'corridor',
      x: (c['x'] as num).toDouble(),
      y: (c['y'] as num).toDouble(),
      roomId: j['roomId'] as String?,
    );
  }
}

class CampusEdge {
  CampusEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.weight,
    required this.bidirectional,
    required this.kind,
  });

  final String id;
  final String from;
  final String to;
  final double weight;
  final bool bidirectional;
  final String kind;

  factory CampusEdge.fromJson(Map<String, dynamic> j) => CampusEdge(
        id: j['id'] as String,
        from: j['from'] as String,
        to: j['to'] as String,
        weight: (j['weight'] as num).toDouble(),
        bidirectional: j['bidirectional'] as bool? ?? true,
        kind: j['kind'] as String? ?? 'corridor',
      );
}

class CampusJoin {
  CampusJoin({
    required this.neptunCode,
    required this.neptunAliases,
    required this.codeBis,
    required this.roomId,
    required this.confidence,
  });

  final String neptunCode;
  final List<String> neptunAliases;
  final String codeBis;
  final String? roomId;
  final String confidence;

  factory CampusJoin.fromJson(Map<String, dynamic> j) => CampusJoin(
        neptunCode: j['neptunCode'] as String? ?? '',
        neptunAliases: ((j['neptunAliases'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        codeBis: j['codeBis'] as String? ?? '',
        roomId: j['roomId'] as String?,
        confidence: j['confidence'] as String? ?? 'heuristic',
      );
}

class CampusAlias {
  CampusAlias({
    required this.alias,
    required this.buildingId,
    required this.roomId,
    required this.nodeId,
  });

  final String alias;
  final String buildingId;
  final String? roomId;
  final String? nodeId;

  factory CampusAlias.fromJson(Map<String, dynamic> j) => CampusAlias(
        alias: j['alias'] as String,
        buildingId: j['buildingId'] as String,
        roomId: j['roomId'] as String?,
        nodeId: j['nodeId'] as String?,
      );
}

class CampusSearchHit {
  CampusSearchHit({
    required this.buildingId,
    required this.room,
    required this.nodeId,
    required this.label,
    required this.score,
  });

  final String buildingId;
  final CampusRoom room;
  final String nodeId;
  final String label;
  final int score;
}

extension CampusMapSearch on CampusMapPackage {
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('á', 'a')
      .replaceAll('ó', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ő', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ű', 'u')
      .replaceAll(RegExp(r'[\s._\-]+'), '');

  List<CampusSearchHit> search(String query, {int limit = 25}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final nq = _norm(q);
    final hits = <CampusSearchHit>[];

    void consider({
      required String buildingId,
      required CampusRoom room,
      required String label,
      required int score,
    }) {
      final nodeId = graphs[buildingId]?.roomNodeByRoomId[room.id];
      if (nodeId == null) return;
      hits.add(CampusSearchHit(
        buildingId: buildingId,
        room: room,
        nodeId: nodeId,
        label: label,
        score: score,
      ));
    }

    for (final entry in joinsByBuilding.entries) {
      final buildingId = entry.key;
      final graph = graphs[buildingId];
      if (graph == null) continue;
      for (final join in entry.value) {
        if (join.roomId == null) continue;
        final room = graph.rooms[join.roomId!];
        if (room == null) continue;
        final candidates = <String>[
          join.neptunCode,
          join.codeBis,
          ...join.neptunAliases,
          room.name,
          room.codeNeptun ?? '',
          ...room.aliases,
        ];
        for (final c in candidates) {
          if (c.isEmpty) continue;
          final nc = _norm(c);
          if (nc == nq) {
            consider(buildingId: buildingId, room: room, label: c, score: 100);
          } else if (nc.contains(nq) || nq.contains(nc)) {
            consider(buildingId: buildingId, room: room, label: c, score: 60);
          }
        }
      }
    }

    for (final a in aliases) {
      final na = _norm(a.alias);
      if (!(na.contains(nq) || nq.contains(na))) continue;
      final graph = graphs[a.buildingId];
      if (graph == null || a.roomId == null) continue;
      final room = graph.rooms[a.roomId!];
      if (room == null) continue;
      consider(
        buildingId: a.buildingId,
        room: room,
        label: a.alias,
        score: na == nq ? 95 : 55,
      );
    }

    // Deduplicate by room id, keep best score.
    final best = <String, CampusSearchHit>{};
    for (final h in hits) {
      final key = '${h.buildingId}:${h.room.id}';
      final prev = best[key];
      if (prev == null || h.score > prev.score) best[key] = h;
    }
    final out = best.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return out.take(limit).toList();
  }
}

/// Minimal priority queue (heap) for Dijkstra.
class PriorityQueue<T> {
  PriorityQueue(this._compare);
  final Comparator<T> _compare;
  final List<T> _data = [];

  bool get isNotEmpty => _data.isNotEmpty;

  void add(T value) {
    _data.add(value);
    _bubbleUp(_data.length - 1);
  }

  T removeFirst() {
    final first = _data.first;
    final last = _data.removeLast();
    if (_data.isNotEmpty) {
      _data[0] = last;
      _bubbleDown(0);
    }
    return first;
  }

  void _bubbleUp(int i) {
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_compare(_data[i], _data[p]) >= 0) break;
      final tmp = _data[i];
      _data[i] = _data[p];
      _data[p] = tmp;
      i = p;
    }
  }

  void _bubbleDown(int i) {
    while (true) {
      final l = i * 2 + 1;
      final r = l + 1;
      var smallest = i;
      if (l < _data.length && _compare(_data[l], _data[smallest]) < 0) {
        smallest = l;
      }
      if (r < _data.length && _compare(_data[r], _data[smallest]) < 0) {
        smallest = r;
      }
      if (smallest == i) break;
      final tmp = _data[i];
      _data[i] = _data[smallest];
      _data[smallest] = tmp;
      i = smallest;
    }
  }
}
