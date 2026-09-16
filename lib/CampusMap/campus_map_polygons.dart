import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neptun2/CampusMap/campus_map_package.dart';

/// BIS FootPrint room polygons (WGS84) + approximate graph route overlay.
class CampusPolygonSet {
  CampusPolygonSet({
    required this.buildingId,
    required this.polygonCount,
    required this.catalogCount,
    required this.bbox,
    required this.floors,
  });

  final String buildingId;
  final int polygonCount;
  final int catalogCount;
  final List<double> bbox; // west, south, east, north
  final Map<int, CampusPolygonFloor> floors;

  factory CampusPolygonSet.fromJson(Map<String, dynamic> j) {
    final floors = <int, CampusPolygonFloor>{};
    for (final e in (j['floors'] as List).cast<Map>()) {
      final fl = CampusPolygonFloor.fromJson(Map<String, dynamic>.from(e));
      floors[fl.level] = fl;
    }
    return CampusPolygonSet(
      buildingId: j['buildingId'] as String,
      polygonCount: (j['polygonCount'] as num?)?.toInt() ?? 0,
      catalogCount: (j['catalogCount'] as num?)?.toInt() ?? 0,
      bbox: ((j['bbox'] as List?) ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      floors: floors,
    );
  }

  CampusPolygonFloor? floorByLevel(int level) => floors[level];
}

class CampusPolygonFloor {
  CampusPolygonFloor({
    required this.level,
    required this.rooms,
  });

  final int level;
  final List<CampusRoomPolygon> rooms;

  factory CampusPolygonFloor.fromJson(Map<String, dynamic> j) {
    final rooms = ((j['rooms'] as List?) ?? const [])
        .cast<Map>()
        .map((e) => CampusRoomPolygon.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return CampusPolygonFloor(
      level: (j['level'] as num).toInt(),
      rooms: rooms,
    );
  }
}

class CampusRoomPolygon {
  CampusRoomPolygon({
    required this.id,
    required this.code,
    required this.number,
    required this.name,
    required this.type,
    required this.rings,
    required this.centroidLng,
    required this.centroidLat,
  });

  final int? id;
  final String code;
  final String number;
  final String name;
  final String type;
  /// Outer rings as [lng, lat] pairs (closed).
  final List<List<Offset>> rings;
  final double centroidLng;
  final double centroidLat;

  factory CampusRoomPolygon.fromJson(Map<String, dynamic> j) {
    final ringsRaw = (j['rings'] as List?) ?? const [];
    final rings = <List<Offset>>[];
    double sx = 0, sy = 0, n = 0;
    for (final ring in ringsRaw) {
      final pts = <Offset>[];
      for (final p in (ring as List)) {
        final lng = (p[0] as num).toDouble();
        final lat = (p[1] as num).toDouble();
        pts.add(Offset(lng, lat));
        sx += lng;
        sy += lat;
        n += 1;
      }
      if (pts.length >= 3) rings.add(pts);
    }
    return CampusRoomPolygon(
      id: (j['id'] as num?)?.toInt(),
      code: j['code'] as String? ?? '',
      number: j['number'] as String? ?? '',
      name: j['name'] as String? ?? '',
      type: j['type'] as String? ?? 'misc',
      rings: rings,
      centroidLng: n > 0 ? sx / n : 0,
      centroidLat: n > 0 ? sy / n : 0,
    );
  }

  String get shortLabel {
    if (number.trim().isNotEmpty) return number;
    if (code.trim().isNotEmpty) return code;
    return name;
  }
}

/// Local equirectangular meters from a WGS origin (y north-up).
class WgsLocalProjector {
  WgsLocalProjector(this.originLng, this.originLat)
      : mPerDegLat = 111320.0,
        mPerDegLng = 111320.0 * math.cos(originLat * math.pi / 180.0);

  final double originLng;
  final double originLat;
  final double mPerDegLat;
  final double mPerDegLng;

