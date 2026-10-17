import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/geo/geo.dart';
import '../../../core/models/poi.dart';
import '../../../platform/location/geolocator_location_source.dart';
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
      RouteFailureCode.noRoute => 'No connected walking route exists to this destination on the offline map.',
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

/// Screen 5 - Live Navigation.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  /// Number of mounted navigation screens (used to avoid duplicates).
  static int mountedCount = 0;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _map = MapController();
  bool _follow = true;
  bool _mapReady = false;
  bool _leaving = false;
  late NavigationController _nav;
  late LocationCoordinator _loc;
  int _framedGeneration = -1;

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
    _nav.removeListener(_onNavChanged);
    _nav.addListener(_onNavChanged);
  }

  @override
  void dispose() {
    NavigationScreen.mountedCount--;
    _nav.removeListener(_onNavChanged);
    super.dispose();
  }

  void _onNavChanged() {
    if (!mounted || _leaving) return;
    if (_nav.phase == NavPhase.arrived && _nav.arrivedAt != null) {
      _leaving = true;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => ArrivalScreen(poiId: _nav.arrivedAt!.id),
      ));
      return;
    }
    if (_nav.phase == NavPhase.idle) {
      _leaving = true;
      Navigator.of(context).maybePop();
      return;
    }
    final r = _nav.route;
    if (!_mapReady) return;
    // Frame each NEW route once, then follow the visitor.
    if (r != null && r.requestId != _framedGeneration) {
      _framedGeneration = r.requestId;
      final pts = [...r.polyline, r.originFix];
      _map.fitCamera(CameraFit.coordinates(
        coordinates: toLatLngs(pts),
        padding: const EdgeInsets.fromLTRB(40, 170, 40, 260),
        maxZoom: 17.5,
      ));
      return;
    }
    final f = _loc.latestFix;
    if (_follow && f != null && _nav.phase == NavPhase.navigating) {
      _map.move(toLatLng(f.position), _map.camera.zoom < 16 ? 16.5 : _map.camera.zoom);
    }
  }

  Future<void> _changeDestination() async {
    final p = await pickDestination(context);
    if (p != null && mounted) {
      setState(() => _follow = true);
      _nav.selectDestination(p); // new route from the LATEST live fix
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final basemap = s.bundle.basemap;
    return PopScope(
      // Back never silently cancels navigation (UI spec 7): it just leaves
      // the screen; the route stays active and can be resumed.
      canPop: true,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: Listenable.merge([_nav, _loc, s.settings]),
          builder: (context, _) {
            final dest = _nav.destination;
            return Column(children: [
              const SimulatedBanner(),
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
                      showBuildings: true,
                      initialCenter: _loc.latestFix?.position ?? dest?.display,
                      initialZoom: 15,
                      onMapTap: () => setState(() => _follow = false),
                    ),
                  // Mark the map ready after first frame so camera calls are safe.
                  if (basemap != null) Builder(builder: (_) {
                    if (!_mapReady) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _mapReady = true;
                          _onNavChanged();
                        }
                      });
                    }
                    return const SizedBox.shrink();
                  }),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              tooltip: 'Back (navigation continues)',
                              icon: const Icon(Icons.arrow_back, color: BB.navy),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _TopBanner(nav: _nav, loc: _loc)),
                        ]),
                        const SizedBox(height: 8),
                        const Align(alignment: Alignment.centerLeft, child: GpsStatusChip(compact: true)),
                      ]),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(children: [
                      if (_loc.isSimulated) _DemoControls(nav: _nav),
                      const SizedBox(height: 8),
                      Material(
                        color: _follow ? BB.teal : Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          tooltip: _follow ? 'Following your position' : 'Follow my position',
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: Icon(Icons.navigation, color: _follow ? Colors.white : BB.navy),
                          onPressed: () {
                            setState(() => _follow = true);
                            final f = _loc.latestFix;
                            if (f != null) _map.move(toLatLng(f.position), 17);
                          },
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
              _BottomPanel(nav: _nav, onChange: _changeDestination),
            ]);
          },
        ),
      ),
    );
  }
}

