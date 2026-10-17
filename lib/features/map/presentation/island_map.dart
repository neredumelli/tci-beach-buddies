// Offline Grand Turk map. Layers are built from bundled vectors only: there is
// NO TileLayer and NO URL anywhere here, so the map cannot hit the network.
//
// Layer order (TDD 6): basemap -> route casing -> route -> POI markers ->
// live location -> destination annotation.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/geo/geo.dart';
import '../../../core/models/location_fix.dart';
import '../../../core/models/poi.dart';
import '../../navigation/domain/route_models.dart';
import '../data/basemap.dart';

/// THE GeoPoint -> LatLng conversion boundary (both are lat, lon order).
LatLng toLatLng(GeoPoint p) => LatLng(p.lat, p.lon);
List<LatLng> toLatLngs(List<GeoPoint> pts) => [for (final p in pts) toLatLng(p)];

/// Pre-built flutter_map primitives (built once per basemap, not per frame).
class BasemapLayers {
  final List<Polygon> base;
  final List<Polygon> buildings;
  final List<Polyline> roads;
  final List<MapLabel> labels;

  BasemapLayers._(this.base, this.buildings, this.roads, this.labels);

  static final Map<Basemap, BasemapLayers> _cache = {};

  factory BasemapLayers.of(Basemap m) => _cache.putIfAbsent(m, () => BasemapLayers._build(m));

  factory BasemapLayers._build(Basemap m) {
    final base = <Polygon>[];
    final buildings = <Polygon>[];
    for (final a in m.areas) {
      final (fill, border) = switch (a.kind) {
        AreaKind.land => (BB.land, const Color(0xFFBFD9A8)),
        AreaKind.water => (BB.sea, BB.sea),
        AreaKind.salina => (const Color(0xFFBFE3EA), const Color(0xFF9CCFD9)),
        AreaKind.wetland => (const Color(0xFFD4E8D0), const Color(0xFFD4E8D0)),
        AreaKind.beach => (BB.sand, BB.sand),
        AreaKind.park => (const Color(0xFFCFE8BE), const Color(0xFFCFE8BE)),
        AreaKind.runway => (const Color(0xFFD6D6D6), const Color(0xFFC4C4C4)),
        AreaKind.building => (const Color(0xFFE1D8CB), const Color(0xFFCBBFAE)),
      };
      final poly = Polygon(
        points: toLatLngs(a.outer),
        holePointsList: a.holes.isEmpty ? null : [for (final h in a.holes) toLatLngs(h)],
        color: fill,
        borderColor: border,
        borderStrokeWidth: a.kind == AreaKind.land ? 1.2 : 0.6,
      );
      (a.kind == AreaKind.building ? buildings : base).add(poly);
    }
    // Draw minor first so major roads sit on top.
    final lines = [...m.lines]..sort((a, b) => b.kind.index.compareTo(a.kind.index));
    final roads = <Polyline>[
      for (final l in lines)
        switch (l.kind) {
          LineKind.majorRoad => Polyline(
              points: toLatLngs(l.points), strokeWidth: 5, color: const Color(0xFFFFF4C2),
              borderStrokeWidth: 1.2, borderColor: const Color(0xFFD9B95A)),
          LineKind.minorRoad => Polyline(
              points: toLatLngs(l.points), strokeWidth: 3.5, color: Colors.white,
              borderStrokeWidth: 1, borderColor: const Color(0xFFC9C3B3)),
          LineKind.track => Polyline(
              points: toLatLngs(l.points), strokeWidth: 2, color: const Color(0xFFB08B5A),
              pattern: StrokePattern.dashed(segments: const [6, 4])),
          LineKind.path => Polyline(
              points: toLatLngs(l.points), strokeWidth: 1.6, color: const Color(0xFFE07A5F),
              pattern: StrokePattern.dashed(segments: const [4, 4])),
        }
    ];
    return BasemapLayers._(base, buildings, roads, m.labels);
  }
}

class IslandMap extends StatelessWidget {
  final MapController controller;
  final Basemap basemap;
  final GeoBounds bounds;
  final List<Poi> pois;
  final String? selectedPoiId;
  final ValueChanged<Poi>? onPoiTap;
  final VoidCallback? onMapTap;
  final LocationFix? userFix;
  final PlannedRoute? route;
  final Poi? destination;
  final bool showBuildings;
  final GeoPoint? initialCenter;
  final double initialZoom;
  final VoidCallback? onReady;

