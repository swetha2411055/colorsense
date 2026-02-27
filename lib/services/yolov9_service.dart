import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// Result of a single YOLOv9 detection
class YoloDetection {
  final String label;
  final double confidence;
  final double x, y, width, height; // normalized 0-1

  const YoloDetection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Offset get center => Offset(x + width / 2, y + height / 2);
}

/// YOLOv9Service
///
/// Runs YOLOv9-tiny TFLite for object detection.
/// Falls back to centre-region pseudo-detections when model file absent.
///
/// Model:  assets/models/yolov9_tiny.tflite
/// Input:  [1, 640, 640, 3] float32  (values in [0, 1])
/// Output: [1, 25200, 85]   float32
///         col 0-3  = cx, cy, w, h (in [0, inputSize] pixels)
///         col 4    = objectness score (pre-sigmoid)
///         col 5-84 = per-class scores (pre-sigmoid)
class YOLOv9Service {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  static const int inputSize      = 640;
  static const double confThresh  = 0.35;
  static const double iouThresh   = 0.45;
  static const int maxDetections  = 20;

  bool get isLoaded => _isLoaded;

  // COCO 80-class labels
  static const List<String> _labels = [
    'person','bicycle','car','motorcycle','airplane','bus','train','truck',
    'boat','traffic light','fire hydrant','stop sign','parking meter','bench',
    'bird','cat','dog','horse','sheep','cow','elephant','bear','zebra',
    'giraffe','backpack','umbrella','handbag','tie','suitcase','frisbee',
    'skis','snowboard','sports ball','kite','baseball bat','baseball glove',
    'skateboard','surfboard','tennis racket','bottle','wine glass','cup',
    'fork','knife','spoon','bowl','banana','apple','sandwich','orange',
    'broccoli','carrot','hot dog','pizza','donut','cake','chair','couch',
    'potted plant','bed','dining table','toilet','tv','laptop','mouse',
    'remote','keyboard','cell phone','microwave','oven','toaster','sink',
    'refrigerator','book','clock','vase','scissors','teddy bear',
    'hair drier','toothbrush',
  ];

  Future<void> init() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      // Try GPU delegate for 3-5× speedup
      try {
        options.addDelegate(GpuDelegate());
      } catch (_) {
        // GPU unavailable — CPU is fine
      }
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolov9_tiny.tflite',
        options: options,
      );
      _isLoaded = true;
      debugPrint('YOLOv9: model loaded ✓');
    } catch (e) {
      _isLoaded = false;
      debugPrint('YOLOv9: model not found, using fallback ($e)');
    }
  }

  Future<List<YoloDetection>> detect(List<int> imageBytes) async {
    final decoded = img.decodeImage(Uint8List.fromList(imageBytes));
    if (decoded == null) return [];
    if (!_isLoaded || _interpreter == null) return _fallback();
    return _runInference(decoded);
  }

  List<YoloDetection> _runInference(img.Image image) {
    // ── Preprocess ────────────────────────────────────────────────────────
    final resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    final inputBuf = Float32List(inputSize * inputSize * 3);
    int idx = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final p = resized.getPixel(x, y);
        inputBuf[idx++] = p.r / 255.0;
        inputBuf[idx++] = p.g / 255.0;
        inputBuf[idx++] = p.b / 255.0;
      }
    }
    // Shape [1, 640, 640, 3]
    final inputTensor = inputBuf.reshape([1, inputSize, inputSize, 3]);

    // ── Output buffer [1, 25200, 85] ─────────────────────────────────────
    final outputBuf = Float32List(1 * 25200 * 85)
        .reshape([1, 25200, 85]);

    try {
      _interpreter!.run(inputTensor, outputBuf);
    } catch (e) {
      debugPrint('YOLOv9 inference error: $e');
      return _fallback();
    }

    // ── Parse predictions ─────────────────────────────────────────────────
    final preds = outputBuf[0] as List;
    final raw = <YoloDetection>[];

    for (int i = 0; i < preds.length; i++) {
      final pred = preds[i] as List;

      final objConf = _sigmoid((pred[4] as num).toDouble());
      if (objConf < confThresh) continue;

      int bestCls = 0;
      double bestScore = 0.0;
      for (int c = 5; c < 85 && c < pred.length; c++) {
        final s = objConf * _sigmoid((pred[c] as num).toDouble());
        if (s > bestScore) {
          bestScore = s;
          bestCls = c - 5;
        }
      }
      if (bestScore < confThresh) continue;

      // cx, cy, w, h are in [0, inputSize] pixel space → normalise
      final cx = (pred[0] as num).toDouble() / inputSize;
      final cy = (pred[1] as num).toDouble() / inputSize;
      final bw = (pred[2] as num).toDouble() / inputSize;
      final bh = (pred[3] as num).toDouble() / inputSize;

      raw.add(YoloDetection(
        label: bestCls < _labels.length ? _labels[bestCls] : 'object',
        confidence: bestScore,
        x: (cx - bw / 2).clamp(0.0, 1.0),
        y: (cy - bh / 2).clamp(0.0, 1.0),
        width: bw.clamp(0.0, 1.0),
        height: bh.clamp(0.0, 1.0),
      ));
    }

    return _nms(raw).take(maxDetections).toList();
  }

  // ── NMS ───────────────────────────────────────────────────────────────────
  List<YoloDetection> _nms(List<YoloDetection> dets) {
    final sorted = [...dets]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final keep = <YoloDetection>[];
    final suppressed = List.filled(sorted.length, false);

    for (int i = 0; i < sorted.length; i++) {
      if (suppressed[i]) continue;
      keep.add(sorted[i]);
      for (int j = i + 1; j < sorted.length; j++) {
        if (!suppressed[j] && _iou(sorted[i], sorted[j]) > iouThresh) {
          suppressed[j] = true;
        }
      }
    }
    return keep;
  }

  double _iou(YoloDetection a, YoloDetection b) {
    final ax2 = a.x + a.width, ay2 = a.y + a.height;
    final bx2 = b.x + b.width, by2 = b.y + b.height;
    final ix1 = max(a.x, b.x), iy1 = max(a.y, b.y);
    final ix2 = min(ax2, bx2), iy2 = min(ay2, by2);
    if (ix2 <= ix1 || iy2 <= iy1) return 0.0;
    final inter = (ix2 - ix1) * (iy2 - iy1);
    final union = a.width * a.height + b.width * b.height - inter;
    return union > 0 ? inter / union : 0.0;
  }

  double _sigmoid(double x) => 1.0 / (1.0 + exp(-x.clamp(-88.0, 88.0)));

  // Fallback: 4 centre-weighted pseudo-detections
  List<YoloDetection> _fallback() => const [
        YoloDetection(label: 'object', confidence: 0.9, x: 0.2, y: 0.2, width: 0.6, height: 0.6),
        YoloDetection(label: 'background', confidence: 0.5, x: 0.0, y: 0.0, width: 1.0, height: 0.4),
        YoloDetection(label: 'foreground', confidence: 0.4, x: 0.1, y: 0.55, width: 0.8, height: 0.45),
      ];

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
