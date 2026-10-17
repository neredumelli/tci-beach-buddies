"""Pipeline + reference-router tests on the SYNTHETIC island.

    python3 -m unittest discover -s tools/pipeline/tests -v
"""
import json
import os
import random
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
PIPE = os.path.dirname(HERE)
ROOT = os.path.dirname(os.path.dirname(PIPE))
sys.path.insert(0, PIPE)
from reference_router import Graph, haversine, route  # noqa: E402
sys.path.insert(0, HERE)
import make_synthetic_osm  # noqa: E402


class SyntheticBundle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        osm = os.path.join(cls.tmp, "synthetic.osm")
        make_synthetic_osm.main(osm)
        cls.proc = subprocess.run(
            [sys.executable, "-I", os.path.join(PIPE, "build_bundle.py"), "--osm", osm,
             "--register", os.path.join(PIPE, "poi_register.json"), "--root", cls.tmp],
            capture_output=True, text=True)
        with open(os.path.join(cls.tmp, "assets/graph/graph.json")) as f:
            cls.gj = json.load(f)
        with open(os.path.join(cls.tmp, "assets/pois/pois.json")) as f:
            cls.pois = {p["id"]: p for p in json.load(f)["pois"]}
        with open(os.path.join(cls.tmp, "build/data_report.json")) as f:
            cls.report = json.load(f)
        cls.g = Graph(cls.gj)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp)

    def ap(self, pid):
        p = self.pois[pid]["approach"]
        return (p[1], p[0])

    def test_build_succeeds_without_blocking_issues(self):
        self.assertEqual(self.proc.returncode, 0, self.proc.stdout + self.proc.stderr)
        self.assertEqual(self.report["blocking"], [])

    def test_disconnected_and_private_ways_dropped(self):
        g = self.report["graph"]
        self.assertGreaterEqual(g["components"], 2)
        self.assertGreater(g["dropped_edges"], 0)
        names = set(self.gj["names"])
        self.assertNotIn("Isolated Lane", names)

    def test_offshore_cay_is_browse_only(self):
        gc = self.pois["gibbs-cay"]
        self.assertFalse(gc["routable"])
        self.assertIsNone(gc["approach"])

    def test_unmatched_register_entries_are_not_routable(self):
        self.assertFalse(self.pois["national-museum"]["routable"])
        self.assertEqual(self.pois["national-museum"]["locationSource"], "register-unverified")

    def test_astar_equals_dijkstra_random_pairs(self):
        rnd = random.Random(42)
        b = self.gj["bounds"]
        for _ in range(150):
            a = (rnd.uniform(21.426, 21.505), rnd.uniform(-71.147, -71.139))
            c = (rnd.uniform(21.426, 21.505), rnd.uniform(-71.147, -71.139))
            r1, r2 = route(self.g, a, c, max_dest_snap=250), route(self.g, a, c, use_heuristic=False, max_dest_snap=250)
            self.assertEqual("failure" in r1, "failure" in r2)
            if "failure" not in r1:
                self.assertAlmostEqual(r1["cost"], r2["cost"], places=6)
                self.assertLessEqual(r1["settled"], r2["settled"])
        self.assertTrue(b["south"] < 21.43)

    def test_route_polyline_length_equals_cost(self):
        r = route(self.g, self.ap("grand-turk-cruise-center"), self.ap("governors-beach"))
        self.assertAlmostEqual(r["distance"], r["cost"], delta=0.05)

    def test_a_to_b_starts_at_current_position_not_cruise_center(self):
        ship, gov, jack = self.ap("grand-turk-cruise-center"), self.ap("governors-beach"), self.ap("jacks-shack")
        correct = route(self.g, gov, jack)                     # live fix at A
        stale = route(self.g, ship, jack)                      # buggy: original origin
        self.assertLess(haversine(correct["polyline"][0], gov), 1.0)
        self.assertLess(correct["distance"], 400)
        self.assertGreater(stale["distance"], correct["distance"] * 3)
        # never passes near the cruise centre
        self.assertGreater(min(haversine(p, ship) for p in correct["polyline"]), 1000)

    def test_split_edge_snap_avoids_vertex_detour(self):
        # Origin in the middle of a long Spine Road edge; destination 30 m north
        # on the same edge -> route must be ~30 m, not via a junction.
        lat = 21.425 + 0.002 * 7 + 0.0007
        o, d = (lat, -71.14005), (lat + 0.00027, -71.14005)
        r = route(self.g, o, d)
        self.assertLess(r["distance"], 35)

    def test_foot_oneway_respected(self):
        # Cross street 5 (i == 10) is a foot one-way from Spine (east) to Beach (west).
        lat = 21.425 + 0.002 * 10 + 0.0001
        east, west = (lat, -71.1405), (lat, -71.1455)
        fwd = route(self.g, east, west)
        back = route(self.g, west, east)
        self.assertLess(fwd["distance"], 700)
        self.assertGreater(back["distance"], fwd["distance"] + 100)  # must detour via another rung

    def test_far_offshore_origin_has_no_snap(self):
        self.assertEqual(route(self.g, (21.449, -71.105), self.ap("governors-beach")), {"failure": "noRoadSnap"})

    def test_manifest_hashes_match(self):
        import hashlib
        with open(os.path.join(self.tmp, "assets/manifest/manifest.json")) as f:
            m = json.load(f)
        for rel, meta in m["files"].items():
            with open(os.path.join(self.tmp, rel), "rb") as fh:
                self.assertEqual(hashlib.sha256(fh.read()).hexdigest(), meta["sha256"])
        self.assertEqual(m["graphVersion"], self.gj["graphVersion"])


if __name__ == "__main__":
    unittest.main()
