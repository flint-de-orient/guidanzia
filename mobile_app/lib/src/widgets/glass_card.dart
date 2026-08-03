import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/guidanzia_colors.dart';

/// A frosted-glass card (BackdropFilter blur behind a translucent surface).
///
/// Use deliberately on hero cards and detail headers — not on every list row —
/// because stacked blurs are GPU-costly on low-end Android devices.
///
/// [tint] defaults to the theme's glass token (null = theme-driven); pass a
/// colour only to override for a specific surface.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.blur = 18,
    this.tint,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: tint ?? g.glassTint,
                  borderRadius: radius,
                  border: Border.all(color: g.glassBorder, width: 1.2),
                ),
                // A transparent Material *below* the tinted DecoratedBox so
                // interactive children (e.g. ListTile) paint their ink/background
                // in front of the glass fill instead of behind it.
                child: Material(
                  type: MaterialType.transparency,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A solid (non-blurred) rounded card — cheap, for list rows and dense content.
/// [color] defaults to the theme's elevated surface (null = theme-driven).
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 22,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    return Material(
      color: color ?? g.surfaceElevated,
      borderRadius: radius,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: g.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