  Offset toLocal(double lng, double lat) => Offset(
        (lng - originLng) * mPerDegLng,
        (lat - originLat) * mPerDegLat,
      );

  Offset toLocalOffset(Offset wgs) => toLocal(wgs.dx, wgs.dy);

  Offset toWgs(double localX, double localY) => Offset(
        originLng + localX / mPerDegLng,
        originLat + localY / mPerDegLat,
      );
}

/// Affine: basemapPx (x,y) → WGS (lng,lat). Approximate — graph digitization ≠ survey.
class PixelToWgsAffine {
  PixelToWgsAffine(this.a, this.b, this.c, this.d, this.e, this.f);

  final double a, b, c, d, e, f;

  Offset call(double x, double y) => Offset(a * x + b * y + c, d * x + e * y + f);

  /// Least-squares fit from control pairs. Returns null if underdetermined.
  static PixelToWgsAffine? fit(List<(Offset px, Offset wgs)> pairs) {
    if (pairs.length < 3) return null;
    // Solve 6 unknowns via normal equations (2 rows per pair).
    final ata = List.generate(6, (_) => List<double>.filled(6, 0));
    final atb = List<double>.filled(6, 0);

    void accum(List<double> row, double rhs) {
      for (var i = 0; i < 6; i++) {
        atb[i] += row[i] * rhs;
        for (var j = 0; j < 6; j++) {
          ata[i][j] += row[i] * row[j];
        }
      }
    }

    for (final (px, wgs) in pairs) {
      accum([px.dx, px.dy, 1, 0, 0, 0], wgs.dx);
      accum([0, 0, 0, px.dx, px.dy, 1], wgs.dy);
    }

    final coef = _solve6(ata, atb);
    if (coef == null) return null;
    return PixelToWgsAffine(coef[0], coef[1], coef[2], coef[3], coef[4], coef[5]);
  }

  static List<double>? _solve6(List<List<double>> a, List<double> b) {
    // Gaussian elimination with partial pivot.
    final m = List.generate(6, (i) => [...a[i], b[i]]);
    for (var col = 0; col < 6; col++) {
      var pivot = col;
      for (var r = col + 1; r < 6; r++) {
        if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
      }
      if (m[pivot][col].abs() < 1e-18) return null;
      final tmp = m[col];
      m[col] = m[pivot];
      m[pivot] = tmp;
      final div = m[col][col];
      for (var j = col; j < 7; j++) {
        m[col][j] /= div;
      }
      for (var r = 0; r < 6; r++) {
        if (r == col) continue;
        final f = m[r][col];
        for (var j = col; j < 7; j++) {
          m[r][j] -= f * m[col][j];
        }
      }
    }
    return [for (var i = 0; i < 6; i++) m[i][6]];
  }
}

/// BIS-like room type fills (educational / corridor / admin / …).
Color bisRoomFill(String type, {required bool dark}) {
  switch (type) {
    case 'educational':
      return dark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD);
    case 'corridor':
      return dark ? const Color(0xFF64748B) : const Color(0xFFE2E8F0);
    case 'administrative':
      return dark ? const Color(0xFFD97706) : const Color(0xFFFDE68A);
    case 'social':
      return dark ? const Color(0xFF059669) : const Color(0xFFA7F3D0);
    case 'outdoor':
      return dark ? const Color(0xFF65A30D) : const Color(0xFFD9F99D);
    case 'misc':
    default:
      return dark ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1);
  }
}

Color bisRoomStroke(String type, {required bool dark}) {
  return dark
      ? Colors.white.withValues(alpha: 0.35)
      : const Color(0xFF334155).withValues(alpha: 0.45);
}

/// Primary campus map: filled BIS FootPrint polygons + graph route line.
class CampusPolygonPainter extends CustomPainter {
  CampusPolygonPainter({
    required this.polygonFloor,
    required this.graph,
    required this.floor,
    required this.affine,
    required this.projector,
    required this.bounds,
    required this.pathNodeIds,
    required this.fromRoomId,
    required this.toRoomId,
    required this.selectedCode,
    required this.routeColor,
    required this.labelColor,
    required this.surfaceColor,
    required this.viewScale,
    required this.dark,
  });

