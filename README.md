# TCI Beach Buddies: Grand Turk offline tourist navigation

This is the Flutter app for Android and iOS. After installation, the map, the destination list, walking routes, live GPS progress, arrival detection and **Return to Ship** all work with mobile data and Wi-Fi switched off.

> **Status: source complete, not yet compiled or device-tested.** See `docs/VERIFICATION.md` for what has been proven, what hasn't, and why. Nothing in this repo should be called production-ready until gates G7/G8 (physical Android and iOS tests) pass.

## How navigation works (and how the old A→B defect is fixed)

All of the following run on the device.

1. **Data:** OpenStreetMap roads and paths are turned into a directed graph for **walking**: split at junctions, private ways removed, only the largest connected network kept (`tools/pipeline/build_bundle.py`).
2. **Routing:** `lib/features/navigation/domain/route_planner.dart`
   - Uses A* with physical length as the cost, so a route is the *shortest walk*, never a straight line.
   - The origin and destination snap to the closest point **on an edge**, joined by virtual split-edge connectors. This stops routes detouring through an unrelated junction.
   - Dijkstra is the test oracle.
3. **A→B guarantee:** `NavigationController.selectDestination()`
   - Each new request increments a generation token and retires the old route.
   - It asks for the **latest live GPS fix** and routes from that fix.
   - The result is published only if its generation is still current.
   - No origin is ever stored between requests. The cruise centre and the previous destination can't become the origin, and a late result for A can't overwrite B.
4. **Return to Ship** runs the same pipeline, with the approved Cruise Center approach point as the destination.
5. **Progress:** remaining distance is measured *along the route*. Rerouting needs 2 good off-route fixes plus an 8 s cooldown. Arrival needs 2 accurate fixes within 30 m. All of these thresholds are provisional (TD-05).
6. **Map:** `flutter_map` draws the bundled vector GeoJSON (land, salinas, beaches, buildings, roads). There is **no tile layer and no URL**, so it can't reach the network.

## Building

Requirements:
- Flutter stable (templates were taken from 3.47.7)
- Android SDK and JDK 17+
- Python 3.10+, plus optional Pillow for the regression PNG
- For iOS: macOS, Xcode, CocoaPods and an Apple Developer team

```bash
# 1. Get the map data (once per data release). Go to https://www.openstreetmap.org/export,
#    choose "Manually select a different area", cover ALL of Grand Turk
#    (about 21.40-21.53 N, 71.10-71.17 W), click Export and save map.osm.
# 2. Build data and app, running every gate in order:
tools/build_release.sh path/to/map.osm
```

`build_release.sh` stops at the first failing gate. In order, it:
1. builds the bundle and writes `build/data_report.md` (POI matching, connectivity, coastline);
2. runs the pipeline unit tests;
3. runs the **mandatory route regression** (Cruise→Governor's Beach→Lighthouse→Ship, plus a nearby A→B switch compared against the old stale-origin route). Output: `build/route_regression.png` and `test/fixtures/regression_routes.json`;
4. runs `flutter pub get`, `analyze` and `test`. The Dart tests repeat the regression vectors against the app's own planner;
5. builds `app-release.apk` and `.aab`, then the iOS IPA on a Mac.

If Gradle or Xcode reports a platform-config problem with the `android/` or `ios/` folders on your Flutter version, run `flutter create --platforms=android,ios --org com.tcibeachbuddies .`. It regenerates missing platform files and leaves `lib/` alone. Then re-check that the location permissions in `AndroidManifest.xml` and `Info.plist` are still present.

**Release signing for Android.** Create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias` and `keyPassword` (see the comment in `android/app/build.gradle.kts`). Without that file, release builds use debug keys, which is fine for QA only.

## Device acceptance (BR-14)

1. Install the APK or IPA. Turn on **airplane mode**, then turn **Location back on**.
2. Run `flutter test integration_test/offline_journey_test.dart -d <device>`. It drives Cruise→A→B→Ship through the UI using Demo location.
3. On Grand Turk, walk the regression routes for real with live GPS, then record the results against AT-01 to AT-20.

**Demo mode** (Settings → Demo / QA) uses a simulated position. While it's on, a yellow **SIMULATED** banner shows on every screen. It switches off when the app restarts. On the navigation screen it adds controls to walk the route, step off-route, or jump to a destination.

## Project layout

```
lib/app/            composition root, theme, tab shell, navigation helpers
lib/core/           geo maths (pure Dart), models
lib/data/           offline bundle verification (SHA-256, versions)
lib/features/navigation/domain       graph, A*, progress, arrival, GPS policy (pure Dart)
lib/features/navigation/application  NavigationController state machine, LocationCoordinator
lib/features/*/presentation          the 7 screens (+ Saved)
lib/platform/location                geolocator adapter + Demo source
tools/pipeline/     OSM -> bundle, reference router, regression, synthetic tests
test/               unit, widget, regression (real + synthetic bundle)
integration_test/   on-device offline journey
```

## Data licence

The map data is © OpenStreetMap contributors and is licensed under ODbL 1.0. Attribution appears on the map and in Settings. The extract's SHA-256 is recorded in `assets/manifest/manifest.json`.
