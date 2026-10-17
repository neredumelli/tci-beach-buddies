# Verification status and traceability

Updated 17 Oct 2026. This file is a record of evidence. It is not a claim of readiness.

## Build environment limits (disclosed as the brief required)

The development workspace could reach GitHub only. Google's Flutter and Dart storage, Maven/Google Maven, Gradle distributions, pub.dev, OpenStreetMap, Overpass, Geofabrik and the TCI data portal were all blocked, and no Mac was available. As a result:

| Item | Status |
|---|---|
| Flutter source (all screens, domain, application, platform layers) | **Written.** Every `.dart` file passes a syntax parse (tree-sitter-dart, 41 files, 0 errors). **Not compiled.** `flutter analyze` and `flutter test` have not run. |
| Android/iOS platform folders | Rendered from the official Flutter 3.47.7 stable templates, with foreground location permissions added and no INTERNET permission in the main manifest. **Not built.** |
| Real Grand Turk map/graph bundle | **Built 17 Oct 2026** from the user-supplied OSM export (cgimap, bbox 21.37–21.55 N, 71.30–70.95 W). Walking graph: 1,418 nodes, 1,825 edges, 154.7 km. 4 components; the 3 small disconnected ones (11 edges) were dropped. Coastline closed (9 land rings). 3,477 basemap features, 2,594 buildings. No URLs in any bundle file. |
| Routing algorithm | **Proven on the REAL Grand Turk graph** with the reference router: R1 Cruise→Governor's 2.44 km, R2 Governor's→Lighthouse 9.02 km from the live fix (the old stale-origin route was 10.81 km), R3 Lighthouse→Ship 10.81 km, R4 nearby switch Governor's→Waterloo 1.20 km (old: 1.77 km), R5 Gibbs Cay browse-only. 18/18 routable POIs reachable both ways from the ship. A* = Dijkstra on every case; no route vertex lies outside the land polygons. Also proven on a synthetic island with the Python reference router, which mirrors the Dart planner (11/11 pipeline tests and 5/5 regression scenarios pass). Dart parity tests are in place and run automatically once Flutter is available. |
| APK / AAB / IPA | **Not produced.** This needs Flutter + Android SDK (and macOS/Xcode for iOS). `tools/build_release.sh` builds them. |
| Physical-device and airplane-mode tests (G7/G8) | **Not done.** |

## Release gates (SDD §12)

| Gate | Evidence produced by | Current state |
|---|---|---|
| G1 Requirements | BRD/FRD approval | Pending business |
| G2 Data quality | `build/data_report.md` (connectivity, POI match, reachability) | **Passed technically.** 18 of 27 destinations matched and routable. 9 are browse-only (Pillory Beach, White Sands Beach, St. Thomas Church, Columbus Landfall, Odd Fellows Lodge, Red Salina, Hawks Nest Salina and Bohio are not in OSM; Gibbs Cay is offshore). Business approval still pending |
| G3 Algorithm | `tools/pipeline/tests`, `test/unit/route_planner_test.dart` | Python: passing. Dart: written, not run |
| G4 Offline map | No URL in the render path; `offline_bundle_test` "no remote URLs"; airplane-mode run | Device run pending |
| G5 Core navigation | `regression.py` + `test/regression/real_bundle_test.dart` + `navigation_controller_test.dart` | **Real data: passing (Python reference router).** Dart replay pending a Flutter toolchain |
| G6 Failure handling | controller tests (no fix, stale, inaccurate, denied, offshore, corrupt bundle) | Written, not run |
| G7 Android QA | signed APK + device evidence | Not started |
| G8 iOS QA | signed IPA + iPhone evidence | Not started |
| G9 Release | defects closed, sign-off | Not started |

## Requirement → implementation → test

| Req | Implementation | Tests |
|---|---|---|
| BR-01 offline | bundled GeoJSON map, graph, POIs; no TileLayer; no INTERNET permission | offline_bundle_test (no URLs); integration test in airplane mode |
| BR-02 map + location | `IslandMap`, `LocationCoordinator`, accuracy circle | widget tests; device |
| BR-03 browse/search | `PoiSearch`, `DestinationsScreen`, `DestinationDetailsScreen` | app_widget_test (search, empty state) |
| BR-04 route from current location | `selectDestination` → `latestAcceptedFix` → `RoutePlanner` | controller J-02 test |
| **BR-05 A→B from latest location** | generation token; no stored origin | controller "Cruise→A→B→Ship", "Rapid A then B"; regression R2/R4 |
| BR-06 Return to Ship everywhere | `ShipButton` (Home, Map, Details), "To Ship" (Navigation), Arrival | controller test; integration test |
| BR-07 no straight/offshore routes | graph-only polylines; `accessRestricted` / `noRoute` typed failures; land-polygon check in regression | route_planner_test (disconnected), R5 Gibbs Cay |
| BR-08 progress + arrival | `RouteProgressTracker` (along-route), `ArrivalEvaluator` (fires once) | controller tests |
| BR-09 GPS / coverage / no-route / simulated states | `GpsPolicy`, `GpsStatusChip` (icon + text), `SimulatedBanner` | controller + widget tests |
| BR-10 beach UI | theme from mockup; 48 dp+ targets; semantics labels | widget tests; UX review |
| BR-11 verified POIs | register is `provisional`; unmatched → browse-only; reachability audit | test_unmatched_register_entries… |
| BR-12 versioned data | manifest (map/graph/POI versions, SHA-256), Settings display | offline_bundle_test |
| BR-13 privacy | location only processed on device; no history persisted | code review |
| BR-14 separate platform sign-off | — | G7/G8 pending |
| BR-15 arrival descriptions / audio | descriptions on Arrival; `audioAsset` field reserved, no clips approved | — |
| BR-16 category filter / distance sort | chips + "Nearest" (only when GPS is good, labelled straight-line) | widget test |
| BR-17 demo mode | `DemoLocationSource`, banner, auto-off at restart, source switch discards fixes | integration test |

## Open decisions that affect this build

- OD-01/OD-02: the 27-destination register in `tools/pipeline/poi_register.json` is a **provisional working baseline**. Every entry ships as `approvalStatus: provisional`. Entries that don't match an OSM feature are browse-only until `verifiedCoordinate` is set.
- OD-02: the Return to Ship endpoint is the network point nearest the OSM "Grand Turk Cruise Center" feature. It still needs approval.
- OD-03: implemented as **walking only**.
- TD-05: GPS thresholds (10 s freshness, 30/100 m accuracy, 35 m off-route x2, 8 s cooldown, 30 m arrival x2) are provisional.
- UI: ETA is hidden by default and appears only as an opt-in "estimate". Photos are replaced by category illustrations until image rights are cleared. 3D view and turn-by-turn voice are not implemented; both are listed as unapproved in the UI spec.
