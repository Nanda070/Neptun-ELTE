import 'package:flutter/material.dart';
import '../language.dart';

/// Parsed ELTE-style room code: `Campus-Floor-Room[-Stream][-Group]`.
class ElteRoomCode {
  final String campusPrefix;
  final String floor;
  final String room;
  final String? stream;
  final String? group;

  const ElteRoomCode({
    required this.campusPrefix,
    required this.floor,
    required this.room,
    this.stream,
    this.group,
  });

  static final RegExp _pattern = RegExp(
    r'^([A-Za-zÉéÁáÓóÖöŐőÚúÜüŰű]{1,3})-(\d+)-(\d+)(?:-(\d+))?(?:-(\d+))?$',
  );

  static ElteRoomCode? tryParse(String? raw) {
    if (raw == null) return null;
    final v = raw.trim();
    if (v.isEmpty) return null;
    final m = _pattern.firstMatch(v);
    if (m == null) return null;
    return ElteRoomCode(
      campusPrefix: m.group(1)!,
      floor: m.group(2)!,
      room: m.group(3)!,
      stream: m.group(4),
      group: m.group(5),
    );
  }

  static bool canDecode(String? raw) => tryParse(raw) != null;

  String buildingName(LanguagePack lang) {
    final key = campusPrefix.toUpperCase().replaceAll('É', 'E');
    switch (key) {
      case 'LD':
        return lang.roomCode_Building_LD;
      case 'LE':
        return lang.roomCode_Building_LE;
      case 'LK':
        return lang.roomCode_Building_LK;
      default:
        return campusPrefix;
    }
  }

  /// Compact summary; only includes stream/group when present in the code.
  String formatSummary(LanguagePack lang) {
    final parts = <String>[
      buildingName(lang),
      '${lang.roomCode_Floor}: $floor',
      '${lang.roomCode_Room}: $room',
    ];
    if (stream != null) {
      parts.add('${lang.roomCode_Stream}: $stream');
    }
    if (group != null) {
      parts.add('${lang.roomCode_Group}: $group');
    }
    return parts.join(', ');
  }
}

/// Tap toggles coded room ↔ localized decode. Non-coded text is plain (no toggle).
class DecodableRoomText extends StatefulWidget {
  final String room;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool softWrap;

  const DecodableRoomText({
    super.key,
    required this.room,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap = true,
  });

  @override
  State<DecodableRoomText> createState() => _DecodableRoomTextState();
}

class _DecodableRoomTextState extends State<DecodableRoomText> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant DecodableRoomText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room != widget.room) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = ElteRoomCode.tryParse(widget.room);
    if (parsed == null) {
      return Text(
        widget.room,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
        softWrap: widget.softWrap,
      );
    }

    final lang = AppStrings.getLanguagePack();
    final display = _expanded ? parsed.formatSummary(lang) : widget.room.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _expanded = !_expanded);
      },
      child: Text(
        display,
        style: widget.style,
        maxLines: _expanded ? null : widget.maxLines,
        overflow: _expanded ? TextOverflow.visible : widget.overflow,
        textAlign: widget.textAlign,
        softWrap: widget.softWrap,
      ),
    );
  }
}
