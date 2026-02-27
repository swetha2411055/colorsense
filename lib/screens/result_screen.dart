import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../models/scan_result.dart';
import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../services/recolorization_service.dart';
import '../core/theme.dart';
import 'chatbot_screen.dart';

class ResultScreen extends StatefulWidget {
  final ScanResult result;
  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Uint8List? _recolorizedImage;
  bool _showOriginal = false;
  bool _showBBoxes = true;

  @override
  void initState() {
    super.initState();
    _applyRecolorization();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<SettingsProvider>();
      if (s.voiceEnabled && widget.result.detectedColors.isNotEmpty) {
        context.read<AppProvider>().speakColors(
          widget.result.detectedColors,
          vibrate: s.vibrationEnabled,
        );
      }
    });
  }

  Future<void> _applyRecolorization() async {
    final s = context.read<SettingsProvider>();
    if (!s.recolorizationEnabled) return;
    final out = await RecolorizationService.applyCorrection(
      widget.result.imageBytes,
      s.cvdType,
    );
    if (mounted && out != null) setState(() => _recolorizedImage = out);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.result.detectedColors;
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildImageSection(colors)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '${colors.length} Object${colors.length == 1 ? '' : 's'} Detected',
                        style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tap any card to hear it  •  🔊 for all',
                        style: TextStyle(fontSize: 11, color: AppTheme.mutedColor),
                      ),
                    ])),
                    // YOLO badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                      ),
                      child: Text('YOLOv9',
                          style: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentCyan)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildColorGrid(colors),
                  const SizedBox(height: 16),
                  _buildActionRow(colors),
                  const SizedBox(height: 16),
                  _buildCvdNote(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(List<DetectedColor> colors) {
    final imageBytes = (_showOriginal || _recolorizedImage == null)
        ? Uint8List.fromList(widget.result.imageBytes)
        : _recolorizedImage!;

    return SizedBox(
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          Image.memory(imageBytes, fit: BoxFit.cover),

          // YOLO bounding box overlay
          if (_showBBoxes)
            Positioned.fill(
              child: CustomPaint(
                painter: _BBoxOverlayPainter(colors: colors),
              ),
            ),

          // Floating labels
          ...colors.map((c) => _buildLabel(c)),

          // Top buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _pill('←', onTap: () => Navigator.pop(context)),
                  Row(children: [
                    if (_recolorizedImage != null)
                      GestureDetector(
                        onTap: () => setState(() => _showOriginal = !_showOriginal),
                        child: _pill(_showOriginal ? 'Show Fixed' : 'Original'),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _showBBoxes = !_showBBoxes),
                      child: _pill(_showBBoxes ? 'Hide Boxes' : 'Show Boxes'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildLabel(DetectedColor c) {
    final sw = MediaQuery.of(context).size.width;
    final imgH = 270.0;

    double lx, ly;
    if (c.boundingBox != null) {
      lx = c.boundingBox!.left * sw;
      ly = c.boundingBox!.top * imgH + 4;
    } else {
      lx = c.labelPosition.dx * sw - 40;
      ly = c.labelPosition.dy * imgH - 14;
    }

    return Positioned(
      left: lx.clamp(4.0, sw - 140),
      top: ly.clamp(44.0, imgH - 36),
      child: GestureDetector(
        onTap: () => context.read<AppProvider>().speakSingle(c),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.flutterColor, width: 1.2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: c.flutterColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                c.name,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildColorGrid(List<DetectedColor> colors) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.9,
      ),
      itemCount: colors.length.clamp(0, 8),
      itemBuilder: (_, i) => _colorCard(colors[i]),
    );
  }

  Widget _colorCard(DetectedColor c) {
    return GestureDetector(
      onTap: () => context.read<AppProvider>().speakSingle(c),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.flutterColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.flutterColor.withOpacity(0.3)),
        ),
        child: Stack(children: [
          // Background blob
          Positioned(
            top: -6, right: -6,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: c.flutterColor.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Object label chip
              if (c.objectLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.flutterColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(c.objectLabel,
                      style: TextStyle(fontSize: 8, color: c.flutterColor, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 3),
              Text(
                c.colorOnly.isNotEmpty ? c.colorOnly : c.name,
                style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(c.hexCode,
                  style: TextStyle(fontSize: 9, color: AppTheme.mutedColor, fontFamily: 'monospace')),
              const SizedBox(height: 2),
              Text(
                '${(c.percentage * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w800, color: c.flutterColor),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildActionRow(List<DetectedColor> colors) {
    return Row(children: [
      _actionBtn('🔊', 'Voice Read', primary: true, onTap: () {
        context.read<AppProvider>().speakColors(colors);
      }),
      const SizedBox(width: 8),
      _actionBtn('💾', 'Save', onTap: () {}),
      const SizedBox(width: 8),
      _actionBtn('↗️', 'Share', onTap: () {}),
      const SizedBox(width: 8),
      _actionBtn('🤖', 'Ask AI', onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatbotScreen(
            initialImage: widget.result.imageBytes,
            initialColors: colors,
          ),
        ));
      }),
    ]);
  }

  Widget _actionBtn(String icon, String label,
      {bool primary = false, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: primary
                ? AppTheme.accentCyan.withOpacity(0.14)
                : AppTheme.surface2Color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primary
                  ? AppTheme.accentCyan.withOpacity(0.35)
                  : AppTheme.borderColor,
            ),
          ),
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: primary ? AppTheme.accentCyan : AppTheme.mutedColor)),
          ]),
        ),
      ),
    );
  }

  Widget _buildCvdNote() {
    final s = context.read<SettingsProvider>();
    final desc = RecolorizationService.getCvdDescription(s.cvdType);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface2Color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(children: [
        const Text('ℹ️', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(desc,
              style: TextStyle(
                  fontSize: 10, color: AppTheme.mutedColor, height: 1.5)),
        ),
      ]),
    );
  }
}

// ── CustomPainter: YOLO bounding boxes ────────────────────────────────────────
class _BBoxOverlayPainter extends CustomPainter {
  final List<DetectedColor> colors;
  const _BBoxOverlayPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in colors) {
      if (c.boundingBox == null) continue;
      final bb = c.boundingBox!;
      final rect = Rect.fromLTWH(
        bb.left * size.width,
        bb.top * size.height,
        bb.width * size.width,
        bb.height * size.height,
      );

      // Filled rect with low opacity
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = c.flutterColor.withOpacity(0.08)
          ..style = PaintingStyle.fill,
      );

      // Stroked border
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = c.flutterColor.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );

      // Corner accents
      _corners(canvas, rect, c.flutterColor);
    }
  }

  void _corners(Canvas canvas, Rect r, Color color) {
    const len = 12.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // TL
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(len, 0), p);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, len), p);
    // TR
    canvas.drawLine(r.topRight, r.topRight + const Offset(-len, 0), p);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, len), p);
    // BL
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(len, 0), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(0, -len), p);
    // BR
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(-len, 0), p);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(0, -len), p);
  }

  @override
  bool shouldRepaint(_BBoxOverlayPainter old) => old.colors != colors;
}
