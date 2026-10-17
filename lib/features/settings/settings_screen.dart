import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../data/offline_bundle.dart';
import '../../platform/location/geolocator_location_source.dart';
import '../../shared/widgets.dart';
import '../navigation/application/location_coordinator.dart';
import 'app_settings.dart';

const appVersion = '1.0.0 (1)';

/// Screen 7 - Settings & Offline Status.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bundle;
    final m = b.manifest;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), automaticallyImplyLeading: false),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.settings, s.location]),
        builder: (context, _) {
          final st = s.location.status;
          final (gIcon, gColor, gText) = GpsStatusChip.describe(st, s.location.latestFix?.accuracyM);
          return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
            const SimulatedBanner(),
            const _Header('Offline Maps'),
            _Card(children: [
              ListTile(
                leading: const Icon(Icons.map, color: BB.ocean),
                title: const Text('Grand Turk Map', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(m == null
                    ? 'Not installed'
                    : 'Installed · release ${m.releaseId}\nVerified on this launch (SHA-256)'),
                isThreeLine: m != null,
                trailing: Icon(
                  b.navigationAvailable ? Icons.check_circle : Icons.error,
                  color: b.navigationAvailable ? BB.success : BB.danger,
                  semanticLabel: b.navigationAvailable ? 'Verified' : 'Problem',
                ),
              ),
              if (m != null) ...[
                _kv('Map version', m.mapVersion),
                _kv('Route graph version', '${m.graphVersion} (${m.travelProfile})'),
                _kv('Destinations version', '${m.poiVersion} · ${s.destinations.length} places'),
                _kv('Map data', '${m.sourceName}, extracted ${m.extractDate}'),
                _kv('Licence', m.sourceLicense),
              ],
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'Updates are installed with new app releases; this screen does not check online.',
                  style: TextStyle(color: BB.muted, fontSize: 12),
                ),
              ),
            ]),
            if (b.issues.isNotEmpty) ...[
              const _Header('Data health'),
              _Card(children: [
                for (final i in b.issues)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      i.severity == BundleIssueSeverity.warning ? Icons.info_outline : Icons.error_outline,
                      color: i.severity == BundleIssueSeverity.warning ? BB.warning : BB.danger,
                    ),
                    title: Text(i.code, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(i.message),
                  ),
              ]),
            ],
            const _Header('GPS Status'),
            _Card(children: [
              ListTile(
                leading: Icon(gIcon, color: gColor),
                title: const Text('Location'),
                subtitle: Text(s.location.isSimulated ? 'SIMULATED (Demo mode) · $gText' : gText),
              ),
              if (st == GpsStatus.permissionDenied || st == GpsStatus.servicesOff)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: OutlinedButton(
                    onPressed: () async {
                      if (st == GpsStatus.servicesOff) {
                        await GeolocatorLocationSource.openLocationSettings();
                      } else {
                        await GeolocatorLocationSource.openAppSettings();
                      }
                      await s.location.retryPermission();
                    },
                    child: const Text('Open location settings'),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'GPS works without mobile data. Your location stays on this phone and is never sent anywhere.',
                  style: TextStyle(color: BB.muted, fontSize: 12),
                ),
              ),
            ]),
            const _Header('App Preferences'),
            _Card(children: [
              ListTile(
                leading: const Icon(Icons.straighten, color: BB.ocean),
                title: const Text('Units'),
                trailing: DropdownButton<DistanceUnits>(
                  value: s.settings.units,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: DistanceUnits.metric, child: Text('Metric (km)')),
                    DropdownMenuItem(value: DistanceUnits.imperial, child: Text('Imperial (mi)')),
                  ],
                  onChanged: (u) {
                    if (u != null) s.settings.setUnits(u);
                  },
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up, color: BB.ocean),
                title: const Text('Arrival sound'),
                value: s.settings.arrivalSound,
                onChanged: s.settings.setArrivalSound,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.vibration, color: BB.ocean),
                title: const Text('Vibration'),
                value: s.settings.vibration,
                onChanged: s.settings.setVibration,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.timer_outlined, color: BB.ocean),
                title: const Text('Show walking-time estimates'),
                subtitle: const Text('Rough guide at 4.5 km/h - not a guaranteed arrival time'),
                value: s.settings.showWalkingEstimate,
                onChanged: s.settings.setShowWalkingEstimate,
              ),
            ]),
            const _Header('Demo / QA'),
            _Card(children: [
              SwitchListTile(
                secondary: const Icon(Icons.science, color: BB.warning),
                title: const Text('Simulated location (Demo mode)'),
                subtitle: const Text(
                    'For staff demonstrations only. A yellow SIMULATED banner is shown on every screen. '
                    'Turns off when the app restarts.'),
                value: s.settings.demoMode,
                onChanged: (v) => s.setDemoMode(v),
              ),
            ]),
            const _Header('Safety'),
            const _Card(children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Routes follow mapped roads and paths but cannot show closures, construction or '
                  'local conditions. Obey road signs, take care near traffic, and allow plenty of '
                  'time to get back to your ship before all-aboard.',
                ),
              ),
            ]),
            const _Header('About'),
            _Card(children: [
              ListTile(
                leading: Image.asset('assets/images/emblem.png', width: 36, height: 36),
                title: const Text('TCI Beach Buddies', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Version $appVersion'),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline, color: BB.ocean),
                title: const Text('Help & Support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showHelp(context),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: BB.ocean),
                title: const Text('Privacy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPrivacy(context),
              ),
              ListTile(
                leading: const Icon(Icons.copyright, color: BB.ocean),
                title: const Text('Map data attribution'),
                subtitle: Text(m?.attribution ?? '© OpenStreetMap contributors'),
              ),
            ]),
          ]);
        },
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(color: BB.muted, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );

  void _showHelp(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _TextSheet(title: 'How to use TCI Beach Buddies', body: '''
• No internet needed: the map, destinations and routes are stored on your phone.
• Allow location access so the app can see where you are. GPS works without mobile data, but needs open sky; under roofs it can be slow or inaccurate.
• Choose a destination and tap Navigate Here. The route always starts from where you are right now.
• Changed your mind? Tap Change while navigating - a new route is calculated from your current position.
• Return to Ship is always one tap away and routes you to the Cruise Center.
• If GPS is weak, the app tells you and pauses guidance rather than guessing.
• Distances in lists are straight-line; while navigating, the distance shown is along the route.'''),
      );

  void _showPrivacy(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _TextSheet(title: 'Privacy', body: '''
• No account is needed.
• Your location is used only on this phone to show your position and plan routes. It is never transmitted.
• The app does not keep a history of where you went.
• Settings and saved favourites are stored only on this phone.'''),
      );
}

class _TextSheet extends StatelessWidget {
  final String title;
  final String body;
  const _TextSheet({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(body.trim(), style: const TextStyle(fontSize: 15, height: 1.5)),
          ]),
        ),
      );
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // Material (not a coloured Container) so ListTile ink/taps stay visible.
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      );
}
