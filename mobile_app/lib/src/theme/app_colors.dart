import 'package:flutter/material.dart';

/// Design tokens — the "Vibrance & Growth" identity: indigo primary, purple
/// secondary, teal accent (reserved for AI-match / success / growth), on a
/// neutral canvas. Light theme only for v1.
class AppColors {
  const AppColors._();

  // Brand accents — Indigo primary / Purple secondary / Teal tertiary
  static const Color primary = Color(0xFF4F46E5); // indigo 600
  static const Color primaryDark = Color(0xFF4338CA); // indigo 700
  static const Color primaryLight = Color(0xFF6366F1); // indigo 500
  static const Color secondary = Color(0xFF9333EA); // purple
  static const Color tertiary = Color(0xFF0D9488); // teal (AI match / success)

  // Surfaces — neutral canvas
  static const Color scaffold = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F4F6);

  // Glass
  static const Color glassTint = Color(0x66FFFFFF); // 40% white
  static const Color glassBorder = Color(0x80FFFFFF); // 50% white rim
  static const Color glassShadow = Color(0x1A4338CA);

  // Text — neutral ramp
  static const Color textPrimary = Color(0xFF111827); // text-main
  static const Color textSecondary = Color(0xFF374151); // text-body
  static const Color textMuted = Color(0xFF6B7280); // text-muted
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Feedback (teal reserved for success/growth)
  static const Color success = Color(0xFF0D9488);
  static const Color warning = Color(0xFFF0A93B);
  static const Color danger = Color(0xFFBA1A1A); // M3 error

  // Match badge (teal pill)
  static const Color matchBg = Color(0xFFCCFBF1); // teal 100
  static const Color matchFg = Color(0xFF0F766E); // teal 700

  // Chip / tile pastels (indigo / teal / purple washes)
  static const List<Color> tilePastels = [
    Color(0xFFE0E7FF), // indigo 100
    Color(0xFFCCFBF1), // teal 100
    Color(0xFFF3E8FF), // purple 100
    Color(0xFFEEF2FF), // indigo 50
  ];
}
