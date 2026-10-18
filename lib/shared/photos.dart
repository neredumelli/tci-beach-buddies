import 'dart:convert';

import 'package:flutter/services.dart';

/// A licensed destination photograph bundled in assets/photos/.
class PhotoCredit {
  final String asset;
  final String title;
  final String author;
  final String license;
  final String sourceUrl;
  const PhotoCredit(this.asset, this.title, this.author, this.license, this.sourceUrl);

  String get line => 'Photo: ${author.isEmpty ? 'Unknown' : author} · $license · Wikimedia Commons';
}

/// Registry of bundled photos keyed by destination id (loaded at start-up).
class Photos {
  static Map<String, PhotoCredit> byPoi = const {};

  static PhotoCredit? of(String poiId) => byPoi[poiId];

  static Future<void> load([AssetBundle? bundle]) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString('assets/photos/credits.json');
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      byPoi = {
        for (final e in j.entries)
          e.key: PhotoCredit(
            'assets/photos/${(e.value as Map)['file']}',
            (e.value as Map)['title'] as String? ?? '',
            (e.value as Map)['author'] as String? ?? '',
            (e.value as Map)['license'] as String? ?? '',
            (e.value as Map)['url'] as String? ?? '',
          ),
      };
    } catch (_) {
      byPoi = const {};
    }
  }
}
