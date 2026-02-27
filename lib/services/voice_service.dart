import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    if (!_initialized) await init();
    await _tts.speak(text);
  }

  Future<void> stop() async => await _tts.stop();

  Future<void> setSpeed(double speed) async {
    await _tts.setSpeechRate(speed.clamp(0.1, 1.0));
  }

  void dispose() => _tts.stop();
}
