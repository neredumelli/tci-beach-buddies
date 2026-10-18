// On-device check that the device text-to-speech engine actually speaks:
//   flutter test integration_test/voice_check_test.dart -d <device>
// Prints the engines, languages and the start/completion events it observed.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tci_beach_buddies/platform/audio/voice_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device speech engine speaks a phrase', (t) async {
    final tts = FlutterTts();
    await Future<void>.delayed(const Duration(seconds: 2));
    // ignore: avoid_print
    print('VOICE engines=${await tts.getEngines} default=${await tts.getDefaultEngine}');
    // ignore: avoid_print
    print('VOICE en-US available=${await tts.isLanguageAvailable('en-US')}');

    final voice = DeviceVoiceService();
    final check = await voice.check();
    // ignore: avoid_print
    print('VOICE check ok=${check.ok} message=${check.message}');
    final events = await voice.lastEvents(const Duration(seconds: 8));
    // ignore: avoid_print
    print('VOICE events=$events');
  });
}