class _TopBanner extends StatelessWidget {
  final NavigationController nav;
  final LocationCoordinator loc;
  const _TopBanner({required this.nav, required this.loc});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    IconData icon;
    String big;
    String small;
    Color bg = BB.navy;
    switch (nav.phase) {
      case NavPhase.waitingForFix:
        icon = Icons.gps_not_fixed;
        big = 'Waiting for GPS';
        small = _waitingText(loc.status);
        bg = const Color(0xFF37474F);
      case NavPhase.calculating:
        icon = Icons.alt_route;
        big = 'Calculating route…';
        small = 'From your current position';
      case NavPhase.rerouting:
        icon = Icons.alt_route;
        big = 'Off route';
        small = 'Recalculating from where you are now';
        bg = BB.warning;
      case NavPhase.noRoute:
        icon = Icons.block;
        big = 'No route';
        small = nav.failure == null ? '' : failureMessage(nav.failure!);
        bg = BB.danger;
      case NavPhase.bundleError:
        icon = Icons.error_outline;
        big = 'Navigation unavailable';
        small = 'Offline route data failed verification';
        bg = BB.danger;
      case NavPhase.navigating:
        if (nav.guidancePaused) {
          icon = Icons.gps_off;
          big = 'Guidance paused';
          small = 'GPS signal lost or inaccurate - keep to the route shown';
          bg = BB.warning;
          break;
        }
        final p = nav.progress;
        final m = p?.nextManeuver;
        icon = m == null ? Icons.straight : maneuverIcon(m.type);
        big = p?.distanceToNextManeuverM == null ? '' : s.settings.formatDistance(p!.distanceToNextManeuverM!);
        small = m?.instruction ?? 'Follow the highlighted route';
        if (big.isEmpty) big = s.settings.formatDistance(p?.remainingM ?? 0);
      case NavPhase.arrived:
        icon = Icons.flag;
        big = 'Arrived';
        small = nav.arrivedAt?.name ?? '';
      case NavPhase.idle:
        icon = Icons.navigation;
        big = 'Navigation ended';
        small = '';
    }
    return Semantics(
      liveRegion: true,
      label: '$big. $small',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          if (nav.phase == NavPhase.calculating || nav.phase == NavPhase.rerouting)
            const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
          else
            Icon(icon, color: Colors.white, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(big, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              if (small.isNotEmpty)
                Text(small, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _waitingText(GpsStatus s) => switch (s) {
        GpsStatus.permissionDenied => 'Allow location access to navigate. Browsing still works.',
        GpsStatus.servicesOff => 'Turn on Location Services to navigate.',
        GpsStatus.outsideCoverage => 'Your position is outside the Grand Turk map.',
        GpsStatus.unusable => 'GPS is too inaccurate. Move into open sky.',
        GpsStatus.stale => 'GPS signal lost. Waiting for a fresh position.',
        _ => 'The route will start from your live position.',
      };
}

class _BottomPanel extends StatelessWidget {
  final NavigationController nav;
  final VoidCallback onChange;
  const _BottomPanel({required this.nav, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final dest = nav.destination;
    final p = nav.progress;
    final r = nav.route;
    return Material(
      color: Colors.white,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              if (dest != null) PoiThumb(poi: dest, size: 44, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dest?.name ?? 'No destination',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: BB.navy)),
                  if (r != null && p != null)
                    Text(
                      '${s.settings.formatDistance(p.remainingM)} to go along route'
                      '${s.settings.showWalkingEstimate ? ' · ${s.settings.formatWalk(p.remainingM)} (estimate)' : ''}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  if (r != null && r.originSnapDistanceM > 25)
                    Text('Start: walk ${s.settings.formatDistance(r.originSnapDistanceM)} to the nearest path (dotted line)',
                        style: const TextStyle(fontSize: 12.5, color: BB.muted)),
                ]),
              ),
            ]),
            if (nav.phase == NavPhase.noRoute) ...[
              const SizedBox(height: 10),
              Text(nav.failure == null ? '' : failureMessage(nav.failure!),
                  style: const TextStyle(color: BB.danger, fontWeight: FontWeight.w600)),
              if (nav.failureDetail.isNotEmpty)
                Text(nav.failureDetail, style: const TextStyle(color: BB.muted, fontSize: 12.5)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: nav.retry, child: const Text('Retry'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: onChange, child: const Text('Other place'))),
              ]),
            ],
            if (nav.phase == NavPhase.waitingForFix &&
                (s.location.status == GpsStatus.permissionDenied || s.location.status == GpsStatus.servicesOff)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Open location settings'),
                onPressed: () async {
                  if (s.location.status == GpsStatus.servicesOff) {
                    await GeolocatorLocationSource.openLocationSettings();
                  } else {
                    await GeolocatorLocationSource.openAppSettings();
                  }
                  await s.location.retryPermission();
                },
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChange,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: BB.purple),
                  onPressed: (dest?.isShipTerminal ?? false) ? null : () => s.nav.returnToShip(),
                  icon: const Icon(Icons.directions_boat),
                  label: const Text('To Ship'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: BB.danger),
              onPressed: nav.stop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('End Navigation'),
            ),
          ]),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.all(6),
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
