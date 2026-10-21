import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/offline_bundle.dart';
import '../../platform/location/geolocator_location_source.dart';
import '../../shared/photos.dart';
import '../../shared/widgets.dart';
import '../navigation/application/location_coordinator.dart';
import 'app_settings.dart';

const appVersion = '1.0.0';

/// 11 Settings: Voice Guidance, Distance Units, Offline Map, GPS Status,
/// App Version, Privacy Policy (+ help, safety, demo mode, attribution).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle;
    final m = b.manifest;
    return Scaffold(
      appBar: AppBar(flexibleSpace: const HeaderBackground(), 
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ShellTabs.go(context, ShellTab.home),
        ),
        actions: [IconButton(tooltip: 'Help', icon: const Icon(Icons.help_outline), onPressed: () => _help(context))],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.settings, s.location]),
        builder: (context, _) {
          final st = s.location.status;
          final gpsActive = st == GpsStatus.good || st == GpsStatus.poor;
          final (_, gColor, gText) = GpsStatusChip.describe(st, s.location.latestFix?.accuracyM);
          return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
            const SimulatedBanner(),
            _Card(children: [
              SwitchListTile(
                secondary: const _IconTile(Icons.volume_up),
                title: Text('Voice Guidance', style: _t),
                value: s.settings.voiceGuidance,
                onChanged: s.settings.setVoiceGuidance,
              ),
              _row(
                Icons.straighten,
                'Distance Units',
                s.settings.units == DistanceUnits.imperial ? 'Miles (mi)' : 'Kilometres (km)',
                BB.go,
                () => s.settings.setUnits(
                    s.settings.units == DistanceUnits.imperial ? DistanceUnits.metric : DistanceUnits.imperial),
              ),
              _ThemeRow(onTap: () => showThemePicker(context)),
              _row(Icons.map, 'Offline Map', b.navigationAvailable ? 'Available' : 'Problem',
                  b.navigationAvailable ? BB.go : BB.danger, () => _offlineMap(context, b)),
              _row(Icons.place, 'GPS Status', gpsActive ? 'Active' : gText, gpsActive ? BB.go : gColor, () async {
                if (st == GpsStatus.permissionDenied) {
                  await GeolocatorLocationSource.openAppSettings();
                  await s.location.retryPermission();
                } else if (st == GpsStatus.servicesOff) {
                  await GeolocatorLocationSource.openLocationSettings();
                  await s.location.retryPermission();
                } else {
                  _gpsInfo(context, gText);
                }
              }),
              _row(Icons.info, 'App Version', 'v$appVersion', BB.muted, () => _about(context, m)),
              _row(Icons.privacy_tip, 'Privacy Policy', '', BB.muted, () => _privacy(context)),
            ]),
            const _Header('Voice & display'),
            _Card(children: [
              SwitchListTile(
                secondary: const _IconTile(Icons.record_voice_over),
                title: Text('Read description on arrival', style: _t),
                value: s.settings.narrateArrival,
                onChanged: s.settings.voiceGuidance ? s.settings.setNarrateArrival : null,
              ),
              ListTile(
                leading: const _IconTile(Icons.campaign_outlined),
                title: Text('Test voice', style: _t),
                subtitle: const Text("If silent: raise media volume or install an offline voice in the phone's text-to-speech settings"),
                onTap: () async {
                  final r = await s.voice.check();
                  if (!context.mounted) return;
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      icon: Icon(r.ok ? Icons.volume_up : Icons.volume_off, color: r.ok ? BB.go : BB.danger, size: 44),
                      title: Text(r.ok ? 'Voice OK' : 'Voice not available'),
                      content: Text(r.message),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                    ),
                  );
                },
              ),
              SwitchListTile(
                secondary: const _IconTile(Icons.vibration),
                title: Text('Vibrate on arrival', style: _t),
                value: s.settings.vibration,
                onChanged: s.settings.setVibration,
              ),
              SwitchListTile(
                secondary: const _IconTile(Icons.schedule),
                title: Text('Show walking time & ETA', style: _t),
                subtitle: const Text('Estimated at 4.5 km/h (2.8 mph)'),
                value: s.settings.showWalkingEstimate,
                onChanged: s.settings.setShowWalkingEstimate,
              ),
            ]),
            const _Header('Demo / QA'),
            _Card(children: [
              SwitchListTile(
                secondary: const _IconTile(Icons.science),
                title: Text('Simulated location (Demo mode)', style: _t),
                subtitle: const Text('For staff demonstrations only. A yellow SIMULATED banner is shown on every '
                    'screen. Turns off when the app restarts.'),
                value: s.settings.demoMode,
                onChanged: (v) => s.setDemoMode(v),
              ),
            ]),
            const _Header('Safety'),
            const _Card(children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text('Routes follow mapped roads and paths but cannot show closures or local conditions. '
                    'Obey road signs, take care near traffic, and allow plenty of time to get back to your ship '
                    'before all-aboard.'),
              ),
            ]),
            const _Header('About'),
            _Card(children: [
              ListTile(
                leading: Image.asset('assets/images/emblem.png', width: 36, height: 36),
                title: Text('TCI Beach Buddies', style: _t),
                subtitle: const Text('Version $appVersion'),
              ),
              ListTile(
                leading: const _IconTile(Icons.copyright),
                title: Text('Map data attribution', style: _t),
                subtitle: Text(m?.attribution ?? '© OpenStreetMap contributors'),
              ),
              if (Photos.byPoi.isNotEmpty)
                ListTile(
                  leading: const _IconTile(Icons.photo_library_outlined),
                  title: Text('Photo credits', style: _t),
                  subtitle: Text(
                      '${Photos.byPoi.values.where((p) => !p.isIllustration).length} licensed photos · '
                      '${Photos.byPoi.values.where((p) => p.isIllustration).length} illustrations (not photos)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _sheet(context, 'Photo credits', [
                    SizedBox(
                      height: 360,
                      child: ListView(children: [
                        for (final e in Photos.byPoi.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                                e.value.isIllustration
                                    ? '${s.poiById(e.key)?.name ?? e.key}: original illustration, not a photo'
                                    : '${s.poiById(e.key)?.name ?? e.key}: ${e.value.author} - ${e.value.license}\n${e.value.sourceUrl}',
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ]);
        },
      ),
    );
  }

  static TextStyle get _t => TextStyle(fontWeight: FontWeight.w600, color: BB.navy);

  Widget _row(IconData icon, String title, String value, Color valueColor, VoidCallback onTap) => ListTile(
        leading: _IconTile(icon),
        title: Text(title, style: _t),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(value, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: valueColor, fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.chevron_right),
        ]),
        onTap: onTap,
      );

  void _sheet(BuildContext context, String title, List<Widget> children) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: BB.navy)),
              const SizedBox(height: 12),
              ...children,
            ]),
          ),
        ),
      );

  void _offlineMap(BuildContext context, BundleHealth b) {
    final m = b.manifest;
    _sheet(context, 'Offline Map', [
      Text(m == null ? 'Not installed' : 'Grand Turk map installed and verified on this launch (SHA-256).'),
      if (m != null) ...[
        const SizedBox(height: 8),
        Text('Release ${m.releaseId}\nMap ${m.mapVersion}\nRoutes ${m.graphVersion} (walking)\nPlaces ${m.poiVersion}\n'
            'Source: ${m.sourceName}, extracted ${m.extractDate}\nLicence: ${m.sourceLicense}'),
      ],
      for (final i in b.issues) Text('• ${i.code}: ${i.message}', style: const TextStyle(color: BB.warning)),
      const SizedBox(height: 8),
      const Text('Updates are installed with new app releases; this screen does not check online.',
          style: TextStyle(color: BB.muted, fontSize: 12.5)),
    ]);
  }

  void _gpsInfo(BuildContext context, String status) => _sheet(context, 'GPS Status', [
        Text(status),
        const SizedBox(height: 8),
        const Text('GPS works without mobile data, but needs open sky. Your location stays on this phone.'),
      ]);

  void _about(BuildContext context, BundleManifest? m) => _sheet(context, 'TCI Beach Buddies', [
        const Text('Version $appVersion — offline tourist navigation for Grand Turk, Turks & Caicos Islands.'),
        const SizedBox(height: 8),
        Text('Map data ${m?.attribution ?? '© OpenStreetMap contributors'} (ODbL).'),
      ]);

  void _privacy(BuildContext context) => _sheet(context, 'Privacy Policy', const [
        Text('• No account is needed.\n'
            '• Your location is used only on this phone to show your position and plan routes. It is never transmitted.\n'
            '• The app does not keep a history of where you went.\n'
            '• Settings and saved places are stored only on this phone.'),
      ]);

  void _help(BuildContext context) => _sheet(context, 'How to use', const [
        Text('• No internet needed: map, places and routes are stored on your phone.\n'
            '• Allow location access so the app can see where you are.\n'
            '• Choose a place, tap Navigate, check the Route Preview, then Start Navigation.\n'
            '• Every route starts from where you are right now.\n'
            '• Return to Cruise Port is always one tap away.'),
      ]);
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
        child: Text(text, style: heading(20)),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          elevation: 2,
          shadowColor: const Color(0x330B2F44),
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)),
        ),
      );
}

