import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/geo/geo.dart';
import '../core/models/poi.dart';
import '../data/offline_bundle.dart';
import '../features/navigation/application/location_coordinator.dart';
import '../features/navigation/application/navigation_controller.dart';
import '../features/navigation/domain/route_planner.dart';
import '../features/settings/app_settings.dart';
import '../platform/location/demo_location_source.dart';
import '../platform/location/geolocator_location_source.dart';
import '../platform/location/location_source.dart';

/// Grand Turk fallback bounds, used only to frame the screen when the
/// offline bundle is missing (never for routing).
const GeoBounds grandTurkFallbackBounds = GeoBounds(21.40, -71.17, 21.53, -71.10);

/// Composition root. Created once after the offline bundle is verified.
class AppServices {
  final BundleHealth bundle;
  final AppSettings settings;
  final LocationCoordinator location;
  final NavigationController nav;
  final LocationSource liveSource;
  DemoLocationSource? demoSource;

  AppServices._(this.bundle, this.settings, this.location, this.nav, this.liveSource);

  static Future<AppServices> create({
    required BundleHealth bundle,
    required AppSettings settings,
    LocationSource? liveSource,
  }) async {
    final coverage = bundle.manifest?.coverage ?? grandTurkFallbackBounds;
    final live = liveSource ?? GeolocatorLocationSource();
    final location = LocationCoordinator(source: live, coverage: coverage);
    final graph = bundle.navigationAvailable ? bundle.graph : null;
    final nav = NavigationController(
      location: location,
      engine: graph == null ? null : LocalRouteEngine(RoutePlanner(graph)),
      pois: bundle.pois,
      bundleValid: bundle.navigationAvailable,
    );
    final s = AppServices._(bundle, settings, location, nav, live);
    nav.onArrival = (_) {
      if (settings.vibration) HapticFeedback.heavyImpact();
      if (settings.arrivalSound) SystemSound.play(SystemSoundType.alert);
    };
    return s;
  }

  List<Poi> get pois => bundle.pois;
  List<Poi> get destinations => bundle.pois.where((p) => !p.isShipTerminal).toList();
  GeoBounds get coverage => bundle.manifest?.coverage ?? grandTurkFallbackBounds;

  Poi? poiById(String id) {
    for (final p in bundle.pois) {
      if (p.id == id) return p;
    }
    return null;
  }

  void dispose() {
    demoSource?.stop();
    nav.dispose();
    location.dispose();
  }

  /// Enable/disable the SIMULATED location source.
  Future<void> setDemoMode(bool enabled) async {
    if (enabled) {
      final ship = nav.shipTerminal;
      demoSource = DemoLocationSource(start: ship?.approach ?? ship?.display ?? coverage.center);
      await location.switchSource(demoSource!);
    } else {
      await demoSource?.stop();
      demoSource = null;
      await location.switchSource(liveSource);
    }
    // Any route computed from the other source is no longer valid.
    nav.stop();
    settings.setDemoMode(enabled);
  }
}

class AppScope extends InheritedWidget {
  final AppServices services;
  const AppScope({super.key, required this.services, required super.child});

  static AppServices of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope missing');
    return s!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}
