// Mandatory route regression on the REAL Grand Turk bundle (TDD 11.1).
// Replays test/fixtures/regression_routes.json (written by
// tools/pipeline/regression.py) against the app's own Dart RoutePlanner, and
// runs the Cruise -> A -> B -> Ship controller journey on real roads.
// Skipped automatically if the real bundle has not been built yet.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tci_beach_buddies/core/geo/geo.dart';
import 'package:tci_beach_buddies/core/models/poi.dart';
import 'package:tci_beach_buddies/features/navigation/application/location_coordinator.dart';
import 'package:tci_beach_buddies/features/navigation/application/navigation_controller.dart';
import 'package:tci_beach_buddies/features/navigation/domain/road_graph.dart';
import 'package:tci_beach_buddies/features/navigation/domain/route_models.dart';
import 'package:tci_beach_buddies/features/navigation/domain/route_planner.dart';

import '../support/fakes.dart';

void main() {
  for (final root in ['.', syntheticRoot]) {
    final vectorsPath = root == '.' ? 'test/fixtures/regression_routes.json' : '$root/regression_routes.json';
    final graphPath = '$root/assets/graph/graph.json';
    final available = File(vectorsPath).existsSync() && File(graphPath).existsSync();
    final label = root == '.' ? 'REAL Grand Turk bundle' : 'synthetic bundle';

    group('Route parity with reference router ($label)', () {
      if (!available) {
        test('bundle not built yet', () {}, skip: 'Run tools/pipeline/build_bundle.py + regression.py first');
        return;
      }
      final graph = RoadGraph.fromJson(readJson(graphPath));
      final pj = readJson('$root/assets/pois/pois.json');
      final pois = {
        for (final p in pj['pois'] as List)
          (p as Map)['id'] as String: Poi.fromJson(p.cast<String, dynamic>())
      };
      final vec = readJson(vectorsPath);
      test('vectors match graph version', () => expect(vec['graphVersion'], graph.graphVersion));
      final planner = RoutePlanner(graph);
      for (final v in (vec['vectors'] as List).cast<Map<String, dynamic>>()) {
        test(v['name'] as String, () {
          final o = (v['origin'] as List).cast<num>();
          final poi = pois[v['destPoiId']]!;
          if (v['expectRoutable'] != true) {
            expect(poi.canNavigate, isFalse);
            return;
          }
          final out = planner.calculate(RouteRequest(
            requestId: 1,
            origin: GeoPoint(o[0].toDouble(), o[1].toDouble()),
            originFixTime: DateTime.now(),
            destinationPoiId: poi.id,
            destinationApproach: poi.approach!,
            travelProfile: 'foot',
            graphVersion: graph.graphVersion,
          ));
          expect(out, isA<RouteSuccess>());
          final r = (out as RouteSuccess).route;
          expect(r.distanceM, closeTo((v['expectedDistanceM'] as num).toDouble(), 0.5));
          final so = (v['expectedSnappedOrigin'] as List).cast<num>();
          expect(haversineM(r.snappedOrigin, GeoPoint(so[0].toDouble(), so[1].toDouble())), lessThan(0.5));
          final dj = planner.asDijkstra().calculate(RouteRequest(
            requestId: 2,
            origin: GeoPoint(o[0].toDouble(), o[1].toDouble()),
            originFixTime: DateTime.now(),
            destinationPoiId: poi.id,
            destinationApproach: poi.approach!,
            travelProfile: 'foot',
            graphVersion: graph.graphVersion,
          )) as RouteSuccess;
          expect(r.distanceM, closeTo(dj.route.distanceM, 1e-6));
        });
      }

      test('controller journey Cruise -> Governor\'s -> Lighthouse -> Ship on $label', () async {
        final src = FakeLocationSource();
        final loc = LocationCoordinator(source: src, coverage: graph.bounds);
        final nav = NavigationController(
            location: loc, engine: LocalRouteEngine(planner), pois: pois.values.toList());
        await loc.start();
        Future<void> at(GeoPoint p) async {
          src.emit(p);
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        final ship = pois['grand-turk-cruise-center']!.approach!;
        final gov = pois['governors-beach']!.approach!;
        final lh = pois['grand-turk-lighthouse']!.approach!;
        await at(ship);
        await nav.selectDestination(pois['governors-beach']!);
        expect(nav.phase, NavPhase.navigating);
        final toGov = nav.route!.distanceM;
        // Walk the route with fixes every ~25 m: no spurious reroutes.
        final r = nav.route!;
        final gen = nav.generation;
        for (var s = 25.0; s < r.distanceM - 40; s += 25) {
          await at(pointAlong(r.polyline, r.cumulative, s));
        }
        expect(nav.generation, gen, reason: 'walking the route must not trigger reroutes');
        await at(gov);
        await at(gov);
        expect(nav.phase, NavPhase.arrived);

        await nav.selectDestination(pois['grand-turk-lighthouse']!);
        final b = nav.route!;
        expect(b.originFix, gov);
        final stale = planner.calculate(RouteRequest(
          requestId: 99,
          origin: ship,
          originFixTime: DateTime.now(),
          destinationPoiId: 'grand-turk-lighthouse',
          destinationApproach: lh,
          travelProfile: 'foot',
          graphVersion: graph.graphVersion,
        )) as RouteSuccess;
        // From Governor's the lighthouse must be closer than from the terminal
        // whenever Governor's lies north of the terminal (true on Grand Turk).
        if (gov.lat > ship.lat) expect(b.distanceM, lessThan(stale.route.distanceM));
        expect(b.distanceM, lessThan(toGov + stale.route.distanceM));

        await at(lh);
        await nav.returnToShip();
        expect(nav.route!.originFix, lh);
        expect(haversineM(nav.route!.endpoint, ship), lessThan(1));
        nav.dispose();
        loc.dispose();
      });
    });
  }
}
