import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../router/app_routes.dart';
import '../state/providers.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';
import '../widgets/theme_toggle.dart';
import '../theme/guidanzia_colors.dart';

/// Public, logged-out entry screen — the "Guidanzia AI Career Mentor" home,
/// recomposed to the app mockup. The same [LandingBody] is reused as the Home
/// tab inside the logged-in shell.
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: GradientBackground(
        child: SafeArea(bottom: false, child: LandingBody()),
      ),
    );
  }
}

/// The Home composition (mockup: hero + AI-mentor image + Future-Ready features
/// + stats + CTA). Auth-aware, self-contained (own brand row), so it works both
/// standalone (logged-out) and as the shell's Home tab (logged-in).
class LandingBody extends ConsumerStatefulWidget {
  const LandingBody({super.key});

  @override
  ConsumerState<LandingBody> createState() => _LandingBodyState();
}

/// Ensures the entrance plays once per app launch (the hand-off from the native
/// splash), not on every return to the Home tab.
bool _landingArrivalPlayed = false;

class _LandingBodyState extends ConsumerState<LandingBody> {
  final _scroll = ScrollController();
  bool _playArrival = false;

  @override
  void initState() {
    super.initState();
    _playArrival = !_landingArrivalPlayed;
    _landingArrivalPlayed = true;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _learnMore() {
    _scroll.animateTo(
      620,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final s = AppStrings(ref.watch(localeProvider));
    final auth = ref.watch(authProvider);
    final status = ref.watch(assessmentStatusProvider);
    final loggedIn = auth.isAuthenticated;

    final Widget body = ListView(
      controller: _scroll,
      // Extra bottom padding so the last card clears the floating bottom nav
      // (the shell uses extendBody), matching the other tabs.
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
      children: [
        _BrandRow(loggedIn: loggedIn),
        const SizedBox(height: 22),

        // ---- Hero ----
        if (loggedIn) ...[
          _WelcomeBanner(
            name: auth.user?.name ?? 'there',
            inProgress: status.inProgress,
          ),
          const SizedBox(height: 16),
          const _InlineAssessmentCta(),
        ] else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: _Badge(text: s.get('heroBadge')),
          ),
          const SizedBox(height: 18),
          _GradientTitle(s.get('heroTitleV2')),
          const SizedBox(height: 14),
          Text(
            s.get('heroSubtitleV2'),
            style: TextStyle(
                fontSize: 15, height: 1.5, color: g.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _PrimaryPill(label: s.get('getStarted'), onTap: () {
            Navigator.of(context).pushNamed(Routes.signup);
          }),
          const SizedBox(height: 12),
          _OutlinePill(label: s.get('learnMore'), onTap: _learnMore),
        ],
        const SizedBox(height: 30),

        // ---- Stats strip (horizontal; honest product facts) ----
        _StatStrip(
          items: [
            ('4', s.get('statGames'), g.gold),
            ('3', s.get('statMatches'), g.lime),
            ('AI', s.get('statPowered'), g.cyan),
            ('3', s.get('statLanguages'), g.gold),
          ],
        ),
        const SizedBox(height: 34),

        // ---- How it works (numbered steps) ----
        Text(s.get('howItWorks'), style: AppText.hero(26)),
        const SizedBox(height: 4),
        Text(s.get('howItWorksSubtitle'),
            style: TextStyle(color: g.onSurfaceVariant, height: 1.4)),
        const SizedBox(height: 22),
        _StepRow(index: 1, title: s.get('step1Title'), desc: s.get('step1Desc')),
        _StepRow(index: 2, title: s.get('step2Title'), desc: s.get('step2Desc')),
        _StepRow(index: 3, title: s.get('step3Title'), desc: s.get('step3Desc'), isLast: true),
        const SizedBox(height: 30),

        // ---- Testimonial ----
        _Testimonial(quote: s.get('testimonial1'))
            .animate()
            .fadeIn(duration: 500.ms)
            .moveY(begin: 16, end: 0),
        const SizedBox(height: 24),

        // ---- Final CTA (logged-out only) ----
        if (!loggedIn)
          _CtaPanel(
            title: s.get('readyTitle'),
            subtitle: s.get('readySubtitle'),
            button: s.get('createFreeAccount'),
            onTap: () => Navigator.of(context).pushNamed(Routes.signup),
          ),
      ],
    );

    // Arrival: a single, gentle fade-and-rise as the app hands off from the
    // native splash. Plays once per launch; on later Home visits it's static.
    if (!_playArrival) return body;
    return body
        .animate()
        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
        .moveY(begin: 16, end: 0, duration: 480.ms, curve: Curves.easeOutCubic);
  }
}

// --------------------------------------------------------------------------
// Pieces
// --------------------------------------------------------------------------

class _BrandRow extends ConsumerWidget {
  const _BrandRow({required this.loggedIn});
  final bool loggedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = Theme.of(context).guidanzia;
    final s = AppStrings(ref.watch(localeProvider));
    return Row(
      children: [
        // Brand mark — the logo ships its own white backing, so the navy art
        // stays legible on both the light and dark themes; a rounded tile +
        // hairline border makes that white block read as an intentional mark.
        Container(
          width: 38,
          height: 38,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: g.outline),
          ),
          child: Image.asset('assets/images/gnz_logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(width: 10),
        // Wordmark: navy on light, yellow-gold on dark — flat per-theme colour
        // (was a gold→lime gradient) so the brand reads the same as the rest of
        // the theme's ink/accent.
        Text(
          s.get('appName'),
          style: AppText.hero(
            24,
            color: Theme.of(context).brightness == Brightness.dark
                ? g.gold
                : g.onSurface,
          ),
        ),
        const Spacer(),
        const ThemeToggle(),
        // Profile lives in the bottom nav for logged-in users, so no profile
        // button here; only the public landing shows a Sign in.
        if (!loggedIn) ...[
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.login),
            style: TextButton.styleFrom(
              foregroundColor: g.gold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: g.gold, width: 1.3),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
            child: Text(s.get('signIn'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: g.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: g.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 15, color: g.gold),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: g.gold,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GradientTitle extends StatelessWidget {
  const _GradientTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return ShaderMask(
      shaderCallback: (r) => LinearGradient(
        colors: [g.gold, g.lime],
      ).createShader(r),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.hero(34, color: Colors.white),
      ),
    );
  }
}

class _PrimaryPill extends StatelessWidget {
  const _PrimaryPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: g.gold.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 10)),
          ],
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: g.goldInk,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _OutlinePill extends StatelessWidget {
  const _OutlinePill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: g.gold, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: g.gold,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _InlineAssessmentCta extends ConsumerWidget {
  const _InlineAssessmentCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings(ref.watch(localeProvider));
    final status = ref.watch(assessmentStatusProvider);

    late final String label;
    late final VoidCallback onTap;
    if (status.inProgress) {
      label = s.get('resumeAssessment');
      final route = switch (status.stage) {
        AssessmentStage.questionnaire => Routes.questionnaire,
        AssessmentStage.games => Routes.games,
        _ => Routes.onboarding,
      };
      onTap = () => Navigator.of(context).pushNamed(route);
    } else {
      label = status.completed
          ? s.get('startNewAssessment')
          : s.get('startAssessment');
      onTap = () {
        ref
            .read(assessmentStatusProvider.notifier)
            .enter(AssessmentStage.onboarding);
        Navigator.of(context).pushNamed(Routes.onboarding);
      };
    }

    return _PrimaryPill(label: label, onTap: onTap);
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.name, required this.inProgress});
  final String name;
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back,',
              style: TextStyle(
                  color: g.onSurfaceVariant.withValues(alpha: 0.9))),
          const SizedBox(height: 2),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.hero(26)),
          if (inProgress) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: g.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Assessment in progress',
                  style: TextStyle(
                      color: g.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Real frosted glass (BackdropFilter) — the mockups' signature surface.
/// This used to be a plain translucent Container, which is why nothing looked
/// glassy: there was no blur behind it at all.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.radius = 28});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: radius,
      child: child,
    );
  }
}

