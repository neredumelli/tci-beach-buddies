import 'package:flutter_test/flutter_test.dart';
import 'package:tci_beach_buddies/core/geo/geo.dart';
import 'package:tci_beach_buddies/features/map/presentation/island_map.dart';

void main() {
  test('haversine: 0.001 deg latitude is ~111 m', () {
    expect(haversineM(const GeoPoint(21.45, -71.14), const GeoPoint(21.451, -71.14)), closeTo(111.2, 0.3));
  });

  test('GeoJSON [lon, lat] <-> GeoPoint(lat, lon) conversion is explicit', () {
    final p = GeoPoint.fromGeoJson([-71.14, 21.45]);
    expect(p.lat, 21.45);
    expect(p.lon, -71.14);
    expect(p.toGeoJson(), [-71.14, 21.45]);
    final ll = toLatLng(p);
    expect(ll.latitude, 21.45);
    expect(ll.longitude, -71.14);
  });

  test('turn angle sign: right is positive', () {
    expect(turnAngleDeg(0, 90), 90);
    expect(turnAngleDeg(0, 270), -90);
    expect(turnAngleDeg(350, 10), closeTo(20, 1e-9));
  });

  test('projection onto segment clamps to endpoints', () {
    const a = GeoPoint(21.45, -71.14), b = GeoPoint(21.46, -71.14);
    final pr = projectOntoSegment(const GeoPoint(21.47, -71.14), a, b);
    expect(pr.t, 1);
    expect(pr.distanceM, closeTo(1112, 2));
  });

  test('bounds contain', () {
    const b = GeoBounds(21.40, -71.17, 21.53, -71.10);
    expect(b.contains(const GeoPoint(21.46, -71.14)), isTrue);
    expect(b.contains(const GeoPoint(21.80, -71.14)), isFalse);
  });
}
