import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/nav_actions.dart';
import '../app/theme.dart';
import '../core/models/poi.dart';
import '../features/navigation/application/location_coordinator.dart';

/// GPS status: icon + TEXT (never colour alone, UI spec 8).
class GpsStatusChip extends StatelessWidget {
  final bool compact;
  const GpsStatusChip({super.key, this.compact = false});

  static (IconData, Color, String) describe(GpsStatus s, double? acc) => switch (s) {
        GpsStatus.good => (Icons.gps_fixed, BB.success, 'GPS good${acc == null ? '' : ' ±${acc.round()} m'}'),
        GpsStatus.poor => (Icons.gps_not_fixed, BB.warning, 'GPS weak${acc == null ? '' : ' ±${acc.round()} m'}'),
        GpsStatus.acquiring => (Icons.gps_not_fixed, BB.muted, 'Finding GPS…'),
        GpsStatus.stale => (Icons.gps_off, BB.warning, 'GPS signal lost'),
        GpsStatus.unusable => (Icons.gps_off, BB.danger, 'GPS too inaccurate'),
        GpsStatus.outsideCoverage => (Icons.wrong_location, BB.danger, 'Outside Grand Turk map'),
        GpsStatus.permissionDenied => (Icons.location_disabled, BB.danger, 'Location permission off'),
        GpsStatus.servicesOff => (Icons.location_disabled, BB.danger, 'Location services off'),
        GpsStatus.idle => (Icons.gps_off, BB.muted, 'GPS idle'),
      };

  @override
  Widget build(BuildContext context) {
    final loc = AppScope.of(context).location;
    return ListenableBuilder(
      listenable: loc,
      builder: (context, _) {
        final (icon, color, text) = describe(loc.status, loc.latestFix?.accuracyM);
        final label = loc.isSimulated ? 'SIMULATED · $text' : text;
        return Semantics(
          label: label,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.6)),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: compact ? 14 : 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(fontSize: compact ? 11.5 : 13, fontWeight: FontWeight.w700, color: BB.ink)),
            ]),
          ),
        );
      },
    );
  }
}

/// Conspicuous banner shown whenever Demo (simulated) location is active.
class SimulatedBanner extends StatelessWidget {
  const SimulatedBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final loc = AppScope.of(context).location;
    return ListenableBuilder(
      listenable: loc,
      builder: (context, _) {
        if (!loc.isSimulated) return const SizedBox.shrink();
        return Material(
          color: const Color(0xFFFFD600),
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.science, size: 18, color: Colors.black),
                SizedBox(width: 6),
                Flexible(
                  child: Text('SIMULATED LOCATION - DEMO MODE, NOT LIVE GPS',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.3)),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// Persistent Return to Ship action (Home, Map, Details, Navigation).
class ShipButton extends StatelessWidget {
  final bool extended;
  final bool replaceRoute;
  const ShipButton({super.key, this.extended = true, this.replaceRoute = false});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final enabled = s.bundle.navigationAvailable && s.nav.shipTerminal != null;
    return Semantics(
      button: true,
      label: 'Return to ship',
      child: extended
          ? FloatingActionButton.extended(
              heroTag: null,
              backgroundColor: enabled ? BB.purple : Colors.grey,
              foregroundColor: Colors.white,
              onPressed: enabled ? () => returnToShip(context, replace: replaceRoute) : null,
              icon: const Icon(Icons.directions_boat),
              label: const Text('Return to Ship', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : FloatingActionButton(
              heroTag: null,
              tooltip: 'Return to Ship',
              backgroundColor: enabled ? BB.purple : Colors.grey,
              foregroundColor: Colors.white,
              onPressed: enabled ? () => returnToShip(context, replace: replaceRoute) : null,
              child: const Icon(Icons.directions_boat),
            ),
    );
  }
}

/// Category illustration used in place of photographs (no imagery has been
/// rights-cleared yet - UI spec 7).
class PoiThumb extends StatelessWidget {
  final Poi poi;
  final double size;
  final double radius;
  const PoiThumb({super.key, required this.poi, this.size = 64, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final c = BB.category(poi.category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.withValues(alpha: 0.85), c],
        ),
      ),
      child: Icon(BB.categoryIcon(poi.category), color: Colors.white, size: size * 0.5),
    );
  }
}

/// Banner explaining offline-data problems (navigation disabled etc.).
class DataHealthBanner extends StatelessWidget {
  const DataHealthBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final b = AppScope.of(context).bundle;
    if (b.navigationAvailable) return const SizedBox.shrink();
    final msg = !b.mapAvailable
        ? 'Offline map data is missing or damaged. Navigation is disabled.'
        : 'Offline route data failed verification. You can browse, but navigation is disabled.';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.warning_amber, color: BB.danger),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class ProvisionalBadge extends StatelessWidget {
  const ProvisionalBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
      child: const Text('Provisional - pending approval',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BB.warning)),
    );
  }
}
