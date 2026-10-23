// Showcase widgets for the photo look: Home hero slideshow, "Must-see"
// cards, a thumbnail gallery and quick-stat tiles on Details.
// Classic themes (the approved baseline) don't use these.
import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/models/poi.dart';
import 'art.dart';
import 'photo_viewer.dart';
import 'photos.dart';
import 'place_info.dart';

/// Full-bleed photos that cross-fade every few seconds (still when the
/// phone asks for reduced motion).
class HeroSlides extends StatefulWidget {
  final List<String> assets;
  final Alignment alignment;
  const HeroSlides({super.key, required this.assets, this.alignment = Alignment.center});

  @override
  State<HeroSlides> createState() => _HeroSlidesState();
}

class _HeroSlidesState extends State<HeroSlides> {
  int _i = 0;
  Timer? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t?.cancel();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!still && widget.assets.length > 1) {
      _t = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) setState(() => _i = (_i + 1) % widget.assets.length);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) return const TropicalScene();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 900),
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
      child: Image.asset(widget.assets[_i],
          key: ValueKey(_i),
          fit: BoxFit.cover,
          alignment: widget.alignment,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) => const TropicalScene()),
    );
  }
}

/// Tall photo card for the Home "Must-see" carousel.
class MustSeeCard extends StatelessWidget {
  final Poi poi;
  final String? distance;
  final VoidCallback onTap;
  const MustSeeCard({super.key, required this.poi, required this.distance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = BB.category(poi.category);
    final tagline = PlaceInfo.of(poi.id)?.tagline ?? '';
    final radius = leafRadius(36, 14);
    return Semantics(
      button: true,
      label: '${poi.name}${distance == null ? '' : ', $distance'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 236,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [BoxShadow(color: cat.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(fit: StackFit.expand, children: [
              PlaceArt(poi: poi, radius: 0),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22000000), Color(0x00000000), Color(0xE00B2F44)],
                    stops: [0, 0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(gradient: BB.categoryGradient(poi.category), borderRadius: leafRadius(12, 4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(BB.categoryIcon(poi.category), size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(poi.category.label,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(poi.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: heading(22, color: Colors.white, height: 1.05)
                          .copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 6)])),
                  if (tagline.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.25, fontWeight: FontWeight.w700)),
                  ],
                  if (distance != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.directions_walk_rounded, size: 14, color: BB.navy),
                        const SizedBox(width: 3),
                        Text(distance!, style: TextStyle(color: BB.navy, fontSize: 12, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Row of thumbnails under the Details title; tapping one opens it full screen.
class PhotoGalleryStrip extends StatelessWidget {
  final Poi poi;
  const PhotoGalleryStrip({super.key, required this.poi});

  @override
  Widget build(BuildContext context) {
    final all = Photos.allOf(poi.id);
    if (all.length < 2) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Photos (${all.length})', style: heading(18, color: BB.ink)),
      const SizedBox(height: 8),
      SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: all.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final p = all[i];
            return Semantics(
              button: true,
              label: '${p.isIllustration ? 'Illustration' : 'Photo'} ${i + 1} of ${all.length}. Open full screen',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => openPhotoViewer(context, poi, index: i),
                child: Container(
                  width: 104,
                  decoration: BoxDecoration(
                    borderRadius: leafRadius(20, 8),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(color: BB.category(poi.category).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: leafRadius(17, 6),
                    child: Image.asset(p.asset,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => TropicalScene(kind: sceneFor(poi), seed: poi.id.hashCode)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// Two or three quick facts in rounded tiles (e.g. from the ship, allow).
class StatTiles extends StatelessWidget {
  final List<(IconData, String, String)> stats;
  const StatTiles({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      for (var i = 0; i < stats.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: i.isEven ? leafRadius(22, 8) : leafRadius(8, 22),
              boxShadow: [BoxShadow(color: BB.navy.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(gradient: BB.headerGradient, shape: BoxShape.circle),
                child: Icon(stats[i].$1, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stats[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: BB.muted, fontWeight: FontWeight.w700)),
                  Text(stats[i].$3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: BB.navy, fontWeight: FontWeight.w900, height: 1.15)),
                ]),
              ),
            ]),
          ),
        ),
      ],
    ]);
  }
}
