import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:neptun2/CampusMap/campus_map_package.dart';

/// Strategy D schematic: mall/metro-style 2D view from graph geometry.
/// No floor-plan photo — corridors as bands, rooms as pins, route as centerline.
class CampusSchematicPainter extends CustomPainter {
  CampusSchematicPainter({
    required this.graph,
    required this.floor,
    required this.pathNodeIds,
    required this.fromRoomId,
    required this.toRoomId,
    required this.corridorColor,
    required this.routeColor,
    required this.labelColor,
    required this.surfaceColor,
    required this.outlineColor,
  });

  final CampusBuildingGraph graph;
  final CampusFloor floor;
  final List<String>? pathNodeIds;
  final String? fromRoomId;
  final String? toRoomId;
  final Color corridorColor;
  final Color routeColor;
  final Color labelColor;
  final Color surfaceColor;
  final Color outlineColor;

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

  double _scale(Size size) =>
      math.min(size.width / floor.basemapWidth, size.height / floor.basemapHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _scale(size);
    final floorNodes = graph.nodes.values
        .where((n) => n.floorId == floor.id)
        .toList(growable: false);
    if (floorNodes.isEmpty) return;

    // Soft schematic surface (not a photo).
    final bg = Paint()..color = surfaceColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(18),
      ),
      bg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(18),
      ),
      Paint()
        ..color = outlineColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final nodeById = {for (final n in floorNodes) n.id: n};
    final sameFloorEdges = graph.edges.where((e) {
      final a = nodeById[e.from];
      final b = nodeById[e.to];
      return a != null && b != null;
    });

    // Corridor bands (wide underlay + thinner centerline).
    final band = Paint()
      ..color = corridorColor.withValues(alpha: 0.22)
      ..strokeWidth = math.max(14.0, 22.0 * scale)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final spine = Paint()
      ..color = corridorColor.withValues(alpha: 0.55)
      ..strokeWidth = math.max(2.2, 3.2 * scale)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final stub = Paint()
      ..color = corridorColor.withValues(alpha: 0.28)
      ..strokeWidth = math.max(1.4, 2.0 * scale)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final e in sameFloorEdges) {
      final a = nodeById[e.from]!;
      final b = nodeById[e.to]!;
      final p0 = _map(Offset(a.x, a.y), size);
      final p1 = _map(Offset(b.x, b.y), size);
      if (e.kind == 'roomStub') {
        canvas.drawLine(p0, p1, stub);
        continue;
      }
      if (e.kind == 'corridor' || e.kind == 'entrance') {
        canvas.drawLine(p0, p1, band);
        canvas.drawLine(p0, p1, spine);
      }
    }

    // Vertical / special nodes.
    for (final n in floorNodes) {
      final p = _map(Offset(n.x, n.y), size);
      if (n.kind == 'lift') {
        _drawMarker(canvas, p, const Color(0xFF3B82F6), 'L', scale);
      } else if (n.kind == 'stair') {
        _drawMarker(canvas, p, const Color(0xFF8B5CF6), 'S', scale);
      } else if (n.kind == 'entrance') {
        _drawMarker(canvas, p, const Color(0xFF0EA5E9), 'E', scale);
      } else if (n.kind == 'poi') {
        _drawMarker(canvas, p, const Color(0xFFF59E0B), '·', scale);
      }
    }

    // Room pins + short labels.
    final roomsOnFloor = graph.rooms.values.where((r) => r.floorId == floor.id);
    final labelStyle = TextStyle(
      color: labelColor.withValues(alpha: 0.78),
      fontSize: math.max(8.0, 9.5 * scale).clamp(8.0, 12.0),
      fontWeight: FontWeight.w600,
      height: 1.05,
    );
    for (final room in roomsOnFloor) {
      final p = _map(Offset(room.x, room.y), size);
      final isFrom = room.id == fromRoomId;
      final isTo = room.id == toRoomId;
      final fill = isFrom
          ? const Color(0xFF16A34A)
          : isTo
              ? const Color(0xFFDC2626)
              : corridorColor.withValues(alpha: 0.85);
      canvas.drawCircle(p, math.max(3.2, 4.2 * scale), Paint()..color = fill);
      canvas.drawCircle(
        p,
        math.max(3.2, 4.2 * scale),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final label = _shortLabel(room);
      if (label.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 72);
      tp.paint(canvas, Offset(p.dx + 5, p.dy - tp.height / 2));
    }

    // Route overlay (smooth centerline).
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
          ..strokeWidth = math.max(8.0, 12.0 * scale)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final line = Paint()
          ..color = routeColor
          ..strokeWidth = math.max(3.5, 5.0 * scale)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final path = Path()..moveTo(draw.first.dx, draw.first.dy);
        for (var i = 1; i < draw.length; i++) {
          path.lineTo(draw[i].dx, draw[i].dy);
        }
        canvas.drawPath(path, glow);
        canvas.drawPath(path, line);
        canvas.drawCircle(draw.first, math.max(4.5, 6 * scale), Paint()..color = const Color(0xFF16A34A));
        canvas.drawCircle(draw.last, math.max(4.5, 6 * scale), Paint()..color = const Color(0xFFDC2626));
      }
    }
  }

  void _drawMarker(Canvas canvas, Offset p, Color color, String glyph, double scale) {
    final r = math.max(5.5, 7.0 * scale);
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
        style: TextStyle(
          color: Colors.white,
          fontSize: math.max(7.0, 8.5 * scale),
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
      // "LD 0.821" → "0.821"
      final parts = neptun.split(RegExp(r'\s+'));
      return parts.length > 1 ? parts.sublist(1).join(' ') : neptun;
    }
    return room.codeBis;
  }

  @override
  bool shouldRepaint(covariant CampusSchematicPainter oldDelegate) {
    return oldDelegate.floor.id != floor.id ||
        oldDelegate.pathNodeIds != pathNodeIds ||
        oldDelegate.fromRoomId != fromRoomId ||
        oldDelegate.toRoomId != toRoomId ||
        oldDelegate.corridorColor != corridorColor ||
        oldDelegate.routeColor != routeColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}
