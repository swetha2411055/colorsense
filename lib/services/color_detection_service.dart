import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/scan_result.dart';
import 'yolov9_service.dart';
import 'package:image/image.dart' as img;

/// ColorDetectionService (YOLOv9 edition)
///
/// Pipeline:
///   1. YOLOv9  → detect objects + bounding boxes
///   2. K-Means → dominant RGB per box
///   3. Nearest-neighbor color name lookup
///
/// Produces labels like "Crimson Red shirt", "Sky Blue car"
class ColorDetectionService {
  YOLOv9Service? _yolo;
  Interpreter? _colorizerInterpreter;
  List<Map<String, dynamic>> _colorNames = [];
  bool _initialized = false;

  bool get yoloLoaded => _yolo?.isLoaded ?? false;

  Future<void> init() async {
    if (_initialized) return;
    await _loadColorNames();
    _yolo = YOLOv9Service();
    await _yolo!.init();
    await _loadColorizer();
    _initialized = true;
  }

  Future<void> _loadColorNames() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/color_names.json');
      _colorNames = List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
    } catch (e) {
      debugPrint('Color names load error: $e');
      _colorNames = _builtinColors;
    }
  }

  Future<void> _loadColorizer() async {
    try {
      _colorizerInterpreter =
          await Interpreter.fromAsset('assets/models/ddcolor.tflite');
    } catch (_) {
      // Optional — matrix recolorization is the fallback
    }
  }

  // ── MAIN PUBLIC API ────────────────────────────────────────────────────────

  /// Full YOLOv9 → K-Means → color name pipeline.
  Future<List<DetectedColor>> detectColorsWithYolo(
      List<int> imageBytes) async {
    if (!_initialized) await init();

    final decoded = img.decodeImage(Uint8List.fromList(imageBytes));
    if (decoded == null) return [];

    // Step 1: YOLO object detection
    final detections = await _yolo!.detect(imageBytes);
    if (detections.isEmpty) return _fallbackWholeImage(decoded);

    // Step 2: dominant color per bounding box
    final results = <DetectedColor>[];
    final seenLabels = <String>{};

    for (final det in detections) {
      final rx =
          (det.x * decoded.width).round().clamp(0, decoded.width - 1);
      final ry =
          (det.y * decoded.height).round().clamp(0, decoded.height - 1);
      final rw = (det.width * decoded.width)
          .round()
          .clamp(1, decoded.width - rx);
      final rh = (det.height * decoded.height)
          .round()
          .clamp(1, decoded.height - ry);

      final cropped =
          img.copyCrop(decoded, x: rx, y: ry, width: rw, height: rh);
      final clusters = _kMeans(cropped, k: 1);
      if (clusters.isEmpty) continue;

      final (r, g, b, pct) = clusters.first;
      final colorName = _nearestColorName(r, g, b);
      final compound = '$colorName ${det.label}';

      if (seenLabels.contains(compound)) continue;
      seenLabels.add(compound);

      results.add(DetectedColor(
        name: compound,
        colorOnly: colorName,
        objectLabel: det.label,
        r: r,
        g: g,
        b: b,
        percentage: pct,
        confidence: det.confidence,
        labelPosition: det.center,
        boundingBox:
            Rect.fromLTWH(det.x, det.y, det.width, det.height),
      ));
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results.take(10).toList();
  }

  /// Fallback when YOLO returns no detections: divide image into 4 zones
  List<DetectedColor> _fallbackWholeImage(img.Image decoded) {
    final regions = [
      (0.0, 0.0, 1.0, 1.0, 'scene'),
      (0.1, 0.0, 0.8, 0.5, 'upper area'),
      (0.1, 0.5, 0.8, 0.5, 'lower area'),
    ];
    final results = <DetectedColor>[];
    for (final (x, y, w, h, label) in regions) {
      final rx = (x * decoded.width).round();
      final ry = (y * decoded.height).round();
      final rw = (w * decoded.width).round().clamp(1, decoded.width - rx);
      final rh =
          (h * decoded.height).round().clamp(1, decoded.height - ry);
      final cropped =
          img.copyCrop(decoded, x: rx, y: ry, width: rw, height: rh);
      final clusters = _kMeans(cropped, k: 2);
      for (final (r, g, b, pct) in clusters) {
        final name = _nearestColorName(r, g, b);
        results.add(DetectedColor(
          name: '$name $label',
          colorOnly: name,
          objectLabel: label,
          r: r, g: g, b: b,
          percentage: pct,
          confidence: 0.5,
          labelPosition: Offset(x + w / 2, y + h / 2),
          boundingBox: Rect.fromLTWH(x, y, w, h),
        ));
      }
    }
    results.sort((a, b) => b.percentage.compareTo(a.percentage));
    return results.take(8).toList();
  }

  /// Legacy shim for backward compat
  Future<List<SaliencyRegion>> detectSaliencyRegions(
      List<int> imageBytes) async {
    final dets = await (_yolo?.detect(imageBytes) ?? Future.value([]));
    return dets
        .map((d) => SaliencyRegion(
              x: d.x,
              y: d.y,
              width: d.width,
              height: d.height,
              score: d.confidence,
              label: d.label,
            ))
        .toList();
  }

  Future<List<DetectedColor>> detectColors(
    List<int> imageBytes,
    List<SaliencyRegion> _,
  ) =>
      detectColorsWithYolo(imageBytes);

  // ── K-MEANS ────────────────────────────────────────────────────────────────

  List<(int, int, int, double)> _kMeans(img.Image image,
      {int k = 3, int maxIter = 12}) {
    final rng = Random(42);
    final pixels = <List<int>>[];
    final step =
        max(1, (image.width * image.height) ~/ 600);
    int n = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (n++ % step == 0) {
          final p = image.getPixel(x, y);
          pixels.add([p.r.toInt(), p.g.toInt(), p.b.toInt()]);
        }
      }
    }
    if (pixels.length < k) return [];

    var centroids = List.generate(k, (_) {
      final p = pixels[rng.nextInt(pixels.length)];
      return [p[0].toDouble(), p[1].toDouble(), p[2].toDouble()];
    });
    final assignments = List.filled(pixels.length, 0);

    for (int iter = 0; iter < maxIter; iter++) {
      bool changed = false;
      for (int i = 0; i < pixels.length; i++) {
        int nearest = 0;
        double minD = double.infinity;
        for (int c = 0; c < k; c++) {
          final d = _dist(pixels[i], centroids[c]);
          if (d < minD) {
            minD = d;
            nearest = c;
          }
        }
        if (assignments[i] != nearest) {
          assignments[i] = nearest;
          changed = true;
        }
      }
      if (!changed) break;

      final sums = List.generate(k, (_) => [0.0, 0.0, 0.0]);
      final counts = List.filled(k, 0);
      for (int i = 0; i < pixels.length; i++) {
        final c = assignments[i];
        sums[c][0] += pixels[i][0];
        sums[c][1] += pixels[i][1];
        sums[c][2] += pixels[i][2];
        counts[c]++;
      }
      for (int c = 0; c < k; c++) {
        if (counts[c] > 0) {
          centroids[c] = [
            sums[c][0] / counts[c],
            sums[c][1] / counts[c],
            sums[c][2] / counts[c]
          ];
        }
      }
    }

    final total = pixels.length;
    return List.generate(k, (c) {
      final count = assignments.where((a) => a == c).length;
      final cen = centroids[c];
      return (
        cen[0].round(),
        cen[1].round(),
        cen[2].round(),
        count / total
      );
    }).where((r) => r.$4 > 0.05).toList();
  }

  double _dist(List<int> px, List<double> cen) => sqrt(
        pow(px[0] - cen[0], 2) +
            pow(px[1] - cen[1], 2) +
            pow(px[2] - cen[2], 2),
      );

  // ── COLOR NAMING ───────────────────────────────────────────────────────────

  String _nearestColorName(int r, int g, int b) {
    String best = 'Unknown';
    double bestDist = double.infinity;
    for (final c in _colorNames) {
      final d = sqrt(
        pow(r - (c['r'] as int), 2) +
            pow(g - (c['g'] as int), 2) +
            pow(b - (c['b'] as int), 2),
      );
      if (d < bestDist) {
        bestDist = d;
        best = c['name'] as String;
      }
    }
    return best;
  }

  // Built-in minimal palette in case JSON fails to load
  static const List<Map<String, dynamic>> _builtinColors = [
    {'name': 'Red',    'r': 220, 'g': 20,  'b': 60},
    {'name': 'Orange', 'r': 255, 'g': 140, 'b': 0},
    {'name': 'Yellow', 'r': 255, 'g': 215, 'b': 0},
    {'name': 'Green',  'r': 34,  'g': 139, 'b': 34},
    {'name': 'Blue',   'r': 30,  'g': 144, 'b': 255},
    {'name': 'Purple', 'r': 128, 'g': 0,   'b': 128},
    {'name': 'Pink',   'r': 255, 'g': 105, 'b': 180},
    {'name': 'Brown',  'r': 139, 'g': 69,  'b': 19},
    {'name': 'Gray',   'r': 128, 'g': 128, 'b': 128},
    {'name': 'White',  'r': 255, 'g': 255, 'b': 255},
    {'name': 'Black',  'r': 10,  'g': 10,  'b': 10},
    {'name': 'Teal',   'r': 0,   'g': 128, 'b': 128},
    {'name': 'Cyan',   'r': 0,   'g': 200, 'b': 220},
  ];

  void dispose() {
    _yolo?.dispose();
    _colorizerInterpreter?.close();
    _initialized = false;
  }
}
