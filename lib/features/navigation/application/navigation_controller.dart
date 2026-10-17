// NavigationController - the single owner of destination, route, progress,
// arrival and rerouting (TDD 4.2-4.5, 5, 5.2; SDD 5.5).
//
// THE A -> B GUARANTEE (BR-05, J-03):
//   Every destination change, reroute and Return to Ship:
//     1. increments the generation token,
//     2. retires the previous route immediately (overlay cleared),
//     3. asks the LocationCoordinator for the latest acceptable LIVE fix,
//     4. routes from that fix to the new destination,
//     5. publishes the result only if its generation is still current.
//   The cruise centre, the previous route origin and the previous
//   destination are never used as a substitute origin. There is no code path
//   that stores an origin between requests.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/geo/geo.dart';
import '../../../core/models/location_fix.dart';
import '../../../core/models/poi.dart';
import '../domain/gps_policy.dart';
import '../domain/route_models.dart';
import '../domain/route_planner.dart';
import '../domain/route_progress.dart';
import 'location_coordinator.dart';

enum NavPhase {
  /// MapReady: browsing, no active navigation.
  idle,
  waitingForFix,
  calculating,
  navigating,
  rerouting,
  arrived,
  noRoute,
  bundleError,
}

/// Async boundary so routing can move to an isolate later and so tests can
/// inject delays to prove stale results are discarded.
abstract class RouteEngine {
  String get graphVersion;
  String get travelProfile;
  Future<RouteOutcome> calculate(RouteRequest request);
}

class LocalRouteEngine implements RouteEngine {
  final RoutePlanner planner;
  LocalRouteEngine(this.planner);
  @override
  String get graphVersion => planner.graph.graphVersion;
  @override
  String get travelProfile => planner.graph.profile;
  @override
  Future<RouteOutcome> calculate(RouteRequest request) async => planner.calculate(request);
}

/// In-memory audit of recent route computations (not persisted: no travel
/// history is stored by default, TDD 10).
class RouteAudit {
  final int generation;
  final String destinationId;
  final GeoPoint origin;
  final bool simulated;
  final double? distanceM;
  final RouteFailureCode? failure;
  final bool isReroute;
  const RouteAudit(this.generation, this.destinationId, this.origin, this.simulated,
      this.distanceM, this.failure, this.isReroute);
}

class NavigationController extends ChangeNotifier {
  final LocationCoordinator location;
  final RouteEngine? engine;
  final List<Poi> pois;
  final GpsPolicy policy;
  final DateTime Function() _now;

  NavPhase _phase;
  Poi? _destination;
  PlannedRoute? _route;
  ProgressSnapshot? _progress;
  RouteFailureCode? _failure;
  String _failureDetail = '';
  bool _guidancePaused = false;
  int _generation = 0;
  DateTime? _lastRerouteAt;
  RouteProgressTracker? _tracker;
  ArrivalEvaluator? _arrival;
  Poi? _arrivedAt;
  StreamSubscription<LocationFix>? _fixSub;
  final List<RouteAudit> audit = [];

  /// Called once per confirmed arrival (haptics/sound hook).
  void Function(Poi poi)? onArrival;

  NavigationController({
    required this.location,
    required this.engine,
    required this.pois,
    this.policy = const GpsPolicy(),
    bool bundleValid = true,
    DateTime Function()? clock,
  })  : _phase = (bundleValid && engine != null) ? NavPhase.idle : NavPhase.bundleError,
        _now = clock ?? DateTime.now {
    _fixSub = location.fixStream.listen(_onFix);
  }

  // ------------------------------------------------------------- getters --
  NavPhase get phase => _phase;
  Poi? get destination => _destination;
  PlannedRoute? get route => _route;
  ProgressSnapshot? get progress => _progress;
  RouteFailureCode? get failure => _failure;
  String get failureDetail => _failureDetail;
  bool get guidancePaused => _guidancePaused;
  int get generation => _generation;
  Poi? get arrivedAt => _arrivedAt;
  bool get isActive =>
      _phase == NavPhase.waitingForFix ||
      _phase == NavPhase.calculating ||
      _phase == NavPhase.navigating ||
      _phase == NavPhase.rerouting;

  Poi? get shipTerminal {
    for (final p in pois) {
      if (p.isShipTerminal) return p;
    }
    return null;
  }

  // ------------------------------------------------------------- actions --

  /// Start (or switch) navigation to [poi] from the latest live position.
  Future<void> selectDestination(Poi poi) async {
    if (_phase == NavPhase.bundleError || engine == null) return;
    final gen = ++_generation;
    _retireRoute();
    _destination = poi;
    _arrivedAt = null;
    _failure = null;
    _failureDetail = '';
    if (!poi.canNavigate) {
      _phase = NavPhase.noRoute;
      _failure = RouteFailureCode.accessRestricted;
      _failureDetail = poi.notRoutableReason ?? '';
      notifyListeners();
      return;
    }
    _phase = NavPhase.waitingForFix;
    notifyListeners();

    final fix = await location.latestAcceptedFix();
    if (gen != _generation) return; // superseded while waiting
    if (_phase != NavPhase.waitingForFix) return; // _onFix already resumed it
    if (fix == null) {
      // Stay in WaitingForFix; _onFix resumes automatically when a valid fix
      // arrives. Never fabricate an origin.
      _failure = RouteFailureCode.noFreshFix;
      notifyListeners();
      return;
    }
    await _calculateFrom(fix, gen, isReroute: false);
  }

