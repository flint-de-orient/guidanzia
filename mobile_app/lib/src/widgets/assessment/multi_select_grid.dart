import 'package:flutter/material.dart';

import '../../screens/questionnaire/question_defs.dart';
import '../../theme/guidanzia_colors.dart';

/// Stitch `assessment_multi_select_industries` — a 2-column grid of icon tiles
/// with a check badge and a live "X of N selected" cap counter. Tiles beyond
/// the cap dim until the user frees a slot.
///
/// Tiles are laid out as [IntrinsicHeight] pairs so the two cards in a row share
/// a height (no ragged columns) while still growing to fit longer real labels —
/// the app's options are full phrases, not the mock's one-word industries.
/// Output stays an ordered value list, so it drops into the questionnaire's
/// existing multi-select fields with no data-contract change.
class MultiSelectTileGrid extends StatelessWidget {
  const MultiSelectTileGrid({
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
              Expanded(child: _Tile(option: a, selected: selected.contains(a.value), disabled: atMax && !selected.contains(a.value), onTap: () => onToggle(a))),
              const SizedBox(width: 12),
              Expanded(
                child: b == null
                    ? const SizedBox.shrink()
                    : _Tile(option: b, selected: selected.contains(b.value), disabled: atMax && !selected.contains(b.value), onTap: () => onToggle(b)),
              ),
            ],
          ),
        ),
      ));
    }

    return Column(
      children: [
        ...rows,
        const SizedBox(height: 4),
        Text('${selected.length} of $max selected',
            style: TextStyle(color: g.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.option, required this.selected, required this.disabled, required this.onTap});

  final QOption option;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: disabled ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: selected ? g.selectedFill : g.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? g.selectedBorder : g.outline, width: selected ? 2 : 1),
              boxShadow: [
                if (selected)
                  BoxShadow(color: g.selectedBorder.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: selected ? g.selectedBorder : g.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(option.icon, size: 24, color: selected ? g.goldInk : g.gold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      option.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w600, color: g.onSurface),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: selected ? g.selectedBorder : g.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
