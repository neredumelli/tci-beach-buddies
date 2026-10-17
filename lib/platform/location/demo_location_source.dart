import 'dart:async';

import '../../core/geo/geo.dart';
import '../../core/models/location_fix.dart';
import 'location_source.dart';

/// SIMULATED position source for staff demos and QA (BR-17, RULE-06).
///
/// * Every fix it emits has `isSimulated = true`; the UI shows a permanent
///   SIMULATED banner while this source is active.
/// * It only moves where it is told to: [placeAt] or [walkAlong].
class DemoLocationSource implements LocationSource {
  final _controller = StreamController<LocationFix>.broadcast();
  Timer? _timer;
  GeoPoint? _position;
  List<GeoPoint>? _walk;
  List<double>? _walkCum;
  double _walkAlong = 0;

  /// Walking speed for simulated movement (m/s). 1.4 m/s ~ 5 km/h.
  double speedMps = 1.4;

  /// Time multiplier so a demo walk does not take real minutes.
  double speedUp = 8;
  final double accuracyM;
  final Duration tick;

  DemoLocationSource({GeoPoint? start, this.accuracyM = 8, this.tick = const Duration(seconds: 1)})
      : _position = start;

  @override
  bool get isSimulated => true;

  @override
  Stream<LocationFix> get fixes => _controller.stream;

  GeoPoint? get position => _position;
  bool get isWalking => _walk != null;

  @override
  Future<LocationPermissionState> ensurePermission() async => LocationPermissionState.granted;

  @override
  Future<void> start() async {
    _timer ??= Timer.periodic(tick, (_) => _emit());
    _emit();
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  /// Teleport to a point (stops any walk) and emit immediately.
  void placeAt(GeoPoint p) {
    _walk = null;
    _position = p;
    _emit();
  }

  /// Walk along a polyline (e.g. the active route) at [speedMps] * [speedUp].
  void walkAlong(List<GeoPoint> pts) {
    if (pts.length < 2) return;
    final cum = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + haversineM(pts[i - 1], pts[i]));
    }
    _walk = pts;
    _walkCum = cum;
    _walkAlong = 0;
    _position = pts.first;
    _emit();
  }

  void stopWalking() => _walk = null;

  void _emit() {
    final w = _walk, c = _walkCum;
    if (w != null && c != null) {
      _walkAlong += speedMps * speedUp * tick.inMilliseconds / 1000.0;
      if (_walkAlong >= c.last) {
        _position = w.last;
        _walk = null;
      } else {
        var i = 1;
        while (c[i] < _walkAlong) {
          i++;
        }
        final seg = c[i] - c[i - 1];
        _position = interpolate(w[i - 1], w[i], seg <= 0 ? 0 : (_walkAlong - c[i - 1]) / seg);
      }
    }
    final p = _position;
    if (p == null) return;
    _controller.add(LocationFix(
      position: p,
      accuracyM: accuracyM,
      timestamp: DateTime.now(),
      speedMps: w != null ? speedMps * speedUp : 0,
      isSimulated: true,
    ));
  }
}
