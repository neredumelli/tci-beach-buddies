import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/shell.dart';
import '../../../app/theme.dart';
import '../../../core/geo/geo.dart';
import '../../../core/models/poi.dart';
import '../../../shared/widgets.dart';
import '../../navigation/application/location_coordinator.dart';
import 'island_map.dart';

/// Screen 2 - Explore Map.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  Poi? _selected;
  bool _buildings = true;
  PoiCategory? _filter;

  void _recenter() {
    final s = AppScope.of(context);
    final f = s.location.latestFix;
    final st = s.location.status;
    if (f == null || !(st == GpsStatus.good || st == GpsStatus.poor)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(GpsStatusChip.describe(st, null).$3 + ' - cannot centre on your location.'),
      ));
      return;
    }
    _map.move(toLatLng(f.position), 16.5);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final basemap = s.bundle.basemap;
    if (basemap == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Explore Grand Turk')),
        body: const Center(child: DataHealthBanner()),
      );
    }
    final pois = s.pois.where((p) => _filter == null || p.category == _filter || p.isShipTerminal).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Grand Turk'),
        actions: [
          IconButton(
            tooltip: 'Settings and offline status',
            icon: const Icon(Icons.offline_pin_outlined),
            onPressed: () => ShellTabs.go(context, ShellTab.more),
          ),
        ],
      ),
      body: Column(children: [
        const SimulatedBanner(),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([s.location, s.nav]),
            builder: (context, _) => Stack(children: [
              IslandMap(
                controller: _map,
                basemap: basemap,
                bounds: s.coverage,
                pois: pois,
                selectedPoiId: _selected?.id,
                onPoiTap: (p) => setState(() => _selected = p),
                onMapTap: () => setState(() => _selected = null),
                userFix: s.location.latestFix,
                route: s.nav.route,
                destination: s.nav.destination,
                showBuildings: _buildings,
              ),
            Positioned(
              top: 10,
              left: 12,
              right: 70,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ShellTabs.go(context, ShellTab.destinations),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Row(children: [
                        Icon(Icons.search, color: BB.muted),
                        SizedBox(width: 10),
                        Text('Search destinations…', style: TextStyle(color: BB.muted, fontSize: 15)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const GpsStatusChip(compact: true),
              ]),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: Column(children: [
                _RoundButton(
                  icon: Icons.filter_list,
                  tooltip: 'Filter categories',
                  onTap: _showFilter,
                  active: _filter != null,
                ),
                const SizedBox(height: 10),
                _RoundButton(
                  icon: Icons.layers,
                  tooltip: _buildings ? 'Hide buildings' : 'Show buildings',
                  onTap: () => setState(() => _buildings = !_buildings),
                ),
                const SizedBox(height: 10),
                _RoundButton(icon: Icons.my_location, tooltip: 'Centre on my location', onTap: _recenter),
              ]),
            ),
            if (s.nav.isActive && _selected == null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 84,
                child: Material(
                  color: BB.navy,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    leading: const Icon(Icons.navigation, color: Colors.white),
                    title: Text('Navigating to ${s.nav.destination?.name ?? ''}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    trailing: const Text('Resume', style: TextStyle(color: Colors.white)),
                    onTap: () => showNavigationScreen(context),
                  ),
                ),
              ),
            if (_selected != null)
              Positioned(left: 12, right: 12, bottom: 16, child: _PoiPreview(poi: _selected!)),
            if (_selected == null)
              const Positioned(right: 14, bottom: 16, child: ShipButton()),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showFilter() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            title: const Text('All categories'),
            trailing: _filter == null ? const Icon(Icons.check) : null,
            onTap: () {
              setState(() => _filter = null);
              Navigator.pop(ctx);
            },
          ),
          for (final c in PoiCategory.values)
            if (AppScope.of(context).pois.any((p) => p.category == c && !p.isShipTerminal))
              ListTile(
                leading: Icon(BB.categoryIcon(c), color: BB.category(c)),
                title: Text(c.pluralLabel),
                trailing: _filter == c ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() => _filter = c);
                  Navigator.pop(ctx);
                },
              ),
        ]),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? BB.teal : Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: tooltip,
        iconSize: 24,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon, color: active ? Colors.white : BB.navy),
        onPressed: onTap,
      ),
    );
  }
}

class _PoiPreview extends StatelessWidget {
  final Poi poi;
  const _PoiPreview({required this.poi});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.location.latestFix;
    final good = s.location.status == GpsStatus.good || s.location.status == GpsStatus.poor;
    final direct = (f != null && good) ? haversineM(f.position, poi.display) : null;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          PoiThumb(poi: poi, size: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(poi.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
              const SizedBox(height: 2),
              Text(
                direct == null
                    ? poi.category.label
                    : '${poi.category.label} · ${s.settings.formatDistance(direct)} direct',
                style: TextStyle(color: BB.category(poi.category), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => openDetails(context, poi),
                  child: const Text('View Details'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
