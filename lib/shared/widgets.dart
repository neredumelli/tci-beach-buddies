import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/nav_actions.dart';
import '../app/theme.dart';
import '../core/geo/geo.dart';
import '../core/models/poi.dart';
import '../features/navigation/application/location_coordinator.dart';
import '../platform/location/geolocator_location_source.dart';
import 'art.dart';

/// GPS status: icon + TEXT (never colour alone).
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
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 11.5 : 13, fontWeight: FontWeight.w700, color: BB.ink)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Conspicuous banner shown whenever Demo (simulated) location is active.
class SimulatedBanner extends StatelessWidget {
  final bool safeTop;
  const SimulatedBanner({super.key, this.safeTop = false});
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
            top: safeTop,
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.science, size: 16, color: Colors.black),
                SizedBox(width: 6),
                Flexible(
                  child: Text('SIMULATED LOCATION - DEMO MODE',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 12.5)),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// "RETURN TO CRUISE PORT" button (Home: theme header colours; Arrival:
/// the theme's port colour) - critical persistent shortcut.
class ReturnToPortButton extends StatelessWidget {
  /// Fill colour; null = the theme's header gradient.
  final Color? color;
  final bool replace;
  final String label;
  const ReturnToPortButton({super.key, this.color, this.replace = false, this.label = 'RETURN TO CRUISE PORT'});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final enabled = s.bundle.navigationAvailable && s.nav.shipTerminal != null;
    final base = color ?? BB.navy;
    final fg = enabled ? BB.onColor(base) : Colors.white;
    final gradient = color == null
        ? BB.headerGradient
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(base, Colors.white, 0.22)!, base],
          );
    final radius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Return to cruise port',
      child: SizedBox(
        height: 62,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: enabled ? gradient : null,
            color: enabled ? null : Colors.grey,
            borderRadius: radius,
            boxShadow: enabled
                ? [BoxShadow(color: base.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: enabled ? () => openReturnToShip(context, replace: replace) : null,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.directions_boat, size: 26, color: fg),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small round ship action used on map screens.
class ShipFab extends StatelessWidget {
  const ShipFab({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final enabled = s.bundle.navigationAvailable && s.nav.shipTerminal != null;
    return FloatingActionButton.small(
      heroTag: null,
      tooltip: 'Return to Cruise Port',
      backgroundColor: enabled ? BB.navy : Colors.grey,
      foregroundColor: Colors.white,
      onPressed: enabled ? () => openReturnToShip(context) : null,
      child: const Icon(Icons.directions_boat),
    );
  }
}

/// Round category icon (Places list).
class CategoryCircle extends StatelessWidget {
  final PoiCategory category;
  final double size;
  const CategoryCircle({super.key, required this.category, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: BB.categoryGradient(category),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: BB.category(category).withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Icon(BB.categoryIcon(category), color: Colors.white, size: size * 0.55),
      );
}

/// Destination card row (04 Destination List / Search / Nearby).
class PlaceCard extends StatelessWidget {
  final Poi poi;
  final String? distance;
  final VoidCallback onTap;
  final bool highlighted;
  const PlaceCard({super.key, required this.poi, required this.distance, required this.onTap, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final cat = BB.category(poi.category);
    final radius = BorderRadius.circular(24);
    return Semantics(
      button: true,
      label: '${poi.name}${distance == null ? '' : ', $distance away'}${poi.canNavigate ? '' : ', browse only'}',
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: highlighted ? Border.all(color: BB.navy, width: 3) : null,
          boxShadow: [BoxShadow(color: cat.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6))],
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
                  colors: [Color(0x33000000), Color(0x00000000), Color(0xCC0B2F44)],
                  stops: [0, 0.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(gradient: BB.categoryGradient(poi.category), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(BB.categoryIcon(poi.category), size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(poi.category.label,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
            if (distance != null)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.place_rounded, size: 15, color: BB.navy),
                    const SizedBox(width: 2),
                    Text(distance!, style: TextStyle(color: BB.navy, fontSize: 13, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            Positioned(
              left: 14,
              right: 86,
              bottom: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (!poi.canNavigate)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFFE08A), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Browse only',
                        style: TextStyle(color: Color(0xFF6B4300), fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                Text(poi.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: heading(22, color: Colors.white, height: 1.05)
                        .copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 6)])),
              ]),
            ),
            Material(type: MaterialType.transparency, child: InkWell(onTap: onTap, child: const SizedBox.expand())),
          ]),
        ),
      ),
    );
  }
}
}

