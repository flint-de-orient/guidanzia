import 'package:flutter/material.dart';
import '../models/career_recommendation.dart';
import '../theme/guidanzia_colors.dart';
import 'common_widgets.dart';

/// The match-scored career card (adapts the "job card" from images 2 & 6 to a
/// career recommendation — "View Career Report" instead of "Apply").
class CareerCard extends StatelessWidget {
  const CareerCard({
    super.key,
    required this.career,
    required this.rank,
    required this.onTap,
  });

  final CareerRecommendation career;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    // Rank accents cycle gold / lime / cyan (icon-box fill, icon colour).
    final accents = [
      [g.gold.withValues(alpha: 0.16), g.gold],
      [g.lime.withValues(alpha: 0.18), g.limeInk],
      [g.cyan.withValues(alpha: 0.16), g.cyan],
    ];
    final accent = accents[(rank - 1) % accents.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: g.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: g.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent[0],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.workspace_premium_rounded,
                      color: accent[1], size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        career.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: g.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Recommendation #$rank',
                          style: TextStyle(
                              color: g.onSurfaceVariant, fontSize: 12.5)),
                    ],
                  ),
                ),
                MatchBadge(percentage: career.matchScore, compact: true),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              career.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: g.onSurfaceVariant, height: 1.45, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _MatchBar(value: career.matchScore / 100),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: g.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: g.goldInk, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchBar extends StatelessWidget {
  const _MatchBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile match',
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 11.5)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: g.outline,
              valueColor: AlwaysStoppedAnimation(g.gold),
            ),
          ),
        ],
      ),
    );
  }
}
