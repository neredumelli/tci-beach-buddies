// Vector "photo" artwork drawn in code: tropical sky, turquoise sea, sand,
// palms and the lighthouse. Used for splash, home hero, destination cards,
// details hero and arrival hero until rights-cleared photographs are approved.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/models/poi.dart';
import 'photo_viewer.dart';
import 'photos.dart';

enum SceneKind { beach, lighthouse, town, salina, food, shop, service }

SceneKind sceneFor(Poi p) {
  if (p.id.contains('lighthouse')) return SceneKind.lighthouse;
  if (p.id.contains('salina') || p.id.contains('creek')) return SceneKind.salina;
  return switch (p.category) {
    PoiCategory.beach => SceneKind.beach,
    PoiCategory.attraction => SceneKind.town,
    PoiCategory.historical => SceneKind.town,
    PoiCategory.restaurant => SceneKind.food,
    PoiCategory.shopping => SceneKind.shop,
    PoiCategory.services => SceneKind.service,
  };
}

/// A tropical scene. [seed] varies cloud/palm placement per destination.
class TropicalScene extends StatelessWidget {
  final SceneKind kind;
  final int seed;
  final bool palms;
  final Widget? child;
  const TropicalScene({super.key, this.kind = SceneKind.beach, this.seed = 1, this.palms = true, this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScenePainter(kind, seed, palms),
      child: child ?? const SizedBox.expand(),
    );
  }
}

/// Image-style thumbnail / hero for a destination.
class PlaceArt extends StatelessWidget {
  final Poi poi;
  final double? width;
  final double? height;
  final double radius;

  /// Tapping opens the image full screen (Details and Arrival heroes).
  final bool expandable;
  const PlaceArt({super.key, required this.poi, this.width, this.height, this.radius = 10, this.expandable = false});

  /// Smallest image that still rotates (tiny map thumbnails stay still).
  static const double _minRotateHeight = 70;

  @override
  Widget build(BuildContext context) {
    final photo = Photos.of(poi.id);
    final all = Photos.allOf(poi.id);
    if (all.length > 1 && (expandable || height == null || height! >= _minRotateHeight)) {
      return PhotoSlides(poi: poi, photos: all, width: width, height: height, radius: radius, expandable: expandable);
    }
    if (photo != null && expandable) {
      return Semantics(
        button: true,
        label: 'Open ${photo.isIllustration ? 'illustration' : 'photo'} of ${poi.name} full screen',
        child: GestureDetector(
          onTap: () => openPhotoViewer(context, poi),
          child: Hero(
            tag: photoHeroTag(poi),
            child: Stack(children: [
              _framed(photo),
              const _EnlargeChip(),
            ]),
          ),
        ),
      );
    }
    if (photo != null) return _framed(photo);
    return _scene();
  }

  Widget _framed(PhotoCredit photo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(photo.asset, fit: BoxFit.cover,
                semanticLabel: photo.isIllustration ? 'Illustration of ${poi.name}, not a photo' : 'Photo of ${poi.name}',
                errorBuilder: (_, __, ___) => TropicalScene(kind: sceneFor(poi), seed: poi.id.hashCode)),
            if (photo.isIllustration && (height ?? 100) >= 56)
              Positioned(
                right: BB.photo && (height ?? 100) >= 150 ? 12 : 6,
                bottom: BB.photo && (height ?? 100) >= 150 ? 44 : 6,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xE60B2F44), borderRadius: BorderRadius.circular(20)),
                    child: Text('Illustration',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                            fontSize: (height ?? 100) >= 150 ? 12 : 10)),
                  ),
                ),
              ),
          ]),
        ),
      );
  }

  Widget _scene() {
    final kind = sceneFor(poi);
    final showIcon = kind == SceneKind.food || kind == SceneKind.shop || kind == SceneKind.service;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: TropicalScene(
          kind: kind,
          seed: poi.id.hashCode,
          child: showIcon
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: BB.category(poi.category), shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)]),
                    child: Icon(BB.categoryIcon(poi.category), color: Colors.white,
                        size: ((height ?? 60) * 0.28).clamp(16, 48).toDouble()),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// "Tap to enlarge" chip on Details and Arrival heroes.
