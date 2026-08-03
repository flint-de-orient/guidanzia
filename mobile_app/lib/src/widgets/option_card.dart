import 'package:flutter/material.dart';
import '../theme/guidanzia_colors.dart';

/// The assessment's single/multi option row — extracted from questionnaire_screen
/// so it's reusable and theme-aware. States: default / selected / disabled /
/// error, plus an optional [rank] badge (for ranked questions like careerValues).
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.description,
    this.disabled = false,
    this.error = false,
    this.rank,
  });

  final String label;
  final String? description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool disabled;
  final bool error;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;

    final borderColor = selected
        ? g.selectedBorder
        : error
            ? g.danger
            : g.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Semantics(
          selected: selected,
          button: true,
          child: GestureDetector(
            onTap: disabled ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: selected ? g.selectedFill : g.surfaceElevated,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 2 : 1,
                ),
                boxShadow: [
                  if (selected)
                    BoxShadow(
                      color: g.selectedBorder.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected
                          ? g.selectedBorder
                          : g.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: rank != null
                        ? Center(
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                color: g.goldInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          )
                        : Icon(
                            icon,
                            color: selected ? g.goldInk : g.gold,
                            size: 26,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: g.onSurface,
                          ),
                        ),
                        if (description != null && description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            description!,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: g.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: g.selectedBorder, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
