import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../providers/settings_provider.dart';

/// RecolorizationService
/// Applies CVD (Color Vision Deficiency) simulation and correction matrices.
/// Uses Brettel/Viénot dichromacy simulation matrices.
class RecolorizationService {

  // ===== SIMULATION MATRICES (what CVD users see) =====
  // These matrices simulate how colors appear to CVD users.
  // Deuteranopia (Red-Green, missing M cones)
  static const List<List<double>> _deuteranopiaSim = [
    [0.29900, 0.58700, 0.11400],
    [0.29900, 0.58700, 0.11400],
    [0.00000, 0.10000, 0.89000],
  ];

  // Protanopia (Red-Green, missing L cones)
  static const List<List<double>> _protanopiaSim = [
    [0.10889, 0.88780, 0.00000],
    [0.10889, 0.88780, 0.00000],
    [0.00000, 0.09580, 0.90420],
  ];

  // Tritanopia (Blue-Yellow, missing S cones)
  static const List<List<double>> _tritanopiaSim = [
    [0.95, 0.05, 0.00],
    [0.00, 0.43333, 0.56667],
    [0.00, 0.47500, 0.52500],
  ];

  // ===== CORRECTION MATRICES (compensate for CVD) =====
  // Shift lost color info to channels the user can perceive.
  // Deuteranopia correction: push red/green differences into blue channel
  static const List<List<double>> _deuteranopiaCorrect = [
    [1.0, 0.0, 0.0],
    [0.494207, 0.0, 1.248531],
    [0.0, 0.0, 1.0],
  ];

  // Protanopia correction
  static const List<List<double>> _protanopiaCorrect = [
    [0.0, 2.02344, -2.52581],
    [0.0, 1.0, 0.0],
    [0.0, 0.0, 1.0],
  ];

  // Tritanopia correction
  static const List<List<double>> _tritanopiaCorrect = [
    [1.0, 0.0, 0.0],
    [0.0, 1.0, 0.0],
    [-0.395913, 0.801109, 0.0],
  ];

  /// Apply CVD correction to image bytes.
  /// Returns recolorized image bytes.
  static Future<Uint8List?> applyCorrection(
    List<int> imageBytes,
    ColorBlindnessType cvdType,
  ) async {
    if (cvdType == ColorBlindnessType.none) return Uint8List.fromList(imageBytes);

    final image = img.decodeImage(Uint8List.fromList(imageBytes));
    if (image == null) return null;

    final matrix = _getCorrectMatrix(cvdType);
    if (matrix == null) return Uint8List.fromList(imageBytes);

    return _applyMatrix(image, matrix);
  }

  /// Simulate CVD (show what user currently sees without correction).
  static Future<Uint8List?> applySimulation(
    List<int> imageBytes,
    ColorBlindnessType cvdType,
  ) async {
    if (cvdType == ColorBlindnessType.none) return Uint8List.fromList(imageBytes);

    final image = img.decodeImage(Uint8List.fromList(imageBytes));
    if (image == null) return null;

    final matrix = _getSimMatrix(cvdType);
    if (matrix == null) return Uint8List.fromList(imageBytes);

    return _applyMatrix(image, matrix);
  }

  static List<List<double>>? _getCorrectMatrix(ColorBlindnessType type) {
    switch (type) {
      case ColorBlindnessType.deuteranopia: return _deuteranopiaCorrect;
      case ColorBlindnessType.protanopia: return _protanopiaCorrect;
      case ColorBlindnessType.tritanopia: return _tritanopiaCorrect;
      default: return null;
    }
  }

  static List<List<double>>? _getSimMatrix(ColorBlindnessType type) {
    switch (type) {
      case ColorBlindnessType.deuteranopia: return _deuteranopiaSim;
      case ColorBlindnessType.protanopia: return _protanopiaSim;
      case ColorBlindnessType.tritanopia: return _tritanopiaSim;
      default: return null;
    }
  }

  static Uint8List _applyMatrix(img.Image image, List<List<double>> matrix) {
    final output = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        final nr = (matrix[0][0] * r + matrix[0][1] * g + matrix[0][2] * b).clamp(0.0, 1.0);
        final ng = (matrix[1][0] * r + matrix[1][1] * g + matrix[1][2] * b).clamp(0.0, 1.0);
        final nb = (matrix[2][0] * r + matrix[2][1] * g + matrix[2][2] * b).clamp(0.0, 1.0);

        output.setPixelRgba(x, y,
          (nr * 255).round(),
          (ng * 255).round(),
          (nb * 255).round(),
          pixel.a.toInt(),
        );
      }
    }

    return Uint8List.fromList(img.encodePng(output));
  }

  /// Get a human-readable description of what CVD affects
  static String getCvdDescription(ColorBlindnessType type) {
    switch (type) {
      case ColorBlindnessType.deuteranopia:
        return 'Reduced sensitivity to green light. Red and green hues appear similar.';
      case ColorBlindnessType.protanopia:
        return 'Reduced sensitivity to red light. Reds appear dark, red-green confusion.';
      case ColorBlindnessType.tritanopia:
        return 'Reduced sensitivity to blue light. Blue-yellow confusion.';
      case ColorBlindnessType.monochromacy:
        return 'Complete color blindness, only shades of gray.';
      case ColorBlindnessType.anomalous:
        return 'Partial color vision deficiency with shifted color perception.';
      case ColorBlindnessType.none:
        return 'Normal color vision.';
    }
  }
}