  /// Return to Ship: same pipeline, destination = approved terminal point.
  Future<void> returnToShip() async {
    final ship = shipTerminal;
    if (ship == null) {
      ++_generation;
      _retireRoute();
      _phase = NavPhase.noRoute;
      _failure = RouteFailureCode.bundleInvalid;
      _failureDetail = 'No approved Cruise Center return point is installed.';
      notifyListeners();
      return;
    }
    await selectDestination(ship);
  }

  /// Retry the current destination (after NoRoute / GPS failure).
  Future<void> retry() async {
    final d = _destination;
    if (d != null) await selectDestination(d);
  }

  void stop() {
    ++_generation;
    _retireRoute();
    _destination = null;
    _arrivedAt = null;
    _failure = null;
    _failureDetail = '';
    if (_phase != NavPhase.bundleError) _phase = NavPhase.idle;
    notifyListeners();
  }

  // ------------------------------------------------------------ internals --

  void _retireRoute() {
    _route = null;
    _progress = null;
    _tracker = null;
    _arrival = null;
    _guidancePaused = false;
  }

  Future<void> _calculateFrom(LocationFix fix, int gen, {required bool isReroute}) async {
    final dest = _destination;
    final eng = engine;
    if (dest == null || eng == null || dest.approach == null) return;
    _phase = isReroute ? NavPhase.rerouting : NavPhase.calculating;
    _failure = null;
    notifyListeners();

    final req = RouteRequest(
      requestId: gen,
      origin: fix.position,
      originFixTime: fix.timestamp,
      destinationPoiId: dest.id,
      destinationApproach: dest.approach!,
      travelProfile: eng.travelProfile,
      graphVersion: eng.graphVersion,
    );
    final outcome = await eng.calculate(req);
    if (gen != _generation) return; // stale result: a newer request exists

    switch (outcome) {
      case RouteSuccess(:final route):
        _audit(gen, dest.id, fix, route.distanceM, null, isReroute);
        _route = route;
        _tracker = RouteProgressTracker(route, policy);
        _arrival = ArrivalEvaluator(route.endpoint, policy);
        _phase = NavPhase.navigating;
        final q = location.qualityOf(fix) ?? FixQuality.stale;
        _progress = _tracker!.update(fix, q);
        // Already at the destination (e.g. Return to Ship from the terminal).
        if (q == FixQuality.good && haversineM(fix.position, route.endpoint) <= policy.arrivalRadiusM) {
          _confirmArrival(dest);
          return;
        }
      case RouteFailure(:final code, :final detail):
        _audit(gen, dest.id, fix, null, code, isReroute);
        _route = null;
        _phase = NavPhase.noRoute;
        _failure = code;
        _failureDetail = detail;
    }
    notifyListeners();
  }

  void _audit(int gen, String id, LocationFix fix, double? dist, RouteFailureCode? f, bool rr) {
    audit.add(RouteAudit(gen, id, fix.position, fix.isSimulated, dist, f, rr));
    if (audit.length > 20) audit.removeAt(0);
  }

  void _onFix(LocationFix fix) {
    final q = location.qualityOf(fix) ?? FixQuality.stale;

    // Waiting for GPS with a destination selected: resume automatically.
    if (_phase == NavPhase.waitingForFix && _destination != null && policy.acceptableForRouting(q)) {
      final gen = _generation;
      _calculateFrom(fix, gen, isReroute: false);
      return;
    }
    if (_phase != NavPhase.navigating) return;
    final tracker = _tracker, arrival = _arrival, dest = _destination;
    if (tracker == null || arrival == null || dest == null) return;

    if (!policy.acceptableForRouting(q)) {
      // Stale / unusable / outside coverage: pause live guidance, keep route.
      if (!_guidancePaused) {
        _guidancePaused = true;
        notifyListeners();
      }
      return;
    }
    _guidancePaused = false;
    _progress = tracker.update(fix, q);

    if (arrival.update(fix, q)) {
      _confirmArrival(dest);
      return;
    }

    final p = _progress!;
    final now = _now();
    final cooled = _lastRerouteAt == null || now.difference(_lastRerouteAt!) >= policy.rerouteCooldown;
    if (p.offRouteConfirmed && q == FixQuality.good && cooled) {
      _lastRerouteAt = now;
      final gen = ++_generation;
      _calculateFrom(fix, gen, isReroute: true);
      return;
    }
    notifyListeners();
  }

  void _confirmArrival(Poi dest) {
    _phase = NavPhase.arrived;
    _arrivedAt = dest;
    _guidancePaused = false;
    notifyListeners();
    onArrival?.call(dest);
  }

  @override
  void dispose() {
    _fixSub?.cancel();
    super.dispose();
  }
}
