import 'package:flutter/material.dart';

import '../../screens/questionnaire/question_defs.dart';
import '../../theme/guidanzia_colors.dart';

/// Stitch `assessment_ranking` — tap options to rank them; each ranked row gets
/// a colour-coded numbered badge (1 gold · 2 lime · 3 cyan), matching the mock's
/// rank palette. Unranked rows show an empty slot + a drag affordance.
///
/// Interaction is tap-to-rank (not drag-reorder): tapping an option assigns it
/// the next rank, tapping a ranked option removes it and the rest shuffle up.
/// The emitted value list stays in rank order, so ranked questions keep their
/// existing data contract — only the presentation changes.
class RankingList extends StatelessWidget {
  const RankingList({
    super.key,
    required this.options,
    required this.rankedOrder,
    required this.max,
    required this.onToggle,
  });

  final List<QOption> options;

  /// Selected values in rank order (index 0 == rank 1).
  final List<String> rankedOrder;
  final int max;
  final ValueChanged<QOption> onToggle;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final atMax = rankedOrder.length >= max;
    return Column(
      children: [
        ...options.map((o) {
          final idx = rankedOrder.indexOf(o.value);
          final isRanked = idx >= 0;
          return _RankRow(
            option: o,
            rank: isRanked ? idx + 1 : null,
            disabled: !isRanked && atMax,
            onTap: () => onToggle(o),
          );
        }),
        const SizedBox(height: 4),
        Text('${rankedOrder.length} of $max ranked',
            style: TextStyle(color: g.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Colour-coded style per rank position, from the mock's rank palette.
({Color fill, Color border, Color badge, Color ink}) _rankStyle(GuidanziaColors g, int rank) {
  switch (rank) {
    case 1:
      return (fill: g.selectedFill, border: g.selectedBorder, badge: g.gold, ink: g.goldInk);
    case 2:
      return (fill: g.lime.withValues(alpha: 0.16), border: g.lime, badge: g.lime, ink: g.limeInk);
    default:
      return (fill: g.cyan.withValues(alpha: 0.14), border: g.cyan, badge: g.cyan, ink: g.goldInk);
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.option, required this.rank, required this.disabled, required this.onTap});

  final QOption option;
  final int? rank;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final ranked = rank != null;
    final s = ranked ? _rankStyle(g, rank!) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Semantics(
          button: true,
          selected: ranked,
          child: GestureDetector(
            onTap: disabled ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: ranked ? s!.fill : g.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ranked ? s!.border : g.outline, width: ranked ? 2 : 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: ranked ? s!.badge : Colors.transparent,
                      shape: BoxShape.circle,
                      border: ranked ? null : Border.all(color: g.outline, width: 1.5),
                    ),
                    child: ranked
                        ? Center(
                            child: Text('${rank!}',
                                style: TextStyle(color: s!.ink, fontWeight: FontWeight.w800, fontSize: 15)))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(option.label,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3, color: g.onSurface)),
                  ),
                  const SizedBox(width: 10),
                  Icon(ranked ? Icons.check_circle : Icons.drag_indicator,
                      size: 20, color: ranked ? s!.border : g.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
