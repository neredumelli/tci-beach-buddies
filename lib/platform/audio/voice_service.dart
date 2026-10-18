import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';

/// Result of checking the device speech engine (shown by "Test voice").
class VoiceCheck {
  final bool ok;
  final String message;
  const VoiceCheck(this.ok, this.message);
}

/// Speech output boundary. Implemented with the device's built-in
/// text-to-speech engine, which runs on-device (no network) on Android and
/// iOS when an offline voice is installed.
abstract class VoiceService {
  Future<void> speak(String text, {bool interrupt = true});
  Future<void> stop();
  bool get isSpeaking;
  Future<VoiceCheck> check();
}

class DeviceVoiceService implements VoiceService {
  final FlutterTts _tts = FlutterTts();
  Future<bool>? _init;
  bool _speaking = false;
  String? _engine;
  String? _language;

  /// Starts the engine immediately so it is bound before the first phrase
  /// (Android binds the TTS service asynchronously; speaking before it is
  /// ready is silently dropped).
  DeviceVoiceService() {
    _init = _initialise();
  }

  @override
  bool get isSpeaking => _speaking;

  Future<bool> _initialise() async {
    try {
      _tts.setStartHandler(() => _speaking = true);
      _tts.setCompletionHandler(() => _speaking = false);
      _tts.setCancelHandler(() => _speaking = false);
      _tts.setErrorHandler((_) => _speaking = false);
      if (Platform.isAndroid) {
        // Wait (bounded) for the engine to bind.
        for (var i = 0; i < 20; i++) {
          final e = await _tts.getDefaultEngine;
          if (e != null && '$e'.isNotEmpty) {
            _engine = '$e';
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (_engine == null) return false;
      } else {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.duckOthers, IosTextToSpeechAudioCategoryOptions.mixWithOthers],
          IosTextToSpeechAudioMode.voicePrompt,
        );
        _engine = 'iOS speech';
      }
      for (final lang in ['en-US', 'en-GB', 'en']) {
        try {
          final ok = await _tts.isLanguageAvailable(lang);
          if (ok == true || ok == 1) {
            await _tts.setLanguage(lang);
            _language = lang;
            break;
          }
        } catch (_) {}
      }
      await _tts.setSpeechRate(Platform.isIOS ? 0.5 : 0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ready() async {
    final ok = await (_init ??= _initialise());
    if (!ok) _init = _initialise(); // try again next time (engine may appear later)
    return ok;
  }

  @override
  Future<void> speak(String text, {bool interrupt = true}) async {
    if (text.trim().isEmpty) return;
    if (!await _ready()) return;
    try {
      if (interrupt) await _tts.stop();
      var r = await _tts.speak(text);
      if (r != 1 && r != true) {
        // Engine was not ready yet: wait and retry once.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        r = await _tts.speak(text);
      }
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
  }

  @override
  Future<VoiceCheck> check() async {
    final ok = await _ready();
    if (!ok) {
      return const VoiceCheck(false,
          'No text-to-speech engine is installed on this device. On Android open Settings > Accessibility > '
          'Text-to-speech output and install "Speech Services by Google" with an English voice. '
          '(Many emulators have no speech engine - test voice on a real phone.)');
    }
    if (_language == null) {
      return VoiceCheck(false,
          'Speech engine "$_engine" has no English voice installed. Install English voice data in the phone\'s '
          'text-to-speech settings (download once while online; it then works offline).');
    }
    await speak('Welcome to Grand Turk. Voice guidance is working.');
    return VoiceCheck(true, 'Voice is working ($_engine, $_language). If you heard nothing, raise the MEDIA volume.');
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
  @override
  Future<VoiceCheck> check() async => const VoiceCheck(true, 'test voice');
}
