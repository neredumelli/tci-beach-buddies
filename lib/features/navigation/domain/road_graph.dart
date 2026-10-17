// Directed, access-aware road/path graph for the approved travel profile.
// Pure Dart (no Flutter imports).
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/geo/geo.dart';

/// Thrown when the bundled graph violates the data contract (TDD 3.2).
class GraphFormatException implements Exception {
  final String message;
  GraphFormatException(this.message);
  @override
  String toString() => 'GraphFormatException: $message';
}

class RoadEdge {
  final int id;
  final int from;
  final int to;

  /// true => may only be traversed from -> to (one-way for this profile).
  final bool forwardOnly;
  final String roadClass;

  /// Road/path name from source data, or '' when unnamed. Never invented.
  final String name;

  /// Full geometry including the from/to node positions.
  final List<GeoPoint> geometry;

  /// Cumulative haversine distance at each geometry vertex; last == length.
  final Float64List cumulative;

  RoadEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.forwardOnly,
    required this.roadClass,
    required this.name,
    required this.geometry,
    required this.cumulative,
  });

  double get lengthM => cumulative[cumulative.length - 1];

  /// Point located [offsetM] metres from the `from` node along the geometry.
  GeoPoint pointAt(double offsetM) {
    if (offsetM <= 0) return geometry.first;
    if (offsetM >= lengthM) return geometry.last;
    var i = 1;
    while (i < cumulative.length && cumulative[i] < offsetM) {
      i++;
    }
    final segLen = cumulative[i] - cumulative[i - 1];
    final t = segLen <= 0 ? 0.0 : (offsetM - cumulative[i - 1]) / segLen;
    return interpolate(geometry[i - 1], geometry[i], t);
  }

  /// Geometry between two offsets, ordered from [a] to [b] (reversed when a > b).
  List<GeoPoint> slice(double a, double b) {
    final lo = math.min(a, b), hi = math.max(a, b);
    final pts = <GeoPoint>[pointAt(lo)];
    for (var i = 0; i < geometry.length; i++) {
      if (cumulative[i] > lo && cumulative[i] < hi) pts.add(geometry[i]);
    }
    pts.add(pointAt(hi));
    return a <= b ? pts : pts.reversed.toList();
  }
}

/// Outgoing traversal option from a node.
class Arc {
  final int edgeId;
  final int toNode;
  final bool forward; // true = traverses edge from->to
  final double cost;
  const Arc(this.edgeId, this.toNode, this.forward, this.cost);
}

class RoadGraph {
  final String graphVersion;
  final String profile;
  final GeoBounds bounds;
  final Float64List _nodeLat;
  final Float64List _nodeLon;
  final List<RoadEdge> edges;
  final List<List<Arc>> adjacency;

  /// Number of distinct edges touching each node (used to suppress turn
  /// instructions where a path merely bends without a junction).
  final Int32List degree;
  late final SegmentGridIndex index = SegmentGridIndex.build(this);

  RoadGraph._(this.graphVersion, this.profile, this.bounds, this._nodeLat,
      this._nodeLon, this.edges, this.adjacency, this.degree);

  int get nodeCount => _nodeLat.length;
  GeoPoint node(int i) => GeoPoint(_nodeLat[i], _nodeLon[i]);

  /// Parses the bundle format produced by tools/pipeline/build_bundle.py:
  /// {
  ///   "schemaVersion": 1, "graphVersion": "...", "profile": "foot",
  ///   "bounds": {south, west, north, east},
  ///   "nodes": [lat0, lon0, lat1, lon1, ...],
  ///   "names": ["", "Front Street", ...], "classes": ["footway", ...],
  ///   "edges": [[from, to, lengthM, forwardOnly(0|1), classIdx, nameIdx,
  ///              [lat, lon, lat, lon, ...]  // intermediate vertices only
  ///             ], ...]
  /// }
  factory RoadGraph.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw GraphFormatException('Unsupported graph schemaVersion ${j['schemaVersion']}');
    }
    final flat = (j['nodes'] as List).cast<num>();
    if (flat.length.isOdd || flat.isEmpty) {
      throw GraphFormatException('nodes array malformed');
    }
    final n = flat.length ~/ 2;
    final lat = Float64List(n), lon = Float64List(n);
    for (var i = 0; i < n; i++) {
      lat[i] = flat[2 * i].toDouble();
      lon[i] = flat[2 * i + 1].toDouble();
      if (!GeoPoint(lat[i], lon[i]).isValid) {
        throw GraphFormatException('invalid coordinate at node $i');
      }
    }
    final names = (j['names'] as List).cast<String>();
    final classes = (j['classes'] as List).cast<String>();
    final rawEdges = j['edges'] as List;
    final edges = <RoadEdge>[];
    final adj = List<List<Arc>>.generate(n, (_) => <Arc>[]);
    final degree = Int32List(n);
    for (var e = 0; e < rawEdges.length; e++) {
      final r = rawEdges[e] as List;
      final from = (r[0] as num).toInt(), to = (r[1] as num).toInt();
      if (from < 0 || from >= n || to < 0 || to >= n) {
        throw GraphFormatException('edge $e references missing node');
      }
      final declared = (r[2] as num).toDouble();
      final fwdOnly = (r[3] as num).toInt() == 1;
      final cls = classes[(r[4] as num).toInt()];
      final name = names[(r[5] as num).toInt()];
      final mid = (r[6] as List).cast<num>();
      final geom = <GeoPoint>[GeoPoint(lat[from], lon[from])];
      for (var k = 0; k + 1 < mid.length; k += 2) {
        geom.add(GeoPoint(mid[k].toDouble(), mid[k + 1].toDouble()));
      }
      geom.add(GeoPoint(lat[to], lon[to]));
      final cum = Float64List(geom.length);
      for (var k = 1; k < geom.length; k++) {
        cum[k] = cum[k - 1] + haversineM(geom[k - 1], geom[k]);
      }
      final len = cum[geom.length - 1];
      if (!len.isFinite || len <= 0) {
        throw GraphFormatException('edge $e has non-positive length');
      }
      // Declared length must agree with geometry (guards against corruption).
      if ((len - declared).abs() > math.max(0.5, declared * 0.01)) {
        throw GraphFormatException(
            'edge $e length mismatch: declared $declared, geometry $len');
      }
      edges.add(RoadEdge(
        id: e,
        from: from,
        to: to,
        forwardOnly: fwdOnly,
        roadClass: cls,
        name: name,
        geometry: geom,
        cumulative: cum,
      ));
      degree[from]++;
      degree[to]++;
      adj[from].add(Arc(e, to, true, len));
      if (!fwdOnly) adj[to].add(Arc(e, from, false, len));
    }
    return RoadGraph._(
      j['graphVersion'] as String,
      j['profile'] as String,
      GeoBounds.fromJson((j['bounds'] as Map).cast<String, dynamic>()),
      lat,
      lon,
      edges,
      adj,
      degree,
    );
  }
}

