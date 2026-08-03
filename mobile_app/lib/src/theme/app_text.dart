import 'package:flutter/material.dart';

/// Typography helpers for the Guidanzia system — Sora display (bundled), with
/// Noto Devanagari/Bengali fallbacks so Hindi/Bengali stay on the same scale.
///
/// Colour defaults to null so headings INHERIT the active theme's onSurface ink
/// (set in AppTheme). Pass an explicit [color] only to override (e.g. white on a
/// hero panel). Use [AppText.hero]/[AppText.headline]/[AppText.title] for
/// headings; plain `TextStyle` (Inter) for body copy.
class AppText {
  const AppText._();

  static const _display = 'Sora';
  static const _fallback = ['NotoDevanagari', 'NotoBengali'];

  /// Sora ExtraBold, tight tracking — hero / display titles.
  static TextStyle hero(double size, {Color? color, double height = 1.1}) =>
      TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: height,
        color: color,
      );

  /// Sora Bold — section headlines.
  static TextStyle headline(double size, {Color? color, double height = 1.2}) =>
      TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: height,
        color: color,
      );

  /// Sora SemiBold — card / list titles.
  static TextStyle title(double size, {Color? color, double height = 1.3}) =>
      TextStyle(
        fontFamily: _display,
        fontFamilyFallback: _fallback,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: height,
        color: color,
      );
}
