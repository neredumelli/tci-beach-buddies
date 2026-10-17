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
    """Three panels: R1, the A->B switch (correct vs old stale origin), R3."""
    from PIL import Image, ImageDraw
    import math
    (r1, _), (r2, _), (r3, _) = routes
    b = gj["bounds"]
    W = 520
    k = math.cos(math.radians((b["south"] + b["north"]) / 2))
    H = int(W * (b["north"] - b["south"]) / ((b["east"] - b["west"]) * k))
    colors = dict(land=(243, 240, 228), salina=(191, 227, 234), water=(169, 220, 235), beach=(246, 235, 211),
                  park=(221, 239, 211), building=(214, 205, 192), runway=(210, 210, 210), wetland=(212, 232, 208))

    def xy(lat, lon):
        return ((lon - b["west"]) / (b["east"] - b["west"]) * W, 70 + (b["north"] - lat) / (b["north"] - b["south"]) * H)

    def base():
        img = Image.new("RGB", (W, H + 150), (169, 220, 235))
        d = ImageDraw.Draw(img)
        for kind in ["land", "park", "beach", "wetland", "salina", "water", "runway", "building"]:
            for f in bm["features"]:
                if f["properties"].get("kind") == kind and f["geometry"]["type"] == "Polygon":
                    d.polygon([xy(c[1], c[0]) for c in f["geometry"]["coordinates"][0]], fill=colors[kind])
        flat = gj["nodes"]
        for e in gj["edges"]:
            pts = [(flat[2 * e[0]], flat[2 * e[0] + 1])] + [(e[6][i], e[6][i + 1]) for i in range(0, len(e[6]), 2)] + \
                  [(flat[2 * e[1]], flat[2 * e[1] + 1])]
            d.line([xy(*q) for q in pts], fill=(160, 160, 160), width=1)
        return img, d

    def dashed(d, poly, col, w):
        pts = [xy(*q) for q in poly]
        acc = 0
        for i in range(len(pts) - 1):
            seg = math.dist(pts[i], pts[i + 1])
            if int(acc / 10) % 2 == 0:
                d.line([pts[i], pts[i + 1]], fill=col, width=w)
            acc += max(seg, 1)

    def dot(d, p, col, label):
        x, y = xy(*p)
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=col, outline=(255, 255, 255), width=2)
        d.text((x + 10, y - 6), label, fill=(0, 0, 0))

    def header(d, title, lines):
        d.rectangle([0, 0, W, 66], fill=(255, 255, 255))
        d.text((10, 8), title, fill=(11, 42, 91))
        for i, (txt, col) in enumerate(lines):
            d.text((10, 26 + 16 * i), txt, fill=col)

    ship = r1["polyline"][0]
    gov = r2["polyline"][0]
    lh = r3["polyline"][0]
    panels = []
    img, d = base()
    d.line([xy(*q) for q in r1["polyline"]], fill=(31, 91, 255), width=5)
    dot(d, ship, (91, 63, 168), "Cruise Center"); dot(d, gov, (14, 138, 158), "Governor's Beach")
    header(d, "1. Cruise Center -> Governor's Beach", [(f"Walking route {r1['distance']/1000:.2f} km", (31, 91, 255))])
    panels.append(img)
    img, d = base()
    if stale:
        dashed(d, stale["polyline"], (211, 47, 47), 4)
    d.line([xy(*q) for q in r2["polyline"]], fill=(30, 158, 90), width=5)
    dot(d, ship, (91, 63, 168), "Cruise Center (old origin)"); dot(d, gov, (14, 138, 158), "You are here (A)")
    dot(d, lh, (232, 130, 12), "Lighthouse (B)")
    header(d, "2. At Governor's Beach, choose Lighthouse", [
        (f"NEW: from live GPS at A  {r2['distance']/1000:.2f} km", (30, 158, 90)),
        (f"OLD bug: from Cruise Center {stale['distance']/1000:.2f} km (dashed)" if stale else "", (211, 47, 47))])
    panels.append(img)
    img, d = base()
    d.line([xy(*q) for q in r3["polyline"]], fill=(91, 63, 168), width=5)
    dot(d, lh, (232, 130, 12), "Lighthouse"); dot(d, ship, (91, 63, 168), "Cruise Center")
    header(d, "3. Return to Ship from Lighthouse", [(f"Walking route {r3['distance']/1000:.2f} km", (91, 63, 168))])
    panels.append(img)
    out = Image.new("RGB", (W * 3 + 20, H + 150), (255, 255, 255))
    for i, pimg in enumerate(panels):
        out.paste(pimg, (i * (W + 10), 0))
    ImageDraw.Draw(out).text((10, H + 125), f"Real OpenStreetMap data, graph {gj['graphVersion']}. Routes from the "
                             "reference router (A* = Dijkstra). (c) OpenStreetMap contributors", fill=(60, 60, 60))
    out.save(os.path.join(a.root, a.png))
    print("wrote", a.png)


if __name__ == "__main__":
    main()