class _EnlargeChip extends StatelessWidget {
  const _EnlargeChip();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: BB.photo ? 12 : 10,
      bottom: BB.photo ? 44 : 10,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xCC0B2F44), borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.zoom_out_map, color: Colors.white, size: 15),
            SizedBox(width: 5),
            Text('Tap to enlarge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

/// A destination with two or more photos: cross-fades to the next photo
/// every few seconds. On Details and Arrival heroes ([expandable]) it also
/// shows dots, can be swiped, and opens the tapped photo full screen.
/// Automatic rotation stops when the phone asks for reduced motion.
class PhotoSlides extends StatefulWidget {
  final Poi poi;
  final List<PhotoCredit> photos;
  final double? width;
  final double? height;
  final double radius;
  final bool expandable;
  static const interval = Duration(seconds: 4);
  const PhotoSlides({super.key, required this.poi, required this.photos, this.width, this.height,
      this.radius = 10, this.expandable = false});

  @override
  State<PhotoSlides> createState() => PhotoSlidesState();
}

class PhotoSlidesState extends State<PhotoSlides> {
  int index = 0;
  Timer? _timer;
  bool _paused = false;

  int get _n => widget.photos.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || _paused) return;
    // Stagger cards so several in a list don't all change at once.
    final offset = Duration(milliseconds: (widget.poi.id.hashCode % 5).abs() * 300);
    _timer = Timer.periodic(PhotoSlides.interval + offset, (_) {
      if (mounted) setState(() => index = (index + 1) % _n);
    });
  }

  void go(int delta) {
    setState(() => index = (index + delta) % _n);
    _restart();
  }

  Future<void> _open() async {
    _paused = true;
    _restart();
    final shown = await openPhotoViewer(context, widget.poi, index: index);
    if (!mounted) return;
    _paused = false;
    setState(() => index = shown ?? index);
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[index];
    final big = widget.expandable;
    Widget img = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
          child: Image.asset(
            photo.asset,
            key: ValueKey(photo.asset),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => TropicalScene(kind: sceneFor(widget.poi), seed: widget.poi.id.hashCode),
          ),
        ),
      ),
    );
    final label = 'Photo ${index + 1} of $_n of ${widget.poi.name}';
    if (!big) return Semantics(image: true, label: label, child: img);
    return Semantics(
      button: true,
      label: '$label. Open full screen',
      hint: 'Swipe left or right for more photos',
      onScrollLeft: () => go(1),
      onScrollRight: () => go(-1),
      child: GestureDetector(
        onTap: _open,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 150) go(v < 0 ? 1 : -1);
        },
        child: Hero(
          tag: photoHeroTag(widget.poi),
          child: Stack(children: [
            img,
            const _EnlargeChip(),
            Positioned(
              right: BB.photo ? 12 : 10,
              bottom: BB.photo ? 44 : 10,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xCC0B2F44), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < _n; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == index ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == index ? Colors.white : Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final SceneKind kind;
  final int seed;
  final bool palms;
  _ScenePainter(this.kind, this.seed, this.palms);

  @override
  void paint(Canvas c, Size s) {
    final rnd = math.Random(seed);
    final w = s.width, h = s.height;
    final horizon = h * (kind == SceneKind.lighthouse ? 0.62 : 0.52);
    // Sky
    c.drawRect(Offset.zero & s, Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF2E8FE0), Color(0xFF7CC8F2), Color(0xFFCDEBFA)]).createShader(Rect.fromLTWH(0, 0, w, horizon)));
    // Sun
    final sun = Offset(w * (0.62 + rnd.nextDouble() * 0.25), horizon * 0.28);
    c.drawCircle(sun, h * 0.16, Paint()..color = const Color(0x33FFF7C2));
    c.drawCircle(sun, h * 0.07, Paint()..color = const Color(0xFFFFF4B0));
    // Clouds
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < 3; i++) {
      final cx = w * rnd.nextDouble(), cy = horizon * (0.15 + rnd.nextDouble() * 0.45), r = h * (0.05 + rnd.nextDouble() * 0.04);
      c.drawCircle(Offset(cx, cy), r, cloud);
      c.drawCircle(Offset(cx + r * 1.1, cy + r * 0.2), r * 0.8, cloud);
      c.drawCircle(Offset(cx - r * 1.0, cy + r * 0.3), r * 0.7, cloud);
    }
    // Sea
    final seaTop = horizon;
    final seaBottom = kind == SceneKind.salina ? h : h * 0.8;
    c.drawRect(Rect.fromLTWH(0, seaTop, w, seaBottom - seaTop), Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: kind == SceneKind.salina
              ? const [Color(0xFF8FCFD8), Color(0xFFC9E8E2)]
              : const [Color(0xFF0A86B8), Color(0xFF19B5C9), Color(0xFF6EE0D8)])
          .createShader(Rect.fromLTWH(0, seaTop, w, seaBottom - seaTop)));
    // Glints
    final glint = Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 1.2;
    for (var i = 0; i < 10; i++) {
      final y = seaTop + (seaBottom - seaTop) * rnd.nextDouble() * 0.8 + 3;
      final x = w * rnd.nextDouble();
      c.drawLine(Offset(x, y), Offset(x + w * 0.05, y), glint);
    }
    if (kind != SceneKind.salina) {
      // Sand with gentle curve
      final sand = Path()
        ..moveTo(0, h * 0.74)
        ..quadraticBezierTo(w * 0.45, h * 0.70, w, h * 0.86)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      c.drawPath(sand, Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFF7E7C3), Color(0xFFEFD7A3)]).createShader(Rect.fromLTWH(0, h * 0.7, w, h * 0.3)));
      // Surf line
      final surf = Path()
        ..moveTo(0, h * 0.74)
        ..quadraticBezierTo(w * 0.45, h * 0.70, w, h * 0.86);
      c.drawPath(surf, Paint()..color = Colors.white.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 2);
    } else {
      // Mangrove shoreline
      final shore = Paint()..color = const Color(0xFF4E8F4A);
      c.drawRect(Rect.fromLTWH(0, horizon - h * 0.04, w, h * 0.05), shore);
    }
    if (kind == SceneKind.lighthouse) _lighthouse(c, Offset(w * 0.3, horizon), h);
    if (kind == SceneKind.town) _houses(c, horizon, w, h, rnd);
    if (palms) {
      _palm(c, Offset(w * 0.08, h * 0.9), h * 0.75, -0.18);
      if (w > h * 0.9) _palm(c, Offset(w * 0.93, h * 0.95), h * 0.6, 0.2);
    }
  }

  void _palm(Canvas c, Offset base, double height, double lean) {
    final trunk = Paint()..color = const Color(0xFF7A5230)..strokeWidth = height * 0.05..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final top = base + Offset(height * lean, -height);
    final ctrl = base + Offset(height * lean * 0.2, -height * 0.55);
    c.drawPath(Path()..moveTo(base.dx, base.dy)..quadraticBezierTo(ctrl.dx, ctrl.dy, top.dx, top.dy), trunk);
    final leaf = Paint()..color = const Color(0xFF1F7A3A)..style = PaintingStyle.stroke..strokeWidth = height * 0.035..strokeCap = StrokeCap.round;
    for (final a in [-2.6, -2.0, -1.2, -0.5, 0.2, 0.8]) {
      final end = top + Offset(math.cos(a) * height * 0.38, math.sin(a) * height * 0.22 + height * 0.1);
      final mid = top + Offset(math.cos(a) * height * 0.2, math.sin(a) * height * 0.2 - height * 0.04);
      c.drawPath(Path()..moveTo(top.dx, top.dy)..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy), leaf);
    }
  }

  void _lighthouse(Canvas c, Offset base, double h) {
    final th = h * 0.5, bw = h * 0.09, tw = h * 0.055;
    final body = Path()
      ..moveTo(base.dx - bw / 2, base.dy)
      ..lineTo(base.dx - tw / 2, base.dy - th)
      ..lineTo(base.dx + tw / 2, base.dy - th)
      ..lineTo(base.dx + bw / 2, base.dy)
      ..close();
    c.drawPath(body, Paint()..color = Colors.white);
    c.drawRect(Rect.fromLTWH(base.dx - tw * 0.8, base.dy - th - h * 0.06, tw * 1.6, h * 0.06), Paint()..color = const Color(0xFFC62828));
    c.drawCircle(Offset(base.dx, base.dy - th - h * 0.08), h * 0.03, Paint()..color = const Color(0xFFFFE082));
    c.drawRect(Rect.fromLTWH(base.dx - bw, base.dy - h * 0.02, bw * 2, h * 0.03), Paint()..color = const Color(0xFF6D8B5A));
  }

  void _houses(Canvas c, double horizon, double w, double h, math.Random rnd) {
    const colors = [Color(0xFFF8C8A0), Color(0xFFBFE3F2), Color(0xFFFFF3B0), Color(0xFFF5B7C5), Colors.white];
    var x = w * 0.25;
    while (x < w * 0.95) {
      final hw = w * (0.08 + rnd.nextDouble() * 0.05), hh = h * (0.08 + rnd.nextDouble() * 0.05);
      c.drawRect(Rect.fromLTWH(x, horizon - hh, hw, hh), Paint()..color = colors[rnd.nextInt(colors.length)]);
      c.drawPath(Path()..moveTo(x - 2, horizon - hh)..lineTo(x + hw / 2, horizon - hh - hh * 0.5)..lineTo(x + hw + 2, horizon - hh)..close(),
          Paint()..color = const Color(0xFFB5523B));
      x += hw + w * 0.02;
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.kind != kind || old.seed != seed || old.palms != palms;
}
