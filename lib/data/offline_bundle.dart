// Offline bundle loader + integrity verification (TDD 3.1, SDD 6.1).
//
// Start-up contract:
//   1. manifest.json must exist and have a supported schema.
//   2. Every listed file must exist and match its SHA-256.
//   3. Map / graph / POIs are parsed independently so that a broken graph
//      still allows safe map browsing, but disables route initiation.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../core/geo/geo.dart';
import '../core/models/poi.dart';
import '../features/map/data/basemap.dart';
import '../features/navigation/domain/road_graph.dart';

class BundleManifest {
  final String bundleId;
  final int schemaVersion;
  final String releaseId;
  final String mapVersion;
  final String graphVersion;
  final String poiVersion;
  final String travelProfile;
  final GeoBounds coverage;
  final String sourceName;
  final String sourceLicense;
  final String attribution;
  final String extractDate;
  final Map<String, String> fileHashes;

  const BundleManifest({
    required this.bundleId,
    required this.schemaVersion,
    required this.releaseId,
    required this.mapVersion,
    required this.graphVersion,
    required this.poiVersion,
    required this.travelProfile,
    required this.coverage,
    required this.sourceName,
    required this.sourceLicense,
    required this.attribution,
    required this.extractDate,
    required this.fileHashes,
  });

  factory BundleManifest.fromJson(Map<String, dynamic> j) {
    final src = (j['source'] as Map).cast<String, dynamic>();
    final files = (j['files'] as Map).cast<String, dynamic>();
    return BundleManifest(
      bundleId: j['bundleId'] as String,
      schemaVersion: j['schemaVersion'] as int,
      releaseId: j['releaseId'] as String,
      mapVersion: j['mapVersion'] as String,
      graphVersion: j['graphVersion'] as String,
      poiVersion: j['poiVersion'] as String,
      travelProfile: j['travelProfile'] as String,
      coverage: GeoBounds.fromJson((j['coverageBounds'] as Map).cast<String, dynamic>()),
      sourceName: src['name'] as String,
      sourceLicense: src['license'] as String,
      attribution: src['attribution'] as String,
      extractDate: src['extractDate'] as String,
      fileHashes: {
        for (final e in files.entries)
          e.key: ((e.value as Map)['sha256'] as String).toLowerCase(),
      },
    );
  }
}

enum BundleIssueSeverity { blocksMap, blocksNavigation, warning }

class BundleIssue {
  final BundleIssueSeverity severity;
  final String code;
  final String message;
  const BundleIssue(this.severity, this.code, this.message);
}

class BundleHealth {
  final BundleManifest? manifest;
  final Basemap? basemap;
  final RoadGraph? graph;
  final List<Poi> pois;
  final List<BundleIssue> issues;

  const BundleHealth({
    required this.manifest,
    required this.basemap,
    required this.graph,
    required this.pois,
    required this.issues,
  });

  bool get mapAvailable =>
      basemap != null && !issues.any((i) => i.severity == BundleIssueSeverity.blocksMap);
  bool get navigationAvailable =>
      graph != null &&
      mapAvailable &&
      !issues.any((i) => i.severity == BundleIssueSeverity.blocksNavigation);
  bool get fullyHealthy => issues.isEmpty;
}

const String manifestAsset = 'assets/manifest/manifest.json';
const String basemapAsset = 'assets/map/basemap.geojson';
const String graphAsset = 'assets/graph/graph.json';
const String poisAsset = 'assets/pois/pois.json';

class OfflineBundle {
  final AssetBundle assets;
  OfflineBundle([AssetBundle? bundle]) : assets = bundle ?? rootBundle;