/// Straight-line distance from the current GOOD fix, or null (screen 04 rule:
/// "Distance only appears when a valid GPS position is available").
String? directDistance(BuildContext context, GeoPoint to, {bool verified = true}) {
  if (!verified) return null;
  final s = AppScope.of(context);
  final st = s.location.status;
  final f = s.location.latestFix;
  if (f == null || !(st == GpsStatus.good || st == GpsStatus.poor)) return null;
  return s.settings.formatDistance(haversineM(f.position, to));
}

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
      margin: const EdgeInsets.symmetric(vertical: 8),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
        child: const Text('Provisional - pending approval',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BB.warning)),
      );
}

// ------------------------------------------------- 12 Recovery dialogs --

/// "GPS Unavailable" (screen 12): explains, offers Open Settings.
Future<void> showGpsUnavailableDialog(BuildContext context, GpsStatus status) {
  final s = AppScope.of(context);
  final msg = switch (status) {
    GpsStatus.permissionDenied => 'Please allow location access for TCI Beach Buddies in your device settings.',
    GpsStatus.servicesOff => 'Please enable location services in your device settings.',
    GpsStatus.outsideCoverage => 'Your position is outside the Grand Turk map. Routes are only available on Grand Turk.',
    GpsStatus.unusable => 'GPS is too inaccurate right now. Move into open sky and try again.',
    _ => 'We could not get your current position yet. Move into open sky and try again.',
  };
  final canOpen = status == GpsStatus.permissionDenied || status == GpsStatus.servicesOff;
  return showDialog<void>(
    context: context,
    builder: (ctx) => _StatusDialog(
      icon: Icons.warning_rounded,
      iconColor: BB.danger,
      title: 'GPS Unavailable',
      message: msg,
      action: canOpen ? 'Open Settings' : 'OK',
      onAction: () async {
        Navigator.pop(ctx);
        if (!canOpen) return;
        if (status == GpsStatus.servicesOff) {
          await GeolocatorLocationSource.openLocationSettings();
        } else {
          await GeolocatorLocationSource.openAppSettings();
        }
        await s.location.retryPermission();
      },
    ),
  );
}

/// "No Route Found" (screen 12).
Future<void> showNoRouteDialog(BuildContext context, String message) => showDialog<void>(
      context: context,
      builder: (ctx) => _StatusDialog(
        icon: Icons.warning_rounded,
        iconColor: BB.orange,
        title: 'No Route Found',
        message: message,
        action: 'OK',
        onAction: () => Navigator.pop(ctx),
      ),
    );

class _StatusDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;
  const _StatusDialog({required this.icon, required this.iconColor, required this.title, required this.message,
      required this.action, required this.onAction});
  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: Icon(icon, color: iconColor, size: 52),
        title: Text(title, style: heading(24)),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: BB.blue, minimumSize: const Size.fromHeight(46)),
              onPressed: onAction,
              child: Text(action),
            ),
          ),
        ],
      );
}

/// Navy app bar used on pushed screens (back arrow + title + optional action).
PreferredSizeWidget navyBar(String title, {List<Widget>? actions, bool back = true}) => AppBar(flexibleSpace: const HeaderBackground(), 
      title: Text(title),
      automaticallyImplyLeading: back,
      actions: actions,
    );
