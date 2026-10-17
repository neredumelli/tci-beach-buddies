// Shortest-distance route planner (TDD 4.1). Pure Dart.
//
// * Edge cost = physical length in metres (shortest, not fastest).
// * A* with an admissible great-circle heuristic; Dijkstra (heuristic = 0) is
//   the correctness oracle used by tests.
// * Origin and destination are snapped to the closest point ON an edge and
//   joined to the graph through virtual split-edge connectors, so a route
//   never detours via an unrelated endpoint vertex.
// * No straight-line fallback exists anywhere in this file.
import 'dart:typed_data';

import '../../../core/geo/geo.dart';
import 'road_graph.dart';
import 'route_models.dart';

class PlannerConfig {
  /// Max distance from the GPS fix to the nearest permitted path.
  final double maxOriginSnapM;

  /// Max distance from a POI approach point to the network.
  final double maxDestinationSnapM;
  const PlannerConfig({this.maxOriginSnapM = 250, this.maxDestinationSnapM = 40});
}

class RoutePlanner {
  final RoadGraph graph;
  final PlannerConfig config;
  final bool useHeuristic;

  /// Statistics from the most recent search (for tests/diagnostics).
  int lastSettledCount = 0;

  RoutePlanner(this.graph, {this.config = const PlannerConfig(), this.useHeuristic = true});

  /// Dijkstra oracle with identical semantics.
  RoutePlanner asDijkstra() => RoutePlanner(graph, config: config, useHeuristic: false);

  RouteOutcome calculate(RouteRequest req) {
    if (!req.origin.isValid || !graph.bounds.contains(req.origin)) {
      return const RouteFailure(RouteFailureCode.outsideCoverage);
    }
    if (req.graphVersion != graph.graphVersion) {
      return RouteFailure(RouteFailureCode.bundleInvalid,
          'graph ${graph.graphVersion} != requested ${req.graphVersion}');
    }
    final o = graph.index.nearest(req.origin, config.maxOriginSnapM);
    if (o == null) return const RouteFailure(RouteFailureCode.noRoadSnap);
    final d = graph.index.nearest(req.destinationApproach, config.maxDestinationSnapM);
    if (d == null) {
      return const RouteFailure(RouteFailureCode.accessRestricted,
          'destination approach point is not on the path network');
    }
    final path = _search(o, d);
    if (path == null) return const RouteFailure(RouteFailureCode.noRoute);
    return RouteSuccess(_buildRoute(req, o, d, path));
  }

  // ---------------------------------------------------------------- search --

  /// Returns the sequence of traversal steps from virtual O to virtual D.
  List<_Step>? _search(EdgeSnap o, EdgeSnap d) {
    final n = graph.nodeCount;
    final vO = n, vD = n + 1;
    final g = Float64List(n + 2)..fillRange(0, n + 2, double.infinity);
    final closed = Uint8List(n + 2);
    final prevNode = Int32List(n + 2)..fillRange(0, n + 2, -1);
    final prevEdge = Int32List(n + 2)..fillRange(0, n + 2, -1);
    final prevFwd = Uint8List(n + 2);
    final destPt = d.point;
    final dEdge = graph.edges[d.edgeId];
    final oEdge = graph.edges[o.edgeId];

    double h(int v) {
      if (!useHeuristic || v == vD) return 0;
      final p = v == vO ? o.point : graph.node(v);
      return haversineM(p, destPt) * 0.999; // strictly admissible
    }

    final heap = _MinHeap();
    void relax(int from, int to, double cost, int edgeId, bool fwd) {
      if (closed[to] == 1) return;
      final ng = g[from] + cost;
      if (ng < g[to]) {
        g[to] = ng;
        prevNode[to] = from;
        prevEdge[to] = edgeId;
        prevFwd[to] = fwd ? 1 : 0;
        heap.push(ng + h(to), to);
      }
    }

    g[vO] = 0;
    heap.push(h(vO), vO);
    var settled = 0;
    while (heap.isNotEmpty) {
      final u = heap.pop();
      if (closed[u] == 1) continue;
      closed[u] = 1;
      settled++;
      if (u == vD) break;
      if (u == vO) {
        // Virtual connectors from the snapped origin.
        relax(vO, oEdge.to, oEdge.lengthM - o.offsetM, oEdge.id, true);
        if (!oEdge.forwardOnly) relax(vO, oEdge.from, o.offsetM, oEdge.id, false);
        if (o.edgeId == d.edgeId) {
          if (d.offsetM >= o.offsetM) {
            relax(vO, vD, d.offsetM - o.offsetM, oEdge.id, true);
          } else if (!oEdge.forwardOnly) {
            relax(vO, vD, o.offsetM - d.offsetM, oEdge.id, false);
          }
        }
        continue;
      }
      for (final arc in graph.adjacency[u]) {
        relax(u, arc.toNode, arc.cost, arc.edgeId, arc.forward);
      }
      // Virtual connectors into the snapped destination.
      if (u == dEdge.from) relax(u, vD, d.offsetM, dEdge.id, true);
      if (u == dEdge.to && !dEdge.forwardOnly) {
        relax(u, vD, dEdge.lengthM - d.offsetM, dEdge.id, false);
      }
    }
    lastSettledCount = settled;
    if (closed[vD] != 1) return null;

    final steps = <_Step>[];
    var cur = vD;
    while (cur != vO) {
      final p = prevNode[cur];
      if (p < 0) return null; // defensive: broken chain
      steps.add(_Step(p, cur, prevEdge[cur], prevFwd[cur] == 1));
      cur = p;
    }
    return steps.reversed.toList();
  }

