import 'package:flutter/material.dart';
import '../theme/guidanzia_colors.dart';

/// The mockups' `.abstract-bg`: a canvas with three soft radial colour washes
/// bleeding through at low opacity. Theme-aware — a light lavender canvas with
/// gold/lime/cyan washes in light, a navy canvas with brighter washes in dark.
/// The washes are what give the glass surfaces something to blur.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      color: g.surface,
      child: Stack(
        children: [
          // Gold wash — top right
          Positioned(
            top: -110,
            right: -90,
            child: _Blob(size: 320, color: g.washA),
          ),
          // Lime wash — bottom left
          Positioned(
            bottom: -140,
            left: -110,
            child: _Blob(size: 380, color: g.washB),
          ),
          // Cyan wash — mid right
          Positioned(
            top: 320,
            right: -70,
            child: _Blob(size: 260, color: g.washC),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
