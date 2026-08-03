import 'package:flutter/material.dart';
import '../../theme/guidanzia_colors.dart';

/// Segmented progress rail from the Stitch design — thin ticks, completed = gold,
/// current = taller lime, remaining = muted outline. Fully data-driven so it
/// adapts to any question count and to skipped/optional questions.
///
/// Optionally shows a context line ("Module 2 · Question 6 of 20").
class ProgressRail extends StatelessWidget {
  const ProgressRail({
    super.key,
    required this.current,
    required this.total,
    this.label,
  });

  /// 1-based index of the current step.
  final int current;

  /// Total steps in this phase (from the flow, not hardcoded).
  final int total;

  /// Optional context line under the rail.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final safeTotal = total < 1 ? 1 : total;
    final clamped = current.clamp(1, safeTotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 10,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(safeTotal, (i) {
              final n = i + 1;
              final done = n < clamped;
              final currentTick = n == clamped;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == safeTotal - 1 ? 0 : 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: currentTick ? 10 : 4,
                    decoration: BoxDecoration(
                      color: done
                          ? g.gold
                          : currentTick
                              ? g.lime
                              : g.outline,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: currentTick
                          ? [
                              BoxShadow(
                                color: g.lime.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 10),
          Text(
            label!,
            style: TextStyle(
              color: g.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}
