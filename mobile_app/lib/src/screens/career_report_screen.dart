import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/capability_traits.dart';
import '../state/providers.dart';
import '../theme/app_gradients.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/common_widgets.dart';
import '../widgets/guidanzia_app_bar.dart';
import '../widgets/trait_chips.dart';
import 'questionnaire/question_defs.dart';
import '../theme/guidanzia_colors.dart';

/// The Career Report = the Mindset Report (web `career-report.tsx`) — a full
/// psychometric profile of the student synthesised from the assessment.
/// Distinct from Job Role Details (which is per-career).
class CareerReportScreen extends ConsumerStatefulWidget {
  const CareerReportScreen({super.key});

  @override
  ConsumerState<CareerReportScreen> createState() => _CareerReportScreenState();
}

class _CareerReportScreenState extends ConsumerState<CareerReportScreen> {
  bool _loading = true;
  Object? _error;
  Map<String, dynamic> _report = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final username = ref.read(authProvider).user?.username;
    try {
      final report =
          await ref.read(apiClientProvider).getMindsetReport(username ?? '');
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _m(String key) =>
      (_report[key] as Map?)?.cast<String, dynamic>() ?? const {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GuidanziaAppBar(title: 'Career Report'),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: _loading
              ? const RotatingLoader(phrases: LoaderPhrases.report)
              : _error != null
                  ? ErrorStateView(
                      // Deliberate empty state — a new user, a mid-first-attempt
                      // user, and a mid-retake user all reach here (no answers on
                      // the server). Keep it a friendly prompt, not a raw error.
                      message: 'Complete your assessment to see your report.',
                      onRetry: _load,
                    )
                  : _content(),
        ),
      ),
    );
  }

  Widget _content() {
    final g = Theme.of(context).guidanzia;
    final onboarding = _m('onboarding');
    final motivation = _m('motivation');
    final cognitive = _m('cognitiveStyle');
    final academic = _m('academic');
    final behavioral = _m('behavioral');
    final constraints = _m('constraints');
    final calibration = _m('calibration');
    final aptitude = _m('aptitude');
    final persistence = _m('persistence');
    final moduleInsights = _m('moduleInsights');
    final game5 = _m('game5Insights');
    final topCareer = (_report['topCareer'] as Map?)?.cast<String, dynamic>();

    final subjectMarks =
        (academic['subjectMarks'] as Map?)?.cast<String, dynamic>() ?? {};
    final favSubjects =
        (academic['favoriteSubjects'] as List?)?.map((e) => e.toString()).toList() ?? [];

    final strengths = strengthsFromReportAptitude(aptitude);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _Header(name: (onboarding['name'] ?? 'Your').toString()),
        const SizedBox(height: 18),

        if (_report['dataComplete'] == false) ...[
          _incompleteNote(),
          const SizedBox(height: 16),
        ],

        if (strengths.isNotEmpty) ...[
          _capabilitySummary(strengths),
          const SizedBox(height: 16),
        ],

        if (topCareer != null) _topCareerCard(topCareer),
        if (topCareer != null) const SizedBox(height: 16),

        _section('1. Motivation Profile', Icons.track_changes_outlined, [
          _row('Why here', labelForField('whyHere', motivation['whyHere']?.toString())),
          _row('5-year vision', labelForField('fiveYearVision', motivation['fiveYearVision']?.toString())),
          _row('Career thinking about', _orNS(motivation['careerThinking'])),
          _row('Career ruled out', _orNS(motivation['careerRuledOut'])),
        ], insight: moduleInsights['module1']?.toString()),
        _section('2. Cognitive & Work Style', Icons.lightbulb_outline, [
          _row('Free Sunday preference', labelForField('freeSunday', cognitive['freeSunday']?.toString())),
          _row('Group project role', labelForField('groupRole', cognitive['groupRole']?.toString())),
          _row('Job deal-breaker', labelForField('jobBothers', cognitive['jobBothers']?.toString())),
        ], insight: moduleInsights['module2']?.toString()),
        _section('3. Academic Strengths vs Aspirations', Icons.menu_book_outlined, [
          _row('Favourite subjects', favSubjects.isEmpty ? '—' : favSubjects.join(', ')),
          _row('Most difficult subject', _orDash(academic['difficultSubject'])),
          _row('Study experience', labelForField('studyExperience', academic['studyExperience']?.toString())),
          if (favSubjects.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Marks in favourite subjects',
                style: TextStyle(color: g.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: favSubjects
                  .map((s) => InfoChip(label: '$s: ${labelForMark(subjectMarks[s]?.toString())}'))
                  .toList(),
            ),
          ],
        ], insight: moduleInsights['module3']?.toString()),
        _section('4. Behavioral Signals', Icons.groups_outlined, [
          _row('Outside activities',
              _joinOrDash(labelsForField('outsideActivities', behavioral['outsideActivities'] as List?))),
          _row('External validation', labelForField('externalValidation', behavioral['externalValidation']?.toString())),
          _row('Self-initiated activity', _orNS(behavioral['selfInitiated'])),
        ], insight: moduleInsights['module4']?.toString()),
        _section('5. Constraints & Values', Icons.favorite_outline, [
          _row('Open to study in',
              _joinOrDash(labelsForField('studyLocation', constraints['studyLocation'] as List?))),
          _row('Family budget discussion', labelForField('familyBudget', constraints['familyBudget']?.toString())),
          _row('Top career values',
              labelsForField('careerValues', constraints['careerValues'] as List?).join('  →  ').ifEmpty('—')),
        ], insight: moduleInsights['module5']?.toString()),
        // Final Calibration is questionnaire module 6, so it belongs right after
        // the other five modules (sections 1-5). Persistence and the game/aptitude
        // analyses follow. (Serials renumbered to read 1→9 in this order.)
        _section('6. Final Calibration', Icons.bolt_outlined, [
          _row('Planning style', labelForField('planningStyle', calibration['planningStyle']?.toString())),
          _row('Stress response', labelForField('stressResponse', calibration['stressResponse']?.toString())),
          _row('Surprise reaction', labelForField('surpriseReaction', calibration['surpriseReaction']?.toString())),
        ], insight: moduleInsights['module6']?.toString()),
        _section('7. Aptitude Pattern', Icons.insights_outlined, [
          _aptBar('Quantitative (Number)', aptitude['numberSense'], const Color(0xFFE0A92E)),
          _aptBar('Verbal (Word)', aptitude['wordSense'], const Color(0xFF7FA300)),
          _aptBar('Spatial (Shape)', aptitude['shapeSense'], const Color(0xFF12A5A5)),
          _aptBar('Abstract (Logic)', aptitude['logicSense'], const Color(0xFFE0902E)),
        ]),
        _section('8. Game 5 — Behavioural Assessment', Icons.sports_esports_outlined, [
          _row('Task 1', _orText(game5['task1'], 'Not completed yet')),
          _row('Task 2', _orText(game5['task2'], 'Not completed yet')),
          _row('Task 3', _orText(game5['task3'], 'Not completed yet')),
        ]),
        _section('9. Persistence Profile', Icons.shield_outlined, [
          _row('Effort rating', _orText(persistence['effortRating'], 'Not completed yet')),
          _row('Approach style', _orText(persistence['approachStyle'], 'Not completed yet')),
          _row('Highest tier reached', _orText(persistence['highestTier'], 'N/A')),
          _flags(persistence['counselorFlags'] as List?),
        ]),
      ],
    );
  }

  // ---- helpers ----

  String _orNS(dynamic v) {
    final s = v?.toString() ?? '';
    return (s.isEmpty || s == 'Not specified') ? 'Not specified' : s;
  }

  String _orDash(dynamic v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? '—' : s;
  }

  String _orText(dynamic v, String fallback) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? fallback : s;
  }

  String _joinOrDash(List<String> items) => items.isEmpty ? '—' : items.join(', ');

  /// Honest note shown when the student left core questions blank — so the
  /// report reads as "directional" rather than implying a complete profile.
  Widget _incompleteNote() {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: g.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: g.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: g.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Based on the sections you completed — a few questions were left '
              'unanswered, so treat these results as directional.',
              style: TextStyle(
                  color: g.onSurfaceVariant, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Client-side capability snapshot — strength labels derived from the
  /// aptitude scores the report already loads (no extra backend call).
  Widget _capabilitySummary(List<String> strengths) {
    final g = Theme.of(context).guidanzia;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: g.gold),
              const SizedBox(width: 8),
              const Text('Your capability snapshot',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text('From your aptitude games, your thinking leans:',
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          TraitChips(traits: strengths),
        ],
      ),
    );
  }

  Widget _topCareerCard(Map<String, dynamic> c) {
    final g = Theme.of(context).guidanzia;
    final score = c['matchScore'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOP CAREER MATCH',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Text((c['title'] ?? '').toString(),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          if (c['description'] != null) ...[
            const SizedBox(height: 8),
            Text(c['description'].toString(),
                style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 13.5)),
          ],
          if (score != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$score% Match',
                  style: TextStyle(color: g.selectedInk, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children,
      {String? insight}) {
    final g = Theme.of(context).guidanzia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: g.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: g.gold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
            if (insight != null && insight.trim().isNotEmpty) _insightCard(insight),
          ],
        ),
      ),
    );
  }

  /// "What we noticed" — the per-module AI insight generated during the
  /// assessment, shown below that module's raw answers.
  Widget _insightCard(String insight) {
    final g = Theme.of(context).guidanzia;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: g.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: g.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 15, color: g.gold),
              const SizedBox(width: 6),
              Text('What we noticed',
                  style: TextStyle(
                      color: g.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 8),
          Text(insight,
              style: TextStyle(color: g.onSurface, fontSize: 13.5, height: 1.5)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    final g = Theme.of(context).guidanzia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(color: g.onSurface, fontSize: 14.5, height: 1.35)),
        ],
      ),
    );
  }

  Widget _flags(List<dynamic>? flags) {
    final g = Theme.of(context).guidanzia;
    final list = (flags ?? []).map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Counselor flags',
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...list.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.flag_outlined, size: 15, color: g.gold),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: TextStyle(fontSize: 13, color: g.onSurfaceVariant))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _aptBar(String label, dynamic score, Color color) {
    final g = Theme.of(context).guidanzia;
    final s = (score is num) ? score.toInt() : int.tryParse('$score') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
              Text('$s/8', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: s / 8,
              minHeight: 8,
              backgroundColor: g.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$name\'s Mindset Report',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('A synthesis of how you think, learn and decide — from your assessment.',
            style: TextStyle(color: g.onSurfaceVariant)),
      ],
    );
  }
}

extension _IfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
