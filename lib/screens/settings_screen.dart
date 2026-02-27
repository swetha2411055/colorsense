import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../core/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Settings', style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 20),
            _buildProfileCard(),
            const SizedBox(height: 20),
            _sectionTitle('Colorblindness Type'),
            _buildCvdSelector(context, settings),
            const SizedBox(height: 20),
            _sectionTitle('Assistance'),
            _toggle(context, '🔊', 'Voice Assistance', 'Read colors aloud automatically', settings.voiceEnabled, (v) => settings.toggleVoice(v)),
            _toggle(context, '📳', 'Vibration Alerts', 'Haptic feedback for color changes', settings.vibrationEnabled, (v) => settings.toggleVibration(v)),
            _toggle(context, '🤖', 'AI Chatbot', 'Ask questions about colors', settings.chatbotEnabled, (v) => settings.toggleChatbot(v)),
            _toggle(context, '🎨', 'Recolorization', 'Adjust image colors for your type', settings.recolorizationEnabled, (v) => settings.toggleRecolorization(v)),
            _toggle(context, '🔍', 'Saliency Overlay', 'Show detected focus regions', settings.saliencyOverlay, (v) => settings.toggleSaliencyOverlay(v)),
            const SizedBox(height: 20),
            _sectionTitle('Voice Speed'),
            _buildVoiceSpeedSlider(context, settings),
            const SizedBox(height: 20),
            _sectionTitle('Label Style'),
            _buildLabelStyle(context, settings),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.accentCyan.withOpacity(0.12), AppTheme.accentGreen.withOpacity(0.08)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const SweepGradient(colors: [AppTheme.accentCyan, AppTheme.accentGreen, Color(0xFFA78BFA), AppTheme.accentCyan]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(child: Text('A', style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ColorSense User', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Personalized for your vision', style: TextStyle(fontSize: 10, color: AppTheme.mutedColor)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
            ),
            child: Text('FREE', style: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentCyan)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: GoogleFonts.syne(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppTheme.mutedColor)),
    );
  }

  Widget _buildCvdSelector(BuildContext context, SettingsProvider settings) {
    final types = [
      (ColorBlindnessType.deuteranopia, 'Deuteranopia', 'Red-Green'),
      (ColorBlindnessType.protanopia, 'Protanopia', 'Red-Green'),
      (ColorBlindnessType.tritanopia, 'Tritanopia', 'Blue-Yellow'),
      (ColorBlindnessType.monochromacy, 'Mono', 'Full'),
      (ColorBlindnessType.anomalous, 'Anomalous', 'Partial'),
      (ColorBlindnessType.none, 'None', 'Normal'),
    ];

    return Wrap(
      spacing: 8, runSpacing: 8,
      children: types.map((t) {
        final selected = settings.cvdType == t.$1;
        return GestureDetector(
          onTap: () => settings.setCvdType(t.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppTheme.accentCyan.withOpacity(0.15) : AppTheme.surface2Color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? AppTheme.accentCyan.withOpacity(0.4) : AppTheme.borderColor),
            ),
            child: Column(
              children: [
                Text(t.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? AppTheme.accentCyan : Colors.white)),
                Text(t.$3, style: TextStyle(fontSize: 9, color: AppTheme.mutedColor)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _toggle(BuildContext ctx, String icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface2Color, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(subtitle, style: TextStyle(fontSize: 10, color: AppTheme.mutedColor)),
        ])),
        Switch(
          value: value, onChanged: onChanged,
          activeColor: AppTheme.accentCyan,
          activeTrackColor: AppTheme.accentCyan.withOpacity(0.3),
        ),
      ]),
    );
  }

  Widget _buildVoiceSpeedSlider(BuildContext context, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface2Color, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Slow', style: TextStyle(fontSize: 10, color: AppTheme.mutedColor)),
            Text('${(settings.voiceSpeed * 100).round()}%', style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentCyan)),
            Text('Fast', style: TextStyle(fontSize: 10, color: AppTheme.mutedColor)),
          ]),
          Slider(
            value: settings.voiceSpeed, min: 0.1, max: 1.0,
            activeColor: AppTheme.accentCyan,
            onChanged: settings.setVoiceSpeed,
          ),
        ],
      ),
    );
  }

  Widget _buildLabelStyle(BuildContext context, SettingsProvider settings) {
    final styles = [('text', 'Text Labels'), ('emoji', 'Emoji'), ('border', 'Borders')];
    return Row(
      children: styles.map((s) {
        final selected = settings.labelStyle == s.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => settings.setLabelStyle(s.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppTheme.accentCyan.withOpacity(0.15) : AppTheme.surface2Color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? AppTheme.accentCyan.withOpacity(0.4) : AppTheme.borderColor),
              ),
              child: Text(s.$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: selected ? AppTheme.accentCyan : Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        );
      }).toList(),
    );
  }
}