/// Settings › Theme: shows the active theme as swatches.
class _ThemeRow extends StatelessWidget {
  final VoidCallback onTap;
  const _ThemeRow({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = BB.palette;
    return ListTile(
      leading: const _IconTile(Icons.palette_outlined),
      title: Text('Theme', style: TextStyle(fontWeight: FontWeight.w600, color: BB.navy)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(p.name, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: BB.blue, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        _Swatch(palette: p, size: 22),
        const Icon(Icons.chevron_right),
      ]),
      onTap: onTap,
    );
  }
}

class _Swatch extends StatelessWidget {
  final AppPalette palette;
  final double size;
  const _Swatch({required this.palette, required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [palette.primary, palette.primaryLight, palette.port, palette.go, palette.primary]),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
        ),
      );
}

/// Bottom sheet listing the predefined themes; picking one restyles the
/// whole app at once and is remembered on this phone.
Future<void> showThemePicker(BuildContext context) {
  final settings = AppScope.of(context).settings;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListenableBuilder(
        listenable: settings,
        builder: (ctx, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Choose a theme', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: BB.navy)),
            const SizedBox(height: 4),
            const Text('Classic or photo look, in different colours. Everything works the same.', style: TextStyle(color: BB.muted)),
            const SizedBox(height: 12),
            for (final t in AppThemes.all) ...[
              _ThemeOption(
                palette: t,
                selected: settings.themeId == t.id,
                onTap: () => settings.setThemeId(t.id),
              ),
              const SizedBox(height: 10),
            ],
          ]),
        ),
      ),
    ),
  );
}