/// Stat cards (Stitch landing) laid out two-per-row so all four fit on screen
/// without horizontal scrolling. Uses honest product facts, not fabricated
/// user counts.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.items});
  final List<(String, String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _card(context, items[i])),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < items.length
                  ? _card(context, items[i + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _card(BuildContext context, (String, String, Color) it) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: g.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: g.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(it.$1, style: AppText.hero(28, color: it.$3)),
          const SizedBox(height: 4),
          Text(it.$2,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// A numbered "How it works" step with a lime-outlined index and connector line.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.title,
    required this.desc,
    this.isLast = false,
  });
  final int index;
  final String title;
  final String desc;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: g.lime, width: 2),
                ),
                child: Center(
                  child: Text('$index',
                      style: TextStyle(
                          color: g.lime, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: g.lime.withValues(alpha: 0.3))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.title(18)),
                  const SizedBox(height: 5),
                  Text(desc,
                      style: TextStyle(
                          color: g.onSurfaceVariant, fontSize: 14, height: 1.45)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Testimonial card with a stylised quote mark (Stitch landing). The avatar +
/// author name are placeholders — the app ships the quotes without attribution.
class _Testimonial extends StatelessWidget {
  const _Testimonial({required this.quote});
  final String quote;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return _GlassCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('99',
              style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 46,
                  height: 0.8,
                  fontWeight: FontWeight.w800,
                  color: g.lime)),
          const SizedBox(height: 8),
          Text('"$quote"',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, height: 1.4, color: g.onSurface)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: g.surfaceMuted, shape: BoxShape.circle),
                child: Icon(Icons.person_outline, size: 20, color: g.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A Guidenzia student',
                      style: TextStyle(fontWeight: FontWeight.w700, color: g.onSurface)),
                  Text('Verified user',
                      style: TextStyle(color: g.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CtaPanel extends StatelessWidget {
  const _CtaPanel({
    required this.title,
    required this.subtitle,
    required this.button,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 16)),
        ],
      ),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: AppText.hero(24, color: Colors.white)),
          const SizedBox(height: 10),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.5)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(button,
                  style: TextStyle(
                      color: g.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
