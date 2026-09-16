import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neptun2/CampusMap/campus_map_package.dart';

void main() {
  test('Dijkstra sample LD same-floor path exists', () {
    final file = File('docs/Technical/campus_map_package/graph_ld.json');
    final g = CampusBuildingGraph.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
    final path = g.shortestPath(
      'ld-n-ld-f0-room-0-821',
      'ld-n-ld-f0-room-0-805',
    );
    expect(path, isNotNull);
    expect(path!.first, 'ld-n-ld-f0-room-0-821');
    expect(path.last, 'ld-n-ld-f0-room-0-805');
    expect(path.length, greaterThan(1));
  });

  test('Dijkstra sample LD cross-floor path exists', () {
    final file = File('docs/Technical/campus_map_package/graph_ld.json');
    final g = CampusBuildingGraph.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
    final path = g.shortestPath(
      'ld-n-ld-f-1-room-00-112',
      'ld-n-ld-f1-room-1-105',
    );
    expect(path, isNotNull);
    expect(path!.length, greaterThan(2));
  });
}
