import 'package:flutter/material.dart';

/// Reusable gradients for hero cards and CTAs (Guidanzia).
class AppGradients {
  const AppGradients._();

  /// Full-screen soft neutral wash (light only — dark screens use tokens).
  static const LinearGradient scaffold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5F6FF), Color(0xFFF8F9FA), Color(0xFFF1FBF9)],
    stops: [0.0, 0.55, 1.0],
  );

  /// GOLD CTA gradient — for BUTTONS only. Foreground on this must be navy
  /// (goldInk), never white. Same in both themes.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5C451), Color(0xFFE0A92E)],
  );

  /// Deep-navy HERO gradient — for header/hero PANELS and avatars where WHITE
  /// content sits. Navy is the other half of the brand and keeps white text
  /// legible in both themes (white-on-gold is unreadable, so panels use this).
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF283569), Color(0xFF12143A)],
  );

  /// Frosted card gradient (subtle diagonal sheen).
  static const LinearGradient glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x88FFFFFF), Color(0x44FFFFFF)],
  );

  /// Cyan accent used on the AI-match / AI-insight surfaces (white content ok).
  static const LinearGradient mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
  );

  /// Per-game accent gradients (Number/Word/Shape/Logic) — Guidanzia palette.
  static const List<List<Color>> gameAccents = [
    [Color(0xFFE0A92E), Color(0xFFB8860B)], // number  – gold
    [Color(0xFF7FA300), Color(0xFF5F7D00)], // word    – lime
    [Color(0xFF12A5A5), Color(0xFF006A6A)], // shape   – cyan
    [Color(0xFFF59E0B), Color(0xFFD97706)], // logic   – amber (kept for spread)
  ];
}
