import '../geo/geo.dart';

enum PoiCategory { beach, landmark, historic, dining, nature, services }

extension PoiCategoryLabel on PoiCategory {
  String get label => switch (this) {
        PoiCategory.beach => 'Beach',
        PoiCategory.landmark => 'Landmark',
        PoiCategory.historic => 'Historic Site',
        PoiCategory.dining => 'Dining',
        PoiCategory.nature => 'Nature',
        PoiCategory.services => 'Services',
      };

  String get pluralLabel => switch (this) {
        PoiCategory.beach => 'Beaches',
        PoiCategory.landmark => 'Landmarks',
        PoiCategory.historic => 'Historic',
        PoiCategory.dining => 'Dining',
        PoiCategory.nature => 'Nature',
        PoiCategory.services => 'Services',
      };
}

/// A destination from the bundled POI register.
///
/// The display pin and the routing approach point are deliberately separate
/// (TDD 3.3): a beach pin may sit on the sand while the approach point is the
/// verified spot on the path network where the visitor arrives.
class Poi {
  final String id;
  final String name;
  final PoiCategory category;
  final GeoPoint display;

  /// Network point used as the routing destination. Null => browse-only.
  final GeoPoint? approach;

  /// Whether the pipeline proved the approach point reachable on the graph.
  final bool routable;

  /// Human-readable reason when not routable (e.g. offshore cay).
  final String? notRoutableReason;
  final String description;
  final String accessNotes;

  /// 'provisional' until the business owner approves the register (OD-01/02).
  final String approvalStatus;

  /// 'osm:<type>/<id>' when matched to source data, else 'register'.
  final String locationSource;
  final bool isShipTerminal;

  /// Optional bundled narration clip (assets/audio/...), only if approved.
  final String? audioAsset;

  const Poi({
    required this.id,
    required this.name,
    required this.category,
    required this.display,
    required this.approach,
    required this.routable,
    required this.notRoutableReason,
    required this.description,
    required this.accessNotes,
    required this.approvalStatus,
    required this.locationSource,
    required this.isShipTerminal,
    this.audioAsset,
  });

  bool get isApproved => approvalStatus == 'approved';
  bool get canNavigate => routable && approach != null;

  factory Poi.fromJson(Map<String, dynamic> j) {
    final ap = j['approach'];
    return Poi(
      id: j['id'] as String,
      name: j['name'] as String,
      category: PoiCategory.values.byName(j['category'] as String),
      display: GeoPoint.fromGeoJson(j['display'] as List),
      approach: ap == null ? null : GeoPoint.fromGeoJson(ap as List),
      routable: j['routable'] as bool,
      notRoutableReason: j['notRoutableReason'] as String?,
      description: j['description'] as String,
      accessNotes: (j['accessNotes'] as String?) ?? '',
      approvalStatus: j['approvalStatus'] as String,
      locationSource: j['locationSource'] as String,
      isShipTerminal: (j['isShipTerminal'] as bool?) ?? false,
      audioAsset: j['audioAsset'] as String?,
    );
  }
}
