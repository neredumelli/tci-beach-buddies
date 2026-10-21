import 'dart:convert';

import 'package:flutter/services.dart';

/// A licensed destination photograph bundled in assets/photos/.
class PhotoCredit {
  final String asset;
  final String title;
  final String author;
  final String license;
  final String sourceUrl;

  /// True for an original drawing standing in until a real photo arrives.
  /// It is never a picture of the actual place, and the UI must say so.
  final bool isIllustration;

  /// A real photo supplied by the client (TCI Beach Buddies) for the app.
  final bool isSupplied;
  const PhotoCredit(this.asset, this.title, this.author, this.license, this.sourceUrl,
      {this.isIllustration = false, this.isSupplied = false});

  String get line => isIllustration
      ? 'Illustration only, not a photo of this place'
      : isSupplied
          ? 'Photo supplied by ${author.isEmpty ? 'TCI Beach Buddies' : author}'
          : 'Photo: ${author.isEmpty ? 'Unknown' : author} · $license';

  static PhotoCredit fromJson(Map m) => PhotoCredit(
        'assets/photos/${m['file']}',
        m['title'] as String? ?? '',
        m['author'] as String? ?? '',
        m['license'] as String? ?? '',
        m['url'] as String? ?? '',
        isIllustration: m['kind'] == 'illustration',
        isSupplied: m['kind'] == 'supplied',
      );
}

/// Registry of bundled photos keyed by destination id (loaded at start-up).
class Photos {
  /// Main (first) image of each destination.
  static Map<String, PhotoCredit> byPoi = const {};

  /// Every image of each destination, main one first. Places with two or
  /// more photos rotate through them on their cards, Details and Arrival.
  static Map<String, List<PhotoCredit>> allByPoi = const {};

  static PhotoCredit? of(String poiId) => byPoi[poiId];

  static List<PhotoCredit> allOf(String poiId) => allByPoi[poiId] ?? const [];

  /// Credit shown under a destination's photo. With several photos it
  /// names every source, so it stays right while the photos rotate.
  static String? creditLine(String poiId) {
    final all = allOf(poiId);
    if (all.isEmpty) return null;
    if (all.length == 1) return all.first.line;
    final names = <String>[];
    for (final p in all) {
      final n = p.isIllustration
          ? 'illustration'
          : p.isSupplied
              ? 'TCI Beach Buddies'
              : '${p.author.isEmpty ? 'Unknown' : p.author} (${p.license})';
      if (!names.contains(n)) names.add(n);
    }
    return '${all.length} photos: ${names.join(' · ')}';
  }

  /// Every bundled image, for the credits list and counts.
  static Iterable<PhotoCredit> get every => allByPoi.values.expand((l) => l);

  static Future<void> load([AssetBundle? bundle]) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString('assets/photos/credits.json', cache: false);
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      allByPoi = {
        for (final e in j.entries)
          e.key: [
            PhotoCredit.fromJson(e.value as Map),
            for (final m in ((e.value as Map)['more'] as List? ?? const [])) PhotoCredit.fromJson(m as Map),
          ],
      };
      byPoi = {for (final e in allByPoi.entries) e.key: e.value.first};
    } catch (_) {
      byPoi = const {};
      allByPoi = const {};
    }
  }
}
