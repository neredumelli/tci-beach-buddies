// GPS quality policy (TDD 5.1). Values are PROVISIONAL test defaults that must
// be confirmed by GPS replay and Grand Turk field validation (TD-05).
import '../../../core/geo/geo.dart';
import '../../../core/models/location_fix.dart';

enum FixQuality {
  /// Fresh and accurate enough for navigation.
  good,

  /// Usable but degraded; UI warns the visitor.
  poor,

  /// Too inaccurate to use (rejected).
  unusable,

  /// Older than the freshness limit (never relabelled as current).
  stale,

  /// Outside the Grand Turk coverage area.
  outsideCoverage,
}

class GpsPolicy {
  final Duration maxFixAge;
  final double goodAccuracyM;
  final double maxAccuracyM;

  // Navigation thresholds.
  final double offRouteDistanceM;
  final int offRouteConsecutiveFixes;
  final Duration rerouteCooldown;
  final double arrivalRadiusM;
  final int arrivalConsecutiveFixes;

  const GpsPolicy({
    this.maxFixAge = const Duration(seconds: 10),
    this.goodAccuracyM = 30,
    this.maxAccuracyM = 100,
    this.offRouteDistanceM = 35,
    this.offRouteConsecutiveFixes = 2,
    this.rerouteCooldown = const Duration(seconds: 8),
    this.arrivalRadiusM = 30,
    this.arrivalConsecutiveFixes = 2,
  });

  FixQuality classify(LocationFix fix, DateTime now, GeoBounds coverage) {
    if (fix.ageAt(now) > maxFixAge) return FixQuality.stale;
    if (!fix.accuracyM.isFinite || fix.accuracyM > maxAccuracyM) {
      return FixQuality.unusable;
    }
    if (!coverage.contains(fix.position)) return FixQuality.outsideCoverage;
    return fix.accuracyM <= goodAccuracyM ? FixQuality.good : FixQuality.poor;
  }

  /// Acceptable as a route ORIGIN (good or poor-but-usable).
  bool acceptableForRouting(FixQuality q) => q == FixQuality.good || q == FixQuality.poor;
}
