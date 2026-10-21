import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets.dart';
import '../../map/presentation/island_map.dart';
import '../application/navigation_controller.dart';
import '../domain/route_models.dart';
import 'navigation_screen.dart' show failureMessage;

/// 07 Route Preview and 10 Return to Cruise Port.
/// Shows the walking route calculated from the LATEST live GPS fix, its
/// along-route distance and walking time, and Start Navigation.
class RoutePreviewScreen extends StatefulWidget {
  final bool isReturn;
  const RoutePreviewScreen({super.key, this.isReturn = false});
  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  final _map = MapController();
  bool _ready = false;
  int _framed = -1;
  int _dialogShownForGen = -1;
  late NavigationController _nav;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nav = AppScope.of(context).nav;
    _nav.removeListener(_onNav);
    _nav.addListener(_onNav);
  }

  @override
  void dispose() {
    _nav.removeListener(_onNav);
    super.dispose();
  }

  void _onNav() {
    if (!mounted) return;
    final r = _nav.route;
    if (_ready && r != null && r.requestId != _framed) {
      _framed = r.requestId;
      _map.fitCamera(CameraFit.coordinates(
        coordinates: toLatLngs([...r.polyline, r.originFix]),
        padding: const EdgeInsets.fromLTRB(40, 40, 40, 60),
        maxZoom: 17,
      ));
    }
    // Screen 12 recovery dialogs, once per request.
    final gen = _nav.generation;
    if (_dialogShownForGen == gen) return;
    if (_nav.phase == NavPhase.noRoute && _nav.failure != null) {
      _dialogShownForGen = gen;
      showNoRouteDialog(context, failureMessage(_nav.failure!));
    } else if (_nav.phase == NavPhase.waitingForFix && _nav.failure == RouteFailureCode.noFreshFix) {
      _dialogShownForGen = gen;
      showGpsUnavailableDialog(context, AppScope.of(context).location.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final basemap = s.bundle.basemap;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Leaving the preview without starting cancels the previewed route.
        if (didPop && !_nav.guidanceStarted) _nav.stop();
      },
      child: Scaffold(
        appBar: AppBar(flexibleSpace: const HeaderBackground(), 
          title: Text(widget.isReturn ? 'Return to Cruise Port' : 'Route Preview'),
          actions: [
            if (!widget.isReturn)
              IconButton(
                tooltip: 'Return to Cruise Port instead',
                icon: const Icon(Icons.directions_boat),
                onPressed: () => openReturnToShip(context, replace: true),
              ),
          ],
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([_nav, s.location, s.settings]),
          builder: (context, _) {
            final dest = _nav.destination;
            final r = _nav.route;
            return Column(children: [
              const SimulatedBanner(),
              Expanded(
                child: basemap == null
                    ? const Center(child: DataHealthBanner())
                    : Stack(children: [
                        IslandMap(
                          controller: _map,
                          basemap: basemap,
                          bounds: s.coverage,
                          pois: [if (dest != null) dest],
                          destination: dest,
                          userFix: s.location.latestFix,
                          route: r,
                          initialCenter: dest?.display,
                          initialZoom: 15,
                          onReady: () {
                            _ready = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) => _onNav());
                          },
                        ),
                        const Positioned(top: 10, left: 12, child: GpsStatusChip(compact: true)),
                      ]),
              ),
              _PreviewCard(nav: _nav, isReturn: widget.isReturn),
            ]);
          },
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final NavigationController nav;
  final bool isReturn;
  const _PreviewCard({required this.nav, required this.isReturn});

  @override
  Widget build(BuildContext context) => BB.photo ? _buildPhoto(context) : _buildClassic(context);

  /// v2.0 look as presented to the customer, brighter (classic themes).
  Widget _buildClassic(BuildContext context) {
    final s = AppScope.of(context);
    final dest = nav.destination;
    final r = nav.route;
    final phase = nav.phase;
    Widget body;
    if (phase == NavPhase.navigating && r != null) {
      body = Row(children: [
        Icon(Icons.place, color: BB.navy, size: 18),
        const SizedBox(width: 4),
        Text(s.settings.formatDistance(r.distanceM), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(width: 22),
        Icon(Icons.schedule, color: BB.navy, size: 18),
        const SizedBox(width: 4),
        Text('${s.settings.walkMinutes(r.distanceM)} min (walk)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ]);
    } else if (phase == NavPhase.waitingForFix) {
      body = Text(
          nav.failure == RouteFailureCode.noFreshFix
              ? 'Waiting for your GPS position. The route always starts where you are now.'
              : 'Finding your GPS position…',
          style: const TextStyle(color: BB.muted));
    } else if (phase == NavPhase.calculating) {
      body = const Row(children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
        SizedBox(width: 10),
        Text('Calculating walking route…'),
      ]);
    } else if (phase == NavPhase.noRoute) {
      body = Text(nav.failure == null ? 'No route available.' : failureMessage(nav.failure!),
          style: const TextStyle(color: BB.danger, fontWeight: FontWeight.w600));
    } else if (phase == NavPhase.arrived) {
      body = Text(isReturn ? 'You are already at the Cruise Center.' : 'You are already at this destination.',
          style: const TextStyle(color: BB.success, fontWeight: FontWeight.w700));
    } else {
      body = const SizedBox.shrink();
    }
    final canStart = phase == NavPhase.navigating && r != null;
    return Material(
      color: Colors.white,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(isReturn ? Icons.directions_boat : Icons.place, color: BB.go),
              const SizedBox(width: 8),
              Expanded(
                child: Text(dest == null ? '—' : (isReturn ? 'Cruise Center' : dest.name),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: BB.navy)),
              ),
            ]),
            const SizedBox(height: 8),
            body,
            if (r != null && r.originSnapDistanceM > 25) ...[
              const SizedBox(height: 4),
              Text('Start: walk ${s.settings.formatDistance(r.originSnapDistanceM)} to the nearest path (dotted line)',
                  style: const TextStyle(fontSize: 12.5, color: BB.muted)),
            ],
            const SizedBox(height: 12),
            if (phase == NavPhase.noRoute || (phase == NavPhase.waitingForFix && nav.failure != null))
              OutlinedButton.icon(onPressed: nav.retry, icon: const Icon(Icons.refresh), label: const Text('Retry'))
            else if (phase == NavPhase.arrived)
              FilledButton(onPressed: () => goHome(context), child: const Text('Home'))
            else
              FilledButton.icon(
                onPressed: canStart ? () => startNavigation(context) : null,
                icon: const Icon(Icons.navigation),
                label: const Text('Start Navigation'),
              ),
          ]),
        ),
      ),
    );
  }

  /// Bold photo look (photo themes).
  Widget _buildPhoto(BuildContext context) {
    final s = AppScope.of(context);
    final dest = nav.destination;
    final r = nav.route;
    final phase = nav.phase;
    Widget body;
    if (phase == NavPhase.navigating && r != null) {
      Widget stat(IconData icon, String value, String label, Color tint) => Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Icon(icon, color: BB.navy, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(value, style: heading(22, color: BB.ink, height: 1.0)),
                    Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: BB.muted)),
                  ]),
                ),
              ]),
            ),
          );
      body = Row(children: [
        stat(Icons.straighten_rounded, s.settings.formatDistance(r.distanceM), 'walking route', BB.selectedRow),
        const SizedBox(width: 10),
        stat(Icons.schedule_rounded, '${s.settings.walkMinutes(r.distanceM)} min (walk)', 'at 4.5 km/h',
            const Color(0xFFFFEBD6)),
      ]);
    } else if (phase == NavPhase.waitingForFix) {
      body = Text(
          nav.failure == RouteFailureCode.noFreshFix
              ? 'Waiting for your GPS position. The route always starts where you are now.'
              : 'Finding your GPS position…',
          style: const TextStyle(color: BB.muted));
    } else if (phase == NavPhase.calculating) {
      body = const Row(children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
        SizedBox(width: 10),
        Text('Calculating walking route…'),
      ]);
    } else if (phase == NavPhase.noRoute) {
      body = Text(nav.failure == null ? 'No route available.' : failureMessage(nav.failure!),
          style: const TextStyle(color: BB.danger, fontWeight: FontWeight.w600));
    } else if (phase == NavPhase.arrived) {
      body = Text(isReturn ? 'You are already at the Cruise Center.' : 'You are already at this destination.',
          style: const TextStyle(color: BB.success, fontWeight: FontWeight.w700));
    } else {
      body = const SizedBox.shrink();
    }
    final canStart = phase == NavPhase.navigating && r != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: BB.navy.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: const Color(0xFFD5DEE4), borderRadius: BorderRadius.circular(5)),
              ),
            ),
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isReturn
                      ? BB.headerGradient
                      : (dest == null ? BB.headerGradient : BB.categoryGradient(dest.category)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(isReturn ? Icons.directions_boat_rounded : Icons.place_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(dest == null ? '—' : (isReturn ? 'Cruise Center' : dest.name),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: heading(24)),
              ),
            ]),
            const SizedBox(height: 12),
            body,
            if (r != null && r.originSnapDistanceM > 25) ...[
              const SizedBox(height: 4),
              Text('Start: walk ${s.settings.formatDistance(r.originSnapDistanceM)} to the nearest path (dotted line)',
                  style: const TextStyle(fontSize: 12.5, color: BB.muted)),
            ],
            const SizedBox(height: 12),
            if (phase == NavPhase.noRoute || (phase == NavPhase.waitingForFix && nav.failure != null))
              OutlinedButton.icon(onPressed: nav.retry, icon: const Icon(Icons.refresh), label: const Text('Retry'))
            else if (phase == NavPhase.arrived)
              FilledButton(onPressed: () => goHome(context), child: const Text('Home'))
            else
              FilledButton.icon(
                onPressed: canStart ? () => startNavigation(context) : null,
                icon: const Icon(Icons.navigation),
                label: const Text('Start Navigation'),
              ),
          ]),
        ),
      ),
    );
  }
}
