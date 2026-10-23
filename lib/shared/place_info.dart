import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../core/models/poi.dart';

/// Extra visitor content for a destination (assets/pois/place_info.json):
/// a one-line tagline, how long to allow, what it's good for, highlights
/// and practical tips. Every field is optional.
class PlaceInfo {
  final String tagline;
  final String time;
  final List<String> bestFor;
  final List<String> highlights;
  final List<String> tips;
  const PlaceInfo({
    this.tagline = '',
    this.time = '',
    this.bestFor = const [],
    this.highlights = const [],
    this.tips = const [],
  });

  bool get isEmpty => tagline.isEmpty && time.isEmpty && bestFor.isEmpty && highlights.isEmpty && tips.isEmpty;

  static List<String> _list(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();

  factory PlaceInfo.fromJson(Map m) => PlaceInfo(
        tagline: m['tagline'] as String? ?? '',
        time: m['time'] as String? ?? '',
        bestFor: _list(m['bestFor']),
        highlights: _list(m['highlights']),
        tips: _list(m['tips']),
      );

  /// Text read aloud by Listen, after the description and facts.
  String get spoken => [
        if (highlights.isNotEmpty) 'Highlights: ${highlights.join('. ')}.',
        if (tips.isNotEmpty) 'Good to know: ${tips.join('. ')}.',
      ].join(' ');

  static Map<String, PlaceInfo> byPoi = const {};

  static PlaceInfo? of(String poiId) => byPoi[poiId];

  static Future<void> load([AssetBundle? bundle]) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString('assets/pois/place_info.json', cache: false);
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      byPoi = {
        for (final e in j.entries)
          if (e.value is Map) e.key: PlaceInfo.fromJson(e.value as Map),
      };
    } catch (_) {
      byPoi = const {};
    }
  }
}

/// A soft wave along the top edge: the content sheet rising over a photo.
class WaveTopClipper extends CustomClipper<Path> {
  final double depth;
  const WaveTopClipper({this.depth = 34});

  @override
  Path getClip(Size s) {
    final w = s.width, d = depth;
    return Path()
      ..moveTo(0, d * 0.15)
      ..cubicTo(w * 0.28, -d * 0.35, w * 0.52, d * 1.05, w, d * 0.55)
      ..lineTo(w, s.height)
      ..lineTo(0, s.height)
      ..close();
  }

  @override
  bool shouldReclip(WaveTopClipper old) => old.depth != depth;
}

/// Leaf shape used for cards: two round corners and two tighter ones.
BorderRadius leafRadius([double big = 30, double small = 10]) => BorderRadius.only(
      topLeft: Radius.circular(big),
      bottomRight: Radius.circular(big),
      topRight: Radius.circular(small),
      bottomLeft: Radius.circular(small),
    );

/// Tagline, quick-info chips, Highlights and Good to know for Details.
class PlaceExtras extends StatelessWidget {
  final Poi poi;
  final PlaceInfo info;

  /// Bold photo look (photo themes) uses the bundled heading font.
  final bool photoLook;
  const PlaceExtras({super.key, required this.poi, required this.info, required this.photoLook});

  @override
  Widget build(BuildContext context) {
    final cat = BB.category(poi.category);
    final light = BB.categoryLight(poi.category);
    Widget title(String t, IconData icon, Color c) => Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.white, 0.35)!]),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 6)],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t,
                style: photoLook
                    ? heading(20, color: BB.ink)
                    : TextStyle(color: BB.navy, fontWeight: FontWeight.w900, fontSize: 17)),
          ),
        ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (info.time.isNotEmpty || info.bestFor.isNotEmpty) ...[
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (info.time.isNotEmpty) _Chip(icon: Icons.schedule_rounded, label: 'Allow ${info.time}', color: BB.navy),
          for (final b in info.bestFor) _Chip(icon: Icons.favorite_rounded, label: b, color: cat),
        ]),
      ],
      if (info.highlights.isNotEmpty) ...[
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: leafRadius(32, 12),
            border: Border.all(color: cat.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [BoxShadow(color: cat.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('Highlights', Icons.auto_awesome_rounded, cat),
            const SizedBox(height: 10),
            for (final h in info.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3, right: 10, left: 4),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: light,
                      borderRadius: leafRadius(7, 2),
                      border: Border.all(color: cat, width: 2),
                    ),
                  ),
                  Expanded(
                    child: Text(h,
                        style: TextStyle(
                            fontSize: 15, height: 1.4, color: BB.ink, fontWeight: photoLook ? FontWeight.w600 : FontWeight.w500)),
                  ),
                ]),
              ),
          ]),
        ),
      ],
      if (info.tips.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE3F6FA), Color(0xFFD2EEF6)],
            ),
            borderRadius: leafRadius(12, 32),
            border: Border.all(color: BB.teal.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('Good to know', Icons.tips_and_updates_rounded, BB.teal),
            const SizedBox(height: 10),
            for (final t in info.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1, right: 8, left: 2),
                    child: Icon(Icons.check_circle_rounded, size: 18, color: BB.teal),
                  ),
                  Expanded(
                    child: Text(t,
                        style: TextStyle(
                            fontSize: 14.5, height: 1.4, color: BB.ink, fontWeight: photoLook ? FontWeight.w600 : FontWeight.w500)),
                  ),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: leafRadius(14, 5),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                style: TextStyle(color: Color.lerp(color, BB.ink, 0.35), fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}
