import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:neptun2/CampusMap/campus_map_package.dart';

/// Mall/TЦ-style floor schematic: filled building shell + corridor ribbons.
/// Graph geometry is used only for room pins and route centerlines — never as
/// the visual building shape (no graph-edge glow topology).
class CampusSchematicPainter extends CustomPainter {
  CampusSchematicPainter({
    required this.graph,
    required this.floor,
    required this.schematic,
    required this.pathNodeIds,
    required this.fromRoomId,
    required this.toRoomId,
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
  final Color corridorColor;
  final Color routeColor;
  final Color labelColor;
  final Color surfaceColor;
  final Color outlineColor;
  /// InteractiveViewer scale — drives label density.
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

    // Soft outer canvas.
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
      // Fallback only if schematic missing — still avoid stroking all edges.
      _paintFallbackHull(canvas, size, floorNodes);
    }

    // Vertical / special nodes (not corridor topology).
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

    // Room pins + collision-aware labels.
    final roomsOnFloor =
        graph.rooms.values.where((r) => r.floorId == floor.id).toList();
    _paintRooms(canvas, size, roomsOnFloor);

    // Route overlay along graph centerline (routing only).
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

    // Building floor plate.
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

    // Courtyard holes as slightly darker voids.
    for (final hole in sch.holes) {
      if (hole.length < 3) continue;
      final hp = _polyPath(hole, size);
      canvas.drawPath(
        hp,
        Paint()..color = surfaceColor.withValues(alpha: 0.85),
      );
      canvas.drawPath(
        hp,
        Paint()
          ..color = outlineColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // Corridor ribbons (filled), then soft centerline.
    final fill = Paint()..color = corridorColor.withValues(alpha: 0.34);
    final stroke = Paint()
      ..color = corridorColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final spine = Paint()
      ..color = corridorColor.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final c in sch.corridors) {
      if (c.polygon.length >= 3) {
        final p = _polyPath(c.polygon, size);
        canvas.drawPath(p, fill);
        canvas.drawPath(p, stroke);
      }
      if (c.centerline.length >= 2) {
        final path = Path();
        final first = _map(c.centerline.first, size);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < c.centerline.length; i++) {
          final pt = _map(c.centerline[i], size);
          path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path, spine);
      }
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
    final pad = 40.0;
    final rect = Rect.fromLTRB(
      _map(Offset(minX - pad, minY - pad), size).dx,
      _map(Offset(minX - pad, minY - pad), size).dy,
      _map(Offset(maxX + pad, maxY + pad), size).dx,
      _map(Offset(maxX + pad, maxY + pad), size).dy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()..color = corridorColor.withValues(alpha: 0.12),
    );
  }

  void _paintRooms(Canvas canvas, Size size, List<CampusRoom> rooms) {
    final labelStyle = TextStyle(
      color: labelColor.withValues(alpha: 0.82),
      fontSize: (10.0 / math.max(0.75, viewScale)).clamp(8.0, 12.0),
      fontWeight: FontWeight.w600,
      height: 1.05,
    );

    // Sort so from/to and named halls paint first.
    final ordered = [...rooms]..sort((a, b) {
        int rank(CampusRoom r) {
          if (r.id == fromRoomId || r.id == toRoomId) return 0;
          if ((r.codeNeptun ?? '').isNotEmpty) return 1;
          return 2;
        }
        return rank(a).compareTo(rank(b));
      });

    final occupied = <Rect>[];
    // At low zoom hide dense overlaps; zoom in → show more.
    final minGap = (28.0 / math.max(0.7, viewScale)).clamp(14.0, 42.0);
    final maxLabels = viewScale < 1.0
        ? 18
        : viewScale < 1.8
            ? 40
            : 120;
    var labelsDrawn = 0;

    for (final room in ordered) {
      final p = _map(Offset(room.x, room.y), size);
      final isFrom = room.id == fromRoomId;
      final isTo = room.id == toRoomId;
      final fill = isFrom
          ? const Color(0xFF16A34A)
          : isTo
              ? const Color(0xFFDC2626)
              : corridorColor.withValues(alpha: 0.9);
      canvas.drawCircle(p, isFrom || isTo ? 5.2 : 3.6, Paint()..color = fill);
      canvas.drawCircle(
        p,
        isFrom || isTo ? 5.2 : 3.6,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final label = _shortLabel(room);
      if (label.isEmpty) continue;
      if (!(isFrom || isTo) && labelsDrawn >= maxLabels) continue;

      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 78);
      final origin = Offset(p.dx + 5, p.dy - tp.height / 2);
      final box = origin & Size(tp.width + 2, tp.height + 2);

      var overlaps = false;
      for (final r in occupied) {
        if ((r.center - box.center).distance < minGap || r.overlaps(box.inflate(2))) {
          overlaps = true;
          break;
        }
      }
      if (overlaps && !(isFrom || isTo)) continue;

      // Soft label chip for readability on ribbons.
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.inflate(1.5), const Radius.circular(3)),
        Paint()..color = surfaceColor.withValues(alpha: 0.72),
      );
      tp.paint(canvas, origin);
      occupied.add(box);
      labelsDrawn++;
    }
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
        oldDelegate.corridorColor != corridorColor ||
        oldDelegate.routeColor != routeColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.viewScale != viewScale;
  }
}
