import 'package:flutter/material.dart';
import '../theme/app_gradients.dart';
import '../theme/guidanzia_colors.dart';

/// The Guidanzia mascot. Renders the illustration asset inside a soft rounded
/// card (the baked background blends with the app theme, echoing the
/// "robot on a card" hero in mockup image 3). Falls back to a shape-drawn
/// robot if the asset is missing.
class MascotPlaceholder extends StatelessWidget {
  const MascotPlaceholder({super.key, this.size = 200});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.16;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55283569),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/mascot/mascot.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _DrawnMascot(size: size),
        ),
      ),
    );
  }
}

/// Vector fallback mascot (used only if the image asset fails to load).
class _DrawnMascot extends StatelessWidget {
  const _DrawnMascot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      width: size,
      height: size,
      color: g.surfaceMuted,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.62,
            height: size * 0.58,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(size * 0.22),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _eye(size * 0.11),
                    SizedBox(width: size * 0.09),
                    _eye(size * 0.11),
                  ],
                ),
                SizedBox(height: size * 0.05),
                Container(
                  width: size * 0.2,
                  height: size * 0.06,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eye(double d) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(d),
        ),
        child: Center(
          child: Container(
            width: d * 0.5,
            height: d * 0.5,
            decoration: const BoxDecoration(
              color: Color(0xFF0B0A3D), // navy pupil
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}
