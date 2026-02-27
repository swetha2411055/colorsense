import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../models/scan_result.dart';
import '../services/color_detection_service.dart';
import '../services/haptic_service.dart';
import '../core/theme.dart';
import 'result_screen.dart';
import 'dart:async';
import 'dart:typed_data';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessingFrame = false;
  List<DetectedColor> _liveColors = [];
  Timer? _frameTimer;
  final _haptic = HapticService();
  List<DetectedColor>? _lastColors;
  Size _previewSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) return;
      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _previewSize = _controller!.value.previewSize != null
            ? Size(_controller!.value.previewSize!.height, _controller!.value.previewSize!.width)
            : const Size(640, 480);
      });
      _frameTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) => _processFrame());
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _processFrame() async {
    if (_isProcessingFrame || _controller == null || !_controller!.value.isInitialized) return;
    _isProcessingFrame = true;
    try {
      final file   = await _controller!.takePicture();
      final bytes  = await file.readAsBytes();
      final svc    = ColorDetectionService();
      await svc.init();
      final colors = await svc.detectColorsWithYolo(bytes);
      svc.dispose();

      if (mounted) {
        // Vibrate / speak on dominant color change
        if (_lastColors != null &&
            colors.isNotEmpty &&
            _lastColors!.isNotEmpty &&
            _lastColors!.first.name != colors.first.name) {
          final settings = context.read<SettingsProvider>();
          if (settings.vibrationEnabled) await _haptic.colorChangeAlert();
          if (settings.voiceEnabled) {
            context.read<AppProvider>().speakColors(colors.take(2).toList(), vibrate: false);
          }
        }
        setState(() { _liveColors = colors; _lastColors = colors; });
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    }
    _isProcessingFrame = false;
  }

  Future<void> _capture() async {
    if (_controller == null) return;
    final file  = await _controller!.takePicture();
    final bytes = await file.readAsBytes();
    final provider = context.read<AppProvider>();
    await provider.processImageBytes(bytes);
    if (provider.currentResult != null && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ResultScreen(result: provider.currentResult!),
      ));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    if (state == AppLifecycleState.inactive) { _frameTimer?.cancel(); _controller?.dispose(); }
    else if (state == AppLifecycleState.resumed) _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frameTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Camera preview
        if (_isInitialized && _controller != null)
          Positioned.fill(child: CameraPreview(_controller!))
        else
          const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)),

        // YOLO bounding box overlays
        if (_liveColors.isNotEmpty)
          Positioned.fill(child: LayoutBuilder(builder: (ctx, constraints) {
            return CustomPaint(
              painter: _YoloBBoxPainter(
                detections: _liveColors,
                canvasSize: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            );
          })),

        // Color label chips (floating over each box)
        ..._liveColors.map((c) => _buildFloatingLabel(c)),

        // Top bar
        SafeArea(child: _buildTopBar()),

        // Bottom panel
        Align(alignment: Alignment.bottomCenter, child: _buildBottomPanel()),
      ]),
    );
  }

  Widget _buildFloatingLabel(DetectedColor c) {
    return LayoutBuilder(builder: (ctx, constraints) {
      // Already in [0,1] — map to screen
      final sw = MediaQuery.of(context).size.width;
      final sh = MediaQuery.of(context).size.height;
      // Place label at top of bounding box
      final rawY = c.boundingBox != null
          ? (c.boundingBox!.top * sh * 0.72) - 28
          : c.labelPosition.dy * sh * 0.7;
      final rawX = c.labelPosition.dx * sw - 50;

      return Positioned(
        left: rawX.clamp(8.0, sw - 130),
        top:  rawY.clamp(56.0, sh * 0.65),
        child: GestureDetector(
          onTap: () => context.read<AppProvider>().speakSingle(c),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 180),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.82),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.flutterColor.withOpacity(0.7), width: 1.5),
              boxShadow: [BoxShadow(color: c.flutterColor.withOpacity(0.25), blurRadius: 8)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: c.flutterColor, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Flexible(child: Text(
                c.name,
                style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              )),
            ]),
          ),
        ),
      );
    });
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _circleBtn('←', () {}),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: AppTheme.accentRed, borderRadius: BorderRadius.circular(20)),
          child: Text('● LIVE', style: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ),
        _circleBtn('⚡', () {}),
      ]),
    );
  }

  Widget _circleBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.black54, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 14))),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      color: Colors.black.withOpacity(0.85),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Scrollable color strip
        if (_liveColors.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _liveColors.take(6).map((c) => Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: c.flutterColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.flutterColor.withOpacity(0.5)),
                ),
                child: Center(child: Text(
                  c.name,
                  style: TextStyle(fontSize: 10, color: c.flutterColor, fontWeight: FontWeight.w600),
                )),
              )).toList(),
            ),
          ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _circleBtn('🔊', () {
            if (_liveColors.isNotEmpty) context.read<AppProvider>().speakColors(_liveColors);
          }),
          GestureDetector(
            onTap: _capture,
            child: Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                color: AppTheme.accentCyan,
                borderRadius: BorderRadius.circular(34),
                boxShadow: [BoxShadow(color: AppTheme.accentCyan.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)],
              ),
              child: const Center(child: Text('📸', style: TextStyle(fontSize: 26))),
            ),
          ),
          _circleBtn('↩️', () {}),
        ]),
      ]),
    );
  }
}

// ── Custom painter: draws YOLO bounding boxes ─────────────────────────────────
class _YoloBBoxPainter extends CustomPainter {
  final List<DetectedColor> detections;
  final Size canvasSize;

  _YoloBBoxPainter({required this.detections, required this.canvasSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      if (det.boundingBox == null) continue;
      final bb = det.boundingBox!;

      // Map normalized box to canvas
      final rect = Rect.fromLTWH(
        bb.left   * size.width,
        bb.top    * size.height * 0.72, // 0.72 accounts for bottom panel
        bb.width  * size.width,
        bb.height * size.height * 0.72,
      );

      // Box stroke
      final paint = Paint()
        ..color    = det.flutterColor.withOpacity(0.85)
        ..style    = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);

      // Corner accents
      _drawCorners(canvas, rect, det.flutterColor);
    }
  }

  void _drawCorners(Canvas canvas, Rect rect, Color color) {
    const len = 14.0;
    const thick = 3.0;
    final p = Paint()..color = color..strokeWidth = thick..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(len, 0), p);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, len), p);
    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-len, 0), p);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, len), p);
    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(len, 0), p);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -len), p);
    // Bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-len, 0), p);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -len), p);
  }

  @override
  bool shouldRepaint(_YoloBBoxPainter old) => old.detections != detections;
}
