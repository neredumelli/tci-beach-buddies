import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/geo/geo.dart';
import '../../../core/models/location_fix.dart';
import '../../../platform/location/location_source.dart';
import '../domain/gps_policy.dart';

/// Visitor-facing GPS status (SDD 5.3).
enum GpsStatus { acquiring, good, poor, stale, unusable, outsideCoverage, permissionDenied, servicesOff, idle }

/// Owns the active location source and classifies every fix.
///
/// RULE-01: "current position" is a fresh, valid fix. A cached fix is NEVER
/// relabelled as live: [latestAcceptedFix] re-checks freshness at call time.
class LocationCoordinator extends ChangeNotifier {
  final GpsPolicy policy;
  GeoBounds coverage;
  final DateTime Function() _now;

  LocationSource _source;
  StreamSubscription<LocationFix>? _sub;
  LocationFix? _latest;
  FixQuality? _latestQuality;
  LocationPermissionState _permission = LocationPermissionState.unknown;
  bool _started = false;
  Timer? _staleTimer;
  final _accepted = StreamController<LocationFix>.broadcast();

  LocationCoordinator({
    required LocationSource source,
    required this.coverage,
    this.policy = const GpsPolicy(),
    DateTime Function()? clock,
  })  : _source = source,
        _now = clock ?? DateTime.now;

  LocationSource get source => _source;
  bool get isSimulated => _source.isSimulated;
  LocationFix? get latestFix => _latest;
  LocationPermissionState get permission => _permission;

  /// Every classified fix (for navigation progress), including poor ones.
  Stream<LocationFix> get fixStream => _accepted.stream;

  FixQuality? qualityOf(LocationFix f) => policy.classify(f, _now(), coverage);

  GpsStatus get status {
    if (!_started) return GpsStatus.idle;
    if (_permission == LocationPermissionState.servicesDisabled) return GpsStatus.servicesOff;
    if (_permission == LocationPermissionState.denied ||
        _permission == LocationPermissionState.deniedForever) {
      return GpsStatus.permissionDenied;
    }
    final f = _latest;
    if (f == null) return GpsStatus.acquiring;
    return switch (policy.classify(f, _now(), coverage)) {
      FixQuality.good => GpsStatus.good,
      FixQuality.poor => GpsStatus.poor,
      FixQuality.stale => GpsStatus.stale,
      FixQuality.unusable => GpsStatus.unusable,
      FixQuality.outsideCoverage => GpsStatus.outsideCoverage,
    };
  }

  Future<void> start() async {
    _started = true;
    _permission = await _source.ensurePermission();
    notifyListeners();
    if (_permission != LocationPermissionState.granted) return;
    _sub ??= _source.fixes.listen(_onFix);
    await _source.start();
    _staleTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      final q = _latest == null ? null : policy.classify(_latest!, _now(), coverage);
      if (q != _latestQuality) {
        _latestQuality = q;
        notifyListeners();
      }
    });
  }

  /// Retry after the visitor changed permissions in system settings.
  Future<void> retryPermission() async {
    await _sub?.cancel();
    _sub = null;
    await start();
  }

  /// Swap between live GPS and Demo. The previous source's last fix is
  /// discarded so a simulated position can never become a "live" origin
  /// (and vice versa).
  Future<void> switchSource(LocationSource next) async {
    await _sub?.cancel();
    _sub = null;
    await _source.stop();
    _source = next;
    _latest = null;
    _latestQuality = null;
    notifyListeners();
    if (_started) await start();
  }

  void _onFix(LocationFix f) {
    if (f.isSimulated != _source.isSimulated) return; // defensive
    _latest = f;
    _latestQuality = policy.classify(f, _now(), coverage);
    _accepted.add(f);
    notifyListeners();
  }

  /// Latest fix if it is fresh and acceptable NOW; otherwise waits up to
  /// [timeout] for a new acceptable fix. Returns null if none arrives.
  Future<LocationFix?> latestAcceptedFix({Duration timeout = const Duration(seconds: 8)}) async {
    final cur = _latest;
    if (cur != null && policy.acceptableForRouting(policy.classify(cur, _now(), coverage))) {
      return cur;
    }
    if (_permission != LocationPermissionState.granted) return null;
    try {
      return await _accepted.stream
          .firstWhere((f) => policy.acceptableForRouting(policy.classify(f, _now(), coverage)))
          .timeout(timeout);
    } on TimeoutException {
      return null;
    } on StateError {
      return null;
    }
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    _sub?.cancel();
    _source.stop();
    _accepted.close();
    super.dispose();
  }
}
