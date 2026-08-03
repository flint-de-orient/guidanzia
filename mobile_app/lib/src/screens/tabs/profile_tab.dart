import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/app_routes.dart';
import '../../state/providers.dart';
import '../../theme/app_text.dart';
import '../../theme/guidanzia_colors.dart';
import '../../widgets/theme_toggle.dart';
import '../career_report_screen.dart';
import '../edit_profile_screen.dart';
import '../settings_screen.dart';
import '../payment_screen.dart';

/// "My Profile", recomposed to the Stitch `student_profile` mockup — gold avatar
/// header, a real "Recent Progress" card (the assessment state, not a fabricated
/// %), two real quick-action tiles, a premium card, then a de-duplicated account
/// menu. The mockup's Level / Goals gamification is intentionally dropped (no
/// backing data).
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final name = user?.name ?? 'Student';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final profile = ref.watch(questionnaireProvider).userProfile;
    final interest = (profile['careerInterest'] ?? '').toString().trim();
    final subtitle = (interest.isNotEmpty && interest != 'Not specified')
        ? 'Aspiring $interest'
        : 'Student';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        _Header(
          name: name,
          initial: initial,
          subtitle: subtitle,
          onSettings: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          onLogout: () => _logout(context, ref),
        ),
        const SizedBox(height: 24),
        const _RecentProgress(),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                icon: Icons.description_outlined,
                label: 'My Career Report',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CareerReportScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickTile(
                icon: Icons.replay_rounded,
                label: 'Retake Assessment',
                onTap: () => Navigator.of(context).pushNamed(Routes.questionnaire),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _PremiumCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentScreen()),
          ),
        ),
        const SizedBox(height: 20),
        _Menu(
          onEdit: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          ),
          onSettings: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          onPremium: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentScreen()),
          ),
          onLogout: () => _logout(context, ref),
        ),
      ],
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in any time.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Log out',
                  style: TextStyle(color: Theme.of(ctx).guidanzia.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.landing, (_) => false);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.initial,
    required this.subtitle,
    required this.onSettings,
    required this.onLogout,
  });
  final String name;
  final String initial;
  final String subtitle;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: g.gold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(initial,
                    style: TextStyle(
                        color: g.goldInk, fontSize: 34, fontWeight: FontWeight.w800)),
              ),
            ),
            const Spacer(),
            const ThemeToggle(),
            const SizedBox(width: 10),
            _CircleIcon(icon: Icons.settings_outlined, onTap: onSettings),
            const SizedBox(width: 10),
            _CircleIcon(icon: Icons.logout_rounded, danger: true, onTap: onLogout),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Flexible(
              child: Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.hero(24)),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: g.lime.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Free Plan',
                  style: TextStyle(
                      color: g.lime, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: g.onSurfaceVariant, fontSize: 14)),
      ],
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap, this.danger = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final c = danger ? g.danger : g.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: g.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: g.outline),
        ),
        child: Icon(icon, size: 20, color: c),
      ),
    );
  }
}

/// The mockup's "Recent Progress" card, wired to the real assessment state
/// (resume / complete / start) — the same data the Home banner uses.
class _RecentProgress extends ConsumerWidget {
  const _RecentProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = Theme.of(context).guidanzia;
    final status = ref.watch(assessmentStatusProvider);
    final recs = ref.watch(recommendationsProvider);
    final hasMatches = recs.maybeWhen(data: (l) => l.isNotEmpty, orElse: () => false);

    late final double pct;
    late final String title;
    late final String sub;
    late final String action;
    late final VoidCallback onTap;

    if (status.inProgress) {
      final isGames = status.stage == AssessmentStage.games;
      pct = isGames ? 0.9 : (status.questionIndex / 20).clamp(0.05, 0.95);
      title = 'Continue your assessment';
      sub = isGames ? 'Aptitude games' : 'Question ${status.questionIndex + 1} of 20';
      action = 'Resume';
      final route = switch (status.stage) {
        AssessmentStage.questionnaire => Routes.questionnaire,
        AssessmentStage.games => Routes.games,
        _ => Routes.onboarding,
      };
      onTap = () => Navigator.of(context).pushNamed(route);
    } else if (status.completed || hasMatches) {
      pct = 1.0;
      title = 'Assessment complete';
      sub = 'Your career matches are ready';
      action = 'View';
      // Jump to the Matches tab (index 2 in the shell).
      onTap = () => ref.read(shellTabProvider.notifier).state = 2;
    } else {
      pct = 0.0;
      title = 'Start your assessment';
      sub = 'Take the smart quiz';
      action = 'Start';
      onTap = () {
        ref.read(assessmentStatusProvider.notifier).enter(AssessmentStage.onboarding);
        Navigator.of(context).pushNamed(Routes.onboarding);
      };
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: g.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: g.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECENT PROGRESS',
              style: TextStyle(
                  color: g.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: g.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.route_rounded, color: g.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(sub, style: TextStyle(color: g.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: g.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(g.lime),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${(pct * 100).round()}% Completed',
                  style: TextStyle(color: g.onSurfaceVariant, fontSize: 12.5)),
              const Spacer(),
              GestureDetector(
                onTap: onTap,
                child: Text(action,
                    style: TextStyle(color: g.lime, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
        decoration: BoxDecoration(
          color: g.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: g.outline),
        ),
        child: Column(
          children: [
            Icon(icon, color: g.gold, size: 26),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.onTap});
  final VoidCallback onTap;

  static const _perks = [
    '1-on-1 mentor guidance sessions',
    'Unlimited AI career reports',
    'Downloadable PDF reports',
  ];

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: g.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: g.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unlock Pro Guidance', style: AppText.headline(22)),
          const SizedBox(height: 8),
          Text(
            'Get direct access to top industry mentors and personalized career roadmaps.',
            style: TextStyle(color: g.onSurfaceVariant, height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: 16),
          for (final p in _perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: g.lime),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p, style: const TextStyle(fontSize: 14))),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹499', style: AppText.hero(28)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('/ year', style: TextStyle(color: g.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: g.gold,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Go Premium Now',
                      style: TextStyle(
                          color: g.goldInk, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(width: 8),
                  Icon(Icons.bolt_rounded, color: g.goldInk, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// De-duplicated account menu — My Career Report and Retake Assessment now live
/// in the quick-action tiles above, so they're removed here.
class _Menu extends StatelessWidget {
  const _Menu({
    required this.onEdit,
    required this.onSettings,
    required this.onPremium,
    required this.onLogout,
  });
  final VoidCallback onEdit;
  final VoidCallback onSettings;
  final VoidCallback onPremium;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      decoration: BoxDecoration(
        color: g.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: g.outline),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            _Tile(icon: Icons.edit_outlined, label: 'Edit personal information', onTap: onEdit),
            const _Divider(),
            _Tile(icon: Icons.settings_outlined, label: 'Account Settings', onTap: onSettings),
            const _Divider(),
            _Tile(icon: Icons.workspace_premium_outlined, label: 'Go Premium', onTap: onPremium),
            const _Divider(),
            _Tile(icon: Icons.logout_rounded, label: 'Log out', danger: true, onTap: onLogout),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final color = danger ? g.danger : g.onSurface;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: danger ? g.danger : g.gold),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: g.onSurfaceVariant),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 56, endIndent: 16);
}
