import 'package:flutter/material.dart';

import '../data/offline_bundle.dart';
import '../features/settings/app_settings.dart';
import '../platform/audio/voice_service.dart';
import '../platform/location/location_source.dart';
import 'app_services.dart';
import 'shell.dart';
import 'theme.dart';
import '../shared/art.dart';

class TciBeachBuddiesApp extends StatefulWidget {
  /// Injection points for tests (bundle and location source).
  final OfflineBundle? bundle;
  final LocationSource? liveSource;
  final VoiceService? voice;
  const TciBeachBuddiesApp({super.key, this.bundle, this.liveSource, this.voice});

  @override
  State<TciBeachBuddiesApp> createState() => _TciBeachBuddiesAppState();
}

class _TciBeachBuddiesAppState extends State<TciBeachBuddiesApp> {
  late final Future<AppServices> _boot = _init();
  AppServices? _services;

  @override
  void dispose() {
    _services?.dispose();
    super.dispose();
  }

  Future<AppServices> _init() async {
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 1200));
    final settings = AppSettings();
    await settings.load();
    final health = await (widget.bundle ?? OfflineBundle()).verifyAndLoad();
    final services = await AppServices.create(
      bundle: health,
      settings: settings,
      liveSource: widget.liveSource,
      voice: widget.voice,
    );
    // Location is requested in context: the permission prompt appears once
    // the visitor is on Home, and declining never blocks browsing (J-01).
    services.location.start();
    await minSplash;
    if (mounted) setState(() => _services = services);
    return services;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCI Beach Buddies',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // AppScope sits ABOVE the Navigator so every pushed route (details,
      // navigation, arrival, pickers) can reach the services.
      builder: (context, child) {
        final s = _services;
        return s == null ? child! : AppScope(services: s, child: child!);
      },
      home: FutureBuilder<AppServices>(
        future: _boot,
        builder: (context, snap) {
          if (snap.hasError) {
            return _FatalScreen(error: '${snap.error}');
          }
          if (!snap.hasData || _services == null) return const _Splash();
          return const MainShell();
        },
      ),
    );
  }
}

/// 01 Splash / Welcome: brand + tropical scene + loading state.
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TropicalScene(
        kind: SceneKind.beach,
        seed: 7,
        child: SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(22)),
                child: Image.asset('assets/images/logo.png', semanticLabel: 'TCI Beach Buddies - Your guide to Grand Turk'),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Your Guide to Grand Turk',
                style: TextStyle(color: BB.navy, fontSize: 20, fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.white, blurRadius: 6)])),
            const Spacer(flex: 5),
            const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
            const SizedBox(height: 10),
            const Text('Loading…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 28),
          ]),
        ),
      ),
    );
  }
}

class _FatalScreen extends StatelessWidget {
  final String error;
  const _FatalScreen({required this.error});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 56, color: BB.danger),
            const SizedBox(height: 12),
            const Text('The app could not start', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