  final CampusPolygonFloor polygonFloor;
  final CampusBuildingGraph graph;
  final CampusFloor floor;
  final PixelToWgsAffine? affine;
  final WgsLocalProjector projector;
  final Rect bounds; // local meters
  final List<String>? pathNodeIds;
  final String? fromRoomId;
  final String? toRoomId;
  final String? selectedCode;
  final Color routeColor;
  final Color labelColor;
  final Color surfaceColor;
  final double viewScale;
  final bool dark;

  Offset _map(Offset local, Size size) {
    final sx = size.width / bounds.width;
    final sy = size.height / bounds.height;
    // Flip Y for screen (local y is north-up).
    return Offset(
      (local.dx - bounds.left) * sx,
      (bounds.bottom - local.dy) * sy,
    );
  }

  Path _ringPath(List<Offset> wgsRing, Size size) {
    final path = Path();
    if (wgsRing.isEmpty) return path;
    final first = _map(projector.toLocalOffset(wgsRing.first), size);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < wgsRing.length; i++) {
      final p = _map(projector.toLocalOffset(wgsRing[i]), size);
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(18),
      ),
      Paint()..color = surfaceColor,
    );

    // Draw corridors first (under), then other rooms, educational on top-ish.
    final ordered = [...polygonFloor.rooms]..sort((a, b) {
        int rank(String t) {
          switch (t) {
            case 'corridor':
              return 0;
            case 'outdoor':
              return 1;
            case 'misc':
              return 2;
            case 'social':
              return 3;
            case 'administrative':
              return 4;
            case 'educational':
              return 5;
            default:
              return 3;
          }
        }
        return rank(a.type).compareTo(rank(b.type));
      });

    for (final room in ordered) {
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = bisRoomFill(room.type, dark: dark).withValues(
          alpha: room.code == selectedCode ? 0.95 : 0.82,
        );
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = room.code == selectedCode ? 2.2 : 0.7
        ..color = room.code == selectedCode
            ? routeColor
            : bisRoomStroke(room.type, dark: dark);
      for (final ring in room.rings) {
        final path = _ringPath(ring, size);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      }
    }

    _paintRoute(canvas, size);
    _paintLabels(canvas, size, ordered);
  }

  void _paintRoute(Canvas canvas, Size size) {
    final ids = pathNodeIds;
    if (ids == null || ids.length < 2 || affine == null) return;

    final pts = <Offset>[];
    for (final id in ids) {
      final n = graph.nodes[id];
      if (n == null || n.floorId != floor.id) continue;
      Offset? wgs;
      if (n.roomId != null) {
        final room = graph.rooms[n.roomId!];
        if (room?.lng != null && room?.lat != null) {
          wgs = Offset(room!.lng!, room.lat!);
        } else if (room != null) {
          // Prefer matching BIS polygon centroid by code.
          final match = _polygonByGraphRoom(room);
          if (match != null) {
            wgs = Offset(match.centroidLng, match.centroidLat);
          }
        }
      }
      wgs ??= affine!(n.x, n.y);
      pts.add(_map(projector.toLocalOffset(wgs), size));
    }
    if (pts.length < 2) return;

    final draw = CampusSchematicPainterCompat.chaikin(pts);
    final glow = Paint()
      ..color = routeColor.withValues(alpha: 0.28)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final line = Paint()
      ..color = routeColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(draw.first.dx, draw.first.dy);
    for (var i = 1; i < draw.length; i++) {
      path.lineTo(draw[i].dx, draw[i].dy);
    }
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
    canvas.drawCircle(draw.first, 6, Paint()..color = const Color(0xFF16A34A));
    canvas.drawCircle(draw.last, 6, Paint()..color = const Color(0xFFDC2626));
  }

  CampusRoomPolygon? _polygonByGraphRoom(CampusRoom room) {
    final code = room.bisRoomCode;
    if (code != null && code.isNotEmpty) {
      for (final p in polygonFloor.rooms) {
        if (p.code == code) return p;
      }
    }
    // Fallback: match short number / codeBis.
    final needle = room.codeBis.replaceAll('.', '-');
    for (final p in polygonFloor.rooms) {
      if (p.number == room.codeBis || p.number == needle) return p;
    }
    return null;
  }

  void _paintLabels(Canvas canvas, Size size, List<CampusRoomPolygon> rooms) {
    final zoom = viewScale;
    final maxLabels = zoom < 1.2
        ? 10
        : zoom < 2.0
            ? 28
            : zoom < 3.5
                ? 60
                : 120;
    final candidates = <CampusRoomPolygon>[];
    for (final r in rooms) {
      if (r.type == 'corridor' || r.type == 'outdoor') continue;
      if (r.code == selectedCode ||
          _isEndpoint(r) ||
          r.type == 'educational' ||
          r.type == 'administrative') {
        candidates.add(r);
      }
    }
    candidates.sort((a, b) {
      int score(CampusRoomPolygon r) {
        var s = 0;
        if (r.code == selectedCode) s += 100;
        if (_isEndpoint(r)) s += 50;
        if (r.type == 'educational') s += 10;
        return s;
      }
      return score(b).compareTo(score(a));
    });

    final placed = <Rect>[];
    var drawn = 0;
    final fontSize = zoom < 1.5 ? 9.0 : (zoom < 2.5 ? 10.5 : 12.0);
    for (final r in candidates) {
      if (drawn >= maxLabels && r.code != selectedCode && !_isEndpoint(r)) {
        continue;
      }
      final local = projector.toLocal(r.centroidLng, r.centroidLat);
      final p = _map(local, size);
      final text = r.shortLabel;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: labelColor.withValues(alpha: r.code == selectedCode ? 1 : 0.85),
            fontSize: fontSize,
            fontWeight:
                r.code == selectedCode ? FontWeight.w800 : FontWeight.w600,
            shadows: [
              Shadow(
                color: surfaceColor.withValues(alpha: 0.9),
                blurRadius: 3,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 72);
      final rect = Rect.fromCenter(
        center: p,
        width: tp.width + 4,
        height: tp.height + 2,
      );
      var overlaps = false;
      for (final q in placed) {
        if (q.overlaps(rect.inflate(2))) {
          overlaps = true;
          break;
        }
      }
      if (overlaps && r.code != selectedCode && !_isEndpoint(r)) continue;
      tp.paint(canvas, Offset(rect.left + 2, rect.top + 1));
      placed.add(rect);
      drawn++;
    }
  }

  bool _isEndpoint(CampusRoomPolygon r) {
    if (fromRoomId != null) {
      final room = graph.rooms[fromRoomId!];
      if (room != null && _polygonByGraphRoom(room)?.code == r.code) return true;
    }
    if (toRoomId != null) {
      final room = graph.rooms[toRoomId!];
      if (room != null && _polygonByGraphRoom(room)?.code == r.code) return true;
    }
    return false;
  }

  /// Hit-test in view coordinates → room polygon (or null).
  static CampusRoomPolygon? findRoomAt({
    required Offset localPos,
    required Size size,
    required CampusPolygonFloor floor,
    required WgsLocalProjector projector,
    required Rect bounds,
  }) {
    // Convert screen → local meters → approximate WGS, then PIP.
    final sx = bounds.width / size.width;
    final sy = bounds.height / size.height;
    final lx = bounds.left + localPos.dx * sx;
    final ly = bounds.bottom - localPos.dy * sy;
    final pt = projector.toWgs(lx, ly);

    CampusRoomPolygon? best;
    // Prefer non-corridor hits.
    for (final room in floor.rooms.reversed) {
      for (final ring in room.rings) {
        if (_pointInRing(pt, ring)) {
          if (best == null ||
              (best.type == 'corridor' && room.type != 'corridor')) {
            best = room;
          }
        }
      }
    }
    return best;
  }

  static bool _pointInRing(Offset pt, List<Offset> ring) {
    // Ray casting; ring in lng/lat.
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].dx, yi = ring[i].dy;
      final xj = ring[j].dx, yj = ring[j].dy;
      final intersect = ((yi > pt.dy) != (yj > pt.dy)) &&
          (pt.dx <
              (xj - xi) * (pt.dy - yi) / ((yj - yi) == 0 ? 1e-18 : (yj - yi)) +
                  xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  @override
  bool shouldRepaint(covariant CampusPolygonPainter oldDelegate) {
    return oldDelegate.polygonFloor != polygonFloor ||
        oldDelegate.pathNodeIds != pathNodeIds ||
        oldDelegate.selectedCode != selectedCode ||
        oldDelegate.viewScale != viewScale ||
        oldDelegate.fromRoomId != fromRoomId ||
        oldDelegate.toRoomId != toRoomId ||
        oldDelegate.dark != dark;
  }
}

/// Tiny helper so we don't import schematic painter just for Chaikin.
class CampusSchematicPainterCompat {
  static List<Offset> chaikin(List<Offset> pts, {int iterations = 2}) {
    if (pts.length < 3) return pts;
    var cur = pts;
    for (var n = 0; n < iterations; n++) {
      final next = <Offset>[cur.first];
      for (var i = 0; i < cur.length - 1; i++) {
        final p = cur[i];
        final q = cur[i + 1];
        next.add(Offset(0.75 * p.dx + 0.25 * q.dx, 0.75 * p.dy + 0.25 * q.dy));
        next.add(Offset(0.25 * p.dx + 0.75 * q.dx, 0.25 * p.dy + 0.75 * q.dy));
      }
      next.add(cur.last);
      cur = next;
    }
    return cur;
  }
}

/// Build projector + bounds padded from polygon bbox (WGS).
({WgsLocalProjector projector, Rect bounds}) buildFloorView(
  CampusPolygonSet set,
  CampusPolygonFloor floor,
) {
  double minLng = 1e9, minLat = 1e9, maxLng = -1e9, maxLat = -1e9;
  for (final r in floor.rooms) {
    for (final ring in r.rings) {
      for (final p in ring) {
        minLng = math.min(minLng, p.dx);
        maxLng = math.max(maxLng, p.dx);
        minLat = math.min(minLat, p.dy);
        maxLat = math.max(maxLat, p.dy);
      }
    }
  }
  if (minLng > maxLng) {
    // Fallback to building bbox.
    final b = set.bbox;
    if (b.length == 4) {
      minLng = b[0];
      minLat = b[1];
      maxLng = b[2];
      maxLat = b[3];
    } else {
      minLng = 19.06;
      minLat = 47.47;
      maxLng = 19.065;
      maxLat = 47.476;
    }
  }
  final originLng = (minLng + maxLng) / 2;
  final originLat = (minLat + maxLat) / 2;
  final projector = WgsLocalProjector(originLng, originLat);
  final sw = projector.toLocal(minLng, minLat);
  final ne = projector.toLocal(maxLng, maxLat);
  final pad = 8.0; // meters
  final bounds = Rect.fromLTRB(
    math.min(sw.dx, ne.dx) - pad,
    math.min(sw.dy, ne.dy) - pad,
    math.max(sw.dx, ne.dx) + pad,
    math.max(sw.dy, ne.dy) + pad,
  );
  return (projector: projector, bounds: bounds);
}

PixelToWgsAffine? fitAffineForFloor(CampusBuildingGraph graph, CampusFloor floor) {
  final pairs = <(Offset, Offset)>[];
  for (final r in graph.rooms.values) {
    if (r.floorId != floor.id) continue;
    if (r.lng == null || r.lat == null) continue;
    pairs.add((Offset(r.x, r.y), Offset(r.lng!, r.lat!)));
  }
  return PixelToWgsAffine.fit(pairs);
}
