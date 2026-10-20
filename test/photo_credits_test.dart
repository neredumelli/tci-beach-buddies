import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every destination has an image, every image file exists, and every
/// stand-in drawing is marked as an illustration so the app labels it.
void main() {
  final credits = (jsonDecode(File('assets/photos/credits.json').readAsStringSync()) as Map).cast<String, dynamic>();
  final pois = ((jsonDecode(File('assets/pois/pois.json').readAsStringSync()) as Map)['pois'] as List)
      .cast<Map<String, dynamic>>();

  test('every destination has a photo or an illustration', () {
    final missing = pois.map((p) => p['id'] as String).where((id) => !credits.containsKey(id)).toList();
    expect(missing, isEmpty);
  });

  test('every credited image file is bundled', () {
    for (final e in credits.entries) {
      final file = File('assets/photos/${(e.value as Map)['file']}');
      expect(file.existsSync(), isTrue, reason: '${e.key} -> ${file.path}');
    }
  });

  test('generated images are marked as illustrations', () {
    for (final e in credits.entries) {
      final v = (e.value as Map);
      if ((v['file'] as String).startsWith('illustration-')) {
        expect(v['kind'], 'illustration', reason: e.key);
      }
    }
  });
}