  // ------------------------------------------------------------- geometry --

  PlannedRoute _buildRoute(RouteRequest req, EdgeSnap o, EdgeSnap d, List<_Step> steps) {
    final n = graph.nodeCount;
    final vO = n, vD = n + 1;
    final pts = <GeoPoint>[];
    final legStartIdx = <int>[]; // index in pts where each step starts
    final legEdges = <int>[];
    final edgeIds = <int>[];

    void append(List<GeoPoint> seg) {
      for (final p in seg) {
        if (pts.isEmpty || pts.last != p) pts.add(p);
      }
    }

    for (final s in steps) {
      final e = graph.edges[s.edgeId];
      List<GeoPoint> seg;
      if (s.from == vO && s.to == vD) {
        seg = e.slice(o.offsetM, d.offsetM);
      } else if (s.from == vO) {
        seg = s.forward ? e.slice(o.offsetM, e.lengthM) : e.slice(o.offsetM, 0);
      } else if (s.to == vD) {
        seg = s.forward ? e.slice(0, d.offsetM) : e.slice(e.lengthM, d.offsetM);
      } else {
        seg = s.forward ? e.geometry : e.geometry.reversed.toList();
      }
      legStartIdx.add(pts.isEmpty ? 0 : pts.length - 1);
      legEdges.add(e.id);
      if (edgeIds.isEmpty || edgeIds.last != e.id) edgeIds.add(e.id);
      append(seg);
    }
    if (pts.isEmpty) append([o.point]);
    if (pts.length == 1) pts.add(pts.first); // zero-length route (already there)

    final cum = Float64List(pts.length);
    for (var i = 1; i < pts.length; i++) {
      cum[i] = cum[i - 1] + haversineM(pts[i - 1], pts[i]);
    }

    final maneuvers = _maneuvers(steps, pts, cum, legStartIdx, vO, vD);
    return PlannedRoute(
      requestId: req.requestId,
      destinationPoiId: req.destinationPoiId,
      originFix: req.origin,
      originFixTime: req.originFixTime,
      snappedOrigin: o.point,
      originSnapDistanceM: o.distanceM,
      endpoint: d.point,
      polyline: pts,
      cumulative: cum,
      edgeIds: edgeIds,
      maneuvers: maneuvers,
    );
  }

  List<Maneuver> _maneuvers(List<_Step> steps, List<GeoPoint> pts, Float64List cum,
      List<int> legStart, int vO, int vD) {
    final out = <Maneuver>[
      Maneuver(ManeuverType.depart, 0, graph.edges[steps.first.edgeId].name, pts.first),
    ];
    for (var k = 1; k < steps.length; k++) {
      final node = steps[k].from; // junction between step k-1 and k
      if (node >= graph.nodeCount) continue;
      if (graph.degree[node] < 3) continue; // a bend, not a decision point
      final idx = legStart[k];
      final at = cum[idx];
      final before = pointAlong(pts, cum, at - 12);
      final after = pointAlong(pts, cum, at + 12);
      final junction = pts[idx];
      if (haversineM(before, junction) < 1 || haversineM(junction, after) < 1) continue;
      final turn = turnAngleDeg(bearingDeg(before, junction), bearingDeg(junction, after));
      final type = _classify(turn);
      if (type == null) continue;
      out.add(Maneuver(type, at, graph.edges[steps[k].edgeId].name, junction));
    }
    out.add(Maneuver(ManeuverType.arrive, cum[cum.length - 1], '', pts.last));
    return out;
  }

  static ManeuverType? _classify(double turn) {
    final a = turn.abs();
    if (a < 30) return null;
    if (a >= 165) return ManeuverType.uTurn;
    if (turn > 0) {
      return a < 60 ? ManeuverType.slightRight : (a < 135 ? ManeuverType.right : ManeuverType.sharpRight);
    }
    return a < 60 ? ManeuverType.slightLeft : (a < 135 ? ManeuverType.left : ManeuverType.sharpLeft);
  }
}

/// Point at along-distance [s] on a polyline with cumulative distances.
GeoPoint pointAlong(List<GeoPoint> pts, List<double> cum, double s) {
  if (s <= 0) return pts.first;
  final total = cum[cum.length - 1];
  if (s >= total) return pts.last;
  var lo = 0, hi = cum.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (cum[mid] <= s) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final seg = cum[hi] - cum[lo];
  return interpolate(pts[lo], pts[hi], seg <= 0 ? 0 : (s - cum[lo]) / seg);
}

class _Step {
  final int from, to, edgeId;
  final bool forward;
  const _Step(this.from, this.to, this.edgeId, this.forward);
}

/// Binary min-heap keyed by priority.
class _MinHeap {
  final List<double> _p = [];
  final List<int> _v = [];
  bool get isNotEmpty => _v.isNotEmpty;

  void push(double priority, int value) {
    _p.add(priority);
    _v.add(value);
    var i = _v.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_p[parent] <= _p[i]) break;
      _swap(i, parent);
      i = parent;
    }
  }

  int pop() {
    final top = _v[0];
    final lastP = _p.removeLast();
    final lastV = _v.removeLast();
    if (_v.isNotEmpty) {
      _p[0] = lastP;
      _v[0] = lastV;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _v.length && _p[l] < _p[m]) m = l;
        if (r < _v.length && _p[r] < _p[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final tp = _p[a];
    _p[a] = _p[b];
    _p[b] = tp;
    final tv = _v[a];
    _v[a] = _v[b];
    _v[b] = tv;
  }
}