/// Where a coordinate lands on the network.
class EdgeSnap {
  final int edgeId;
  final GeoPoint point;

  /// Metres from the edge's `from` node along its geometry.
  final double offsetM;

  /// Distance from the query coordinate to [point].
  final double distanceM;
  const EdgeSnap(this.edgeId, this.point, this.offsetM, this.distanceM);
}

/// Uniform grid over edge segments for nearest-segment lookup (TDD 2.2
/// "R-tree/grid index for edge snapping"). Snapping is to the closest point on
/// a segment, not to the nearest vertex, so routes never detour via an
/// unrelated endpoint node.
class SegmentGridIndex {
  static const double cellDeg = 0.0005; // ~55 m
  final RoadGraph _g;
  final Map<int, List<int>> _cells; // key -> packed (edgeId << 12 | segIdx)

  SegmentGridIndex._(this._g, this._cells);

  static int _key(int cx, int cy) => cx * 1000003 + cy;

  factory SegmentGridIndex.build(RoadGraph g) {
    final cells = <int, List<int>>{};
    for (final e in g.edges) {
      if (e.geometry.length - 1 >= 4096) {
        throw GraphFormatException('edge ${e.id} has too many vertices');
      }
      for (var s = 0; s + 1 < e.geometry.length; s++) {
        final a = e.geometry[s], b = e.geometry[s + 1];
        final x0 = (math.min(a.lon, b.lon) / cellDeg).floor();
        final x1 = (math.max(a.lon, b.lon) / cellDeg).floor();
        final y0 = (math.min(a.lat, b.lat) / cellDeg).floor();
        final y1 = (math.max(a.lat, b.lat) / cellDeg).floor();
        for (var x = x0; x <= x1; x++) {
          for (var y = y0; y <= y1; y++) {
            (cells[_key(x, y)] ??= <int>[]).add((e.id << 12) | s);
          }
        }
      }
    }
    return SegmentGridIndex._(g, cells);
  }

  /// Nearest point on any permitted edge within [maxDistanceM], or null.
  EdgeSnap? nearest(GeoPoint p, double maxDistanceM) {
    final dLat = metersToLatDeg(maxDistanceM);
    final dLon = metersToLonDeg(maxDistanceM, p.lat);
    final x0 = ((p.lon - dLon) / cellDeg).floor();
    final x1 = ((p.lon + dLon) / cellDeg).floor();
    final y0 = ((p.lat - dLat) / cellDeg).floor();
    final y1 = ((p.lat + dLat) / cellDeg).floor();
    EdgeSnap? best;
    final seen = <int>{};
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        final list = _cells[_key(x, y)];
        if (list == null) continue;
        for (final packed in list) {
          if (!seen.add(packed)) continue;
          final e = _g.edges[packed >> 12];
          final s = packed & 0xFFF;
          final a = e.geometry[s], b = e.geometry[s + 1];
          final pr = projectOntoSegment(p, a, b);
          if (pr.distanceM > maxDistanceM) continue;
          if (best == null || pr.distanceM < best.distanceM) {
            final off = e.cumulative[s] + haversineM(a, pr.point);
            best = EdgeSnap(e.id, pr.point, math.min(off, e.lengthM), pr.distanceM);
          }
        }
      }
    }
    return best;
  }
}
