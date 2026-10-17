"""Generates a SYNTHETIC test island (NOT Grand Turk data) in OSM XML.

Used only to unit-test the pipeline and router logic before/without the real
extract. Layout (inside the Grand Turk bbox so coverage checks apply):
  * a north-south 'Spine Road' with a parallel 'Beach Path' to the west,
    linked by cross streets every ~220 m (a ladder network),
  * a closed coastline ring around it, a salt pond polygon,
  * POIs named like register entries at known places,
  * an offshore 'Gibbs Cay' node (must be browse-only),
  * a disconnected private compound (must be dropped),
  * a foot one-way segment (must be respected).
"""
import sys

LAT0, LON_SPINE, LON_BEACH = 21.425, -71.140, -71.146


def main(out):
    nodes, ways = [], []
    nid = [1000]

    def node(lat, lon, tags=None):
        nid[0] += 1
        nodes.append((nid[0], lat, lon, tags or {}))
        return nid[0]

    spine, beach = [], []
    rungs = 40
    for i in range(rungs + 1):
        lat = LAT0 + i * 0.002  # ~222 m
        spine.append(node(lat, LON_SPINE))
        beach.append(node(lat, LON_BEACH))
        # extra intermediate vertices so ways have shape
    ways.append((spine, {"highway": "secondary", "name": "Spine Road"}))
    ways.append((beach, {"highway": "footway", "name": "Beach Path"}))
    for i in range(0, rungs + 1, 2):
        mid = node(LAT0 + i * 0.002 + 0.0001, (LON_SPINE + LON_BEACH) / 2)
        tags = {"highway": "residential", "name": f"Cross Street {i // 2}"}
        if i == 10:
            tags = {"highway": "footway", "oneway:foot": "yes"}  # east -> west only
            ways.append(([spine[i], mid, beach[i]], tags))
            continue
        ways.append(([beach[i], mid, spine[i]], tags))
    # Disconnected private compound (should be dropped from routing).
    a, b = node(21.47, -71.130), node(21.471, -71.131)
    ways.append(([a, b], {"highway": "service", "name": "Isolated Lane"}))
    c = node(21.4705, -71.1302)
    ways.append(([b, c], {"highway": "service"}))
    ways.append(([spine[5], node(21.436, -71.137)], {"highway": "service", "access": "private"}))
    # Coastline ring (counter-clockwise => land on the left).
    ring = [node(21.420, -71.150), node(21.420, -71.134), node(21.510, -71.134), node(21.510, -71.150)]
    ways.append((ring + [ring[0]], {"natural": "coastline"}))
    # Salt pond.
    sp = [node(21.450, -71.143), node(21.450, -71.1415), node(21.452, -71.1415), node(21.452, -71.143)]
    ways.append((sp + [sp[0]], {"natural": "water", "water": "salt_pond", "name": "Town Salina"}))
    # Filler nodes (buildings) so the extract passes the size sanity check.
    for k in range(130):
        la, lo = 21.43 + (k % 13) * 0.005, -71.1395 + (k // 13) * 0.0004
        q = [node(la, lo), node(la, lo + 0.0001), node(la + 0.0001, lo + 0.0001), node(la + 0.0001, lo)]
        ways.append((q + [q[0]], {"building": "yes"}))
    # POIs.
    node(LAT0 + 0.0003, LON_SPINE - 0.0004, {"amenity": "ferry_terminal", "name": "Grand Turk Cruise Center"})
    node(LAT0 + 0.016, LON_BEACH - 0.0006, {"natural": "beach", "name": "Governor's Beach"})
    node(LAT0 + 0.080, LON_SPINE + 0.0003, {"man_made": "lighthouse", "name": "Grand Turk Lighthouse"})
    node(LAT0 + 0.0185, LON_BEACH - 0.0005, {"amenity": "bar", "name": "Jack's Shack"})
    node(LAT0 + 0.036, LON_SPINE + 0.0004, {"place": "town", "name": "Cockburn Town"})
    node(21.449, -71.105, {"place": "islet", "name": "Gibbs Cay"})
    with open(out, "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<osm version="0.6" generator="synthetic-test">\n')
        f.write('<meta osm_base="2026-01-01T00:00:00Z"/>\n')
        for i, la, lo, t in nodes:
            if t:
                f.write(f'<node id="{i}" lat="{la:.7f}" lon="{lo:.7f}">')
                f.writelines(f'<tag k="{k}" v="{v}"/>' for k, v in t.items())
                f.write("</node>\n")
            else:
                f.write(f'<node id="{i}" lat="{la:.7f}" lon="{lo:.7f}"/>\n')
        for w, (nds, t) in enumerate(ways, start=1):
            f.write(f'<way id="{w}">')
            f.writelines(f'<nd ref="{n}"/>' for n in nds)
            f.writelines(f'<tag k="{k}" v="{v}"/>' for k, v in t.items())
            f.write("</way>\n")
        f.write("</osm>\n")


if __name__ == "__main__":
    main(sys.argv[1])
