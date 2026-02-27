import 'package:flutter/material.dart';
import 'dart:typed_data';

class ScanResult {
  final String id;
  final DateTime timestamp;
  final List<int> imageBytes;
  final List<DetectedColor> detectedColors;
  final List<SaliencyRegion> saliencyRegions; // now backed by YOLO boxes

  ScanResult({
    required this.id,
    required this.timestamp,
    required this.imageBytes,
    required this.detectedColors,
    required this.saliencyRegions,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
    id:        json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    imageBytes: List<int>.from(json['imageBytes']),
    detectedColors: (json['detectedColors'] as List)
        .map((e) => DetectedColor.fromJson(e)).toList(),
    saliencyRegions: (json['saliencyRegions'] as List)
        .map((e) => SaliencyRegion.fromJson(e)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'imageBytes': imageBytes,
    'detectedColors': detectedColors.map((e) => e.toJson()).toList(),
    'saliencyRegions': saliencyRegions.map((e) => e.toJson()).toList(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────

class DetectedColor {
  /// Compound label, e.g. "Sky Blue sky" or "Crimson Red shirt"
  final String name;

  /// Just the color part: "Sky Blue"
  final String colorOnly;

  /// Just the YOLO object part: "sky" / "shirt" / "car"
  final String objectLabel;

  final int r, g, b;
  final double percentage;
  final double confidence;       // YOLO detection confidence
  final Offset labelPosition;    // normalized 0-1 center
  final Rect? boundingBox;       // normalized 0-1 LTWH rect from YOLO

  DetectedColor({
    required this.name,
    this.colorOnly  = '',
    this.objectLabel = '',
    required this.r,
    required this.g,
    required this.b,
    required this.percentage,
    this.confidence    = 1.0,
    required this.labelPosition,
    this.boundingBox,
  });

  Color get flutterColor => Color.fromRGBO(r, g, b, 1.0);

  String get hexCode =>
      '#${r.toRadixString(16).padLeft(2,'0')}${g.toRadixString(16).padLeft(2,'0')}${b.toRadixString(16).padLeft(2,'0')}'.toUpperCase();

  factory DetectedColor.fromJson(Map<String, dynamic> j) => DetectedColor(
    name:          j['name'],
    colorOnly:     j['colorOnly']   ?? '',
    objectLabel:   j['objectLabel'] ?? '',
    r: j['r'], g: j['g'], b: j['b'],
    percentage:    (j['percentage'] as num).toDouble(),
    confidence:    (j['confidence'] as num? ?? 1.0).toDouble(),
    labelPosition: Offset((j['lx'] as num).toDouble(), (j['ly'] as num).toDouble()),
    boundingBox:   j['bbx'] != null
        ? Rect.fromLTWH(
            (j['bbx'] as num).toDouble(), (j['bby'] as num).toDouble(),
            (j['bbw'] as num).toDouble(), (j['bbh'] as num).toDouble())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'colorOnly': colorOnly,
    'objectLabel': objectLabel,
    'r': r, 'g': g, 'b': b,
    'percentage': percentage,
    'confidence': confidence,
    'lx': labelPosition.dx,
    'ly': labelPosition.dy,
    if (boundingBox != null) ...{
      'bbx': boundingBox!.left,  'bby': boundingBox!.top,
      'bbw': boundingBox!.width, 'bbh': boundingBox!.height,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────

class SaliencyRegion {
  final double x, y, width, height; // 0-1 normalized
  final double score;
  final String label; // YOLO class label e.g. "person", "car"

  SaliencyRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.score,
    this.label = '',
  });

  factory SaliencyRegion.fromJson(Map<String, dynamic> j) => SaliencyRegion(
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    width:  (j['w'] as num).toDouble(),
    height: (j['h'] as num).toDouble(),
    score:  (j['score'] as num).toDouble(),
    label:  j['label'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'x': x, 'y': y, 'w': width, 'h': height, 'score': score, 'label': label,
  };
}
