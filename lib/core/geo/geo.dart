// Pure-Dart geodesy helpers. No Flutter imports: the routing domain must be
// testable in isolation (TDD 2, "Domain: pure Dart, deterministic").
//
// COORDINATE CONVENTION (TDD 6 / SDD 8.2):
//   * GeoPoint is (lat, lon) - WGS84 degrees.
//   * GeoJSON arrays are [lon, lat].
//   * Only GeoPoint.fromGeoJson / toGeoJson cross that boundary.
import 'dart:math' as math;

const double earthRadiusM = 6371008.8;

class GeoPoint {
  final double lat;
  final double lon;
  const GeoPoint(this.lat, this.lon);

  /// GeoJSON position [lon, lat] -> GeoPoint(lat, lon).
  factory GeoPoint.fromGeoJson(List<dynamic> lonLat) =>
      GeoPoint((lonLat[1] as num).toDouble(), (lonLat[0] as num).toDouble());

  /// GeoPoint(lat, lon) -> GeoJSON position [lon, lat].
  List<double> toGeoJson() => [lon, lat];

  bool get isValid =>
      lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint(${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)})';
}

class GeoBounds {
  final double south, west, north, east;
  const GeoBounds(this.south, this.west, this.north, this.east);

  factory GeoBounds.fromJson(Map<String, dynamic> j) => GeoBounds(
        (j['south'] as num).toDouble(),
        (j['west'] as num).toDouble(),
        (j['north'] as num).toDouble(),
        (j['east'] as num).toDouble(),
      );

  bool contains(GeoPoint p) =>
      p.lat >= south && p.lat <= north && p.lon >= west && p.lon <= east;

  GeoPoint get center => GeoPoint((south + north) / 2, (west + east) / 2);
}

double _rad(double d) => d * math.pi / 180.0;
double _deg(double r) => r * 180.0 / math.pi;

/// Great-circle distance in metres (haversine).
double haversineM(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLon = _rad(b.lon - a.lon);
  final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * earthRadiusM * math.asin(math.min(1.0, math.sqrt(s)));
}

/// Initial bearing a -> b in degrees [0, 360).
double bearingDeg(GeoPoint a, GeoPoint b) {
  final p1 = _rad(a.lat), p2 = _rad(b.lat);
  final dl = _rad(b.lon - a.lon);
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (_deg(math.atan2(y, x)) + 360.0) % 360.0;
}

/// Signed smallest turn from bearing [from] to bearing [to], in (-180, 180].
/// Positive = right turn, negative = left turn.
double turnAngleDeg(double from, double to) {
  var d = (to - from) % 360.0;
  if (d > 180.0) d -= 360.0;
  if (d <= -180.0) d += 360.0;
  return d;
}

/// Sum of haversine lengths along a polyline.
double polylineLengthM(List<GeoPoint> pts) {
  var total = 0.0;
  for (var i = 1; i < pts.length; i++) {
    total += haversineM(pts[i - 1], pts[i]);
  }
  return total;
}

/// Result of projecting a point onto a segment.
class SegmentProjection {
  /// Fraction along the segment in [0, 1].
  final double t;
  final GeoPoint point;
  final double distanceM;
  const SegmentProjection(this.t, this.point, this.distanceM);
}

/// Projects [p] onto segment [a]-[b] using a local equirectangular plane,
/// which is accurate to centimetres over the few-hundred-metre segments of an
/// island road network.
SegmentProjection projectOntoSegment(GeoPoint p, GeoPoint a, GeoPoint b) {
  final cosLat = math.cos(_rad(p.lat));
  final ax = a.lon * cosLat, ay = a.lat;
  final bx = b.lon * cosLat, by = b.lat;
  final px = p.lon * cosLat, py = p.lat;
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  if (t < 0) t = 0;
  if (t > 1) t = 1;
  final q = GeoPoint(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t);
  return SegmentProjection(t, q, haversineM(p, q));
}

GeoPoint interpolate(GeoPoint a, GeoPoint b, double t) =>
    GeoPoint(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t);

/// Metres -> degrees of latitude (approx).
double metersToLatDeg(double m) => m / 111320.0;

/// Metres -> degrees of longitude at [lat] (approx).
double metersToLonDeg(double m, double lat) =>
    m / (111320.0 * math.cos(_rad(lat)));
