import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/scan_result.dart';
import '../services/color_detection_service.dart';
import '../services/voice_service.dart';
import '../services/haptic_service.dart';

class AppProvider extends ChangeNotifier {
  final ColorDetectionService _colorService = ColorDetectionService();
  final VoiceService _voiceService = VoiceService();
  final HapticService _hapticService = HapticService();

  List<ScanResult> _history = [];
  ScanResult? _currentResult;
  bool _isProcessing = false;
  String _statusMessage = '';

  List<ScanResult> get history => _history;
  ScanResult? get currentResult => _currentResult;
  bool get isProcessing => _isProcessing;
  String get statusMessage => _statusMessage;

  AppProvider() {
    _init();
  }

  Future<void> _init() async {
    _loadHistory();
    await _colorService.init();
    await _voiceService.init();
  }

  void _loadHistory() {
    try {
      final box = Hive.box('scan_history');
      _history = box.values
          .map((e) {
            try {
              return ScanResult.fromJson(
                  Map<String, dynamic>.from(jsonDecode(e as String)));
            } catch (_) {
              return null;
            }
          })
          .whereType<ScanResult>()
          .toList()
          .reversed
          .toList();
    } catch (_) {
      _history = [];
    }
    notifyListeners();
  }

  Future<void> processImageBytes(List<int> imageBytes) async {
    _isProcessing = true;
    _statusMessage = 'Running YOLOv9 object detection...';
    notifyListeners();

    try {
      // YOLOv9 → K-Means → color name  (single pipeline call)
      final detectedColors =
          await _colorService.detectColorsWithYolo(imageBytes);

      _statusMessage = 'Building result...';
      notifyListeners();

      // Convert YOLOv9 bounding boxes → SaliencyRegion for legacy compat
      final saliencyRegions = detectedColors
          .map((c) => SaliencyRegion(
                x: c.boundingBox?.left ?? c.labelPosition.dx - 0.1,
                y: c.boundingBox?.top ?? c.labelPosition.dy - 0.1,
                width: c.boundingBox?.width ?? 0.2,
                height: c.boundingBox?.height ?? 0.2,
                score: c.confidence,
                label: c.objectLabel,
              ))
          .toList();

      _currentResult = ScanResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        imageBytes: imageBytes,
        detectedColors: detectedColors,
        saliencyRegions: saliencyRegions,
      );

      // Persist to Hive — skip if imageBytes too large for box (store without image)
      try {
        final box = Hive.box('scan_history');
        final resultForStorage = ScanResult(
          id: _currentResult!.id,
          timestamp: _currentResult!.timestamp,
          imageBytes: imageBytes.length < 500000
              ? imageBytes
              : imageBytes.sublist(0, 500000),
          detectedColors: detectedColors,
          saliencyRegions: saliencyRegions,
        );
        await box.put(_currentResult!.id, jsonEncode(resultForStorage.toJson()));
      } catch (_) {
        // Storage failure is non-fatal
      }

      _history.insert(0, _currentResult!);
      if (_history.length > 50) _history = _history.sublist(0, 50);

      _statusMessage =
          'Done! ${detectedColors.length} object${detectedColors.length == 1 ? '' : 's'} detected.';
    } catch (e) {
      _statusMessage = 'Error: ${e.toString().split('\n').first}';
      debugPrint('processImageBytes error: $e');
    }

    _isProcessing = false;
    notifyListeners();
  }

  Future<void> speakColors(List<DetectedColor> colors,
      {bool vibrate = true}) async {
    if (colors.isEmpty) return;
    final text = colors.map((c) => c.name).join(', ');
    await _voiceService.speak('I can see: $text');
    if (vibrate) await _hapticService.colorDetectedPattern(colors.length);
  }

  Future<void> speakSingle(DetectedColor color) async {
    final pct = (color.percentage * 100).toStringAsFixed(0);
    await _voiceService.speak('${color.name}, $pct percent');
    await _hapticService.singlePulse();
  }

  void clearHistory() {
    _history.clear();
    try {
      Hive.box('scan_history').clear();
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _colorService.dispose();
    _voiceService.dispose();
    super.dispose();
  }
}
