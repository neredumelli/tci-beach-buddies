import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DistanceUnits { metric, imperial }

/// Local-only preferences and favourites (no account, no cloud).
class AppSettings extends ChangeNotifier {
  SharedPreferences? _prefs;

  /// Miles by default (cruise visitors, v2.0 screens); switchable to km.
  DistanceUnits units = DistanceUnits.imperial;
  /// Spoken turn-by-turn guidance and alerts (device text-to-speech, offline).
  bool voiceGuidance = true;

  /// Read the destination description aloud on arrival.
  bool narrateArrival = true;
  bool vibration = true;

  /// Walking-time estimates are NOT an approved feature (UI spec 7); off by
  /// default and labelled as an estimate when enabled.
  bool showWalkingEstimate = true;

  /// Demo / simulated location (BR-17). Off by default; never persisted ON
  /// across restarts so a visitor cannot unknowingly start in simulation.
  bool demoMode = false;

  /// Predefined colour theme (see AppThemes); the default is the v2.0 look.
  String themeId = 'island-blue';

  final Set<String> favorites = {};

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      units = p.getString('units') == 'metric' ? DistanceUnits.metric : DistanceUnits.imperial;
      voiceGuidance = p.getBool('voiceGuidance') ?? true;
      narrateArrival = p.getBool('narrateArrival') ?? true;
      vibration = p.getBool('vibration') ?? true;
      showWalkingEstimate = p.getBool('showWalkingEstimate') ?? true;
      themeId = p.getString('theme') ?? themeId;
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

  void setVoiceGuidance(bool v) {
    voiceGuidance = v;
    _prefs?.setBool('voiceGuidance', v);
    notifyListeners();
  }

  void setNarrateArrival(bool v) {
    narrateArrival = v;
    _prefs?.setBool('narrateArrival', v);
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

  void setThemeId(String id) {
    if (id == themeId) return;
    themeId = id;
    _prefs?.setString('theme', id);
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

  /// Walking time at 4.5 km/h (provisional speed model, 75 m per minute).
  int walkMinutes(double meters) => (meters / 75.0).ceil().clamp(1, 999);

  String formatWalk(double meters) => '~${walkMinutes(meters)} min walk';

  /// Arrival clock time for [meters] of walking from now.
  String eta(double meters, [DateTime? now]) {
    final t = (now ?? DateTime.now()).add(Duration(minutes: walkMinutes(meters)));
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }
}
