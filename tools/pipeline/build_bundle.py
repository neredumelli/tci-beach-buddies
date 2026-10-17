#!/usr/bin/env python3
"""TCI Beach Buddies offline bundle builder (Python 3.10+, standard library only).

Licensed source -> Grand Turk extract -> walking profile filter -> split at
intersections -> directed edges + lengths -> connectivity audit -> POI
matching + approach-point validation -> basemap vectors -> manifest + SHA-256.

Usage (from the project root):
    python3 tools/pipeline/build_bundle.py --osm path/to/map.osm

Input: an OpenStreetMap XML extract covering ALL of Grand Turk, e.g. from
https://www.openstreetmap.org/export (bbox ~ 21.40..21.53 N, -71.17..-71.10 E).
Outputs (overwritten): assets/{graph,pois,map,manifest}/... and
build/data_report.{json,md}. Exit code is non-zero on any release-blocking issue.
"""
import argparse
import datetime as dt
import hashlib
import json
import math
import os
import re
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reference_router import Graph, haversine, route  # noqa: E402

GRAND_TURK = dict(south=21.40, west=-71.17, north=21.53, east=-71.10)

WALK_HIGHWAYS = {
    "trunk", "trunk_link", "primary", "primary_link", "secondary", "secondary_link",
    "tertiary", "tertiary_link", "unclassified", "residential", "living_street", "service",
    "pedestrian", "footway", "path", "track", "steps", "cycleway", "bridleway", "road", "corridor",
}
MAJOR = {"trunk", "trunk_link", "primary", "primary_link", "secondary", "secondary_link", "tertiary", "tertiary_link"}
MINOR = {"unclassified", "residential", "living_street", "service", "road", "pedestrian"}
PATHS = {"footway", "path", "steps", "cycleway", "bridleway", "corridor"}
FOOT_OK = {"yes", "designated", "permissive"}
MAX_POI_TO_NETWORK_M = 250.0


def r6(x):
    return round(x, 6)


# ----------------------------------------------------------------- parsing --
def parse_osm(path):
    nodes, ways, rels = {}, {}, {}
    meta = {}
    for ev, el in ET.iterparse(path, events=("end",)):
        tag = el.tag
        if tag == "node":
            t = {c.get("k"): c.get("v") for c in el.findall("tag")}
            nodes[int(el.get("id"))] = (float(el.get("lat")), float(el.get("lon")), t)
            el.clear()
        elif tag == "way":
            nds = [int(n.get("ref")) for n in el.findall("nd")]
            t = {c.get("k"): c.get("v") for c in el.findall("tag")}
            ways[int(el.get("id"))] = (nds, t)
            el.clear()
        elif tag == "relation":
            mem = [(m.get("type"), int(m.get("ref")), m.get("role")) for m in el.findall("member")]
            t = {c.get("k"): c.get("v") for c in el.findall("tag")}
            rels[int(el.get("id"))] = (mem, t)
            el.clear()
        elif tag == "meta":
            meta = dict(el.attrib)
        elif tag == "osm":
            meta.setdefault("generator", el.get("generator", ""))
    return nodes, ways, rels, meta


def walkable(t):
    hw = t.get("highway")
    if hw not in WALK_HIGHWAYS:
        return False
    if t.get("foot") in ("no", "private", "use_sidepath"):
        return False
    if t.get("access") in ("no", "private") and t.get("foot") not in FOOT_OK:
        return False
    if t.get("construction") or t.get("disused") == "yes":
        return False
    return True


def foot_oneway(t):
    v = t.get("oneway:foot")
    if v in ("yes", "1", "true"):
        return 1
    if v == "-1":
        return -1
    return 0


