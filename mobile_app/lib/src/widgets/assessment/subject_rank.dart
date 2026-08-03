import 'package:flutter/material.dart';

import '../../screens/questionnaire/question_defs.dart';
import '../../theme/guidanzia_colors.dart';

/// Per-subject icons for the subject grids (Stitch `assessment_top_3_subjects`).
/// Flutter Material equivalents of the mock's Material-Symbols glyphs — mapped,
/// not left empty, since close matches exist for our subject list.
const _subjectIcons = <String, IconData>{
  'Physics': Icons.public,
  'Chemistry': Icons.science_outlined,
  'Biology': Icons.biotech_outlined,
  'Mathematics': Icons.functions,
  'English': Icons.menu_book_outlined,
  'Bengali': Icons.translate_rounded,
  'Computer Science': Icons.terminal_rounded,
  'Economics': Icons.trending_up_rounded,
  'Geography': Icons.map_outlined,
  'History': Icons.history_edu_outlined,
  'Political Science': Icons.gavel_rounded,
  'Accountancy': Icons.account_balance_wallet_outlined,
};

IconData subjectIcon(String s) => _subjectIcons[s] ?? Icons.menu_book_outlined;

/// The "1st: ___ · 2nd: ___ · 3rd: ___" ranked-selection summary (Stitch).
/// Wraps rather than overflowing when real (long) subject names fill the slots.
class RankSummaryBar extends StatelessWidget {
  const RankSummaryBar({super.key, required this.slots, required this.filled, this.accent});

  final int slots;
  final List<String> filled;
  final Color? accent;

  static const _ord = ['1st', '2nd', '3rd', '4th', '5th'];

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final a = accent ?? g.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: g.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: g.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: a),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (var i = 0; i < slots; i++)
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: '${_ord[i]}: ',
                        style: TextStyle(color: a, fontWeight: FontWeight.w800, fontSize: 14)),
                    TextSpan(
                        text: i < filled.length ? filled[i] : '___',
                        style: TextStyle(
                            color: i < filled.length ? g.onSurface : g.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Q8 favourite subjects — a 2-column grid of icon cards with a rank badge and
/// the rank-summary bar. Selection order is the rank (Stitch top-3 subjects).
class SubjectRankGrid extends StatelessWidget {
  const SubjectRankGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.max,
    required this.onToggle,
  });

  final List<QOption> options;
  final List<String> selected;
  final int max;
  final ValueChanged<QOption> onToggle;

  @override
  Widget build(BuildContext context) {
    final atMax = selected.length >= max;
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      final a = options[i];
      final b = (i + 1 < options.length) ? options[i + 1] : null;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _card(context, a, atMax)),
              const SizedBox(width: 12),
              Expanded(child: b == null ? const SizedBox.shrink() : _card(context, b, atMax)),
            ],
          ),
        ),
      ));
    }
    return Column(
      children: [
        RankSummaryBar(slots: max, filled: selected, accent: Theme.of(context).guidanzia.lime),
        const SizedBox(height: 16),
        ...rows,
      ],
    );
  }

  Widget _card(BuildContext context, QOption o, bool atMax) {
    final g = Theme.of(context).guidanzia;
    final rank = selected.indexOf(o.value);
    final sel = rank >= 0;
    final disabled = !sel && atMax;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => onToggle(o),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sel ? g.selectedFill : g.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? g.selectedBorder : g.outline, width: sel ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(subjectIcon(o.value), size: 24, color: sel ? g.selectedBorder : g.gold),
                  const Spacer(),
                  if (sel)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: g.gold, shape: BoxShape.circle),
                      child: Center(
                        child: Text('${rank + 1}',
                            style: TextStyle(
                                color: g.goldInk, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(o.label,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: g.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Q9 least-favourite / most-difficult subject — a single-column list of subject
/// rows with a rank circle (Stitch `assessment_least_favorite_ranking`). Capped
/// at one pick for now (the app stores a single value); [max] lifts later.
class SubjectRankList extends StatelessWidget {
  const SubjectRankList({
    super.key,
    required this.options,
    required this.selected,
    required this.max,
    required this.onToggle,
  });

  final List<QOption> options;
  final List<String> selected;
  final int max;
  final ValueChanged<QOption> onToggle;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Column(
      children: [
        RankSummaryBar(slots: max, filled: selected, accent: g.gold),
        const SizedBox(height: 16),
        ...options.map((o) {
          final rank = selected.indexOf(o.value);
          final sel = rank >= 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => onToggle(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: sel ? g.selectedFill : g.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? g.selectedBorder : g.outline, width: sel ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(o.label,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600, color: g.onSurface)),
                    ),
                    if (sel)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: g.gold, shape: BoxShape.circle),
                        child: Center(
                          child: Text('${rank + 1}',
                              style: TextStyle(
                                  color: g.goldInk, fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      )
                    else
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: g.outline, width: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