  const IslandMap({
    super.key,
    required this.controller,
    required this.basemap,
    required this.bounds,
    required this.pois,
    this.selectedPoiId,
    this.onPoiTap,
    this.onMapTap,
    this.userFix,
    this.route,
    this.destination,
    this.showBuildings = true,
    this.initialCenter,
    this.initialZoom = 13.2,
    this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final layers = BasemapLayers.of(basemap);
    final r = route;
    final fix = userFix;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: toLatLng(initialCenter ?? bounds.center),
        initialZoom: initialZoom,
        minZoom: 12,
        maxZoom: 19,
        backgroundColor: BB.sea,
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(LatLng(bounds.south, bounds.west), LatLng(bounds.north, bounds.east)),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, __) => onMapTap?.call(),
        onMapReady: onReady,
      ),
      children: [
        PolygonLayer(polygons: layers.base),
        if (showBuildings) _ZoomGate(minZoom: 15.5, child: PolygonLayer(polygons: layers.buildings)),
        PolylineLayer(polylines: layers.roads),
        _ZoomGate(
          minZoom: 13.5,
          child: MarkerLayer(markers: [
            for (final l in layers.labels)
              Marker(
                point: toLatLng(l.at),
                width: 140,
                height: 24,
                child: IgnorePointer(
                  child: Center(
                    child: Text(l.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: l.kind == 'place' ? 13 : 11,
                          fontWeight: l.kind == 'place' ? FontWeight.w800 : FontWeight.w600,
                          fontStyle: l.kind == 'water' ? FontStyle.italic : FontStyle.normal,
                          color: l.kind == 'water' ? const Color(0xFF2B6F86) : const Color(0xFF4A4A4A),
                          shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
                        )),
                  ),
                ),
              ),
          ]),
        ),
        if (r != null) ...[
          // Off-network walk from the GPS fix to the snapped path (dashed,
          // clearly not a road route).
          if (r.originSnapDistanceM > 5)
            PolylineLayer(polylines: [
              Polyline(
                points: [toLatLng(r.originFix), toLatLng(r.snappedOrigin)],
                strokeWidth: 3,
                color: BB.route.withValues(alpha: 0.7),
                pattern: StrokePattern.dotted(),
              ),
            ]),
          PolylineLayer(polylines: [
            Polyline(points: toLatLngs(r.polyline), strokeWidth: 9, color: Colors.white),
            Polyline(points: toLatLngs(r.polyline), strokeWidth: 6, color: BB.route),
          ]),
        ],
        MarkerLayer(markers: [
          for (final p in pois)
            Marker(
              point: toLatLng(p.display),
              width: p.id == selectedPoiId || p.id == destination?.id ? 46 : 36,
              height: p.id == selectedPoiId || p.id == destination?.id ? 46 : 36,
              alignment: Alignment.topCenter,
              child: _PoiPin(
                poi: p,
                selected: p.id == selectedPoiId || p.id == destination?.id,
                onTap: onPoiTap == null ? null : () => onPoiTap!(p),
              ),
            ),
        ]),
        if (fix != null) ...[
          CircleLayer(circles: [
            CircleMarker(
              point: toLatLng(fix.position),
              radius: fix.accuracyM,
              useRadiusInMeter: true,
              color: (fix.isSimulated ? Colors.amber : BB.user).withValues(alpha: 0.15),
              borderColor: (fix.isSimulated ? Colors.amber : BB.user).withValues(alpha: 0.5),
              borderStrokeWidth: 1,
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: toLatLng(fix.position),
              width: 26,
              height: 26,
              child: Semantics(
                label: fix.isSimulated ? 'Simulated position' : 'Your location',
                child: Container(
                  decoration: BoxDecoration(
                    color: fix.isSimulated ? Colors.amber.shade700 : BB.user,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
                  ),
                  child: fix.isSimulated
                      ? const Center(
                          child: Text('S', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)))
                      : null,
                ),
              ),
            ),
          ]),
        ],
        Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            color: Colors.white.withValues(alpha: 0.75),
            child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10)),
          ),
        ),
      ],
    );
  }
}

/// Shows [child] only at or above [minZoom].
class _ZoomGate extends StatelessWidget {
  final double minZoom;
  final Widget child;
  const _ZoomGate({required this.minZoom, required this.child});
  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    return zoom >= minZoom ? child : const SizedBox.shrink();
  }
}

class _PoiPin extends StatelessWidget {
  final Poi poi;
  final bool selected;
  final VoidCallback? onTap;
  const _PoiPin({required this.poi, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = poi.isShipTerminal ? BB.purple : BB.category(poi.category);
    return Semantics(
      button: onTap != null,
      label: '${poi.name}, ${poi.category.label}',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(alignment: Alignment.topCenter, children: [
          Icon(Icons.location_on, color: c, size: selected ? 46 : 36,
              shadows: const [Shadow(color: Color(0x66000000), blurRadius: 4)]),
          Padding(
            padding: EdgeInsets.only(top: selected ? 9 : 7),
            child: Icon(poi.isShipTerminal ? Icons.directions_boat : BB.categoryIcon(poi.category),
                color: Colors.white, size: selected ? 18 : 14),
          ),
        ]),
      ),
    );
  }
}
