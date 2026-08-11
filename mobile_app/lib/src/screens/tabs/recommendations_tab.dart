import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../models/capability_traits.dart';
import '../../models/career_recommendation.dart';
import '../../router/app_routes.dart';
import '../../state/providers.dart';
import '../../theme/app_text.dart';
import '../../theme/guidanzia_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/tab_header.dart';
import '../../widgets/trait_chips.dart';
import '../unlock_career_path_screen.dart';

/// "Your top 3" — recomposed to the Stitch `career_assessment_results` mockup:
/// three equal match cards (strongest first), each with a gold match score and
/// an "Explore this path" action, then a retake footer.
///
/// Honest-data note: the mockup's per-career trait tags are omitted (the app has
/// no per-career trait data). The user-level "Your strengths" row below is the
/// honest substitute — computed from the aptitude scores.
class RecommendationsTab extends ConsumerWidget {
  const RecommendationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = Theme.of(context).guidanzia;
    final s = AppStrings(ref.watch(localeProvider));
    final async = ref.watch(recommendationsProvider);

    final q = ref.watch(questionnaireProvider);
    final strengths = strengthsFromAptitude(
      number: q.numberSenseScore,
      word: q.wordSenseScore,
      shape: q.shapeSenseScore,
      logic: q.logicSenseScore,
    );

    return RefreshIndicator(
      color: g.gold,
      onRefresh: () async {
        ref.invalidate(recommendationsProvider);
        await ref.read(recommendationsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TabHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.get('yourMatches'), style: AppText.hero(26)),
                const SizedBox(height: 4),
                Text('Based on your 20-question assessment',
                    style: TextStyle(color: g.onSurfaceVariant, fontSize: 13.5)),
              ],
            ),
          ),
          if (strengths.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('YOUR STRENGTHS',
                style: TextStyle(
                    color: g.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            TraitChips(traits: strengths),
          ],
          const SizedBox(height: 20),
          async.when(
            // Show the loading cycle while regenerating after a re-assessment,
            // instead of lingering on the previous assessment's recommendations.
            skipLoadingOnRefresh: false,
            loading: () => const _LoadingCareers(),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 20),
              child: ErrorStateView(
                message: 'We could not generate your recommendations yet.\n\n$e',
                onRetry: () => ref.invalidate(recommendationsProvider),
              ),
            ),
            data: (careers) {
              if (careers.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: ErrorStateView(
                      message:
                          'No recommendations yet. Complete the assessment to see your matches.'),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < careers.length; i++) ...[
                    _ResultCard(
                      career: careers[i],
                      strongest: i == 0,
                      onTap: () => _open(context, careers[i]),
                    ).animate().fadeIn(delay: (110 * i).ms).moveY(begin: 14, end: 0),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  _RetakeCard(
                    onTap: () async {
                      await startRetake(ref);
                      if (context.mounted) {
                        Navigator.of(context).pushNamed(Routes.questionnaire);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, CareerRecommendation c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UnlockCareerPathScreen(career: c)),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.career, required this.strongest, required this.onTap});
  final CareerRecommendation career;
  final bool strongest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: g.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: g.outline),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (strongest) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: g.lime.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('STRONGEST MATCH',
                  style: TextStyle(
                      color: g.lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(career.title, style: AppText.hero(22))),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${career.matchScore}%', style: AppText.hero(28, color: g.gold)),
                  Text('MATCH',
                      style: TextStyle(
                          color: g.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ExpandableDescription(text: career.description),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: g.gold, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Explore this path',
                      style: TextStyle(
                          color: g.gold, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, color: g.gold, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The fit-reason text, truncated to 2 lines with a "Read more" toggle to reveal
/// the full reasoning (the same text also shows in the role deep-dive header).
class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text});
  final String text;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    final canExpand = widget.text.trim().length > 90;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : 2,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(color: g.onSurfaceVariant, fontSize: 14, height: 1.45),
        ),
        if (canExpand)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _expanded ? 'Read less' : 'Read more',
                style: TextStyle(
                    color: g.gold, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _RetakeCard extends StatelessWidget {
  const _RetakeCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: g.surfaceMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: g.outline),
        ),
        child: Column(
          children: [
            Icon(Icons.refresh_rounded, color: g.gold),
            const SizedBox(height: 10),
            Text('Not what you expected?',
                style: TextStyle(color: g.onSurface, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Retake the assessment',
                style: TextStyle(
                    color: g.gold,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: g.gold)),
          ],
        ),
      ),
    );
  }
}

class _LoadingCareers extends StatelessWidget {
  const _LoadingCareers();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        const RotatingLoader(phrases: LoaderPhrases.recommendations),
        const SizedBox(height: 20),
        ...List.generate(
          3,
          (i) => Builder(builder: (context) {
            final g = Theme.of(context).guidanzia;
            return Container(
              height: 160,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: g.surfaceMuted,
                borderRadius: BorderRadius.circular(24),
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(
                  duration: 1200.ms,
                  color: g.surfaceElevated,
                );
          }),
        ),
      ],
    );
  }
}
