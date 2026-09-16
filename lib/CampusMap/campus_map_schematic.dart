import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:neptun2/CampusMap/campus_map_package.dart';

/// Mall-style floor schematic: filled building shell + corridor ribbons.
/// Graph is for room pins + route centerlines only (not graph-edge glow).
class CampusSchematicPainter extends CustomPainter {
  CampusSchematicPainter({
    required this.graph,
    required this.floor,
    required this.schematic,
    required this.pathNodeIds,
    required this.fromRoomId,
    required this.toRoomId,
    required this.selectedRoomId,
    required this.corridorColor,
    required this.routeColor,
    required this.labelColor,
    required this.surfaceColor,
    required this.outlineColor,
    required this.viewScale,
  });

  final CampusBuildingGraph graph;
  final CampusFloor floor;
  final CampusFloorSchematic? schematic;
  final List<String>? pathNodeIds;
  final String? fromRoomId;
  final String? toRoomId;
  final String? selectedRoomId;
  final Color corridorColor;
  final Color routeColor;
  final Color labelColor;
  final Color surfaceColor;
  final Color outlineColor;
  final double viewScale;

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

  Offset _map(Offset p, Size size) {
    final sx = size.width / floor.basemapWidth;
    final sy = size.height / floor.basemapHeight;
    return Offset(p.dx * sx, p.dy * sy);
  }

