// Route progress, off-route detection and arrival evaluation (TDD 4.4, 4.5).
// Remaining distance is ALONG THE ROUTE, never crow-flies.
import 'dart:math' as math;

import '../../../core/geo/geo.dart';
import '../../../core/models/location_fix.dart';
import 'gps_policy.dart';
import 'route_models.dart';

class ProgressSnapshot {
  final double alongM;
  final double remainingM;
  final double deviationM;
  final GeoPoint pointOnRoute;

  /// True once deviation has been confirmed by enough consecutive good fixes.
  final bool offRouteConfirmed;
  final Maneuver? nextManeuver;
  final double? distanceToNextManeuverM;
  const ProgressSnapshot({
    required this.alongM,
    required this.remainingM,
    required this.deviationM,
    required this.pointOnRoute,
    required this.offRouteConfirmed,
    required this.nextManeuver,
    required this.distanceToNextManeuverM,
  });
}

class RouteProgressTracker {
  final PlannedRoute route;
  final GpsPolicy policy;
  double _lastAlong = 0;
  int _offRouteCount = 0;

  RouteProgressTracker(this.route, this.policy);

  ProgressSnapshot update(LocationFix fix, FixQuality quality) {
    final pts = route.polyline;
    final cum = route.cumulative;
    // 1) Windowed projection near the last known progress, so that out-and-back
    //    routes (same road both ways) do not jump to the wrong leg.
    final win = _project(fix.position, _lastAlong - 40, _lastAlong + 400);
    var best = win;
    // 2) Global projection if the window looks wrong (visitor skipped ahead).
    if (win == null || win.distance > policy.offRouteDistanceM) {
      final global = _project(fix.position, double.negativeInfinity, double.infinity);
      if (global != null && (win == null || global.distance + 20 < win.distance)) {
        best = global;
      }
    }
    best ??= _Proj(pts.first, 0, haversineM(fix.position, pts.first));
    _lastAlong = best.along;

    if (quality == FixQuality.good && best.distance > policy.offRouteDistanceM) {
      _offRouteCount++;
    } else if (quality == FixQuality.good) {
      _offRouteCount = 0;
    } // poor/stale fixes neither confirm nor clear deviation

    final total = cum[cum.length - 1];
    Maneuver? next;
    for (final m in route.maneuvers) {
      if (m.atDistanceM > best.along + 2 && m.type != ManeuverType.depart) {
        next = m;
        break;
      }
    }
    return ProgressSnapshot(
      alongM: best.along,
      remainingM: math.max(0, total - best.along),
      deviationM: best.distance,
      pointOnRoute: best.point,
      offRouteConfirmed: _offRouteCount >= policy.offRouteConsecutiveFixes,
      nextManeuver: next,
      distanceToNextManeuverM: next == null ? null : math.max(0, next.atDistanceM - best.along),
    );
  }

  _Proj? _project(GeoPoint p, double fromAlong, double toAlong) {
    final pts = route.polyline;
    final cum = route.cumulative;
    _Proj? best;
    for (var i = 0; i + 1 < pts.length; i++) {
      if (cum[i + 1] < fromAlong || cum[i] > toAlong) continue;
      final pr = projectOntoSegment(p, pts[i], pts[i + 1]);
      if (best == null || pr.distanceM < best.distance) {
        final along = cum[i] + haversineM(pts[i], pr.point);
        best = _Proj(pr.point, along, pr.distanceM);
      }
    }
    return best;
  }
}

class _Proj {
  final GeoPoint point;
  final double along;
  final double distance;
  const _Proj(this.point, this.along, this.distance);
}

/// Confirms arrival at the APPROVED APPROACH POINT using proximity, accuracy
/// and consecutive fixes. Emits at most one arrival per navigation session.
class ArrivalEvaluator {
  final GeoPoint target;
  final GpsPolicy policy;
  int _count = 0;
  bool _fired = false;

  ArrivalEvaluator(this.target, this.policy);

  bool get hasArrived => _fired;

  /// Returns true exactly once, on the fix that confirms arrival.
  bool update(LocationFix fix, FixQuality quality) {
    if (_fired) return false;
    if (quality != FixQuality.good) return false; // poor fixes cannot confirm
    final d = haversineM(fix.position, target);
    if (d <= policy.arrivalRadiusM) {
      _count++;
    } else {
      _count = 0;
    }
    if (_count >= policy.arrivalConsecutiveFixes) {
      _fired = true;
      return true;
    }
    return false;
  }
}
