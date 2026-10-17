// Controller-level tests of the critical journeys on the SYNTHETIC bundle:
// Cruise -> A -> B -> Ship, rapid switching, GPS failures, rerouting.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tci_beach_buddies/core/geo/geo.dart';
import 'package:tci_beach_buddies/core/models/poi.dart';
import 'package:tci_beach_buddies/features/navigation/application/location_coordinator.dart';
import 'package:tci_beach_buddies/features/navigation/application/navigation_controller.dart';
import 'package:tci_beach_buddies/features/navigation/domain/road_graph.dart';
import 'package:tci_beach_buddies/features/navigation/domain/route_models.dart';
import 'package:tci_beach_buddies/features/navigation/domain/route_planner.dart';
import 'package:tci_beach_buddies/platform/location/location_source.dart';

import '../support/fakes.dart';

class Harness {
  final FakeLocationSource src;
  final LocationCoordinator loc;
  final DelayingEngine engine;
  final NavigationController nav;
  final Map<String, Poi> pois;
  Harness._(this.src, this.loc, this.engine, this.nav, this.pois);

  static Future<Harness> create({LocationPermissionState perm = LocationPermissionState.granted}) async {
    final graph = RoadGraph.fromJson(readJson('$syntheticRoot/assets/graph/graph.json'));
    final pj = readJson('$syntheticRoot/assets/pois/pois.json');
    final pois = [for (final p in pj['pois'] as List) Poi.fromJson((p as Map).cast<String, dynamic>())];
    final src = FakeLocationSource(permission: perm);
    final loc = LocationCoordinator(source: src, coverage: graph.bounds);
    final engine = DelayingEngine(LocalRouteEngine(RoutePlanner(graph)));
    final nav = NavigationController(location: loc, engine: engine, pois: pois);
    await loc.start();
    return Harness._(src, loc, engine, nav, {for (final p in pois) p.id: p});
  }

  Future<void> at(GeoPoint p, {double acc = 5, DateTime? time}) async {
    src.emit(p, accuracy: acc, at: time);
    await pump();
  }

  static Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 5));
  GeoPoint ap(String id) => pois[id]!.approach!;
}

