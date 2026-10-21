import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/geo/geo.dart';
import '../../../core/models/poi.dart';
import '../../../shared/widgets.dart';
import '../../map/presentation/island_map.dart';
import '../application/location_coordinator.dart';
import '../application/navigation_controller.dart';
import '../domain/route_models.dart';
import 'arrival_screen.dart';

String failureMessage(RouteFailureCode code) => switch (code) {
      RouteFailureCode.noFreshFix => 'We do not have a current GPS position yet. Move into open sky and wait a moment.',
      RouteFailureCode.lowAccuracy => 'Your GPS position is too inaccurate to plan a route safely.',
      RouteFailureCode.outsideCoverage => 'You appear to be outside the Grand Turk map area.',
      RouteFailureCode.noRoadSnap => 'You are too far from any mapped road or path to start a route.',
      RouteFailureCode.noRoute => 'Unable to calculate a walking route to this destination.',
      RouteFailureCode.accessRestricted => 'This destination has no verified walking access point.',
      RouteFailureCode.bundleInvalid => 'Offline route data is not valid. Navigation is disabled.',
    };

IconData maneuverIcon(ManeuverType t) => switch (t) {
      ManeuverType.depart => Icons.straight,
      ManeuverType.slightLeft => Icons.turn_slight_left,
      ManeuverType.left => Icons.turn_left,
      ManeuverType.sharpLeft => Icons.turn_sharp_left,
      ManeuverType.slightRight => Icons.turn_slight_right,
      ManeuverType.right => Icons.turn_right,
      ManeuverType.sharpRight => Icons.turn_sharp_right,
      ManeuverType.uTurn => Icons.u_turn_left,
      ManeuverType.arrive => Icons.flag,
    };

/// 08 Turn-by-Turn Navigation: navy maneuver banner, live map + GPS marker,
/// mute, recenter, Stop / Change / Return, and a navy bar with remaining
/// distance, minutes and ETA.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});
  static int mountedCount = 0;
  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _map = MapController();
  bool _follow = true;
  bool _ready = false;
  bool _leaving = false;
  int _framed = -1;
  late NavigationController _nav;
  late LocationCoordinator _loc;

  @override
  void initState() {
    super.initState();
    NavigationScreen.mountedCount++;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context);
    _nav = s.nav;
    _loc = s.location;
    _nav.removeListener(_onNav);
    _nav.addListener(_onNav);
  }

  @override
  void dispose() {
    NavigationScreen.mountedCount--;
    _nav.removeListener(_onNav);
    super.dispose();
  }

  void _onNav() {
    if (!mounted || _leaving) return;
    if (_nav.phase == NavPhase.arrived && _nav.arrivedAt != null) {
      _leaving = true;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => ArrivalScreen(poiId: _nav.arrivedAt!.id)));
      return;
    }
    if (_nav.phase == NavPhase.idle) {
      _leaving = true;
      Navigator.of(context).maybePop();
      return;
    }
    if (!_ready) return;
    final r = _nav.route;
    if (r != null && r.requestId != _framed) {
      _framed = r.requestId;
      final f = _loc.latestFix;
      _map.move(toLatLng(f?.position ?? r.snappedOrigin), 17);
      return;
    }
    final f = _loc.latestFix;
    if (_follow && f != null && _nav.phase == NavPhase.navigating) {
      _map.move(toLatLng(f.position), _map.camera.zoom < 16 ? 17 : _map.camera.zoom);
    }
  }

  Future<void> _change() async {
    final p = await pickDestination(context);
    if (p != null && mounted) {
      setState(() => _follow = true);
      _nav.selectDestination(p, startGuidance: true); // from the LATEST live fix
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final basemap = s.bundle.basemap;
    return Scaffold(
      backgroundColor: BB.navy,
      body: ListenableBuilder(
        listenable: Listenable.merge([_nav, _loc, s.settings]),
        builder: (context, _) {
          final dest = _nav.destination;
          return Column(children: [
            const SimulatedBanner(safeTop: true),
            Expanded(
              child: Stack(children: [
                if (basemap != null)
                  IslandMap(
                    controller: _map,
                    basemap: basemap,
                    bounds: s.coverage,
                    pois: [if (dest != null) dest],
                    destination: dest,
                    userFix: _loc.latestFix,
                    route: _nav.route,
                    initialCenter: _loc.latestFix?.position ?? dest?.display,
                    initialZoom: 16.5,
                    onMapTap: () => setState(() => _follow = false),
                    onReady: () {
                      _ready = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) => _onNav());
                    },
                  ),
                // Pinned to the top and sized to its content, so the map stays visible.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                      child: _ManeuverBanner(nav: _nav, loc: _loc, onBack: () => Navigator.of(context).maybePop()),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(children: [
                    if (_loc.isSimulated) _DemoControls(nav: _nav),
                    const SizedBox(height: 8),
                    _CircleBtn(
                      icon: s.settings.voiceGuidance ? Icons.volume_up : Icons.volume_off,
                      tooltip: s.settings.voiceGuidance ? 'Mute voice' : 'Unmute voice',
                      onTap: () {
                        s.settings.setVoiceGuidance(!s.settings.voiceGuidance);
                        if (!s.settings.voiceGuidance) s.voice.stop();
                      },
                    ),
                    const SizedBox(height: 8),
                    _CircleBtn(
                      icon: Icons.my_location,
                      tooltip: 'Recenter',
                      active: _follow,
                      onTap: () {
                        setState(() => _follow = true);
                        final f = _loc.latestFix;
                        if (f != null && _ready) _map.move(toLatLng(f.position), 17);
                      },
                    ),
                  ]),
                ),
              ]),
            ),
            _ActionRow(nav: _nav, onChange: _change),
            _StatsBar(nav: _nav),
          ]);
        },
      ),
    );
  }
}

