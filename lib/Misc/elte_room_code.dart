import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';
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

  String get _normalizedPrefix =>
      campusPrefix.toUpperCase().replaceAll('É', 'E');

  /// True only for known Lágymányos buildings (LD / LE / LK).
  bool get hasMapsDeepLink {
    switch (_normalizedPrefix) {
      case 'LD':
      case 'LE':
      case 'LK':
        return true;
      default:
        return false;
    }
  }

  /// Building search string for Apple/Google Maps. Null for unknown prefixes
  /// so we never drop a wrong campus pin.
  String? mapsSearchQuery() {
    switch (_normalizedPrefix) {
      case 'LD':
        return 'ELTE Déli Tömb, 1117 Budapest';
      case 'LE':
        return 'ELTE Északi Tömb, 1117 Budapest';
      case 'LK':
        return 'ELTE Kémiai tömb, 1117 Budapest';
      default:
        return null;
    }
  }

  Uri? mapsUri() {
    final q = mapsSearchQuery();
    if (q == null) return null;
    final encoded = Uri.encodeComponent(q);
    if (Platform.isIOS || Platform.isMacOS) {
      return Uri.parse('https://maps.apple.com/?q=$encoded');
    }
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
  }

  Future<bool> openMaps() async {
    final uri = mapsUri();
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String buildingName(LanguagePack lang) {
    switch (_normalizedPrefix) {
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

/// Tap toggles coded room ↔ localized decode. Known LD/LE/LK buildings expose
/// an “Open map” deep-link after decode. Non-coded / unknown-prefix text stays
/// text-only (no map pin).
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
    final showMap = _expanded && parsed.hasMapsDeepLink;
    final align = widget.textAlign ?? TextAlign.start;
    final cross = align == TextAlign.center
        ? CrossAxisAlignment.center
        : (align == TextAlign.end || align == TextAlign.right)
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
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
        ),
        if (showMap)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                parsed.openMaps();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: ((widget.style?.fontSize) ?? 14) + 2,
                    color: AppColors.getTheme().onSecondaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      lang.roomCode_OpenMap,
                      style: (widget.style ?? const TextStyle()).copyWith(
                        color: AppColors.getTheme().onSecondaryContainer,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            AppColors.getTheme().onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: widget.textAlign,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
