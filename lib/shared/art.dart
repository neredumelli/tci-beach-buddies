// Vector "photo" artwork drawn in code: tropical sky, turquoise sea, sand,
// palms and the lighthouse. Used for splash, home hero, destination cards,
// details hero and arrival hero until rights-cleared photographs are approved.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/models/poi.dart';
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
  const PlaceArt({super.key, required this.poi, this.width, this.height, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    final photo = Photos.of(poi.id);
    if (photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(photo.asset, fit: BoxFit.cover, semanticLabel: 'Photo of ${poi.name}',
              errorBuilder: (_, __, ___) => TropicalScene(kind: sceneFor(poi), seed: poi.id.hashCode)),
        ),
      );
    }
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
