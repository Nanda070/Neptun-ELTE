import 'package:flutter/material.dart';
import 'package:neptun2/CampusMap/campus_map_package.dart';
import 'package:neptun2/colors.dart';
import 'package:neptun2/haptics.dart';
import 'package:neptun2/language.dart';
import 'package:neptun2/Misc/elte_room_code.dart';

/// Indoor campus map (Phase B MVP). Works without Neptun login.
class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key, this.initialBuildingId = 'ld'});

  final String initialBuildingId;

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  CampusMapPackage? _pkg;
  Object? _loadError;
  String _buildingId = 'ld';
  int _floorLevel = 0;
  CampusSearchHit? _from;
  CampusSearchHit? _to;
  List<String>? _pathNodeIds;
  final _searchCtrl = TextEditingController();
  List<CampusSearchHit> _searchHits = const [];
  bool _pickingFrom = true;

  @override
  void initState() {
    super.initState();
    _buildingId = widget.initialBuildingId;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pkg = await CampusMapPackage.load();
      if (!mounted) return;
      setState(() {
        _pkg = pkg;
        _loadError = null;
        final g = pkg.graphs[_buildingId];
        if (g != null && g.floors.isNotEmpty) {
          _floorLevel = g.floors.any((f) => f.level == 0)
              ? 0
              : g.floors.first.level;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  CampusBuildingGraph? get _graph => _pkg?.graphs[_buildingId];

  void _onSearchChanged(String q) {
    final pkg = _pkg;
    if (pkg == null) return;
    setState(() => _searchHits = pkg.search(q));
  }

  void _selectHit(CampusSearchHit hit) {
    AppHaptics.lightImpact();
    setState(() {
      _buildingId = hit.buildingId;
      final floor = _graph?.floorById(hit.room.floorId);
      if (floor != null) _floorLevel = floor.level;
      if (_pickingFrom) {
        _from = hit;
      } else {
        _to = hit;
      }
      _pathNodeIds = null;
      _searchCtrl.clear();
      _searchHits = const [];
    });
  }

  void _route() {
    final g = _graph;
    final from = _from;
    final to = _to;
    if (g == null || from == null || to == null) return;
    if (from.buildingId != to.buildingId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.getLanguagePack().campusMap_CrossBuildingHint)),
      );
      return;
    }
    AppHaptics.lightImpact();
    final path = g.shortestPath(from.nodeId, to.nodeId);
    setState(() {
      _buildingId = from.buildingId;
      _pathNodeIds = path;
      if (path != null && path.isNotEmpty) {
        final startFloor = g.nodes[path.first]?.floorId;
        final fl = startFloor == null ? null : g.floorById(startFloor);
        if (fl != null) _floorLevel = fl.level;
      }
    });
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.getLanguagePack().campusMap_NoPath)),
      );
    }
  }

  void _clearRoute() {
    setState(() {
      _from = null;
      _to = null;
      _pathNodeIds = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppStrings.getLanguagePack();
    final theme = AppColors.getTheme();

    return Scaffold(
      backgroundColor: theme.rootBackground,
      appBar: AppBar(
        backgroundColor: theme.rootBackground,
        foregroundColor: theme.textColor,
        title: Text(lang.campusMap_Title, style: TextStyle(color: theme.textColor)),
        actions: [
          if (_from != null || _to != null || _pathNodeIds != null)
            IconButton(
              tooltip: lang.campusMap_Clear,
              onPressed: _clearRoute,
              icon: Icon(Icons.clear_all_rounded, color: theme.textColor),
            ),
        ],
      ),
      body: _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${lang.campusMap_LoadError}\n$_loadError',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textColor),
                ),
              ),
            )
          : _pkg == null
              ? Center(child: CircularProgressIndicator(color: theme.onSecondaryContainer))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text(
                        lang.campusMap_HonestyBanner,
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _buildingSwitcher(lang, theme),
                    _floorSwitcher(lang, theme),
                    _routeChips(lang, theme),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        style: TextStyle(color: theme.textColor),
                        decoration: InputDecoration(
                          hintText: _pickingFrom
                              ? lang.campusMap_SearchFrom
                              : lang.campusMap_SearchTo,
                          hintStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.45)),
                          prefixIcon: Icon(Icons.search, color: theme.textColor.withValues(alpha: 0.7)),
                          filled: true,
                          fillColor: theme.textColor.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.2)),
                          ),
                        ),
                      ),
                    ),
                    if (_searchHits.isNotEmpty)
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          itemCount: _searchHits.length,
                          itemBuilder: (ctx, i) {
                            final h = _searchHits[i];
                            final bName = h.buildingId == 'ld'
                                ? lang.roomCode_Building_LD
                                : lang.roomCode_Building_LE;
                            return ListTile(
                              dense: true,
                              title: Text(h.label, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '$bName · ${h.room.displayLabel}',
                                style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12),
                              ),
                              onTap: () => _selectHit(h),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: (_from != null && _to != null) ? _route : null,
                              icon: const Icon(Icons.route_rounded),
                              label: Text(lang.campusMap_Route),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_from != null && ElteRoomCode.canDecode(_from!.room.displayLabel.replaceAll(' ', '-')))
                            IconButton(
                              tooltip: lang.roomCode_OpenMap,
                              onPressed: () {
                                final code = _from!.room.displayLabel
                                    .replaceAll(' ', '-')
                                    .replaceAll('.', '-');
                                final parsed = ElteRoomCode.tryParse(code) ??
                                    ElteRoomCode.tryParse(
                                      '${_from!.buildingId.toUpperCase()}-${_from!.room.codeBis.replaceAll('_', '-')}',
                                    );
                                parsed?.openMaps();
                              },
                              icon: Icon(Icons.map_outlined, color: theme.onSecondaryContainer),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(child: _mapCanvas(theme, lang)),
                  ],
                ),
    );
  }

  Widget _buildingSwitcher(LanguagePack lang, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(lang.roomCode_Building_LD),
            selected: _buildingId == 'ld',
            onSelected: (_) {
              AppHaptics.lightImpact();
              setState(() {
                _buildingId = 'ld';
                _pathNodeIds = null;
                _floorLevel = 0;
              });
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(lang.roomCode_Building_LE),
            selected: _buildingId == 'le',
            onSelected: (_) {
              AppHaptics.lightImpact();
              setState(() {
                _buildingId = 'le';
                _pathNodeIds = null;
                _floorLevel = 0;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _floorSwitcher(LanguagePack lang, dynamic theme) {
    final g = _graph;
    if (g == null) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final f in g.floors)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('${f.level}'),
                selected: _floorLevel == f.level,
                onSelected: (_) {
                  AppHaptics.lightImpact();
                  setState(() => _floorLevel = f.level);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _routeChips(LanguagePack lang, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: FilterChip(
              selected: _pickingFrom,
              label: Text(
                _from == null
                    ? lang.campusMap_From
                    : '${lang.campusMap_From}: ${_from!.label}',
                overflow: TextOverflow.ellipsis,
              ),
              onSelected: (_) => setState(() => _pickingFrom = true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilterChip(
              selected: !_pickingFrom,
              label: Text(
                _to == null
                    ? lang.campusMap_To
                    : '${lang.campusMap_To}: ${_to!.label}',
                overflow: TextOverflow.ellipsis,
              ),
              onSelected: (_) => setState(() => _pickingFrom = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapCanvas(dynamic theme, LanguagePack lang) {
    final pkg = _pkg!;
    final g = _graph;
    if (g == null) return const SizedBox.shrink();
    final floor = g.floorByLevel(_floorLevel);
    if (floor == null) {
      return Center(child: Text(lang.campusMap_LoadError, style: TextStyle(color: theme.textColor)));
    }
    final asset = pkg.basemapAsset(_buildingId, _floorLevel);
    final pathPts = <Offset>[];
    if (_pathNodeIds != null) {
      for (final id in _pathNodeIds!) {
        final n = g.nodes[id];
        if (n == null) continue;
        if (n.floorId != floor.id) continue;
        pathPts.add(Offset(n.x, n.y));
      }
    }

    CampusRoom? pinRoom;
    if (_from != null && _from!.buildingId == _buildingId) {
      final f = g.floorById(_from!.room.floorId);
      if (f?.level == _floorLevel) pinRoom = _from!.room;
    }
    CampusRoom? pinTo;
    if (_to != null && _to!.buildingId == _buildingId) {
      final f = g.floorById(_to!.room.floorId);
      if (f?.level == _floorLevel) pinTo = _to!.room;
    }

    final floorsOnPath = <int>{};
    if (_pathNodeIds != null) {
      for (final id in _pathNodeIds!) {
        final n = g.nodes[id];
        if (n == null) continue;
        final fl = g.floorById(n.floorId);
        if (fl != null) floorsOnPath.add(fl.level);
      }
    }

    return Column(
      children: [
        if (floorsOnPath.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              '${lang.campusMap_FloorsOnPath}: ${floorsOnPath.toList()..sort()}',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.7), fontSize: 12),
            ),
          ),
        Expanded(
          child: InteractiveViewer(
            minScale: 0.6,
            maxScale: 5,
            child: AspectRatio(
              aspectRatio: floor.basemapWidth / floor.basemapHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sx = constraints.maxWidth / floor.basemapWidth;
                  final sy = constraints.maxHeight / floor.basemapHeight;
                  Offset map(Offset p) => Offset(p.dx * sx, p.dy * sy);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(asset, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                      CustomPaint(
                        painter: _PathPainter(
                          points: pathPts.map(map).toList(),
                          color: theme.onSecondaryContainer,
                        ),
                      ),
                      if (pinRoom != null)
                        _pin(map(Offset(pinRoom.x, pinRoom.y)), Colors.green.shade700, 'A'),
                      if (pinTo != null)
                        _pin(map(Offset(pinTo.x, pinTo.y)), Colors.red.shade700, 'B'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Text(
            floor.labelEn,
            style: TextStyle(color: theme.textColor.withValues(alpha: 0.55), fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _pin(Offset p, Color color, String label) {
    return Positioned(
      left: p.dx - 10,
      top: p.dy - 22,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          Icon(Icons.location_on, color: color, size: 22),
        ],
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.points, required this.color});
  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