class _ManeuverBanner extends StatelessWidget {
  final NavigationController nav;
  final LocationCoordinator loc;
  final VoidCallback onBack;
  const _ManeuverBanner({required this.nav, required this.loc, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    IconData icon = Icons.navigation;
    String big = '';
    String small = '';
    Color bg = BB.navy;
    var spinner = false;
    switch (nav.phase) {
      case NavPhase.waitingForFix:
        icon = Icons.gps_not_fixed;
        big = 'Waiting for GPS';
        small = 'The route will start from your live position.';
        bg = const Color(0xFF37474F);
      case NavPhase.calculating:
        big = 'Calculating route…';
        spinner = true;
      case NavPhase.rerouting:
        big = 'Off route';
        small = 'Recalculating from where you are now';
        bg = BB.warning;
        spinner = true;
      case NavPhase.noRoute:
        icon = Icons.block;
        big = 'No route';
        small = nav.failure == null ? '' : failureMessage(nav.failure!);
        bg = BB.danger;
      case NavPhase.bundleError:
        icon = Icons.error_outline;
        big = 'Navigation unavailable';
        bg = BB.danger;
      case NavPhase.navigating:
        if (nav.guidancePaused) {
          icon = Icons.gps_off;
          big = 'Guidance paused';
          small = 'GPS signal lost - keep to the route shown';
          bg = BB.warning;
          break;
        }
        final p = nav.progress;
        final m = p?.nextManeuver;
        final d = p?.distanceToNextManeuverM;
        icon = m == null ? Icons.straight : maneuverIcon(m.type);
        big = m == null ? 'Follow the route' : m.instruction;
        small = d == null ? '' : s.settings.formatDistance(d);
      case NavPhase.arrived:
        icon = Icons.flag;
        big = 'Arrived';
      case NavPhase.idle:
        big = 'Navigation ended';
    }
    return Semantics(
      liveRegion: true,
      label: '$big. $small',
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
        decoration: BoxDecoration(
          color: bg,
          gradient: bg == BB.navy ? BB.headerGradient : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(children: [
          IconButton(
            tooltip: 'Back (navigation continues)',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
          ),
          if (spinner)
            const SizedBox(width: 44, height: 44, child: Padding(
              padding: EdgeInsets.all(6), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)))
          else
            Icon(icon, color: Colors.white, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(big, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              if (small.isNotEmpty)
                Text(small, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final NavigationController nav;
  final VoidCallback onChange;
  const _ActionRow({required this.nav, required this.onChange});
  @override
  Widget build(BuildContext context) {
    final isShip = nav.destination?.isShipTerminal ?? false;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(children: [
        Expanded(
          child: _ActionBtn(icon: Icons.stop_circle_outlined, label: 'Stop', color: BB.danger, onTap: nav.stop),
        ),
        const SizedBox(width: 8),
        Expanded(child: _ActionBtn(icon: Icons.swap_horiz, label: 'Change', color: BB.blue, onTap: onChange)),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionBtn(
            icon: Icons.directions_boat,
            label: 'Return',
            color: BB.navy,
            onTap: isShip ? null : () => openReturnToShip(context, replace: true),
          ),
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          foregroundColor: color,
          side: BorderSide(color: onTap == null ? Colors.black12 : color, width: 1.6),
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 14.5)),
      );
}

class _StatsBar extends StatelessWidget {
  final NavigationController nav;
  const _StatsBar({required this.nav});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = nav.progress;
    final rem = p?.remainingM ?? nav.route?.distanceM;
    Widget cell(String t) => Expanded(
        child: Text(t, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)));
    Widget sep() => Container(width: 1, height: 26, color: Colors.white30);
    return Container(
      decoration: BoxDecoration(gradient: BB.headerGradient),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: rem == null
              ? Text(nav.destination?.name ?? '', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))
              : Row(children: [
                  cell(s.settings.formatDistance(rem)),
                  sep(),
                  cell('${s.settings.walkMinutes(rem)} min'),
                  sep(),
                  cell('ETA ${s.settings.eta(rem)}'),
                ]),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  const _CircleBtn({required this.icon, required this.tooltip, required this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) => Material(
        color: active ? BB.blue : Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: IconButton(
          tooltip: tooltip,
          constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
          icon: Icon(icon, color: active ? Colors.white : BB.navy, size: 26),
          onPressed: onTap,
        ),
      );
}

/// QA/demo-only controls; visible only while SIMULATED location is active.
class _DemoControls extends StatelessWidget {
  final NavigationController nav;
  const _DemoControls({required this.nav});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final demo = s.demoSource;
    if (demo == null) return const SizedBox.shrink();
    final r = nav.route;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFFFD600), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        const Text('DEMO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
        IconButton(
          tooltip: 'Simulate walking the route',
          icon: const Icon(Icons.directions_walk),
          onPressed: r == null ? null : () => demo.walkAlong([r.originFix, ...r.polyline]),
        ),
        IconButton(
          tooltip: 'Simulate stepping 60 m off route',
          icon: const Icon(Icons.wrong_location),
          onPressed: demo.position == null
              ? null
              : () {
                  final p = demo.position!;
                  demo.placeAt(GeoPoint(p.lat + metersToLatDeg(60), p.lon));
                },
        ),
        IconButton(
          tooltip: 'Place simulated position at a destination',
          icon: const Icon(Icons.pin_drop),
          onPressed: () async {
            final Poi? p = await pickDestination(context);
            if (p != null) demo.placeAt(p.approach ?? p.display);
          },
        ),
      ]),
    );
  }
}
