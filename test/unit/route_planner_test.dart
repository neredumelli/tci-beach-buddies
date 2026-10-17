import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tci_beach_buddies/core/geo/geo.dart';
import 'package:tci_beach_buddies/features/navigation/domain/road_graph.dart';
import 'package:tci_beach_buddies/features/navigation/domain/route_models.dart';
import 'package:tci_beach_buddies/features/navigation/domain/route_planner.dart';

import '../support/fakes.dart';

RouteRequest req(GeoPoint o, GeoPoint d, {String gv = 'test-1', int id = 1}) => RouteRequest(
      requestId: id,
      origin: o,
      originFixTime: DateTime(2026),
      destinationPoiId: 'x',
      destinationApproach: d,
      travelProfile: 'foot',
      graphVersion: gv,
    );

/// 6 x 6 grid ladder, ~111 m spacing, plus one disconnected edge.
RoadGraph grid({bool withOneWay = false}) {
  final nodes = <(double, double)>[];
  for (var r = 0; r < 6; r++) {
    for (var c = 0; c < 6; c++) {
      nodes.add((21.44 + r * 0.001, -71.15 + c * 0.001));
    }
  }
  final edges = <(int, int, bool, String)>[];
  for (var r = 0; r < 6; r++) {
    for (var c = 0; c < 6; c++) {
      final i = r * 6 + c;
      if (c < 5) edges.add((i, i + 1, withOneWay && r == 0, 'Row $r'));
      if (r < 5) edges.add((i, i + 6, false, 'Col $c'));
    }
  }
  nodes.add((21.50, -71.12));
  nodes.add((21.501, -71.12));
  edges.add((36, 37, false, 'Island'));
  return RoadGraph.fromJson(graphJson(nodes, edges));
}

void main() {
  test('A* equals Dijkstra on random origin/destination pairs', () {
    final g = grid();
    final astar = RoutePlanner(g, config: const PlannerConfig(maxDestinationSnapM: 250));
    final dijkstra = astar.asDijkstra();
    final rnd = Random(7);
    var compared = 0;
    for (var i = 0; i < 200; i++) {
      GeoPoint rp() => GeoPoint(21.44 + rnd.nextDouble() * 0.005, -71.15 + rnd.nextDouble() * 0.005);
      final a = astar.calculate(req(rp(), rp()));
      final d = dijkstra.calculate(req(rp(), rp()));
      expect(a, isA<RouteSuccess>());
      expect(d, isA<RouteSuccess>());
      final o = rp(), t = rp();
      final r1 = astar.calculate(req(o, t)) as RouteSuccess;
      final r2 = dijkstra.calculate(req(o, t)) as RouteSuccess;
      expect(r1.route.distanceM, closeTo(r2.route.distanceM, 1e-6));
      compared++;
    }
    expect(compared, 200);
  });

  test('route polyline starts at snapped origin and follows the grid (Manhattan distance)', () {
    final g = grid();
    final p = RoutePlanner(g);
    // From node (0,0) to node (2,3): 5 blocks of ~111/104 m.
    final r = p.calculate(req(const GeoPoint(21.44, -71.15), const GeoPoint(21.442, -71.147))) as RouteSuccess;
    final expected = haversineM(const GeoPoint(21.44, -71.15), const GeoPoint(21.442, -71.15)) +
        haversineM(const GeoPoint(21.442, -71.15), const GeoPoint(21.442, -71.147));
    expect(r.route.distanceM, closeTo(expected, 1.0));
    expect(r.route.polyline.first, r.route.snappedOrigin);
    expect(r.route.polyline.last, r.route.endpoint);
    // Not a straight line: longer than the crow-flies distance.
    expect(r.route.distanceM, greaterThan(haversineM(const GeoPoint(21.44, -71.15), const GeoPoint(21.442, -71.147)) + 50));
  });

  test('split-edge snapping: origin and destination mid-edge do not detour via a vertex', () {
    final g = grid();
    final p = RoutePlanner(g);
    // Both points on the edge between (0,0) and (0,1), 30 m apart.
    const o = GeoPoint(21.44, -71.1497);
    const d = GeoPoint(21.44, -71.1494);
    final r = p.calculate(req(o, d)) as RouteSuccess;
    expect(r.route.distanceM, closeTo(haversineM(o, d), 0.5));
  });

  test('one-way edges are respected', () {
    final g = grid(withOneWay: true);
    final p = RoutePlanner(g);
    const west = GeoPoint(21.44, -71.15), east = GeoPoint(21.44, -71.149);
    final fwd = p.calculate(req(west, east)) as RouteSuccess;
    final back = p.calculate(req(east, west)) as RouteSuccess;
    expect(fwd.route.distanceM, closeTo(haversineM(west, east), 0.5));
    expect(back.route.distanceM, greaterThan(fwd.route.distanceM + 150)); // detour via row 1
  });

  test('disconnected destination -> NoRoute, never a straight line', () {
    final g = grid();
    final p = RoutePlanner(g);
    final r = p.calculate(req(const GeoPoint(21.44, -71.15), const GeoPoint(21.5005, -71.12)));
    expect(r, isA<RouteFailure>());
    expect((r as RouteFailure).code, RouteFailureCode.noRoute);
  });

  test('typed failures: outside coverage, no road snap, access restricted, version mismatch', () {
    final p = RoutePlanner(grid());
    expect((p.calculate(req(const GeoPoint(21.9, -71.15), const GeoPoint(21.44, -71.15))) as RouteFailure).code,
        RouteFailureCode.outsideCoverage);
    expect((p.calculate(req(const GeoPoint(21.47, -71.16), const GeoPoint(21.44, -71.15))) as RouteFailure).code,
        RouteFailureCode.noRoadSnap);
    expect((p.calculate(req(const GeoPoint(21.44, -71.15), const GeoPoint(21.47, -71.16))) as RouteFailure).code,
        RouteFailureCode.accessRestricted);
    expect((p.calculate(req(const GeoPoint(21.44, -71.15), const GeoPoint(21.44, -71.149), gv: 'other')) as RouteFailure).code,
        RouteFailureCode.bundleInvalid);
  });

  test('maneuvers: a right-angle turn at a junction is reported with the real road name', () {
    final p = RoutePlanner(grid());
    // East along Row 0 then north along Col 3.
    final r = p.calculate(req(const GeoPoint(21.44, -71.15), const GeoPoint(21.443, -71.147))) as RouteSuccess;
    final turns = r.route.maneuvers.where((m) => m.type == ManeuverType.left || m.type == ManeuverType.right);
    expect(turns, isNotEmpty);
    expect(r.route.maneuvers.first.type, ManeuverType.depart);
    expect(r.route.maneuvers.last.type, ManeuverType.arrive);
    for (final m in r.route.maneuvers) {
      expect(m.roadName == '' || m.roadName.startsWith('Row') || m.roadName.startsWith('Col'), isTrue);
    }
  });

  test('corrupt graph is rejected (length mismatch, bad node ref)', () {
    final j = graphJson([(21.44, -71.15), (21.441, -71.15)], [(0, 1, false, '')]);
    ((j['edges'] as List)[0] as List)[2] = 9999.0;
    expect(() => RoadGraph.fromJson(j), throwsA(isA<GraphFormatException>()));
    final k = graphJson([(21.44, -71.15), (21.441, -71.15)], [(0, 1, false, '')]);
    ((k['edges'] as List)[0] as List)[1] = 5;
    expect(() => RoadGraph.fromJson(k), throwsA(isA<GraphFormatException>()));
  });
}
