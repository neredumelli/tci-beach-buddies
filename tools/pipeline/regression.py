#!/usr/bin/env python3
"""Mandatory route regression (TDD 11.1 / SDD 12.1) on the BUILT bundle.

    python3 tools/pipeline/regression.py [--root .] [--png build/route_regression.png]

* Runs Cruise Center -> Governor's Beach -> Grand Turk Lighthouse -> Ship with
  the reference router (A* and Dijkstra must agree).
* Proves destination switching: the route to B starts at the live position
  near A, and compares it with the STALE-ORIGIN behaviour of the old build.
* Checks every routable POI both ways from the ship, every polyline vertex
  over land, and the offshore cay is NoRoute.
* Writes test/fixtures/regression_routes.json which the Dart tests replay
  against the app's own RoutePlanner.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_bundle import point_in_ring  # noqa: E402
from reference_router import Graph, haversine, route  # noqa: E402


def load(root, rel):
    with open(os.path.join(root, rel), encoding="utf-8") as f:
        return json.load(f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--png", default="build/route_regression.png")
    a = ap.parse_args()
    gj = load(a.root, "assets/graph/graph.json")
    pois = {p["id"]: p for p in load(a.root, "assets/pois/pois.json")["pois"]}
    bm = load(a.root, "assets/map/basemap.geojson")
    land = [f["geometry"]["coordinates"][0] for f in bm["features"] if f["properties"].get("kind") == "land"]
    g = Graph(gj)
    results, failures, vectors = [], [], []

    def ll(p):
        return (p[1], p[0])

    def check(name, origin, dest_id, must_start_near=None, avoid=None, expect_failure=None):
        dest = pois[dest_id]
        if expect_failure:
            ok = not dest["routable"]
            results.append(dict(name=name, ok=ok, detail="browse-only: " + str(dest["notRoutableReason"])))
            if not ok:
                failures.append(name)
            vectors.append(dict(name=name, origin=list(origin), destPoiId=dest_id, expectRoutable=False))
            return None
        A = route(g, origin, ll(dest["approach"]))
        D = route(g, origin, ll(dest["approach"]), use_heuristic=False)
        notes = []
        ok = "failure" not in A and "failure" not in D
        if ok:
            if abs(A["cost"] - D["cost"]) > 1e-6:
                ok = False
                notes.append("A* != Dijkstra")
            if must_start_near and haversine(A["polyline"][0], must_start_near) > 260:
                ok = False
                notes.append("route does not start at live position")
            if avoid:
                dmin = min(haversine(p, avoid[0]) for p in A["polyline"])
                notes.append(f"closest approach to {avoid[2]}: {dmin:.0f} m")
                if dmin < avoid[1]:
                    ok = False
                    notes.append("passes the stale origin")
            if land:
                off = sum(1 for p in A["polyline"] if not any(point_in_ring(p, r) for r in land))
                if off:
                    notes.append(f"{off} vertices outside land polygon (check coastline)")
        else:
            notes.append(A.get("failure", "") + "/" + D.get("failure", ""))
        results.append(dict(name=name, ok=ok, distance_m=None if not ok else round(A["distance"], 1),
                            settled_astar=A.get("settled"), settled_dijkstra=D.get("settled"),
                            origin_snap_m=None if not ok else round(A["origin_snap"], 1), detail="; ".join(notes)))
        if not ok:
            failures.append(name)
        else:
            vectors.append(dict(name=name, origin=list(origin), destPoiId=dest_id, expectRoutable=True,
                                expectedDistanceM=round(A["distance"], 3),
                                expectedSnappedOrigin=list(A["snapped_origin"])))
        return A

    ship = ll(pois["grand-turk-cruise-center"]["approach"])
    gov = ll(pois["governors-beach"]["approach"])
    lh = ll(pois["grand-turk-lighthouse"]["approach"])
    r1 = check("R1 Cruise Center -> Governor's Beach", ship, "governors-beach", must_start_near=ship)
    r2 = check("R2 Governor's Beach -> Lighthouse (live fix at Governor's)", gov, "grand-turk-lighthouse",
               must_start_near=gov)
    r3 = check("R3 Lighthouse -> Return to Ship", lh, "grand-turk-cruise-center", must_start_near=lh)

    # The old defect: B routed from the original (cruise) origin, or via A.
    stale = route(g, ship, lh)
    via_a = (r1["distance"] + r2["distance"]) if r1 and r2 else None
    # Nearby A->B switch: nearest routable POI to Governor's Beach.
    near = sorted((p for p in pois.values() if p["routable"] and p["id"] not in ("governors-beach", "grand-turk-cruise-center")),
                  key=lambda p: haversine(gov, ll(p["approach"])))
    nearby_cmp = None
    if near:
        b = near[0]
        rb = check(f"R4 Governor's Beach -> nearby {b['name']} (live fix at A)", gov, b["id"], must_start_near=gov,
                   avoid=(ship, 150, "Cruise Center") if haversine(gov, ship) > 400 else None)
        sb = route(g, ship, ll(b["approach"]))
        if rb and "failure" not in sb:
            nearby_cmp = dict(destination=b["name"], correct_m=round(rb["distance"]), stale_origin_m=round(sb["distance"]),
                              via_cruise_center_m=round(route(g, gov, ship)["distance"] + sb["distance"]))
    for pid in ("gibbs-cay",):
        if pid in pois and not pois[pid]["routable"]:
            check(f"R5 {pois[pid]['name']} is browse-only (no route over water)", ship, pid, expect_failure=True)
    # All routable POIs both ways.
    matrix = []
    for p in pois.values():
        if not p["routable"] or p["isShipTerminal"]:
            continue
        t, f = route(g, ship, ll(p["approach"])), route(g, ll(p["approach"]), ship)
        okp = "failure" not in t and "failure" not in f
        matrix.append(dict(id=p["id"], to_m=round(t.get("distance", -1)), back_m=round(f.get("distance", -1)), ok=okp))
        if not okp:
            failures.append("matrix " + p["id"])
    summary = dict(results=results, stale_origin_lighthouse_m=None if "failure" in stale else round(stale["distance"]),
                   correct_lighthouse_from_governors_m=None if not r2 else round(r2["distance"]),
                   via_a_m=None if via_a is None else round(via_a), nearby_switch=nearby_cmp, matrix=matrix,
                   failures=failures, graphVersion=gj["graphVersion"])
    os.makedirs(os.path.join(a.root, "build"), exist_ok=True)
    with open(os.path.join(a.root, "build/route_regression.json"), "w") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    os.makedirs(os.path.join(a.root, "test/fixtures"), exist_ok=True)
    with open(os.path.join(a.root, "test/fixtures/regression_routes.json"), "w") as f:
        json.dump(dict(graphVersion=gj["graphVersion"], vectors=vectors), f, indent=2)
    for r in results:
        print(("PASS " if r["ok"] else "FAIL ") + r["name"], r.get("distance_m"), r["detail"])
    print("nearby switch:", nearby_cmp)
    print("matrix:", sum(m["ok"] for m in matrix), "/", len(matrix), "POIs reachable both ways")
    try:
        render_png(a, gj, pois, bm, [(r1, (31, 91, 255)), (r2, (232, 130, 12)), (r3, (91, 63, 168))],
                   None if "failure" in stale else stale)
    except ImportError:
        print("Pillow not installed; skipping PNG")
    sys.exit(1 if failures else 0)


def render_png(a, gj, pois, bm, routes, stale):
    from PIL import Image, ImageDraw
    b = gj["bounds"]
    W = 900
    import math
    k = math.cos(math.radians((b["south"] + b["north"]) / 2))
    H = int(W * (b["north"] - b["south"]) / ((b["east"] - b["west"]) * k))
    img = Image.new("RGB", (W, H), (169, 220, 235))
    d = ImageDraw.Draw(img)

    def xy(lat, lon):
        return ((lon - b["west"]) / (b["east"] - b["west"]) * W, (b["north"] - lat) / (b["north"] - b["south"]) * H)

    colors = dict(land=(243, 240, 228), salina=(191, 227, 234), water=(169, 220, 235), beach=(246, 235, 211),
                  park=(221, 239, 211), building=(214, 205, 192), runway=(210, 210, 210), wetland=(212, 232, 208))
    order = ["land", "park", "beach", "wetland", "salina", "water", "runway", "building"]
    for kind in order:
        for f in bm["features"]:
            if f["properties"].get("kind") == kind and f["geometry"]["type"] == "Polygon":
                d.polygon([xy(c[1], c[0]) for c in f["geometry"]["coordinates"][0]], fill=colors[kind])
    flat = gj["nodes"]
    for e in gj["edges"]:
        pts = [(flat[2 * e[0]], flat[2 * e[0] + 1])] + [(e[6][i], e[6][i + 1]) for i in range(0, len(e[6]), 2)] + \
              [(flat[2 * e[1]], flat[2 * e[1] + 1])]
        d.line([xy(*p) for p in pts], fill=(150, 150, 150), width=1)
    if stale:
        pts = [xy(*p) for p in stale["polyline"]]
        for i in range(0, len(pts) - 1, 2):
            d.line([pts[i], pts[i + 1]], fill=(211, 47, 47), width=2)
    for r, col in routes:
        if r:
            d.line([xy(*p) for p in r["polyline"]], fill=col, width=4)
    for p in pois.values():
        x, y = xy(p["display"][1], p["display"][0])
        col = (91, 63, 168) if p["isShipTerminal"] else ((14, 138, 158) if p["routable"] else (120, 120, 120))
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=col, outline=(255, 255, 255))
    d.rectangle([8, 8, 370, 92], fill=(255, 255, 255))
    d.text((14, 12), "Route regression (reference router, real bundle)", fill=(0, 0, 0))
    d.text((14, 30), "blue: R1 Cruise -> Governor's Beach", fill=(31, 91, 255))
    d.text((14, 46), "orange: R2 Governor's -> Lighthouse (from live fix)", fill=(232, 130, 12))
    d.text((14, 62), "purple: R3 Lighthouse -> Ship", fill=(91, 63, 168))
    d.text((14, 78), "red dashed: OLD stale-origin route Cruise -> Lighthouse", fill=(211, 47, 47))
    img.save(os.path.join(a.root, a.png))
    print("wrote", a.png)


if __name__ == "__main__":
    main()
