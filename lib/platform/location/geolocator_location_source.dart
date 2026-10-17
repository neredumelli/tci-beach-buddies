import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../core/geo/geo.dart';
import '../../core/models/location_fix.dart';
import 'location_source.dart';

/// Live, on-device GPS. Foreground only; positions never leave the device.
class GeolocatorLocationSource implements LocationSource {
  final _controller = StreamController<LocationFix>.broadcast();
  StreamSubscription<Position>? _sub;

  @override
  bool get isSimulated => false;

  @override
  Stream<LocationFix> get fixes => _controller.stream;

  @override
  Future<LocationPermissionState> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationPermissionState.servicesDisabled;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      switch (p) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return LocationPermissionState.granted;
        case LocationPermission.deniedForever:
          return LocationPermissionState.deniedForever;
        case LocationPermission.denied:
          return LocationPermissionState.denied;
        case LocationPermission.unableToDetermine:
          return LocationPermissionState.unknown;
      }
    } catch (_) {
      return LocationPermissionState.unknown;
    }
  }

  @override
  Future<void> start() async {
    if (_sub != null) return;
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        _controller.add(LocationFix(
          position: GeoPoint(pos.latitude, pos.longitude),
          accuracyM: pos.accuracy,
          // Receiver timestamp: lets the policy reject cached/stale positions.
          timestamp: pos.timestamp.toLocal(),
          speedMps: pos.speed >= 0 ? pos.speed : null,
          isSimulated: false,
        ));
      },
      onError: (Object _) {
        // Errors surface as "no fresh fix" through the freshness policy.
      },
    );
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();
  static Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
