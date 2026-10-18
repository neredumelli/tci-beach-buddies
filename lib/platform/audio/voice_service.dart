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
  final List<String> _events = [];
  Completer<void>? _started;
  int _gen = 0;

  /// Starts the engine immediately so it is bound before the first phrase
  /// (Android binds the TTS service asynchronously; speaking before it is
  /// ready is silently dropped).
  DeviceVoiceService() {
    _init = _initialise();
  }

  @override
  bool get isSpeaking => _speaking;

  void _log(String e) {
    _events.add(e);
    if (_events.length > 30) _events.removeAt(0);
  }

  /// Recent engine events (start / done / error), for diagnostics.
  Future<List<String>> lastEvents(Duration wait) async {
    await Future<void>.delayed(wait);
    return List.of(_events);
  }

  Future<bool> _initialise() async {
    try {
      _tts.setStartHandler(() {
        _speaking = true;
        _log('start');
        if (!(_started?.isCompleted ?? true)) _started!.complete();
      });
      _tts.setCompletionHandler(() {
        _speaking = false;
        _log('done');
      });
      _tts.setCancelHandler(() => _speaking = false);
      _tts.setErrorHandler((m) {
        _speaking = false;
        _log('error:$m');
      });
      if (Platform.isAndroid) {
        // Wait (bounded) for the engine to bind. Some phones report no
        // "default" engine even though one is installed, so also look at the
        // installed engines and pick one explicitly (Google's first).
        List<String> engines = const [];
        for (var i = 0; i < 20; i++) {
          try {
            final d = await _tts.getDefaultEngine;
            if (d != null && '$d'.isNotEmpty) _engine = '$d';
          } catch (_) {}
          try {
            final l = await _tts.getEngines;
            if (l is List) engines = l.map((e) => '$e').where((e) => e.isNotEmpty).toList();
          } catch (_) {}
          if (_engine != null || engines.isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (_engine == null && engines.isNotEmpty) {
          _engine = engines.contains('com.google.android.tts') ? 'com.google.android.tts' : engines.first;
          try {
            await _tts.setEngine(_engine!);
          } catch (_) {}
        }
        _log('engine:${_engine ?? 'none'} installed:${engines.join(',')}');
        // No engine found: still try to speak (the system may resolve one).
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
      _log('language:${_language ?? 'default'}');
      await _tts.setSpeechRate(Platform.isIOS ? 0.5 : 0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      return true;
    } catch (e) {
      _log('init-failed:$e');
      return false;
    }
  }

  Future<void> _ready() async {
    final ok = await (_init ??= _initialise());
    if (!ok) _init = _initialise(); // try again next time (engine may appear later)
  }

  /// Speaks [text]; returns true if the engine reported that audio started.
  Future<bool> _say(String text, {bool interrupt = true}) async {
    if (text.trim().isEmpty) return false;
    final gen = ++_gen;
    await _ready();
    for (var attempt = 0; attempt < 2; attempt++) {
      if (gen != _gen) return false; // a newer phrase replaced this one
      try {
        if (interrupt) await _tts.stop();
        final started = _started = Completer<void>();
        final r = await _tts.speak(text);
        _log('speak:$r');
        final ok = await started.future.then((_) => true).timeout(const Duration(seconds: 3), onTimeout: () => false);
        if (ok) return true;
        if (gen != _gen) return false;
      } catch (e) {
        _log('speak-failed:$e');
      }
      // Engine was not ready (common right after launch): re-bind and retry.
      _init = _initialise();
      await _ready();
    }
    return false;
  }

  @override
  Future<void> speak(String text, {bool interrupt = true}) async {
    await _say(text, interrupt: interrupt);
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
    final started = await _say('Welcome to Grand Turk. Voice guidance is working.');
    if (started) {
      return VoiceCheck(true,
          'Voice is working (${_engine ?? 'system'}, ${_language ?? 'default language'}). If you heard nothing, raise the MEDIA volume.');
    }
    if (_engine == null) {
      return const VoiceCheck(false,
          'No text-to-speech engine is installed on this device. On Android open Settings > Accessibility > '
          'Text-to-speech output and install "Speech Services by Google" with an English voice. '
          '(Many emulators have no speech engine - test voice on a real phone.)');
    }
    return VoiceCheck(false,
        'The speech engine "$_engine" did not start speaking. Open the phone\'s Settings > Accessibility > '
        'Text-to-speech output, choose "Speech Services by Google", tap Play to test, and install the English voice data.');
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
