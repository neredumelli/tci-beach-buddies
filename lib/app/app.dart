import 'package:flutter/material.dart';

import '../data/offline_bundle.dart';
import '../features/settings/app_settings.dart';
import '../platform/audio/voice_service.dart';
import '../platform/location/location_source.dart';
import 'app_services.dart';
import 'shell.dart';
import 'theme.dart';
import '../shared/photos.dart';

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
    final minSplash = Future<void>.delayed(const Duration(seconds: 5));
    final settings = AppSettings();
    await settings.load();
    await Photos.load(widget.bundle?.assets); // same asset source as the offline bundle
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

/// 01 Splash / Welcome - the approved design image from the v2.0
/// walkthrough, used as-is (logo, tagline, beach and "Loading..." text);
/// only the loading ring is drawn live so it animates.
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3FA2E6),
      body: Semantics(
        label: 'TCI Beach Buddies. Your guide to Grand Turk. Loading',
        child: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/images/splash.jpg', fit: BoxFit.cover, alignment: Alignment.center),
          // Ring sits where the design's ring was (88% down the image).
          LayoutBuilder(builder: (context, c) {
            final d = c.maxHeight * 0.058;
            return Align(
              alignment: const Alignment(0, 0.762),
              child: SizedBox(
                width: d,
                height: d,
                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              ),
            );
          }),
        ]),
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
