// Route request/result contracts (TDD 4.1). Pure Dart.
import 'dart:typed_data';

import '../../../core/geo/geo.dart';

/// Typed routing failures. The UI maps each one to an actionable message and
/// NEVER substitutes a straight line (BR-07, RULE-02).
enum RouteFailureCode {
  noFreshFix,
  lowAccuracy,
  outsideCoverage,
  noRoadSnap,
  noRoute,
  accessRestricted,
  bundleInvalid,
}

enum ManeuverType {
  depart,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
  arrive,
}

class Maneuver {
  final ManeuverType type;

  /// Along-route distance (m) at which the maneuver happens.
  final double atDistanceM;

  /// Name of the road/path being joined, from source data only ('' if none).
  final String roadName;
  final GeoPoint point;
  const Maneuver(this.type, this.atDistanceM, this.roadName, this.point);

  String get instruction {
    final onto = roadName.isEmpty ? '' : ' onto $roadName';
    switch (type) {
      case ManeuverType.depart:
        return roadName.isEmpty ? 'Head off along the path' : 'Head along $roadName';
      case ManeuverType.slightLeft:
        return 'Bear left$onto';
      case ManeuverType.left:
        return 'Turn left$onto';
      case ManeuverType.sharpLeft:
        return 'Sharp left$onto';
      case ManeuverType.slightRight:
        return 'Bear right$onto';
      case ManeuverType.right:
        return 'Turn right$onto';
      case ManeuverType.sharpRight:
        return 'Sharp right$onto';
      case ManeuverType.uTurn:
        return 'Turn around$onto';
      case ManeuverType.arrive:
        return 'Arrive at destination';
    }
  }
}

class RouteRequest {
  final int requestId;
  final GeoPoint origin;
  final DateTime originFixTime;
  final String destinationPoiId;
  final GeoPoint destinationApproach;
  final String travelProfile;
  final String graphVersion;
  const RouteRequest({
    required this.requestId,
    required this.origin,
    required this.originFixTime,
    required this.destinationPoiId,
    required this.destinationApproach,
    required this.travelProfile,
    required this.graphVersion,
  });
}

class PlannedRoute {
  final int requestId;
  final String destinationPoiId;

  /// The live fix this route was computed from (audit trail for BR-05).
  final GeoPoint originFix;
  final DateTime originFixTime;

  /// Origin projected onto the network.
  final GeoPoint snappedOrigin;
  final double originSnapDistanceM;

  /// Approved approach point on the network.
  final GeoPoint endpoint;

  /// Road-following geometry, starting at [snappedOrigin], ending at [endpoint].
  final List<GeoPoint> polyline;

  /// Cumulative along-route distance at each polyline vertex.
  final Float64List cumulative;
  final List<int> edgeIds;
  final List<Maneuver> maneuvers;

  PlannedRoute({
    required this.requestId,
    required this.destinationPoiId,
    required this.originFix,
    required this.originFixTime,
    required this.snappedOrigin,
    required this.originSnapDistanceM,
    required this.endpoint,
    required this.polyline,
    required this.cumulative,
    required this.edgeIds,
    required this.maneuvers,
  });

  /// Network distance (does not include the off-network walk to the snap point).
  double get distanceM => cumulative.isEmpty ? 0 : cumulative[cumulative.length - 1];
}

sealed class RouteOutcome {
  const RouteOutcome();
}

class RouteSuccess extends RouteOutcome {
  final PlannedRoute route;
  const RouteSuccess(this.route);
}

class RouteFailure extends RouteOutcome {
  final RouteFailureCode code;
  final String detail;
  const RouteFailure(this.code, [this.detail = '']);
}
