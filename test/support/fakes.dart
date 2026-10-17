import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:tci_beach_buddies/core/geo/geo.dart';
import 'package:tci_beach_buddies/core/models/location_fix.dart';
import 'package:tci_beach_buddies/features/navigation/application/navigation_controller.dart';
import 'package:tci_beach_buddies/features/navigation/domain/route_models.dart';
import 'package:tci_beach_buddies/platform/location/location_source.dart';

/// Manually driven location source for deterministic tests.
class FakeLocationSource implements LocationSource {
  final _c = StreamController<LocationFix>.broadcast();
  LocationPermissionState permission;
  @override
  final bool isSimulated;
  FakeLocationSource({this.permission = LocationPermissionState.granted, this.isSimulated = false});

  @override
  Stream<LocationFix> get fixes => _c.stream;
  @override
  Future<LocationPermissionState> ensurePermission() async => permission;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}

  void emit(GeoPoint p, {double accuracy = 5, DateTime? at}) => _c.add(LocationFix(
        position: p,
        accuracyM: accuracy,
        timestamp: at ?? DateTime.now(),
        isSimulated: isSimulated,
      ));
}

/// Route engine wrapper that can delay specific requests (stale-result tests).
class DelayingEngine implements RouteEngine {
  final RouteEngine inner;
  final Map<String, Completer<void>> gates = {};
  final List<RouteRequest> requests = [];
  DelayingEngine(this.inner);
  @override
  String get graphVersion => inner.graphVersion;
  @override
  String get travelProfile => inner.travelProfile;
  @override
  Future<RouteOutcome> calculate(RouteRequest r) async {
    requests.add(r);
    final g = gates[r.destinationPoiId];
    if (g != null) await g.future;
    return inner.calculate(r);
  }
}

/// AssetBundle that serves files from a directory (e.g. the synthetic bundle).
class DirectoryAssetBundle extends CachingAssetBundle {
  final String root;
  final Map<String, List<int>> overrides;
  DirectoryAssetBundle(this.root, {this.overrides = const {}});
  @override
  Future<ByteData> load(String key) async {
    final o = overrides[key];
    final bytes = o ?? await File('$root/$key').readAsBytes();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

const syntheticRoot = 'test/fixtures/synthetic_bundle';

Map<String, dynamic> readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

/// Builds a graph JSON in the bundle format from simple node/edge lists.
/// nodes: [(lat, lon)], edges: [(from, to, forwardOnly, name)]
Map<String, dynamic> graphJson(List<(double, double)> nodes, List<(int, int, bool, String)> edges,
    {String version = 'test-1', GeoBounds bounds = const GeoBounds(21.40, -71.17, 21.53, -71.10)}) {
  final names = <String>[''];
  final flat = <double>[for (final n in nodes) ...[n.$1, n.$2]];
  final e = <List<Object>>[];
  for (final (u, v, fo, name) in edges) {
    var ni = names.indexOf(name);
    if (ni < 0) {
      names.add(name);
      ni = names.length - 1;
    }
    final len = haversineM(GeoPoint(nodes[u].$1, nodes[u].$2), GeoPoint(nodes[v].$1, nodes[v].$2));
    e.add([u, v, len, fo ? 1 : 0, 0, ni, <double>[]]);
  }
  return {
    'schemaVersion': 1,
    'graphVersion': version,
    'profile': 'foot',
    'bounds': {'south': bounds.south, 'west': bounds.west, 'north': bounds.north, 'east': bounds.east},
    'nodes': flat,
    'names': names,
    'classes': ['footway'],
    'edges': e,
  };
}
