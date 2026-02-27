import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bgColor = Color(0xFF0A0A0F);
  static const Color surfaceColor = Color(0xFF13131A);
  static const Color surface2Color = Color(0xFF1C1C27);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentGreen = Color(0xFF69FF84);
  static const Color accentRed = Color(0xFFFF6B6B);
  static const Color borderColor = Color(0x12FFFFFF);
  static const Color mutedColor = Color(0xFF6B6B80);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: const ColorScheme.dark(
        background: bgColor,
        surface: surfaceColor,
        primary: accentCyan,
        secondary: accentGreen,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.syne(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      useMaterial3: true,
    );
  }
}
