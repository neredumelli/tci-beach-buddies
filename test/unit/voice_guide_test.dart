import 'package:flutter_test/flutter_test.dart';
import 'package:tci_beach_buddies/core/geo/geo.dart';
import 'package:tci_beach_buddies/core/models/poi.dart';
import 'package:tci_beach_buddies/features/navigation/application/location_coordinator.dart';
import 'package:tci_beach_buddies/features/navigation/application/navigation_controller.dart';
import 'package:tci_beach_buddies/features/navigation/application/voice_guide.dart';
import 'package:tci_beach_buddies/features/navigation/domain/road_graph.dart';
import 'package:tci_beach_buddies/features/navigation/domain/route_planner.dart';
import 'package:tci_beach_buddies/features/settings/app_settings.dart';
import 'package:tci_beach_buddies/platform/audio/voice_service.dart';

import '../support/fakes.dart';

void main() {
  late FakeLocationSource src;
  late NavigationController nav;
  late RecordingVoiceService voice;
  late AppSettings settings;
  late Map<String, Poi> pois;

  Future<void> at(GeoPoint p, {double acc = 5}) async {
    src.emit(p, accuracy: acc);
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  setUp(() async {
    final graph = RoadGraph.fromJson(readJson('$syntheticRoot/assets/graph/graph.json'));
    final pj = readJson('$syntheticRoot/assets/pois/pois.json');
    final list = [for (final p in pj['pois'] as List) Poi.fromJson((p as Map).cast<String, dynamic>())];
    pois = {for (final p in list) p.id: p};
    src = FakeLocationSource();
    final loc = LocationCoordinator(source: src, coverage: graph.bounds);
    nav = NavigationController(location: loc, engine: LocalRouteEngine(RoutePlanner(graph)), pois: list);
    voice = RecordingVoiceService();
    settings = AppSettings();
    VoiceGuide(nav, voice, settings);
    await loc.start();
  });

  test('speaks route start, turns along the way, and arrival with description', () async {
    final ship = pois['grand-turk-cruise-center']!.approach!;
    await at(ship);
    await nav.selectDestination(pois['governors-beach']!);
    expect(voice.spoken.first, startsWith("Starting route to Governor's Beach."));
    final r = nav.route!;
    for (var s = 10.0; s < r.distanceM - 35; s += 10) {
      await at(pointAlong(r.polyline, r.cumulative, s));
    }
    final turns = voice.spoken.where((t) => RegExp(r'^(In .*, )?(turn|bear|sharp|Turn|Bear|Sharp)').hasMatch(t));
    expect(turns, isNotEmpty, reason: voice.spoken.join(' / '));
    final gov = pois['governors-beach']!.approach!;
    await at(gov);
    await at(gov);
    expect(voice.spoken, contains("You have arrived at Governor's Beach."));
    expect(voice.spoken, contains(pois['governors-beach']!.description));
  });

  test('announces GPS loss and off-route rerouting', () async {
    final ship = pois['grand-turk-cruise-center']!.approach!;
    await at(ship);
    await nav.selectDestination(pois['grand-turk-lighthouse']!);
    await at(ship, acc: 500);
    expect(voice.spoken, contains('GPS signal lost. Guidance paused.'));
    final off = GeoPoint(ship.lat + metersToLatDeg(20), ship.lon + metersToLonDeg(120, ship.lat));
    await at(off);
    await at(off);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(voice.spoken, contains('Off route. Recalculating from your position.'));
    expect(voice.spoken.any((t) => t.startsWith('New route,')), isTrue);
  });

  test('silent when voice guidance is switched off', () async {
    settings.setVoiceGuidance(false);
    await at(pois['grand-turk-cruise-center']!.approach!);
    await nav.selectDestination(pois['governors-beach']!);
    expect(voice.spoken, isEmpty);
  });
}