# ------------------------------------------------------------------- graph --
def build_graph(nodes, ways, report):
    wk = {wid: w for wid, w in ways.items() if walkable(w[1]) and len(w[0]) >= 2}
    wk = {wid: (nds, t) for wid, (nds, t) in wk.items() if all(n in nodes for n in nds)}
    use = {}
    for nds, _ in wk.values():
        for i, n in enumerate(nds):
            use[n] = use.get(n, 0) + (2 if i in (0, len(nds) - 1) else 1)
    raw_edges = []  # (node_ids list, tags, wid)
    for wid, (nds, t) in wk.items():
        start = 0
        for i in range(1, len(nds)):
            if i == len(nds) - 1 or use.get(nds[i], 0) >= 2:
                seg = nds[start:i + 1]
                if seg[0] == seg[-1] and len(seg) >= 3:  # loop: split in the middle
                    m = len(seg) // 2
                    raw_edges.append((seg[:m + 1], t, wid))
                    raw_edges.append((seg[m:], t, wid))
                elif len(seg) >= 2 and seg[0] != seg[-1]:
                    raw_edges.append((seg, t, wid))
                start = i
    # Connectivity audit (undirected) -> keep largest component.
    parent = {}

    def find(x):
        parent.setdefault(x, x)
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for seg, _, _ in raw_edges:
        a, b = find(seg[0]), find(seg[-1])
        if a != b:
            parent[a] = b
    comp_size = {}
    for seg, _, _ in raw_edges:
        r = find(seg[0])
        comp_size[r] = comp_size.get(r, 0) + 1
    if not comp_size:
        raise SystemExit("ERROR: no walkable ways found in the extract")
    main = max(comp_size, key=comp_size.get)
    kept = [e for e in raw_edges if find(e[0][0]) == main]
    report["graph"] = dict(
        walkable_ways=len(wk), raw_edges=len(raw_edges), components=len(comp_size),
        kept_edges=len(kept), dropped_edges=len(raw_edges) - len(kept),
        dropped_component_sizes=sorted([s for r, s in comp_size.items() if r != main], reverse=True)[:20],
    )
    node_index = {}
    flat = []

    def nid(osm_id):
        if osm_id not in node_index:
            node_index[osm_id] = len(node_index)
            la, lo, _ = nodes[osm_id]
            flat.extend([r6(la), r6(lo)])
        return node_index[osm_id]

    names, classes = [""], []
    name_ix, class_ix = {"": 0}, {}
    edges = []
    for seg, t, wid in kept:
        ow = foot_oneway(t)
        if ow == -1:
            seg = seg[::-1]
        u, v = nid(seg[0]), nid(seg[-1])
        pts = [(r6(nodes[n][0]), r6(nodes[n][1])) for n in seg]
        length = sum(haversine(pts[i - 1], pts[i]) for i in range(1, len(pts)))
        if length <= 0.05:
            continue
        nm = t.get("name") or t.get("ref") or ""
        if nm not in name_ix:
            name_ix[nm] = len(names)
            names.append(nm)
        cl = t["highway"]
        if cl not in class_ix:
            class_ix[cl] = len(classes)
            classes.append(cl)
        mid = []
        for p in pts[1:-1]:
            mid.extend(p)
        edges.append([u, v, round(length, 3), 1 if ow else 0, class_ix[cl], name_ix[nm], mid])
    lats, lons = flat[0::2], flat[1::2]
    bounds = dict(south=r6(min(lats) - 0.01), west=r6(min(lons) - 0.01),
                  north=r6(max(lats) + 0.01), east=r6(max(lons) + 0.01))
    body = json.dumps([flat, names, classes, edges], separators=(",", ":")).encode()
    gv = "foot-" + hashlib.sha256(body).hexdigest()[:10]
    total_km = sum(e[2] for e in edges) / 1000
    report["graph"].update(nodes=len(lats), edges=len(edges), total_km=round(total_km, 2), graphVersion=gv)
    return dict(schemaVersion=1, graphVersion=gv, profile="foot", bounds=bounds,
                nodes=flat, names=names, classes=classes, edges=edges)


# ------------------------------------------------------------------- rings --
def assemble_rings(seqs):
    """Join node-id sequences into closed rings. Returns (rings, open_chains)."""
    seqs = [list(s) for s in seqs if len(s) >= 2]
    rings = []
    while seqs:
        cur = seqs.pop()
        changed = True
        while cur[0] != cur[-1] and changed:
            changed = False
            for i, s in enumerate(seqs):
                if s[0] == cur[-1]:
                    cur += s[1:]
                elif s[-1] == cur[-1]:
                    cur += s[::-1][1:]
                elif s[-1] == cur[0]:
                    cur = s + cur[1:]
                elif s[0] == cur[0]:
                    cur = s[::-1] + cur[1:]
                else:
                    continue
                seqs.pop(i)
                changed = True
                break
        if cur[0] == cur[-1] and len(cur) >= 4:
            rings.append(cur)
        else:
            rings.append(None)
    closed = [r for r in rings if r]
    return closed, sum(1 for r in rings if r is None)