  Path _polyPath(List<Offset> pts, Size size) {
    final path = Path();
    if (pts.isEmpty) return path;
    final first = _map(pts.first, size);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < pts.length; i++) {
      final p = _map(pts[i], size);
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final floorNodes = graph.nodes.values
        .where((n) => n.floorId == floor.id)
        .toList(growable: false);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(18),
      ),
      Paint()..color = surfaceColor,
    );

    final sch = schematic;
    if (sch != null && sch.shell.length >= 3) {
      _paintBuildingPlan(canvas, size, sch);
    } else if (floorNodes.isNotEmpty) {
      _paintFallbackHull(canvas, size, floorNodes);
    }

    for (final n in floorNodes) {
      final p = _map(Offset(n.x, n.y), size);
      if (n.kind == 'lift') {
        _drawMarker(canvas, p, const Color(0xFF3B82F6), 'L');
      } else if (n.kind == 'stair') {
        _drawMarker(canvas, p, const Color(0xFF8B5CF6), 'S');
      } else if (n.kind == 'entrance') {
        _drawMarker(canvas, p, const Color(0xFF0EA5E9), 'E');
      } else if (n.kind == 'poi') {
        _drawMarker(canvas, p, const Color(0xFFF59E0B), '·');
      }
    }

    final roomsOnFloor =
        graph.rooms.values.where((r) => r.floorId == floor.id).toList();
    _paintRooms(canvas, size, roomsOnFloor);

    if (pathNodeIds != null && pathNodeIds!.length >= 2) {
      final pts = <Offset>[];
      for (final id in pathNodeIds!) {
        final n = graph.nodes[id];
        if (n == null || n.floorId != floor.id) continue;
        pts.add(_map(Offset(n.x, n.y), size));
      }
      if (pts.length >= 2) {
        final draw = chaikin(pts);
        final glow = Paint()
          ..color = routeColor.withValues(alpha: 0.28)
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final line = Paint()
          ..color = routeColor
          ..strokeWidth = 4.2
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
    }
  }

  void _paintBuildingPlan(Canvas canvas, Size size, CampusFloorSchematic sch) {
    final shellPath = _polyPath(sch.shell, size);
    for (final hole in sch.holes) {
      if (hole.length >= 3) {
        shellPath.addPath(_polyPath(hole, size), Offset.zero);
      }
    }
    shellPath.fillType = PathFillType.evenOdd;

    canvas.drawPath(
      shellPath,
      Paint()..color = outlineColor.withValues(alpha: 0.07),
    );
    canvas.drawPath(
      shellPath,
      Paint()
        ..color = outlineColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    for (final hole in sch.holes) {
      if (hole.length < 3) continue;
      final hp = _polyPath(hole, size);
      canvas.drawPath(hp, Paint()..color = surfaceColor.withValues(alpha: 0.85));
      canvas.drawPath(
        hp,
        Paint()
          ..color = outlineColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    final roomsHere = graph.rooms.values
        .where((r) => r.floorId == floor.id)
        .toList(growable: false);

    for (final c in sch.corridors) {
      final active = _corridorActiveForFloor(c, roomsHere);
      final fillA = active ? 0.38 : 0.10;
      final strokeA = active ? 0.55 : 0.16;
      final spineA = active ? 0.48 : 0.12;
      if (c.polygon.length >= 3) {
        final p = _polyPath(c.polygon, size);
        canvas.drawPath(p, Paint()..color = corridorColor.withValues(alpha: fillA));
        canvas.drawPath(
          p,
          Paint()
            ..color = corridorColor.withValues(alpha: strokeA)
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 1.2 : 0.9,
        );
      }
      if (c.centerline.length >= 2) {
        final path = Path();
        final first = _map(c.centerline.first, size);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < c.centerline.length; i++) {
          final pt = _map(c.centerline[i], size);
          path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = corridorColor.withValues(alpha: spineA)
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 1.8 : 1.0
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    // Room-extent plate — floors look different even with shared shell template.
    if (roomsHere.isNotEmpty) {
      var minX = roomsHere.first.x;
      var maxX = roomsHere.first.x;
      var minY = roomsHere.first.y;
      var maxY = roomsHere.first.y;
      for (final r in roomsHere) {
        minX = math.min(minX, r.x);
        maxX = math.max(maxX, r.x);
        minY = math.min(minY, r.y);
        maxY = math.max(maxY, r.y);
      }
      const pad = 48.0;
      final plate = Rect.fromLTRB(
        _map(Offset(minX - pad, minY - pad), size).dx,
        _map(Offset(minX - pad, minY - pad), size).dy,
        _map(Offset(maxX + pad, maxY + pad), size).dx,
        _map(Offset(maxX + pad, maxY + pad), size).dy,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(plate, const Radius.circular(10)),
        Paint()
          ..color = corridorColor.withValues(alpha: 0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  void _paintFallbackHull(Canvas canvas, Size size, List<CampusNode> nodes) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final n in nodes) {
      if (n.kind == 'room') continue;
      minX = math.min(minX, n.x);
      minY = math.min(minY, n.y);
      maxX = math.max(maxX, n.x);
      maxY = math.max(maxY, n.y);
    }
    if (!minX.isFinite) return;
    const pad = 40.0;
    final tl = _map(Offset(minX - pad, minY - pad), size);
    final br = _map(Offset(maxX + pad, maxY + pad), size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(tl.dx, tl.dy, br.dx, br.dy),
        const Radius.circular(12),
      ),
      Paint()..color = corridorColor.withValues(alpha: 0.12),
    );
  }

  void _paintRooms(Canvas canvas, Size size, List<CampusRoom> rooms) {
    // Clean progressive labels: pins always; collision-aware offsets;
    // smaller type in clusters; zoom-in reveals more; tap focuses one.
    final ordered = [...rooms]..sort((a, b) {
        int rank(CampusRoom r) {
          if (r.id == fromRoomId || r.id == toRoomId || r.id == selectedRoomId) {
            return 0;
          }
          if ((r.codeNeptun ?? '').isNotEmpty) return 1;
          return 2;
        }
        return rank(a).compareTo(rank(b));
      });

    final occupied = <Rect>[];
    final showAll = viewScale >= 1.85;
    final baseFont = showAll
        ? 8.5
        : viewScale >= 1.25
            ? 8.0
            : 7.4;
    final gap = showAll ? 10.0 : (viewScale >= 1.25 ? 12.0 : 14.0);

    for (final room in ordered) {
      final p = _map(Offset(room.x, room.y), size);
      final isFrom = room.id == fromRoomId;
      final isTo = room.id == toRoomId;
      final isSelected = room.id == selectedRoomId;
      final fill = isFrom
          ? const Color(0xFF16A34A)
          : isTo
              ? const Color(0xFFDC2626)
              : isSelected
                  ? const Color(0xFF0EA5E9)
                  : corridorColor.withValues(alpha: 0.88);
      final pinR = (isFrom || isTo || isSelected) ? 5.0 : 3.2;
      canvas.drawCircle(p, pinR, Paint()..color = fill);
      canvas.drawCircle(
        p,
        pinR,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final label = _shortLabel(room);
      if (label.isEmpty) continue;

      final force = isFrom || isTo || isSelected;
      final placed = _tryPlaceLabel(
        canvas: canvas,
        anchor: p,
        label: label,
        force: force || showAll,
        baseFont: force ? math.max(baseFont, 8.5) : baseFont,
        gap: force ? gap * 0.7 : gap,
        occupied: occupied,
      );
      if (!placed && !force && viewScale >= 1.15) {
        _tryPlaceLabel(
          canvas: canvas,
          anchor: p,
          label: label,
          force: false,
          baseFont: 6.8,
          gap: 11.0,
          occupied: occupied,
        );
      }
    }
  }

  bool _tryPlaceLabel({
    required Canvas canvas,
    required Offset anchor,
    required String label,
    required bool force,
    required double baseFont,
    required double gap,
    required List<Rect> occupied,
  }) {
    const offsets = <Offset>[
      Offset(5, 0),
      Offset(5, -10),
      Offset(5, 10),
      Offset(-5, -12),
      Offset(-5, 12),
      Offset(0, -14),
      Offset(0, 14),
      Offset(12, -6),
      Offset(12, 6),
      Offset(-16, 0),
    ];
    final fonts = force
        ? <double>[baseFont, baseFont - 0.8, 6.5]
        : <double>[baseFont, baseFont - 1.0, 6.5];

    for (final fontSize in fonts) {
      if (fontSize < 6.2) continue;
      final style = TextStyle(
        color: labelColor.withValues(alpha: 0.86),
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.0,
      );
      final tp = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 72);
      for (final off in offsets) {
        final origin = Offset(
          anchor.dx + off.dx - (off.dx < 0 ? tp.width : 0),
          anchor.dy + off.dy - tp.height / 2,
        );
        final box = (origin & Size(tp.width, tp.height)).inflate(1.2);
        var overlaps = false;
        for (final r in occupied) {
          if (r.overlaps(box) || (r.center - box.center).distance < gap) {
            overlaps = true;
            break;
          }
        }
        if (overlaps && !force) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(box.inflate(1.0), const Radius.circular(2.5)),
          Paint()..color = surfaceColor.withValues(alpha: overlaps ? 0.55 : 0.78),
        );
        tp.paint(canvas, origin);
        occupied.add(box);
        return true;
      }
    }
    return false;
  }

  bool _corridorActiveForFloor(
    CampusCorridorRibbon corridor,
    List<CampusRoom> rooms,
  ) {
    if (rooms.isEmpty || corridor.centerline.isEmpty) return true;
    const thresh = 110.0;
    for (final room in rooms) {
      for (final p in corridor.centerline) {
        final dx = room.x - p.dx;
        final dy = room.y - p.dy;
        if (dx * dx + dy * dy <= thresh * thresh) return true;
      }
    }
    return false;
  }

  void _drawMarker(Canvas canvas, Offset p, Color color, String glyph) {
    const r = 6.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: p, width: r * 2, height: r * 2),
        Radius.circular(r * 0.45),
      ),
      Paint()..color = color.withValues(alpha: 0.92),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
  }

  String _shortLabel(CampusRoom room) {
    final neptun = room.codeNeptun?.trim();
    if (neptun != null && neptun.isNotEmpty) {
      final parts = neptun.split(RegExp(r'\s+'));
      return parts.length > 1 ? parts.sublist(1).join(' ') : neptun;
    }
    return room.codeBis;
  }

  @override
  bool shouldRepaint(covariant CampusSchematicPainter oldDelegate) {
    return oldDelegate.floor.id != floor.id ||
        oldDelegate.schematic != schematic ||
        oldDelegate.pathNodeIds != pathNodeIds ||
        oldDelegate.fromRoomId != fromRoomId ||
        oldDelegate.toRoomId != toRoomId ||
        oldDelegate.selectedRoomId != selectedRoomId ||
        oldDelegate.corridorColor != corridorColor ||
        oldDelegate.routeColor != routeColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.viewScale != viewScale;
  }
}
