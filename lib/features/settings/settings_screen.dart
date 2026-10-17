import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../data/offline_bundle.dart';
import '../../platform/location/geolocator_location_source.dart';
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
      appBar: AppBar(
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
                secondary: const Icon(Icons.volume_up, color: BB.blue),
                title: const Text('Voice Guidance', style: _t),
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
                secondary: const Icon(Icons.record_voice_over, color: BB.blue),
                title: const Text('Read description on arrival', style: _t),
                value: s.settings.narrateArrival,
                onChanged: s.settings.voiceGuidance ? s.settings.setNarrateArrival : null,
              ),
              ListTile(
                leading: const Icon(Icons.campaign_outlined, color: BB.blue),
                title: const Text('Test voice', style: _t),
                subtitle: const Text("If silent: raise media volume or install an offline voice in the phone's text-to-speech settings"),
                onTap: () => s.voice.speak('Welcome to Grand Turk. Voice guidance is working.'),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.vibration, color: BB.blue),
                title: const Text('Vibrate on arrival', style: _t),
                value: s.settings.vibration,
                onChanged: s.settings.setVibration,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.schedule, color: BB.blue),
                title: const Text('Show walking time & ETA', style: _t),
                subtitle: const Text('Estimated at 4.5 km/h (2.8 mph)'),
                value: s.settings.showWalkingEstimate,
                onChanged: s.settings.setShowWalkingEstimate,
              ),
            ]),
            const _Header('Demo / QA'),
            _Card(children: [
              SwitchListTile(
                secondary: const Icon(Icons.science, color: BB.warning),
                title: const Text('Simulated location (Demo mode)', style: _t),
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
                title: const Text('TCI Beach Buddies', style: _t),
                subtitle: const Text('Version $appVersion'),
              ),
              ListTile(
                leading: const Icon(Icons.copyright, color: BB.blue),
                title: const Text('Map data attribution', style: _t),
                subtitle: Text(m?.attribution ?? '© OpenStreetMap contributors'),
              ),
            ]),
          ]);
        },
      ),
    );
  }

  static const _t = TextStyle(fontWeight: FontWeight.w600, color: BB.navy);

  Widget _row(IconData icon, String title, String value, Color valueColor, VoidCallback onTap) => ListTile(
        leading: Icon(icon, color: BB.blue),
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
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: BB.navy)),
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
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: BB.navy, fontSize: 15)),
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
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      );
}
