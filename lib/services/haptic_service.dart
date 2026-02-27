import 'package:vibration/vibration.dart';

class HapticService {
  /// Single short pulse (tap feedback)
  Future<void> singlePulse() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }
  }

  /// Pattern based on number of colors detected
  Future<void> colorDetectedPattern(int colorCount) async {
    if (!(await Vibration.hasVibrator() ?? false)) return;

    // Pulse once per detected color with increasing intensity
    final pattern = <int>[];
    for (int i = 0; i < colorCount; i++) {
      pattern.addAll([0, 80, 120]); // wait, vibrate, pause
    }
    Vibration.vibrate(pattern: pattern);
  }

  /// Warm color family (red, orange, yellow) - short double pulse
  Future<void> warmColorAlert() async {
    if (!(await Vibration.hasVibrator() ?? false)) return;
    Vibration.vibrate(pattern: [0, 60, 80, 60]);
  }

  /// Cool color family (blue, green, purple) - long single pulse
  Future<void> coolColorAlert() async {
    if (!(await Vibration.hasVibrator() ?? false)) return;
    Vibration.vibrate(duration: 150);
  }

  /// Alert when dominant color changes significantly (camera mode)
  Future<void> colorChangeAlert() async {
    if (!(await Vibration.hasVibrator() ?? false)) return;
    Vibration.vibrate(pattern: [0, 100, 100, 100, 100, 100]);
  }

  Future<void> stop() async => Vibration.cancel();
}
