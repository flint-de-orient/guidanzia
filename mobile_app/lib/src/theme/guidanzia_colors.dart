import 'package:flutter/material.dart';

/// The Guidanzia semantic token layer, as a [ThemeExtension] so it resolves
/// per-theme at runtime (rather than as compile-time `static const` values).
///
/// This is the Dart equivalent of a CSS-variable layer: widgets read roles via
/// `Theme.of(context).guidanzia`, and the SAME role name yields a light or dark
/// value depending on the active [ThemeData]. Only the ~15 roles the primitives
/// and shared chrome actually consume are modelled — intentionally NOT the full
/// Material tonal palette.
@immutable
class GuidanziaColors extends ThemeExtension<GuidanziaColors> {
  const GuidanziaColors({
    // Brand accents
    required this.gold,
    required this.goldInk,
    required this.lime,
    required this.limeInk,
    required this.cyan,
    // Surfaces
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    // Ink & structure
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    // Interactive (primitive) roles
    required this.selectedFill,
    required this.selectedBorder,
    required this.selectedInk,
    // Feedback
    required this.danger,
    // Glass chrome
    required this.glassTint,
    required this.glassBorder,
    // Background washes (GradientBackground)
    required this.washA,
    required this.washB,
    required this.washC,
  });

  final Color gold; // primary CTA / brand accent
  final Color goldInk; // ink on gold
  final Color lime; // success / progress / streaks
  final Color limeInk; // ink on lime
  final Color cyan; // data-viz / AI insight

  final Color surface; // page background
  final Color surfaceElevated; // cards / raised chrome
  final Color surfaceMuted; // subtle fills

  final Color onSurface; // primary ink
  final Color onSurfaceVariant; // muted ink
  final Color outline; // hairline borders

  final Color selectedFill; // selected option background
  final Color selectedBorder; // selected option border
  final Color selectedInk; // text/icon on a selected option

  final Color danger; // error state

  final Color glassTint; // frosted-card fill
  final Color glassBorder; // frosted-card rim

  final Color washA; // background blob 1
  final Color washB; // background blob 2
  final Color washC; // background blob 3

  /// LIGHT — designed as its own theme, NOT dark's accents on white. Accents
  /// go DEEP so they read on a light canvas (bright gold/lime wash out on white,
  /// exactly as cyan already knew). The canvas is meaningfully tinted so pure-
  /// white cards separate from it, and glass gets a real navy hairline edge.
  /// Bright gold stays reserved for the filled CTA (AppGradients.primary), so
  /// light gains two gold weights — deep accents + a punchy button.
  static const light = GuidanziaColors(
    gold: Color(0xFFBE8C00), // deep gold — icons / borders / accents on white
    goldInk: Color(0xFF0B0A3D),
    lime: Color(0xFF5F7D00), // deep lime — reads on white
    limeInk: Color(0xFF1B2900),
    cyan: Color(0xFF006A6A),
    surface: Color(0xFFECEFF8), // tinted canvas so white cards lift off it
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE3E7F3),
    onSurface: Color(0xFF0B0A3D),
    onSurfaceVariant: Color(0xFF565E7E),
    outline: Color(0xFFCBD2EA), // visible hairline
    selectedFill: Color(0xFFFBEBBE), // gold wash strong enough to read on white
    selectedBorder: Color(0xFFBE8C00),
    selectedInk: Color(0xFF4A3600),
    danger: Color(0xFFBA1A1A),
    glassTint: Color(0xE6FFFFFF), // 90% white — clearly above the tinted canvas
    glassBorder: Color(0x1F0B0A3D), // navy hairline (was invisible white)
    washA: Color(0x1FF5C451), // gold
    washB: Color(0x1AC6F24E), // lime
    washC: Color(0x144BDFDF), // cyan
  );

  /// DARK — derived from the navy DNA (no comp exists). Bright accents survive
  /// the flip; surfaces and ink invert; glass becomes a translucent navy panel
  /// instead of a milky white smear.
  static const dark = GuidanziaColors(
    gold: Color(0xFFF5C451),
    goldInk: Color(0xFF0B0A1F),
    lime: Color(0xFFC6F24E),
    limeInk: Color(0xFF151F00),
    cyan: Color(0xFF69F7F7),
    surface: Color(0xFF0B1020),
    surfaceElevated: Color(0xFF141F42),
    surfaceMuted: Color(0xFF1B2650),
    onSurface: Color(0xFFEEF1FF),
    onSurfaceVariant: Color(0xFF9AA5CE),
    outline: Color(0xFF2A3560),
    selectedFill: Color(0x33F5C451), // 20% gold on navy
    selectedBorder: Color(0xFFF5C451),
    selectedInk: Color(0xFFFFDF9D),
    danger: Color(0xFFFFB4AB),
    glassTint: Color(0x99141F42), // translucent navy panel
    glassBorder: Color(0x33FFFFFF),
    washA: Color(0x2EF5C451),
    washB: Color(0x24C6F24E),
    washC: Color(0x2469F7F7),
  );

  @override
  GuidanziaColors copyWith({
    Color? gold,
    Color? goldInk,
    Color? lime,
    Color? limeInk,
    Color? cyan,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outline,
    Color? selectedFill,
    Color? selectedBorder,
    Color? selectedInk,
    Color? danger,
    Color? glassTint,
    Color? glassBorder,
    Color? washA,
    Color? washB,
    Color? washC,
  }) {
    return GuidanziaColors(
      gold: gold ?? this.gold,
      goldInk: goldInk ?? this.goldInk,
      lime: lime ?? this.lime,
      limeInk: limeInk ?? this.limeInk,
      cyan: cyan ?? this.cyan,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
      selectedFill: selectedFill ?? this.selectedFill,
      selectedBorder: selectedBorder ?? this.selectedBorder,
      selectedInk: selectedInk ?? this.selectedInk,
      danger: danger ?? this.danger,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      washA: washA ?? this.washA,
      washB: washB ?? this.washB,
      washC: washC ?? this.washC,
    );
  }

  @override
  GuidanziaColors lerp(ThemeExtension<GuidanziaColors>? other, double t) {
    if (other is! GuidanziaColors) return this;
    return GuidanziaColors(
      gold: Color.lerp(gold, other.gold, t)!,
      goldInk: Color.lerp(goldInk, other.goldInk, t)!,
      lime: Color.lerp(lime, other.lime, t)!,
      limeInk: Color.lerp(limeInk, other.limeInk, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t)!,
      selectedBorder: Color.lerp(selectedBorder, other.selectedBorder, t)!,
      selectedInk: Color.lerp(selectedInk, other.selectedInk, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      washA: Color.lerp(washA, other.washA, t)!,
      washB: Color.lerp(washB, other.washB, t)!,
      washC: Color.lerp(washC, other.washC, t)!,
    );
  }
}

/// Ergonomic access: `Theme.of(context).guidanzia` (never null — the extension
/// is registered on both light and dark themes).
extension GuidanziaTheme on ThemeData {
  GuidanziaColors get guidanzia =>
      extension<GuidanziaColors>() ?? GuidanziaColors.light;
}
