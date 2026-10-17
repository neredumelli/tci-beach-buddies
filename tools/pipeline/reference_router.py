"""Reference implementation of the app's routing semantics (Python, stdlib only).

Mirrors lib/features/navigation/domain/{road_graph,route_planner}.dart:
  * same haversine radius, same equirectangular segment projection,
  * snap to the closest point ON an edge (not the nearest vertex),
  * virtual origin/destination nodes joined by split-edge connectors,
  * A* with 0.999 x great-circle heuristic, Dijkstra as oracle.

It is used by the data pipeline to prove every routable POI is reachable and to
produce the route regression vectors that the Dart tests re-check
(test/fixtures/regression_routes.json).
"""
import heapq
import math

EARTH_R = 6371008.8


def haversine(a, b):
    """a, b = (lat, lon) degrees -> metres."""
    dlat = math.radians(b[0] - a[0])
    dlon = math.radians(b[1] - a[1])
    s = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(a[0])) * math.cos(math.radians(b[0])) * math.sin(dlon / 2) ** 2)
    return 2 * EARTH_R * math.asin(min(1.0, math.sqrt(s)))


def project(p, a, b):
    """Project p onto segment a-b (local equirectangular). Returns (t, point, dist)."""
    c = math.cos(math.radians(p[0]))
    ax, ay, bx, by, px, py = a[1] * c, a[0], b[1] * c, b[0], p[1] * c, p[0]
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else ((px - ax) * dx + (py - ay) * dy) / l2
    t = max(0.0, min(1.0, t))
    q = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
    return t, q, haversine(p, q)


