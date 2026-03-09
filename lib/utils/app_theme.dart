// ─────────────────────────────────────────────────────────────────────────────
// app_theme.dart
// Global design system for StrideTrack.
// Defines the color palette, typography (DM Sans font), component themes,
// and utility formatting helpers for distance, duration, and pace.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {

  // ── Color Palette ─────────────────────────────────────────────────────────
  static const orange      = Color(0xFFFC4C02); // Primary brand color (Strava orange)
  static const darkBg      = Color(0xFF080808); // Main scaffold background
  static const cardBg      = Color(0xFF141414); // Card / bottom sheet background
  static const surfaceBg   = Color(0xFF1E1E1E); // Input fields, secondary surfaces
  static const divider     = Color(0xFF2A2A2A); // Subtle borders and dividers
  static const textPrimary   = Color(0xFFF0F0F0); // Main readable text
  static const textSecondary = Color(0xFF6B6B6B); // Labels, captions, hints
  static const textMuted     = Color(0xFF3A3A3A); // Placeholder / empty state text
  static const green  = Color(0xFF00C896); // Success, start marker
  static const blue   = Color(0xFF3D8EFF); // Pause button
  static const red    = Color(0xFFFF4B4B); // Stop button, errors, delete

  // ── App Theme ─────────────────────────────────────────────────────────────
  // Full MaterialApp dark theme using DM Sans as the primary font.
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: orange,
      secondary: orange,
      surface: cardBg,
      background: darkBg,
    ),

    // Typography — DM Sans for a clean modern look
    textTheme: GoogleFonts.dmSansTextTheme(
      const TextTheme(
        displayLarge:   TextStyle(color: textPrimary),
        displayMedium:  TextStyle(color: textPrimary),
        headlineLarge:  TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge:     TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium:    TextStyle(color: textPrimary),
        bodyLarge:      TextStyle(color: textPrimary),
        bodyMedium:     TextStyle(color: textSecondary),
        labelLarge:     TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      ),
    ),

    // AppBar — transparent, no elevation
    appBarTheme: AppBarTheme(
      backgroundColor: darkBg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
      iconTheme: const IconThemeData(color: textPrimary),
    ),

    // Card — dark background, rounded corners
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Primary action buttons — orange, rounded
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
  );
}

// ─── Format Utilities ─────────────────────────────────────────────────────────
// Static helpers used across screens to display metrics consistently.
class FormatUtils {

  // Format seconds into MM:SS or HH:MM:SS string
  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    }
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  // Format meters to human-readable distance (e.g. "320m" or "1.45km")
  static String distance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)}m';
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }

  // Calculate and format pace as min'sec"/km (e.g. "5'30"")
  static String pace(double distMeters, int seconds) {
    if (distMeters < 10) return '--\'--"';
    final paceSecPerKm = (seconds / distMeters) * 1000;
    final mins = (paceSecPerKm / 60).floor();
    final secs = (paceSecPerKm % 60).round();
    return "$mins'${secs.toString().padLeft(2,'0')}\"";
  }
}