// Vector basemap parsed from the bundled GeoJSON (assets/map/basemap.geojson).
// The map is drawn from these local vectors only: there is no tile layer and
// no URL anywhere in the rendering path, so it cannot reach the network.
import '../../../core/geo/geo.dart';

enum AreaKind { land, water, salina, wetland, beach, park, building, runway }

enum LineKind { majorRoad, minorRoad, path, track }

class MapArea {
  final AreaKind kind;
  final List<GeoPoint> outer;
  final List<List<GeoPoint>> holes;
  const MapArea(this.kind, this.outer, this.holes);
}

class MapLine {
  final LineKind kind;
  final String name;
  final List<GeoPoint> points;
  const MapLine(this.kind, this.name, this.points);
}

class MapLabel {
  final String text;
  final GeoPoint at;
  final String kind; // 'place' | 'water' | 'area'
  const MapLabel(this.text, this.at, this.kind);
}

class Basemap {
  final List<MapArea> areas;
  final List<MapLine> lines;
  final List<MapLabel> labels;
  const Basemap(this.areas, this.lines, this.labels);

  factory Basemap.fromGeoJson(Map<String, dynamic> fc) {
    if (fc['type'] != 'FeatureCollection') {
      throw const FormatException('basemap is not a FeatureCollection');
    }
    final areas = <MapArea>[];
    final lines = <MapLine>[];
    final labels = <MapLabel>[];
    for (final f in (fc['features'] as List).cast<Map<String, dynamic>>()) {
      final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
      final geom = (f['geometry'] as Map).cast<String, dynamic>();
      final kind = props['kind'] as String? ?? '';
      final name = props['name'] as String? ?? '';
      final type = geom['type'] as String;
      final coords = geom['coordinates'] as List;
      List<GeoPoint> ring(List r) => r.map((c) => GeoPoint.fromGeoJson(c as List)).toList();
      switch (type) {
        case 'Polygon':
          final k = _areaKind(kind);
          if (k != null) {
            areas.add(MapArea(k, ring(coords[0] as List),
                [for (final h in coords.skip(1)) ring(h as List)]));
          }
        case 'MultiPolygon':
          final k = _areaKind(kind);
          if (k != null) {
            for (final poly in coords) {
              final p = poly as List;
              areas.add(MapArea(k, ring(p[0] as List), [for (final h in p.skip(1)) ring(h as List)]));
            }
          }
        case 'LineString':
          final k = _lineKind(kind);
          if (k != null) lines.add(MapLine(k, name, ring(coords)));
        case 'Point':
          if (name.isNotEmpty) labels.add(MapLabel(name, GeoPoint.fromGeoJson(coords), kind));
      }
    }
    // Draw order: land first, buildings last.
    areas.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return Basemap(areas, lines, labels);
  }

  static AreaKind? _areaKind(String k) => switch (k) {
        'land' => AreaKind.land,
        'water' => AreaKind.water,
        'salina' => AreaKind.salina,
        'wetland' => AreaKind.wetland,
        'beach' => AreaKind.beach,
        'park' => AreaKind.park,
        'building' => AreaKind.building,
        'runway' => AreaKind.runway,
        _ => null,
      };

  static LineKind? _lineKind(String k) => switch (k) {
        'major_road' => LineKind.majorRoad,
        'minor_road' => LineKind.minorRoad,
        'path' => LineKind.path,
        'track' => LineKind.track,
        _ => null,
      };
}
