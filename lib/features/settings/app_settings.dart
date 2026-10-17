import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DistanceUnits { metric, imperial }

/// Local-only preferences and favourites (no account, no cloud).
class AppSettings extends ChangeNotifier {
  SharedPreferences? _prefs;

  DistanceUnits units = DistanceUnits.metric;
  bool arrivalSound = true;
  bool vibration = true;

  /// Walking-time estimates are NOT an approved feature (UI spec 7); off by
  /// default and labelled as an estimate when enabled.
  bool showWalkingEstimate = false;

  /// Demo / simulated location (BR-17). Off by default; never persisted ON
  /// across restarts so a visitor cannot unknowingly start in simulation.
  bool demoMode = false;

  final Set<String> favorites = {};

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      units = p.getString('units') == 'imperial' ? DistanceUnits.imperial : DistanceUnits.metric;
      arrivalSound = p.getBool('arrivalSound') ?? true;
      vibration = p.getBool('vibration') ?? true;
      showWalkingEstimate = p.getBool('showWalkingEstimate') ?? false;
      favorites
        ..clear()
        ..addAll(p.getStringList('favorites') ?? const []);
    } catch (_) {
      // Preferences unavailable: run with defaults.
    }
    notifyListeners();
  }

  void setUnits(DistanceUnits u) {
    units = u;
    _prefs?.setString('units', u.name);
    notifyListeners();
  }

  void setArrivalSound(bool v) {
    arrivalSound = v;
    _prefs?.setBool('arrivalSound', v);
    notifyListeners();
  }

  void setVibration(bool v) {
    vibration = v;
    _prefs?.setBool('vibration', v);
    notifyListeners();
  }

  void setShowWalkingEstimate(bool v) {
    showWalkingEstimate = v;
    _prefs?.setBool('showWalkingEstimate', v);
    notifyListeners();
  }

  void setDemoMode(bool v) {
    demoMode = v;
    notifyListeners();
  }

  bool isFavorite(String id) => favorites.contains(id);

  void toggleFavorite(String id) {
    if (!favorites.remove(id)) favorites.add(id);
    _prefs?.setStringList('favorites', favorites.toList()..sort());
    notifyListeners();
  }

  String formatDistance(double meters) {
    if (units == DistanceUnits.imperial) {
      final miles = meters / 1609.344;
      if (miles < 0.1) return '${(meters * 3.28084).round()} ft';
      return '${miles.toStringAsFixed(miles < 10 ? 1 : 0)} mi';
    }
    if (meters < 1000) return '${(meters / 10).round() * 10} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Walking time at 4.5 km/h (provisional speed model).
  String formatWalk(double meters) {
    final min = (meters / 75.0).ceil();
    return '~$min min walk';
  }
}