class _ThemeOption extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.palette, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.name} theme. ${palette.description}${selected ? '. Selected' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: selected ? palette.primary : const Color(0xFFD5DEEA), width: selected ? 3 : 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Mini preview: header bar, a Return button and a Go button.
              Container(
                height: 34,
                decoration: BoxDecoration(gradient: palette.header),
                alignment: Alignment.center,
                child: const Text('Grand Turk',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              Container(
                color: palette.bg,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(palette.name,
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: palette.primary)),
                      Text(palette.description, style: const TextStyle(fontSize: 13, color: BB.muted)),
                      const SizedBox(height: 8),
                      Row(children: [
                        _pill(palette.primary, Icons.directions_boat, 'Return'),
                        const SizedBox(width: 6),
                        _pill(palette.go, Icons.navigation, 'Navigate'),
                      ]),
                    ]),
                  ),
                  Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: selected ? palette.primary : BB.muted, size: 30),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pill(Color c, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: BB.onColor(c)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: BB.onColor(c), fontSize: 12.5, fontWeight: FontWeight.w800)),
        ]),
      );
}

/// Colourful rounded icon square used on every Settings row.
class _IconTile extends StatelessWidget {
  final IconData icon;
  const _IconTile(this.icon);

  static final _colors = <IconData, Color>{
    Icons.volume_up: Color(0xFF0270B8),
    Icons.straighten: Color(0xFFC04A00),
    Icons.palette_outlined: Color(0xFF6A2FC0),
    Icons.map: Color(0xFF1E7F35),
    Icons.place: Color(0xFFC62032),
    Icons.info: Color(0xFF2F44C2),
    Icons.privacy_tip: Color(0xFF00747F),
    Icons.record_voice_over: Color(0xFF0270B8),
    Icons.campaign_outlined: Color(0xFFC04A00),
    Icons.vibration: Color(0xFF6A2FC0),
    Icons.schedule: Color(0xFF1E7F35),
    Icons.science: Color(0xFFB26A00),
    Icons.copyright: Color(0xFF2F44C2),
    Icons.photo_library_outlined: Color(0xFFC62032),
  };

  @override
  Widget build(BuildContext context) {
    if (!BB.photo) return Icon(icon, color: BB.blue);
    final c = _colors[icon] ?? BB.blue;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(c, Colors.white, 0.25)!, c],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.30), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
