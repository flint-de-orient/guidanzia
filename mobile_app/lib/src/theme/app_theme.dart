import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:google_fonts/google_fonts.dart';
import 'guidanzia_colors.dart';

/// Central [ThemeData] — Guidanzia identity. Inter for body, Poppins for
/// headings (Sora swap is a later phase), with Noto Devanagari / Bengali
/// fallbacks so Hindi and Bengali render on the same type scale.
///
/// The brand token layer ([GuidanziaColors]) is attached to BOTH themes via
/// `extensions`, so widgets read `Theme.of(context).guidanzia` and get the
/// right value per theme. `AppColors` remains as light-only constants that
/// not-yet-migrated screens keep referencing — dark rolls out screen by screen.
class AppTheme {
  const AppTheme._();

  static const List<String> _fontFallback = ['NotoDevanagari', 'NotoBengali'];

  static ThemeData light() => _build(Brightness.light, GuidanziaColors.light);
  static ThemeData dark() => _build(Brightness.dark, GuidanziaColors.dark);

  static ThemeData _build(Brightness brightness, GuidanziaColors g) {
    final isLight = brightness == Brightness.light;
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: g.onSurface,
      displayColor: g.onSurface,
      fontFamilyFallback: _fontFallback,
    );

    // Sora display (bundled), tight tracking to match the Guidanzia scale.
    TextStyle sora(TextStyle? s, FontWeight w, double tracking) =>
        (s ?? const TextStyle()).copyWith(
          fontFamily: 'Sora',
          fontFamilyFallback: _fontFallback,
          fontWeight: w,
          letterSpacing: tracking,
          color: g.onSurface,
        );

    final textTheme = inter.copyWith(
      displayLarge: sora(inter.displayLarge, FontWeight.w800, -0.5),
      displayMedium: sora(inter.displayMedium, FontWeight.w800, -0.5),
      displaySmall: sora(inter.displaySmall, FontWeight.w700, -0.3),
      headlineLarge: sora(inter.headlineLarge, FontWeight.w700, -0.3),
      headlineMedium: sora(inter.headlineMedium, FontWeight.w700, -0.3),
      headlineSmall: sora(inter.headlineSmall, FontWeight.w700, -0.2),
      titleLarge: sora(inter.titleLarge, FontWeight.w700, -0.2),
    );

    return base.copyWith(
      scaffoldBackgroundColor: g.surface,
      extensions: [g],
      colorScheme: base.colorScheme.copyWith(
        primary: g.gold,
        onPrimary: g.goldInk,
        secondary: g.lime,
        onSecondary: g.limeInk,
        tertiary: g.cyan,
        surface: g.surfaceElevated,
        onSurface: g.onSurface,
        error: g.danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: g.onSurface),
        titleTextStyle: TextStyle(
          color: g.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        // Status-bar icons follow the theme (dark icons on light, light on dark).
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : g.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: TextStyle(color: g.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: g.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: g.selectedBorder, width: 2),
        ),
      ),
      dividerColor: g.outline,
      splashColor: g.gold.withValues(alpha: 0.08),
    );
  }
}
