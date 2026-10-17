// Spoken guidance driven by NavigationController state.
// Speaks only what the app actually knows: maneuvers derived from the road
// graph (road names only when present in the map data), along-route
// distances, GPS problems and verified arrival.
import '../../../platform/audio/voice_service.dart';
import '../../settings/app_settings.dart';
import '../domain/route_models.dart';
import 'navigation_controller.dart';

class VoiceGuide {
  final NavigationController nav;
  final VoiceService voice;
  final AppSettings settings;

  /// Distance before a turn at which it is announced.
  final double announceAtM;

  int _routeGen = -1;
  NavPhase? _lastPhase;
  bool _wasPaused = false;
  final Set<int> _announced = {}; // indices of maneuvers already spoken
  final Set<int> _preAnnounced = {};

  VoiceGuide(this.nav, this.voice, this.settings, {this.announceAtM = 40}) {
    nav.addListener(_onChange);
  }

  void dispose() => nav.removeListener(_onChange);

  bool get _on => settings.voiceGuidance;

  String spokenDistance(double m) {
    if (settings.units == DistanceUnits.imperial) {
      final ft = m * 3.28084;
      if (ft < 1000) return '${(ft / 50).round() * 50} feet';
      final mi = m / 1609.344;
      return '${mi.toStringAsFixed(1)} miles';
    }
    if (m < 1000) return '${(m / 10).round() * 10} metres';
    return '${(m / 1000).toStringAsFixed(1)} kilometres';
  }

  void _say(String text, {bool interrupt = true}) {
    if (_on) voice.speak(text, interrupt: interrupt);
  }

  void _onChange() {
    final phase = nav.phase;
    final dest = nav.destination;
    // Route Preview: nothing is spoken until Start Navigation.
    if (!nav.guidanceStarted && phase != NavPhase.arrived) {
      _lastPhase = phase;
      return;
    }

    if (phase != _lastPhase) {
      switch (phase) {
        case NavPhase.rerouting:
          _say('Off route. Recalculating from your position.');
        case NavPhase.noRoute:
          _say('No walking route is available to this destination.');
        case NavPhase.arrived:
          final p = nav.arrivedAt;
          if (p != null) {
            _say(p.isShipTerminal ? 'You have arrived at the ${p.name}.' : 'You have arrived at ${p.name}.');
            if (settings.narrateArrival && !p.isShipTerminal && p.description.isNotEmpty) {
              _say(p.description, interrupt: false);
            }
          }
        case NavPhase.idle:
          if (_lastPhase == NavPhase.navigating) voice.stop();
        default:
          break;
      }
      _lastPhase = phase;
    }

    final r = nav.route;
    if (phase == NavPhase.navigating && r != null && dest != null) {
      if (r.requestId != _routeGen) {
        // New route (first route, destination change, reroute, ship).
        final isReroute = _routeGen != -1 && nav.audit.isNotEmpty && nav.audit.last.isReroute;
        _routeGen = r.requestId;
        _announced.clear();
        _preAnnounced.clear();
        final first = r.maneuvers.isNotEmpty ? r.maneuvers.first.instruction : '';
        final where = dest.isShipTerminal ? 'back to the ship' : 'to ${dest.name}';
        _say(isReroute
            ? 'New route, ${spokenDistance(r.distanceM)}.'
            : 'Starting route $where. ${spokenDistance(r.distanceM)}. $first.');
      }
      if (nav.guidancePaused && !_wasPaused) {
        _say('GPS signal lost. Guidance paused.');
      } else if (!nav.guidancePaused && _wasPaused) {
        _say('GPS signal restored.');
      }
      _wasPaused = nav.guidancePaused;

      final p = nav.progress;
      final m = p?.nextManeuver;
      final d = p?.distanceToNextManeuverM;
      if (p != null && m != null && d != null && !nav.guidancePaused) {
        final idx = r.maneuvers.indexOf(m);
        if (m.type == ManeuverType.arrive) {
          if (d <= 120 && _preAnnounced.add(idx)) {
            _say('Your destination is ${spokenDistance(d)} ahead.');
          }
        } else if (d <= announceAtM && _announced.add(idx)) {
          _say(m.instruction);
        } else if (d > announceAtM && d <= 200 && _preAnnounced.add(idx)) {
          _say('In ${spokenDistance(d)}, ${_lowerFirst(m.instruction)}.');
        }
      }
    } else if (phase != NavPhase.navigating && phase != NavPhase.rerouting) {
      _wasPaused = false;
    }
  }

  static String _lowerFirst(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}
