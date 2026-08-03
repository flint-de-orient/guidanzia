import 'package:flutter/material.dart';

import '../models/career_recommendation.dart';
import '../theme/app_text.dart';
import '../theme/guidanzia_colors.dart';
import '../widgets/gradient_background.dart';
import '../widgets/guidanzia_app_bar.dart';
import '../widgets/primary_button.dart';
import 'role_detail_screen.dart';

/// Stitch `unlock_career_path` — a payment-gateway *prototype* shown when the
/// user taps a recommendation, before the deep-dive dossier opens. Payment isn't
/// wired yet, so "Unlock now" tap-throughs into the deep-dive; the screen stays
/// in the flow as the reference point for real payment later. The perks listed
/// are the real dossier sections, not invented features.
class UnlockCareerPathScreen extends StatelessWidget {
  const UnlockCareerPathScreen({super.key, required this.career});

  final CareerRecommendation career;

  static const _perks = [
    ('Salary Insights', Icons.trending_up_rounded),
    ('Top Institutes', Icons.account_balance_outlined),
    ('Skill Roadmap', Icons.psychology_outlined),
    ('90-Day Plan', Icons.map_outlined),
    ('Job Market Data', Icons.insights_outlined),
    ('Scholarships', Icons.volunteer_activism_outlined),
    ('Certifications', Icons.workspace_premium_outlined),
    ('Expert Guidance', Icons.groups_outlined),
  ];

  void _unlock(BuildContext context) {
    // Prototype gate: proceed straight to the dossier (no real charge).
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RoleDetailScreen(career: career)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Scaffold(
      appBar: const GuidanziaAppBar(),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: g.gold, width: 2),
                        ),
                        child: Icon(Icons.lock_outline_rounded, color: g.gold, size: 36),
                      ),
                      const SizedBox(height: 24),
                      Text('Unlock your full path',
                          textAlign: TextAlign.center, style: AppText.hero(34)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: g.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: g.outline),
                        ),
                        child: Text('${career.title.toUpperCase()} PATH',
                            style: TextStyle(
                                color: g.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.8)),
                      ),
                      const SizedBox(height: 26),
                      _PriceCard(),
                      const SizedBox(height: 26),
                      _PerksGrid(),
                    ],
                  ),
                ),
              ),
              _Footer(onUnlock: () => _unlock(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: g.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: g.gold, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('₹199', style: AppText.hero(34)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('one-time',
                style: TextStyle(color: g.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _PerksGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    Widget perk((String, IconData) p) => Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: g.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(p.$1,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            ),
          ],
        );
    final perks = UnlockCareerPathScreen._perks;
    final rows = <Widget>[];
    for (var i = 0; i < perks.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          children: [
            Expanded(child: perk(perks[i])),
            const SizedBox(width: 12),
            Expanded(
                child: i + 1 < perks.length ? perk(perks[i + 1]) : const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onUnlock});
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: g.outline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 15, color: g.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('SECURE ENCRYPTED PAYMENT',
                  style: TextStyle(
                      color: g.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Unlock now', onPressed: onUnlock),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('Maybe later',
                style: TextStyle(color: g.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
