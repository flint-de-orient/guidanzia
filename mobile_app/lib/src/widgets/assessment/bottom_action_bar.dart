import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/guidanzia_colors.dart';

/// Thumb-zone action bar from the Stitch design — pinned to the bottom over a
/// blurred surface, with iOS safe-area padding. A low-emphasis back chevron, an
/// optional low-emphasis Skip, and a full-width gold Continue that only
/// activates once the question is answered.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    this.onBack,
    required this.onContinue,
    this.continueEnabled = true,
    this.continueLabel = 'Continue',
    this.onSkip,
    this.skipLabel = 'Skip',
  });

  final VoidCallback? onBack;
  final VoidCallback onContinue;
  final bool continueEnabled;
  final String continueLabel;
  final VoidCallback? onSkip;
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: g.surface.withValues(alpha: 0.85),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            14 + MediaQuery.of(context).padding.bottom,
          ),
          child: Row(
            children: [
              if (onBack != null) ...[
                _CircleButton(icon: Icons.chevron_left_rounded, onTap: onBack!, g: g),
                const SizedBox(width: 12),
              ],
              if (onSkip != null) ...[
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: g.onSurfaceVariant,
                    minimumSize: const Size(0, 54),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(skipLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _ContinueButton(
                  label: continueLabel,
                  enabled: continueEnabled,
                  onTap: onContinue,
                  g: g,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, required this.g});
  final IconData icon;
  final VoidCallback onTap;
  final GuidanziaColors g;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: g.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(color: g.outline),
          ),
          child: Icon(icon, color: g.onSurfaceVariant, size: 28),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.g,
  });
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final GuidanziaColors g;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? g.gold : g.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
            boxShadow: enabled
                ? [BoxShadow(color: g.gold.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? g.goldInk : g.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
