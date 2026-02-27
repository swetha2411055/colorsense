import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum ColorBlindnessType { deuteranopia, protanopia, tritanopia, monochromacy, anomalous, none }

class SettingsProvider extends ChangeNotifier {
  late Box _box;

  ColorBlindnessType _cvdType = ColorBlindnessType.deuteranopia;
  bool _voiceEnabled = true;
  bool _vibrationEnabled = true;
  bool _chatbotEnabled = true;
  bool _recolorizationEnabled = true;
  bool _saliencyOverlay = false;
  double _voiceSpeed = 0.5;
  double _fontSize = 1.0;
  String _labelStyle = 'text'; // 'text', 'emoji', 'border'

  ColorBlindnessType get cvdType => _cvdType;
  bool get voiceEnabled => _voiceEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get chatbotEnabled => _chatbotEnabled;
  bool get recolorizationEnabled => _recolorizationEnabled;
  bool get saliencyOverlay => _saliencyOverlay;
  double get voiceSpeed => _voiceSpeed;
  double get fontSize => _fontSize;
  String get labelStyle => _labelStyle;

  Future<void> init() async {
    _box = Hive.box('colorsense_prefs');
    _cvdType = ColorBlindnessType.values[_box.get('cvd_type', defaultValue: 0)];
    _voiceEnabled = _box.get('voice', defaultValue: true);
    _vibrationEnabled = _box.get('vibration', defaultValue: true);
    _chatbotEnabled = _box.get('chatbot', defaultValue: true);
    _recolorizationEnabled = _box.get('recolor', defaultValue: true);
    _saliencyOverlay = _box.get('saliency', defaultValue: false);
    _voiceSpeed = _box.get('voice_speed', defaultValue: 0.5);
    _fontSize = _box.get('font_size', defaultValue: 1.0);
    _labelStyle = _box.get('label_style', defaultValue: 'text');
    notifyListeners();
  }

  void setCvdType(ColorBlindnessType type) {
    _cvdType = type;
    _box.put('cvd_type', type.index);
    notifyListeners();
  }

  void toggleVoice(bool v) { _voiceEnabled = v; _box.put('voice', v); notifyListeners(); }
  void toggleVibration(bool v) { _vibrationEnabled = v; _box.put('vibration', v); notifyListeners(); }
  void toggleChatbot(bool v) { _chatbotEnabled = v; _box.put('chatbot', v); notifyListeners(); }
  void toggleRecolorization(bool v) { _recolorizationEnabled = v; _box.put('recolor', v); notifyListeners(); }
  void toggleSaliencyOverlay(bool v) { _saliencyOverlay = v; _box.put('saliency', v); notifyListeners(); }
  void setVoiceSpeed(double v) { _voiceSpeed = v; _box.put('voice_speed', v); notifyListeners(); }
  void setFontSize(double v) { _fontSize = v; _box.put('font_size', v); notifyListeners(); }
  void setLabelStyle(String v) { _labelStyle = v; _box.put('label_style', v); notifyListeners(); }
}