  Future<Uint8List?> _bytes(String key) async {
    try {
      final data = await assets.load(key);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  Future<BundleHealth> verifyAndLoad() async {
    final issues = <BundleIssue>[];
    final mBytes = await _bytes(manifestAsset);
    if (mBytes == null) {
      return const BundleHealth(manifest: null, basemap: null, graph: null, pois: [], issues: [
        BundleIssue(BundleIssueSeverity.blocksMap, 'MANIFEST_MISSING',
            'Offline data is not installed in this build (manifest.json missing). '
                'Run tools/pipeline/build_bundle.py and rebuild the app.'),
      ]);
    }
    BundleManifest manifest;
    try {
      manifest = BundleManifest.fromJson(
          (jsonDecode(utf8.decode(mBytes)) as Map).cast<String, dynamic>());
    } catch (e) {
      return BundleHealth(manifest: null, basemap: null, graph: null, pois: const [], issues: [
        BundleIssue(BundleIssueSeverity.blocksMap, 'MANIFEST_INVALID', 'manifest.json unreadable: $e'),
      ]);
    }
    if (manifest.schemaVersion != 1) {
      issues.add(BundleIssue(BundleIssueSeverity.blocksMap, 'SCHEMA_UNSUPPORTED',
          'Bundle schema ${manifest.schemaVersion} is not supported by this app version.'));
    }

    Future<Uint8List?> verified(String key, BundleIssueSeverity sev) async {
      final b = await _bytes(key);
      if (b == null) {
        issues.add(BundleIssue(sev, 'FILE_MISSING', '$key is missing'));
        return null;
      }
      final expected = manifest.fileHashes[key];
      final actual = sha256.convert(b).toString();
      if (expected == null) {
        issues.add(BundleIssue(sev, 'HASH_UNLISTED', '$key is not listed in manifest'));
        return null;
      }
      if (expected != actual) {
        issues.add(BundleIssue(sev, 'HASH_MISMATCH', '$key failed SHA-256 verification'));
        return null;
      }
      return b;
    }

    Basemap? basemap;
    final bm = await verified(basemapAsset, BundleIssueSeverity.blocksMap);
    if (bm != null) {
      try {
        basemap = Basemap.fromGeoJson((jsonDecode(utf8.decode(bm)) as Map).cast<String, dynamic>());
      } catch (e) {
        issues.add(BundleIssue(BundleIssueSeverity.blocksMap, 'MAP_INVALID', 'Basemap unreadable: $e'));
      }
    }

    RoadGraph? graph;
    final gb = await verified(graphAsset, BundleIssueSeverity.blocksNavigation);
    if (gb != null) {
      try {
        graph = RoadGraph.fromJson((jsonDecode(utf8.decode(gb)) as Map).cast<String, dynamic>());
        if (graph.graphVersion != manifest.graphVersion) {
          issues.add(const BundleIssue(BundleIssueSeverity.blocksNavigation, 'GRAPH_VERSION',
              'Road graph version does not match the manifest.'));
          graph = null;
        } else {
          graph.index; // build spatial index eagerly at start-up
        }
      } on GraphFormatException catch (e) {
        issues.add(BundleIssue(BundleIssueSeverity.blocksNavigation, 'GRAPH_INVALID', e.message));
      } catch (e) {
        issues.add(BundleIssue(BundleIssueSeverity.blocksNavigation, 'GRAPH_INVALID', '$e'));
      }
    }

    var pois = <Poi>[];
    final pb = await verified(poisAsset, BundleIssueSeverity.blocksNavigation);
    if (pb != null) {
      try {
        final j = (jsonDecode(utf8.decode(pb)) as Map).cast<String, dynamic>();
        if (j['poiVersion'] != manifest.poiVersion) {
          issues.add(const BundleIssue(BundleIssueSeverity.blocksNavigation, 'POI_VERSION',
              'POI register version does not match the manifest.'));
        }
        pois = [
          for (final p in (j['pois'] as List)) Poi.fromJson((p as Map).cast<String, dynamic>())
        ];
        if (!pois.any((p) => p.isShipTerminal && p.canNavigate)) {
          issues.add(const BundleIssue(BundleIssueSeverity.blocksNavigation, 'NO_SHIP_POINT',
              'No routable Cruise Center return point in the POI register.'));
        }
      } catch (e) {
        issues.add(BundleIssue(BundleIssueSeverity.blocksNavigation, 'POI_INVALID', '$e'));
      }
    }
    if (pois.any((p) => !p.isApproved)) {
      issues.add(const BundleIssue(BundleIssueSeverity.warning, 'POI_PROVISIONAL',
          'Destination register is provisional and awaiting business approval (OD-01/OD-02).'));
    }
    return BundleHealth(
        manifest: manifest, basemap: basemap, graph: graph, pois: pois, issues: issues);
  }
}
