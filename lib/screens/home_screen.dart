import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../core/theme.dart';
import 'camera_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';
import 'chatbot_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildHome(),
          const CameraScreen(),
          const ChatbotScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildHome() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildModeCards(),
            const SizedBox(height: 28),
            _buildRecentScans(),
            const SizedBox(height: 20),
            _buildStatsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('See the World',
                style: GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
              RichText(text: TextSpan(children: [
                TextSpan(text: 'in ', style: GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                TextSpan(text: 'Full Color', style: GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.accentCyan)),
              ])),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _navIndex = 3),
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.accentCyan, AppTheme.accentGreen]),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Center(
              child: Text('A', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeCards() {
    return Row(
      children: [
        Expanded(child: _modeCard(
          icon: '📷',
          title: 'Live Camera',
          subtitle: 'Real-time color detection',
          color: AppTheme.accentCyan,
          onTap: () => setState(() => _navIndex = 1),
        )),
        const SizedBox(width: 12),
        Expanded(child: _modeCard(
          icon: '🖼️',
          title: 'Gallery',
          subtitle: 'Upload & analyze image',
          color: AppTheme.accentGreen,
          onTap: _pickImage,
        )),
      ],
    );
  }

  Widget _modeCard({required String icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.mutedColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentScans() {
    final history = context.watch<AppProvider>().history;
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Scans', style: GoogleFonts.syne(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppTheme.mutedColor)),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: history.length.clamp(0, 6),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final scan = history[i];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ResultScreen(result: scan),
                )),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: scan.imageBytes.isNotEmpty ? DecorationImage(
                      image: MemoryImage(Uint8List.fromList(scan.imageBytes)),
                      fit: BoxFit.cover,
                    ) : null,
                    color: AppTheme.surfaceColor,
                  ),
                  child: scan.detectedColors.isNotEmpty ? Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                      ),
                      child: Text(scan.detectedColors.first.name, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center),
                    ),
                  ) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final history = context.watch<AppProvider>().history;
    final allColors = history.expand((s) => s.detectedColors).toList();
    final uniqueNames = allColors.map((c) => c.name).toSet();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface2Color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _stat(history.length.toString(), 'Scans'),
          const Expanded(child: SizedBox()),
          _stat(uniqueNames.length.toString(), 'Colors'),
          const Expanded(child: SizedBox()),
          _stat('—', 'Streak'),
        ],
      ),
    );
  }

  Widget _stat(String num, String label) {
    return Column(
      children: [
        Text(num, style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.accentCyan)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.mutedColor, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildNavBar() {
    final items = [
      ('🏠', 'Home'),
      ('📷', 'Camera'),
      ('🤖', 'Chat'),
      ('⚙️', 'Settings'),
    ];
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = _navIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _navIndex = i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(items[i].$1, style: TextStyle(fontSize: 22, shadows: selected ? [Shadow(color: AppTheme.accentCyan, blurRadius: 8)] : null)),
                  const SizedBox(height: 2),
                  Text(items[i].$2, style: TextStyle(fontSize: 9, color: selected ? AppTheme.accentCyan : AppTheme.mutedColor)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final provider = context.read<AppProvider>();
    await provider.processImageBytes(bytes);
    if (provider.currentResult != null && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ResultScreen(result: provider.currentResult!),
      ));
    }
  }
}
