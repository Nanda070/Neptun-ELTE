import 'package:flutter/material.dart';
import 'package:neptun2/CampusMap/campus_map_package.dart';
import 'package:neptun2/CampusMap/campus_map_polygons.dart';
import 'package:neptun2/colors.dart';
import 'package:neptun2/haptics.dart';
import 'package:neptun2/language.dart';
import 'package:neptun2/Misc/elte_room_code.dart';

/// Indoor campus map — BIS FootPrint room polygons (not schematic ribbons).
/// Works without Neptun login. Scope: IT faculty LD+LE.
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
  final _transform = TransformationController();
  double _viewScale = 1.0;
  CampusRoomPolygon? _selectedPoly;

  @override
  void initState() {
    super.initState();
    _buildingId = widget.initialBuildingId;
    _transform.addListener(_onTransform);
    _load();
  }

  void _onTransform() {
    final s = _transform.value.getMaxScaleOnAxis();
    if ((s - _viewScale).abs() > 0.04) {
      setState(() => _viewScale = s);
    }
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
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
      _selectedPoly = _polyForGraphRoom(hit.room);
      _searchCtrl.clear();
      _searchHits = const [];
    });
  }

  CampusRoomPolygon? _polyForGraphRoom(CampusRoom room) {
    final floor = _pkg?.floorPolygons(_buildingId, _floorLevel);
    if (floor == null) return null;
    final code = room.bisRoomCode;
    if (code != null && code.isNotEmpty) {
      for (final p in floor.rooms) {
        if (p.code == code) return p;
      }
    }
    final needle = room.codeBis.replaceAll('.', '-');
    for (final p in floor.rooms) {
      if (p.number == room.codeBis || p.number == needle) return p;
    }
    return null;
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
      _selectedPoly = null;
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
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.onSecondaryContainer.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.onSecondaryContainer.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          lang.campusMap_ItFacultyOnlyShort,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.textColor.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
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
                _selectedPoly = null;
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
                _selectedPoly = null;
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
                  setState(() {
                    _floorLevel = f.level;
                    _selectedPoly = null;
                  });
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

    final polySet = pkg.polygons[_buildingId];
    final polyFloor = pkg.floorPolygons(_buildingId, _floorLevel);

    String? fromRoomId;
    String? toRoomId;
    if (_from != null && _from!.buildingId == _buildingId) {
      final f = g.floorById(_from!.room.floorId);
      if (f?.level == _floorLevel) fromRoomId = _from!.room.id;
    }
    if (_to != null && _to!.buildingId == _buildingId) {
      final f = g.floorById(_to!.room.floorId);
      if (f?.level == _floorLevel) toRoomId = _to!.room.id;
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? theme.textColor.withValues(alpha: 0.06)
        : const Color(0xFFF1F5F9);
    final route = theme.onSecondaryContainer;

    if (polySet == null || polyFloor == null || polyFloor.rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            lang.campusMap_LoadError,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textColor),
          ),
        ),
      );
    }

    final view = buildFloorView(polySet, polyFloor);
    final affine = fitAffineForFloor(g, floor);
    final aspect = view.bounds.width / view.bounds.height;

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
            transformationController: _transform,
            minScale: 0.55,
            maxScale: 8,
            child: AspectRatio(
              aspectRatio: aspect.isFinite && aspect > 0.2 ? aspect : 1.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      if (w <= 0 || h <= 0) return;
                      final hit = CampusPolygonPainter.findRoomAt(
                        localPos: details.localPosition,
                        size: Size(w, h),
                        floor: polyFloor,
                        projector: view.projector,
                        bounds: view.bounds,
                      );
                      AppHaptics.lightImpact();
                      setState(() => _selectedPoly = hit);
                    },
                    child: CustomPaint(
                      painter: CampusPolygonPainter(
                        polygonFloor: polyFloor,
                        graph: g,
                        floor: floor,
                        affine: affine,
                        projector: view.projector,
                        bounds: view.bounds,
                        pathNodeIds: _pathNodeIds,
                        fromRoomId: fromRoomId,
                        toRoomId: toRoomId,
                        selectedCode: _selectedPoly?.code,
                        routeColor: route,
                        labelColor: theme.textColor,
                        surfaceColor: surface,
                        viewScale: _viewScale,
                        dark: isDark,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (_selectedPoly != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Material(
              color: theme.textColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                title: Text(
                  _selectedPoly!.name.isNotEmpty
                      ? _selectedPoly!.name
                      : _selectedPoly!.shortLabel,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  [
                    if (_selectedPoly!.code.isNotEmpty) _selectedPoly!.code,
                    _selectedPoly!.type,
                  ].join(' · '),
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.close, color: theme.textColor.withValues(alpha: 0.6)),
                  onPressed: () => setState(() => _selectedPoly = null),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
          child: Text(
            '${floor.labelEn} · ${lang.campusMap_CoverageHint.replaceAll('{n}', '${pkg.totalPolygonCount}').replaceAll('{c}', '${pkg.totalCatalogCount}')}',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textColor.withValues(alpha: 0.5), fontSize: 11),
          ),
        ),
      ],
    );
  }
}
