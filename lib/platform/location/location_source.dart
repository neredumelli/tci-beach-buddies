import 'dart:async';

import '../../core/models/location_fix.dart';

enum LocationPermissionState {
  unknown,
  granted,
  denied,
  deniedForever,
  servicesDisabled,
}

/// Platform adapter boundary (TDD 8.1). Implementations: live GPS
/// (geolocator) and the clearly-labelled Demo source.
abstract class LocationSource {
  bool get isSimulated;

  /// Requests foreground permission if needed and reports the result.
  Future<LocationPermissionState> ensurePermission();

  /// Continuous stream of fixes while started.
  Stream<LocationFix> get fixes;

  Future<void> start();
  Future<void> stop();
}
