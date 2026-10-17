import 'package:flutter_tts/flutter_tts.dart';

/// Speech output boundary. Implemented with the device's built-in
/// text-to-speech engine, which runs on-device (no network) on Android and
/// iOS when an offline voice is installed (default on most phones).
abstract class VoiceService {
  Future<void> speak(String text, {bool interrupt = true});
  Future<void> stop();
  bool get isSpeaking;
}

class DeviceVoiceService implements VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _speaking = false;

  @override
  bool get isSpeaking => _speaking;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      _tts.setStartHandler(() => _speaking = true);
      _tts.setCompletionHandler(() => _speaking = false);
      _tts.setCancelHandler(() => _speaking = false);
      _tts.setErrorHandler((_) => _speaking = false);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      // Duck other audio rather than stopping it (iOS).
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.duckOthers, IosTextToSpeechAudioCategoryOptions.mixWithOthers],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    } catch (_) {
      // No TTS engine: speech silently unavailable, app keeps working.
    }
  }

  @override
  Future<void> speak(String text, {bool interrupt = true}) async {
    await _init();
    try {
      if (interrupt) await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
  }
}

/// Silent implementation for tests.
class RecordingVoiceService implements VoiceService {
  final List<String> spoken = [];
  @override
  bool get isSpeaking => false;
  @override
  Future<void> speak(String text, {bool interrupt = true}) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}