class Graph:
    CELL = 0.0005

    def __init__(self, gj):
        flat = gj["nodes"]
        self.nodes = [(flat[2 * i], flat[2 * i + 1]) for i in range(len(flat) // 2)]
        self.version = gj["graphVersion"]
        self.edges = []  # dict(from,to,fwd_only,name,geom,cum)
        self.adj = [[] for _ in self.nodes]
        self.degree = [0] * len(self.nodes)
        names = gj["names"]
        for eid, r in enumerate(gj["edges"]):
            u, v, declared, fo, _cls, ni, mid = r
            geom = [self.nodes[u]] + [(mid[k], mid[k + 1]) for k in range(0, len(mid) - 1, 2)] + [self.nodes[v]]
            cum = [0.0]
            for k in range(1, len(geom)):
                cum.append(cum[-1] + haversine(geom[k - 1], geom[k]))
            L = cum[-1]
            assert L > 0 and abs(L - declared) <= max(0.5, declared * 0.01), (eid, L, declared)
            self.edges.append(dict(id=eid, u=u, v=v, fo=bool(fo), name=names[ni], geom=geom, cum=cum, L=L))
            self.adj[u].append((eid, v, True, L))
            if not fo:
                self.adj[v].append((eid, u, False, L))
            self.degree[u] += 1
            self.degree[v] += 1
        self.cells = {}
        for e in self.edges:
            g = e["geom"]
            for s in range(len(g) - 1):
                a, b = g[s], g[s + 1]
                for x in range(math.floor(min(a[1], b[1]) / self.CELL), math.floor(max(a[1], b[1]) / self.CELL) + 1):
                    for y in range(math.floor(min(a[0], b[0]) / self.CELL), math.floor(max(a[0], b[0]) / self.CELL) + 1):
                        self.cells.setdefault((x, y), []).append((e["id"], s))

    def nearest(self, p, max_d):
        dlat = max_d / 111320.0
        dlon = max_d / (111320.0 * math.cos(math.radians(p[0])))
        best = None
        seen = set()
        for x in range(math.floor((p[1] - dlon) / self.CELL), math.floor((p[1] + dlon) / self.CELL) + 1):
            for y in range(math.floor((p[0] - dlat) / self.CELL), math.floor((p[0] + dlat) / self.CELL) + 1):
                for key in self.cells.get((x, y), ()):
                    if key in seen:
                        continue
                    seen.add(key)
                    eid, s = key
                    e = self.edges[eid]
                    a, b = e["geom"][s], e["geom"][s + 1]
                    _t, q, d = project(p, a, b)
                    if d > max_d:
                        continue
                    if best is None or d < best["dist"]:
                        off = min(e["cum"][s] + haversine(a, q), e["L"])
                        best = dict(edge=eid, point=q, off=off, dist=d)
        return best

    def point_at(self, e, off):
        if off <= 0:
            return e["geom"][0]
        if off >= e["L"]:
            return e["geom"][-1]
        cum = e["cum"]
        i = 1
        while i < len(cum) and cum[i] < off:
            i += 1
        seg = cum[i] - cum[i - 1]
        t = 0 if seg <= 0 else (off - cum[i - 1]) / seg
        a, b = e["geom"][i - 1], e["geom"][i]
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

    def slice(self, e, a, b):
        lo, hi = min(a, b), max(a, b)
        pts = [self.point_at(e, lo)]
        for i, c in enumerate(e["cum"]):
            if lo < c < hi:
                pts.append(e["geom"][i])
        pts.append(self.point_at(e, hi))
        return pts if a <= b else pts[::-1]


def route(g, origin, dest, use_heuristic=True, max_origin_snap=250.0, max_dest_snap=40.0):
    """Returns dict(distance, polyline, edges, snapped_origin, origin_snap) or dict(failure=...)."""
    o = g.nearest(origin, max_origin_snap)
    if o is None:
        return dict(failure="noRoadSnap")
    d = g.nearest(dest, max_dest_snap)
    if d is None:
        return dict(failure="accessRestricted")
    n = len(g.nodes)
    VO, VD = n, n + 1
    oe, de = g.edges[o["edge"]], g.edges[d["edge"]]
    INF = float("inf")
    gs = {VO: 0.0}
    prev = {}
    closed = set()

    def h(v):
        if not use_heuristic or v == VD:
            return 0.0
        p = o["point"] if v == VO else g.nodes[v]
        return haversine(p, d["point"]) * 0.999

    heap = [(h(VO), VO)]

    def relax(frm, to, cost, eid, fwd):
        if to in closed:
            return
        ng = gs[frm] + cost
        if ng < gs.get(to, INF):
            gs[to] = ng
            prev[to] = (frm, eid, fwd)
            heapq.heappush(heap, (ng + h(to), to))

    settled = 0
    while heap:
        _, u = heapq.heappop(heap)
        if u in closed:
            continue
        closed.add(u)
        settled += 1
        if u == VD:
            break
        if u == VO:
            relax(VO, oe["v"], oe["L"] - o["off"], oe["id"], True)
            if not oe["fo"]:
                relax(VO, oe["u"], o["off"], oe["id"], False)
            if o["edge"] == d["edge"]:
                if d["off"] >= o["off"]:
                    relax(VO, VD, d["off"] - o["off"], oe["id"], True)
                elif not oe["fo"]:
                    relax(VO, VD, o["off"] - d["off"], oe["id"], False)
            continue
        for eid, to, fwd, cost in g.adj[u]:
            relax(u, to, cost, eid, fwd)
        if u == de["u"]:
            relax(u, VD, d["off"], de["id"], True)
        if u == de["v"] and not de["fo"]:
            relax(u, VD, de["L"] - d["off"], de["id"], False)
    if VD not in closed:
        return dict(failure="noRoute")
    steps = []
    cur = VD
    while cur != VO:
        frm, eid, fwd = prev[cur]
        steps.append((frm, cur, eid, fwd))
        cur = frm
    steps.reverse()
    pts = []
    edges = []
    for frm, to, eid, fwd in steps:
        e = g.edges[eid]
        if frm == VO and to == VD:
            seg = g.slice(e, o["off"], d["off"])
        elif frm == VO:
            seg = g.slice(e, o["off"], e["L"]) if fwd else g.slice(e, o["off"], 0)
        elif to == VD:
            seg = g.slice(e, 0, d["off"]) if fwd else g.slice(e, e["L"], d["off"])
        else:
            seg = e["geom"] if fwd else e["geom"][::-1]
        if not edges or edges[-1] != eid:
            edges.append(eid)
        for p in seg:
            if not pts or pts[-1] != p:
                pts.append(p)
    dist = sum(haversine(pts[i - 1], pts[i]) for i in range(1, len(pts)))
    return dict(distance=dist, cost=gs[VD], polyline=pts, edges=edges, snapped_origin=o["point"],
                origin_snap=o["dist"], endpoint=d["point"], settled=settled)
