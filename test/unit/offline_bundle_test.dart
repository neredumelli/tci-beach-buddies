import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tci_beach_buddies/data/offline_bundle.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('valid synthetic bundle verifies and loads map, graph and POIs', () async {
    final h = await OfflineBundle(DirectoryAssetBundle(syntheticRoot)).verifyAndLoad();
    expect(h.mapAvailable, isTrue);
    expect(h.navigationAvailable, isTrue);
    expect(h.graph!.edges, isNotEmpty);
    expect(h.pois.where((p) => p.isShipTerminal && p.canNavigate), hasLength(1));
    // Register is provisional -> warning only, not blocking.
    expect(h.issues.every((i) => i.severity == BundleIssueSeverity.warning), isTrue);
  });

  test('missing manifest blocks the map with a diagnostic', () async {
    final h = await OfflineBundle(DirectoryAssetBundle('/nonexistent')).verifyAndLoad();
    expect(h.mapAvailable, isFalse);
    expect(h.navigationAvailable, isFalse);
    expect(h.issues.single.code, 'MANIFEST_MISSING');
  });

  test('corrupted graph (hash mismatch) disables navigation but keeps the map', () async {
    final bytes = File('$syntheticRoot/$graphAsset').readAsBytesSync().toList();
    bytes[bytes.length ~/ 2] = bytes[bytes.length ~/ 2] == 48 ? 49 : 48;
    final h = await OfflineBundle(DirectoryAssetBundle(syntheticRoot, overrides: {graphAsset: bytes})).verifyAndLoad();
    expect(h.mapAvailable, isTrue);
    expect(h.navigationAvailable, isFalse);
    expect(h.issues.any((i) => i.code == 'HASH_MISMATCH'), isTrue);
  });

  test('graph version mismatch with manifest disables navigation', () async {
    final m = readJson('$syntheticRoot/$manifestAsset');
    m['graphVersion'] = 'foot-other';
    final h = await OfflineBundle(DirectoryAssetBundle(syntheticRoot,
        overrides: {manifestAsset: utf8.encode(jsonEncode(m))})).verifyAndLoad();
    expect(h.navigationAvailable, isFalse);
    expect(h.issues.any((i) => i.code == 'GRAPH_VERSION'), isTrue);
  });

  test('bundle contains no remote URLs (offline-only rendering)', () {
    for (final f in [basemapAsset, graphAsset, poisAsset, manifestAsset]) {
      final s = File('$syntheticRoot/$f').readAsStringSync();
      expect(RegExp(r'https?://').hasMatch(s), isFalse, reason: f);
    }
  });
}