void main() {
  test('J-02/J-03/J-04: Cruise -> A -> B -> Ship always routes from the LATEST live fix', () async {
    final h = await Harness.create();
    final ship = h.ap('grand-turk-cruise-center');
    final gov = h.ap('governors-beach');
    final jack = h.ap('jacks-shack');

    await h.at(ship);
    await h.nav.selectDestination(h.pois['governors-beach']!);
    expect(h.nav.phase, NavPhase.navigating);
    final r1 = h.nav.route!;
    expect(r1.originFix, ship);

    // Walk to A and arrive (two consecutive good fixes).
    await h.at(gov);
    await h.at(gov);
    expect(h.nav.phase, NavPhase.arrived);
    expect(h.nav.arrivedAt!.id, 'governors-beach');

    // Select nearby B: new route must start at A, not the cruise centre.
    await h.nav.selectDestination(h.pois['jacks-shack']!);
    expect(h.nav.phase, NavPhase.navigating);
    final r2 = h.nav.route!;
    expect(r2.originFix, gov, reason: 'origin must be the latest live fix');
    expect(haversineM(r2.snappedOrigin, gov), lessThan(5));
    expect(r2.distanceM, lessThan(400));
    final passesShip = r2.polyline.any((p) => haversineM(p, ship) < 500);
    expect(passesShip, isFalse, reason: 'must not detour via the cruise centre');
    expect(r2.requestId, greaterThan(r1.requestId));

    // Return to Ship from B uses the latest fix at B.
    await h.at(jack);
    await h.nav.returnToShip();
    expect(h.nav.destination!.isShipTerminal, isTrue);
    expect(h.nav.route!.originFix, jack);
    expect(haversineM(h.nav.route!.endpoint, ship), lessThan(1));
  });

  test('Rapid A then B: a late A result never overwrites B', () async {
    final h = await Harness.create();
    await h.at(h.ap('grand-turk-cruise-center'));
    final gate = Completer<void>();
    h.engine.gates['grand-turk-lighthouse'] = gate; // A is slow
    final fa = h.nav.selectDestination(h.pois['grand-turk-lighthouse']!);
    await Harness.pump();
    final fb = h.nav.selectDestination(h.pois['governors-beach']!);
    await fb;
    expect(h.nav.destination!.id, 'governors-beach');
    expect(h.nav.route!.destinationPoiId, 'governors-beach');
    gate.complete(); // A finishes late
    await fa;
    await Harness.pump();
    expect(h.nav.route!.destinationPoiId, 'governors-beach');
    expect(h.nav.destination!.id, 'governors-beach');
  });

  test('No fix: waits (no fabricated route), then resumes automatically on a valid fix', () async {
    final h = await Harness.create();
    final f = h.nav.selectDestination(h.pois['governors-beach']!);
    await Harness.pump();
    expect(h.nav.phase, NavPhase.waitingForFix);
    expect(h.nav.route, isNull);
    final here = h.ap('grand-turk-cruise-center');
    await h.at(here);
    await f;
    await Harness.pump();
    expect(h.nav.phase, NavPhase.navigating);
    expect(h.nav.route!.originFix, here);
  });

  test('Stale fix is never relabelled as current', () async {
    final h = await Harness.create();
    await h.at(h.ap('grand-turk-cruise-center'), time: DateTime.now().subtract(const Duration(minutes: 5)));
    expect(h.loc.status, GpsStatus.stale);
    unawaited(h.nav.selectDestination(h.pois['governors-beach']!));
    await Harness.pump();
    expect(h.nav.phase, NavPhase.waitingForFix);
    expect(h.nav.route, isNull);
  });

  test('Inaccurate fix (>100 m) rejected; poor (30-100 m) accepted with warning', () async {
    final h = await Harness.create();
    await h.at(h.ap('grand-turk-cruise-center'), acc: 250);
    expect(h.loc.status, GpsStatus.unusable);
    await h.at(h.ap('grand-turk-cruise-center'), acc: 60);
    expect(h.loc.status, GpsStatus.poor);
  });

  test('Permission denied: navigation waits and browsing data is still available', () async {
    final h = await Harness.create(perm: LocationPermissionState.denied);
    expect(h.loc.status, GpsStatus.permissionDenied);
    await h.nav.selectDestination(h.pois['governors-beach']!);
    expect(h.nav.phase, NavPhase.waitingForFix);
    expect(h.nav.failure, RouteFailureCode.noFreshFix);
    expect(h.pois.length, greaterThan(20));
  });

  test('Browse-only (offshore) destination -> NoRoute accessRestricted, no line drawn', () async {
    final h = await Harness.create();
    await h.at(h.ap('grand-turk-cruise-center'));
    await h.nav.selectDestination(h.pois['gibbs-cay']!);
    expect(h.nav.phase, NavPhase.noRoute);
    expect(h.nav.failure, RouteFailureCode.accessRestricted);
    expect(h.nav.route, isNull);
  });

  test('Off-route: reroute only after 2 good deviating fixes, from the new position', () async {
    final h = await Harness.create();
    final ship = h.ap('grand-turk-cruise-center');
    await h.at(ship);
    await h.nav.selectDestination(h.pois['grand-turk-lighthouse']!);
    final gen = h.nav.generation;
    // One jittery fix well off the route: no reroute yet.
    final off = GeoPoint(ship.lat + metersToLatDeg(20), ship.lon + metersToLonDeg(120, ship.lat));
    await h.at(off);
    expect(h.nav.generation, gen);
    // A poor-accuracy fix does not count.
    await h.at(off, acc: 70);
    expect(h.nav.generation, gen);
    // Second good deviating fix -> reroute from `off`.
    await h.at(off);
    await Harness.pump();
    expect(h.nav.generation, gen + 1);
    expect(h.nav.route!.originFix, off);
    expect(h.nav.phase, NavPhase.navigating);
  });

  test('Lost GPS while navigating pauses guidance but keeps the route', () async {
    final h = await Harness.create();
    await h.at(h.ap('grand-turk-cruise-center'));
    await h.nav.selectDestination(h.pois['governors-beach']!);
    await h.at(h.ap('grand-turk-cruise-center'), acc: 500);
    expect(h.nav.guidancePaused, isTrue);
    expect(h.nav.route, isNotNull);
  });

  test('Remaining distance is along the route and decreases while walking', () async {
    final h = await Harness.create();
    await h.at(h.ap('grand-turk-cruise-center'));
    await h.nav.selectDestination(h.pois['grand-turk-lighthouse']!);
    final r = h.nav.route!;
    final start = h.nav.progress!.remainingM;
    expect(start, closeTo(r.distanceM, 1));
    final mid = pointAlong(r.polyline, r.cumulative, r.distanceM / 2);
    await h.at(mid);
    expect(h.nav.progress!.remainingM, closeTo(r.distanceM / 2, 5));
    expect(h.nav.progress!.remainingM, greaterThan(haversineM(mid, r.endpoint) - 1));
  });

  test('Arrival fires once; Return to Ship at the terminal shows arrival immediately', () async {
    final h = await Harness.create();
    var arrivals = 0;
    h.nav.onArrival = (_) => arrivals++;
    final ship = h.ap('grand-turk-cruise-center');
    await h.at(ship);
    await h.nav.returnToShip();
    expect(h.nav.phase, NavPhase.arrived);
    await h.at(ship);
    await h.at(ship);
    expect(arrivals, 1);
  });

  test('Stop clears route and progress; later selection starts fresh', () async {
    final h = await Harness.create();
    await h.at(h.ap('grand-turk-cruise-center'));
    await h.nav.selectDestination(h.pois['governors-beach']!);
    h.nav.stop();
    expect(h.nav.phase, NavPhase.idle);
    expect(h.nav.route, isNull);
    expect(h.nav.progress, isNull);
  });
}
