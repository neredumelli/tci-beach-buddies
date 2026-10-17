import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/shell.dart';
import '../../../app/theme.dart';
import '../../../core/models/poi.dart';
import '../../../shared/art.dart';
import '../../../shared/widgets.dart';
import '../../navigation/application/location_coordinator.dart';
import 'island_map.dart';

/// 06 Offline Map ("Grand Turk Map"): coastline, roads, water, markers, GPS
/// position, zoom, recenter, active route. Tap a marker -> preview card.
class MapScreen extends StatefulWidget {
  final String? focusPoiId;
  final bool pushed;
  const MapScreen({super.key, this.focusPoiId, this.pushed = false});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  Poi? _selected;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.focusPoiId != null && _selected == null) {
      _selected = AppScope.of(context).poiById(widget.focusPoiId!);
    }
  }

  void _zoom(double d) {
    if (!_ready) return;
    final c = _map.camera;
    _map.move(c.center, (c.zoom + d).clamp(12, 19).toDouble());
  }

  void _recenter() {
    final s = AppScope.of(context);
    final f = s.location.latestFix;
    final st = s.location.status;
    if (f == null || !(st == GpsStatus.good || st == GpsStatus.poor)) {
      showGpsUnavailableDialog(context, st);
      return;
    }
    if (_ready) _map.move(toLatLng(f.position), 16.5);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final basemap = s.bundle.basemap;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grand Turk Map'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => widget.pushed ? Navigator.pop(context) : ShellTabs.go(context, ShellTab.home),
        ),
        actions: [IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: () => openSearch(context))],
      ),
      body: basemap == null
          ? const Center(child: Padding(padding: EdgeInsets.all(16), child: DataHealthBanner()))
          : Column(children: [
              const SimulatedBanner(),
              Expanded(
                child: ListenableBuilder(
                  listenable: Listenable.merge([s.location, s.nav]),
                  builder: (context, _) {
                    final focus = widget.focusPoiId == null ? null : s.poiById(widget.focusPoiId!);
                    return Stack(children: [
                      IslandMap(
                        controller: _map,
                        basemap: basemap,
                        bounds: s.coverage,
                        pois: s.pois,
                        selectedPoiId: _selected?.id,
                        onPoiTap: (p) => setState(() => _selected = p),
                        onMapTap: () => setState(() => _selected = null),
                        userFix: s.location.latestFix,
                        route: s.nav.guidanceStarted ? s.nav.route : null,
                        destination: s.nav.guidanceStarted ? s.nav.destination : null,
                        initialCenter: focus?.display,
                        initialZoom: focus == null ? 13.2 : 16,
                        onReady: () => _ready = true,
                      ),
                      const Positioned(top: 10, left: 12, child: GpsStatusChip(compact: true)),
                      Positioned(
                        top: 10,
                        right: 12,
                        child: _RoundBtn(icon: Icons.navigation, tooltip: 'Centre on my location', onTap: _recenter),
                      ),
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            _RoundBtn(icon: Icons.add, tooltip: 'Zoom in', onTap: () => _zoom(1)),
                            const SizedBox(height: 8),
                            _RoundBtn(icon: Icons.remove, tooltip: 'Zoom out', onTap: () => _zoom(-1)),
                          ]),
                        ),
                      ),
                      if (_selected == null) ...[
                        const Positioned(left: 12, bottom: 16, child: ShipFab()),
                        if (s.nav.guidanceStarted && s.nav.isActive)
                          Positioned(
                            left: 70,
                            right: 12,
                            bottom: 16,
                            child: FilledButton.icon(
                              onPressed: () => showNavigationScreen(context),
                              icon: const Icon(Icons.navigation),
                              label: Text('Resume: ${s.nav.destination?.name ?? ''}', overflow: TextOverflow.ellipsis),
                            ),
                          ),
                      ],
                      if (_selected != null)
                        Positioned(left: 12, right: 12, bottom: 12, child: _PoiCard(poi: _selected!)),
                    ]);
                  },
                ),
              ),
            ]),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: BB.navy,
        shape: const CircleBorder(),
        elevation: 3,
        child: IconButton(
          tooltip: tooltip,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(icon, color: Colors.white),
          onPressed: onTap,
        ),
      );
}

class _PoiCard extends StatelessWidget {
  final Poi poi;
  const _PoiCard({required this.poi});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final dist = directDistance(context, poi.display);
    final canGo = poi.canNavigate && s.bundle.navigationAvailable;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            onTap: () => openDetails(context, poi),
            child: Row(children: [
              PlaceArt(poi: poi, width: 70, height: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(poi.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: BB.navy)),
                  Text(dist == null ? poi.category.label : '${poi.category.label} · $dist',
                      style: TextStyle(color: BB.category(poi.category), fontWeight: FontWeight.w600)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: canGo
                ? () => poi.isShipTerminal ? openReturnToShip(context) : openRoutePreview(context, poi)
                : null,
            icon: const Icon(Icons.navigation),
            label: Text(canGo ? 'Start Navigation' : 'Browse only'),
          ),
        ]),
      ),
    );
  }
}