def ring_coords(nodes, ring):
    return [[r6(nodes[n][1]), r6(nodes[n][0])] for n in ring if n in nodes]


def ring_area(c):
    a = 0.0
    for i in range(len(c) - 1):
        a += c[i][0] * c[i + 1][1] - c[i + 1][0] * c[i][1]
    return a / 2


def point_in_ring(pt, ring):
    """pt=(lat,lon); ring=[[lon,lat],...]"""
    x, y = pt[1], pt[0]
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i]
        xj, yj = ring[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-30) + xi:
            inside = not inside
        j = i
    return inside


def area_kind(t):
    if t.get("natural") == "coastline":
        return None
    if t.get("building") and t.get("building") != "no":
        return "building"
    if t.get("landuse") == "salt_pond" or t.get("water") in ("salt_pond", "salina", "salt"):
        return "salina"
    if t.get("natural") == "water" or t.get("water") or t.get("landuse") in ("reservoir", "basin"):
        return "water"
    if t.get("natural") == "wetland":
        return "wetland"
    if t.get("natural") in ("beach", "sand"):
        return "beach"
    if t.get("leisure") in ("park", "nature_reserve", "garden") or t.get("landuse") in ("grass", "recreation_ground"):
        return "park"
    if t.get("aeroway") in ("runway", "taxiway", "apron") and t.get("area") != "no":
        return "runway"
    return None


def build_basemap(nodes, ways, rels, report):
    feats = []
    # Land from coastline (land on the left of coastline ways).
    coast = [w[0] for w in ways.values() if w[1].get("natural") == "coastline"]
    rings, open_chains = assemble_rings(coast)
    land_rings = [ring_coords(nodes, r) for r in rings]
    if not land_rings:
        for nds, t in ways.values():
            if t.get("place") == "island" and nds and nds[0] == nds[-1]:
                land_rings.append(ring_coords(nodes, nds))
    report["basemap"] = dict(coastline_ways=len(coast), land_rings=len(land_rings), open_coastline_chains=open_chains)
    for c in land_rings:
        feats.append(dict(type="Feature", properties=dict(kind="land"), geometry=dict(type="Polygon", coordinates=[c])))
    # Areas from closed ways.
    used_in_mp = set()
    for mem, t in rels.values():
        if t.get("type") != "multipolygon":
            continue
        k = area_kind(t)
        if not k:
            continue
        outer = [ways[r][0] for (ty, r, role) in mem if ty == "way" and r in ways and role in ("outer", "")]
        inner = [ways[r][0] for (ty, r, role) in mem if ty == "way" and r in ways and role == "inner"]
        used_in_mp.update(r for (ty, r, _) in mem if ty == "way")
        o_r, _ = assemble_rings(outer)
        i_r, _ = assemble_rings(inner)
        for o in o_r:
            oc = ring_coords(nodes, o)
            holes = [ring_coords(nodes, i) for i in i_r]
            holes = [h for h in holes if h and point_in_ring((h[0][1], h[0][0]), oc)]
            feats.append(dict(type="Feature", properties=dict(kind=k, name=t.get("name", "")),
                              geometry=dict(type="Polygon", coordinates=[oc] + holes)))
    counts = {}
    for wid, (nds, t) in ways.items():
        if len(nds) < 4 or nds[0] != nds[-1] or wid in used_in_mp and not t:
            continue
        k = area_kind(t)
        if not k:
            continue
        c = ring_coords(nodes, nds)
        if len(c) < 4:
            continue
        counts[k] = counts.get(k, 0) + 1
        feats.append(dict(type="Feature", properties=dict(kind=k, name=t.get("name", "")),
                          geometry=dict(type="Polygon", coordinates=[c])))
        if k in ("water", "salina") and t.get("name"):
            cx = sum(p[0] for p in c[:-1]) / (len(c) - 1)
            cy = sum(p[1] for p in c[:-1]) / (len(c) - 1)
            feats.append(dict(type="Feature", properties=dict(kind="water", name=t["name"]),
                              geometry=dict(type="Point", coordinates=[r6(cx), r6(cy)])))
    # Roads (all highways, for display).
    for nds, t in ways.values():
        hw = t.get("highway")
        if not hw or hw in ("proposed", "construction", "platform", "bus_stop") or t.get("area") == "yes":
            continue
        kind = "major_road" if hw in MAJOR else "minor_road" if hw in MINOR else "track" if hw == "track" else \
            "path" if hw in PATHS else None
        if not kind:
            continue
        c = [[r6(nodes[n][1]), r6(nodes[n][0])] for n in nds if n in nodes]
        if len(c) >= 2:
            feats.append(dict(type="Feature", properties=dict(kind=kind, name=t.get("name", "")),
                              geometry=dict(type="LineString", coordinates=c)))
    # Place labels.
    for la, lo, t in nodes.values():
        if t.get("place") in ("town", "village", "hamlet", "suburb", "neighbourhood", "locality") and t.get("name"):
            feats.append(dict(type="Feature", properties=dict(kind="place", name=t["name"]),
                              geometry=dict(type="Point", coordinates=[r6(lo), r6(la)])))
    report["basemap"].update(area_counts=counts, features=len(feats))
    return dict(type="FeatureCollection", features=feats), land_rings


