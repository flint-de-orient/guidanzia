import 'package:flutter/material.dart';

import '../theme/guidanzia_colors.dart';

/// Stitch trait tags — a wrap of small pill chips used by the module-insight
/// card, the results strengths row and the career-report summary. The labels
/// are always computed from real data (see `capability_traits.dart`), never
/// fabricated.
///
/// [onHero] switches to a translucent-white style for use on the navy hero
/// gradient; the default is a gold-tinted pill for the light/dark canvas.
class TraitChips extends StatelessWidget {
  const TraitChips({super.key, required this.traits, this.onHero = false});

  final List<String> traits;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    if (traits.isEmpty) return const SizedBox.shrink();
    final g = Theme.of(context).guidanzia;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in traits)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: onHero ? Colors.white.withValues(alpha: 0.18) : g.surfaceMuted,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: onHero ? Colors.white.withValues(alpha: 0.35) : g.outline,
              ),
            ),
            child: Text(
              t,
              style: TextStyle(
                color: onHero ? Colors.white : g.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
