import '../../../core/geo/geo.dart';
import '../../../core/models/poi.dart';

/// Offline, case- and accent-insensitive search over bundled POIs.
class PoiSearch {
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[’'`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<Poi> search(
    List<Poi> pois, {
    String query = '',
    PoiCategory? category,
    GeoPoint? sortFrom,
  }) {
    final q = _norm(query);
    final terms = q.isEmpty ? const <String>[] : q.split(' ');
    final out = pois.where((p) {
      if (p.isShipTerminal) return false;
      if (category != null && p.category != category) return false;
      if (terms.isEmpty) return true;
      final hay = _norm('${p.name} ${p.category.label} ${p.category.pluralLabel}');
      return terms.every(hay.contains);
    }).toList();
    if (sortFrom != null) {
      out.sort((a, b) => haversineM(sortFrom, a.display).compareTo(haversineM(sortFrom, b.display)));
    } else {
      out.sort((a, b) => a.name.compareTo(b.name));
    }
    return out;
  }
}