# -------------------------------------------------------------------- POIs --
def norm(s):
    s = s.lower().replace("&", " and ").replace("’", "").replace("'", "")
    s = re.sub(r"\bst\b\.?", "saint", s)
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def feature_candidates(nodes, ways, rels=None):
    out = []
    keys = ("name", "name:en", "alt_name", "official_name", "old_name", "short_name")
    for nid_, (la, lo, t) in nodes.items():
        nm = [t[k] for k in keys if t.get(k)]
        if nm:
            out.append(dict(src=f"osm:node/{nid_}", names=nm, pt=(la, lo), tags=t, highway=False))
    for wid, (nds, t) in ways.items():
        nm = [t[k] for k in keys if t.get(k)]
        pts = [(nodes[n][0], nodes[n][1]) for n in nds if n in nodes]
        if not nm or not pts:
            continue
        if t.get("highway"):
            cum = [0]
            for i in range(1, len(pts)):
                cum.append(cum[-1] + haversine(pts[i - 1], pts[i]))
            half = cum[-1] / 2
            i = next(i for i, c in enumerate(cum) if c >= half)
            pt = pts[i]
        else:
            ring = pts[:-1] if len(pts) > 1 and pts[0] == pts[-1] else pts
            pt = (sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring))
        out.append(dict(src=f"osm:way/{wid}", names=nm, pt=pt, tags=t, highway=bool(t.get("highway")),
                        outline=pts))
    for rid, (mem, t) in (rels or {}).items():
        nm = [t[k] for k in keys if t.get(k)]
        if not nm or t.get("type") not in ("multipolygon", None) or t.get("boundary"):
            continue
        pts = [(nodes[n][0], nodes[n][1]) for (ty, r, role) in mem if ty == "way" and r in ways
               and role in ("outer", "") for n in ways[r][0] if n in nodes]
        if not pts:
            continue
        pt = (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
        out.append(dict(src=f"osm:relation/{rid}", names=nm, pt=pt, tags=t, highway=False, outline=pts))
    return out


def match_poi(entry, cands):
    aliases = [norm(a) for a in entry["aliases"]]
    fb = (entry["fallback"][1], entry["fallback"][0])
    allow_hw = entry["id"] == "front-street"
    best = None
    for tier in (1, 2):
        for c in cands:
            if c["highway"] and not allow_hw:
                continue
            ok = False
            for n in c["names"]:
                nn = norm(n)
                if tier == 1 and nn in aliases:
                    ok = True
                if tier == 2 and any(len(a) >= 6 and (a in nn or nn in a) and len(nn) >= 6 for a in aliases):
                    ok = True
            if not ok:
                continue
            d = haversine(fb, c["pt"])
            if d > 4000:
                continue
            if best is None or d < best[0]:
                best = (d, c, tier)
        if best:
            break
    return best


def build_pois(register, nodes, ways, graph_json, land_rings, report, rels=None):
    g = Graph(graph_json)
    cands = feature_candidates(nodes, ways, rels)
    pois, rows = [], []
    entries = [dict(register["shipTerminal"], isShipTerminal=True)] + [dict(e, isShipTerminal=False) for e in register["destinations"]]
    for e in entries:
        m = match_poi(e, cands)
        verified = bool(e.get("verifiedCoordinate"))
        if m:
            disp = m[1]["pt"]
            src = m[1]["src"]
            matched_name = m[1]["names"][0]
        else:
            disp = (e["fallback"][1], e["fallback"][0])
            src = "register-verified" if verified else "register-unverified"
            matched_name = None
        approach, reason = None, None
        snap = g.nearest(disp, MAX_POI_TO_NETWORK_M)
        outline = m[1].get("outline") if m else None
        if outline and len(outline) > 2 and not m[1]["highway"]:
            # Areas (beaches, salinas, airport): the visitor arrives at the
            # closest point of the network to the AREA EDGE, not its centroid.
            step = max(1, len(outline) // 200)
            for q in outline[::step]:
                sq = g.nearest(q, MAX_POI_TO_NETWORK_M)
                if sq and (snap is None or sq["dist"] < snap["dist"]):
                    snap = sq
        if not m and not verified:
            reason = "Location not yet verified on the map data"
        elif snap is None:
            reason = "No walkable road or path within 250 m (e.g. offshore or no public access)"
        else:
            approach = snap["point"]
        on_land = any(point_in_ring(disp, r) for r in land_rings) if land_rings else None
        pois.append(dict(
            id=e["id"], name=e["name"], category=e["category"],
            display=[r6(disp[1]), r6(disp[0])],
            approach=None if approach is None else [r6(approach[1]), r6(approach[0])],
            routable=approach is not None, notRoutableReason=reason,
            description=e["description"], accessNotes=e.get("accessNotes", ""),
            approvalStatus="provisional", locationSource=src, isShipTerminal=e["isShipTerminal"],
        ))
        rows.append(dict(id=e["id"], name=e["name"], matched=matched_name, source=src,
                         match_offset_from_fallback_m=None if not m else round(m[0]),
                         match_tier=None if not m else m[2],
                         network_distance_m=None if snap is None else round(snap["dist"], 1),
                         display_on_land=on_land, routable=approach is not None, reason=reason))
    # Reachability audit against the ship terminal, both directions.
    ship = next(p for p in pois if p["isShipTerminal"])
    if ship["approach"]:
        sp = (ship["approach"][1], ship["approach"][0])
        for p, row in zip(pois, rows):
            if not p["routable"] or p is ship:
                continue
            ap = (p["approach"][1], p["approach"][0])
            r1, r2 = route(g, sp, ap), route(g, ap, sp)
            if "failure" in r1 or "failure" in r2:
                p["routable"], p["approach"] = False, None
                p["notRoutableReason"] = "Not connected to the walking network from the Cruise Center"
                row.update(routable=False, reason=p["notRoutableReason"])
            else:
                row.update(from_ship_m=round(r1["distance"]), to_ship_m=round(r2["distance"]))
    report["pois"] = rows
    return dict(schemaVersion=1, poiVersion=register["poiVersion"], pois=pois)


# --------------------------------------------------------------------- main --
def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, separators=(",", ":"), ensure_ascii=False)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--osm", required=True)
    ap.add_argument("--register", default="tools/pipeline/poi_register.json")
    ap.add_argument("--root", default=".")
    a = ap.parse_args()
    report = dict(source=os.path.basename(a.osm), built=dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"))
    nodes, ways, rels, meta = parse_osm(a.osm)
    report["input"] = dict(nodes=len(nodes), ways=len(ways), relations=len(rels), meta=meta)
    gt_nodes = sum(1 for la, lo, _ in nodes.values()
                   if GRAND_TURK["south"] <= la <= GRAND_TURK["north"] and GRAND_TURK["west"] <= lo <= GRAND_TURK["east"])
    if gt_nodes < 500:
        raise SystemExit(f"ERROR: extract has only {gt_nodes} nodes inside Grand Turk - wrong area?")
    with open(a.register, encoding="utf-8") as f:
        register = json.load(f)
    graph = build_graph(nodes, ways, report)
    basemap, land_rings = build_basemap(nodes, ways, rels, report)
    pois = build_pois(register, nodes, ways, graph, land_rings, report, rels)

    extract_date = (meta.get("osm_base") or report["built"])[:10]
    root = a.root
    paths = {
        "assets/graph/graph.json": graph,
        "assets/pois/pois.json": pois,
        "assets/map/basemap.geojson": basemap,
    }
    for rel, obj in paths.items():
        write_json(os.path.join(root, rel), obj)
    files = {rel: dict(sha256=sha256(os.path.join(root, rel)), bytes=os.path.getsize(os.path.join(root, rel)))
             for rel in paths}
    manifest = dict(
        bundleId="tci-bb-grand-turk", schemaVersion=1,
        releaseId=f"{extract_date}.{graph['graphVersion'][-6:]}",
        coverageBounds=graph["bounds"], mapVersion=f"osm-{extract_date}",
        graphVersion=graph["graphVersion"], poiVersion=pois["poiVersion"], travelProfile="foot",
        source=dict(name="OpenStreetMap", license="ODbL 1.0 (opendatacommons.org/licenses/odbl)",
                    attribution="© OpenStreetMap contributors", extractDate=extract_date,
                    extractFile=os.path.basename(a.osm), extractSha256=sha256(a.osm)),
        files=files,
    )
    write_json(os.path.join(root, "assets/manifest/manifest.json"), manifest)
    report["manifest"] = manifest

    blocking = []
    ship = next(p for p in pois["pois"] if p["isShipTerminal"])
    if not ship["routable"]:
        blocking.append("Cruise Center return point is not routable")
    for must in ("governors-beach", "grand-turk-lighthouse"):
        p = next(p for p in pois["pois"] if p["id"] == must)
        if not p["routable"]:
            blocking.append(f"Mandatory regression POI {must} is not routable: {p['notRoutableReason']}")
    if report["basemap"]["land_rings"] == 0:
        blocking.append("No closed coastline: land polygon could not be built (extract must cover the whole island)")
    report["blocking"] = blocking
    os.makedirs(os.path.join(root, "build"), exist_ok=True)
    with open(os.path.join(root, "build/data_report.json"), "w") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    with open(os.path.join(root, "build/data_report.md"), "w") as f:
        f.write(render_md(report))
    print(render_md(report))
    sys.exit(1 if blocking else 0)


def render_md(r):
    g, b = r["graph"], r["basemap"]
    L = [f"# Offline data build report\n", f"Source: `{r['source']}`  Built: {r['built']}\n",
         "## Road/path graph (walking profile)\n",
         f"- Walkable ways: {g['walkable_ways']}; edges kept: {g['edges']} ({g['total_km']} km); nodes: {g['nodes']}",
         f"- Connected components: {g['components']}; dropped edges outside the main network: {g['dropped_edges']} "
         f"(largest dropped components: {g['dropped_component_sizes'][:8]})",
         f"- graphVersion: `{g['graphVersion']}`\n",
         "## Basemap\n",
         f"- Coastline ways: {b['coastline_ways']}; closed land rings: {b['land_rings']}; open chains: {b['open_coastline_chains']}",
         f"- Areas: {b.get('area_counts')}; total features: {b.get('features')}\n",
         "## Destinations (provisional register)\n",
         "| id | matched OSM name | source | network dist (m) | routable | from ship (m) | reason |",
         "|---|---|---|---|---|---|---|"]
    for p in r["pois"]:
        L.append(f"| {p['id']} | {p['matched'] or '-'} | {p['source']} | {p['network_distance_m']} | "
                 f"{'yes' if p['routable'] else 'NO'} | {p.get('from_ship_m', '-')} | {p['reason'] or ''} |")
    L.append("\n## Release-blocking issues\n")
    L += [f"- {x}" for x in r["blocking"]] or ["- none"]
    return "\n".join(L) + "\n"


if __name__ == "__main__":
    main()
