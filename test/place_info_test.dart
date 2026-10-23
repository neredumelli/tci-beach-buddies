import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tci_beach_buddies/shared/place_info.dart';

/// Extra place content refers to real destinations and has no empty lines.
void main() {
  final info = (jsonDecode(File('assets/pois/place_info.json').readAsStringSync()) as Map).cast<String, dynamic>();
  final ids = ((jsonDecode(File('assets/pois/pois.json').readAsStringSync()) as Map)['pois'] as List)
      .map((p) => (p as Map)['id'] as String)
      .toSet();

  test('every entry is for a known destination', () {
    final unknown = info.keys.where((k) => !k.startsWith('_') && !ids.contains(k)).toList();
    expect(unknown, isEmpty);
  });

  test('entries parse and have no blank text', () {
    for (final e in info.entries.where((e) => !e.key.startsWith('_'))) {
      final p = PlaceInfo.fromJson(e.value as Map);
      expect(p.isEmpty, isFalse, reason: e.key);
      for (final t in [...p.highlights, ...p.tips, ...p.bestFor]) {
        expect(t.trim(), isNotEmpty, reason: e.key);
      }
    }
  });
}
