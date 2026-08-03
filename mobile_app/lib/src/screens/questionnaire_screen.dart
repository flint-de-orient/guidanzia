import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/capability_traits.dart';
import '../models/questionnaire_data.dart';
import '../router/app_routes.dart';
import '../state/providers.dart';
import '../theme/app_text.dart';
import '../theme/guidanzia_colors.dart';
import '../widgets/gradient_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/option_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/trait_chips.dart';
import '../widgets/assessment/progress_rail.dart';
import '../widgets/assessment/bottom_action_bar.dart';
import '../widgets/assessment/multi_select_grid.dart';
import '../widgets/assessment/ranking_list.dart';
import '../widgets/assessment/subject_rank.dart';
import '../widgets/guidanzia_app_bar.dart';
import 'questionnaire/question_defs.dart';

/// Full Module 1-6 assessment (20 questions) with per-module AI feedback —
/// a 1:1 port of the web onboarding-new flow.
class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  ConsumerState<QuestionnaireScreen> createState() =>
      _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  late final QuestionnaireData q = ref.read(questionnaireProvider);

  int _index = 0; // into kQuestions (0..19)
  bool _showFeedback = false;
  bool _feedbackLoading = false;
  String _feedbackText = '';
  int _feedbackModule = 1;
  List<String> _feedbackTraits = const [];

  // Which question numbers close a module.
  static const _moduleEnd = {4: 1, 7: 2, 11: 3, 14: 4, 17: 5, 20: 6};

  final _text = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    // Resume where the user left off if they navigated away via a tab.
    final saved = ref.read(assessmentStatusProvider).questionIndex;
    _index = saved.clamp(0, kQuestions.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assessmentStatusProvider.notifier).enter(AssessmentStage.questionnaire);
    });
  }

  Question get _q => kQuestions[_index];

  TextEditingController _controllerFor(String field) {
    return _text.putIfAbsent(field, () {
      final initial = switch (field) {
        'careerThinking' => q.careerThinking,
        'careerRuledOut' => q.careerRuledOut,
        'selfInitiated' => q.selfInitiated,
        _ => '',
      };
      return TextEditingController(text: initial);
    });
  }

  @override
  void dispose() {
    // If the user is leaving mid-assessment (e.g. tapped a nav tab), remember
    // the current question so Resume returns here. Skip once finished (stage
    // cleared) so we don't overwrite the reset pointer.
    if (ref.read(assessmentStatusProvider).inProgress) {
      ref.read(assessmentStatusProvider.notifier).setQuestionIndex(_index);
    }
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- read current answer for validation / selection state ----

  String? _single(String field) => switch (field) {
        'whyHere' => q.whyHere,
        'fiveYearVision' => q.fiveYearVision,
        'freeSunday' => q.freeSunday,
        'groupRole' => q.groupRole,
        'jobBothers' => q.jobBothers,
        'difficultSubject' => q.difficultSubject,
        'studyExperience' => q.studyExperience,
        'externalValidation' => q.externalValidation,
        'familyBudget' => q.familyBudget,
        'planningStyle' => q.planningStyle,
        'stressResponse' => q.stressResponse,
        'surpriseReaction' => q.surpriseReaction,
        'studyLocation' => q.studyLocation.isEmpty ? null : q.studyLocation.first,
        _ => null,
      };

  void _setSingle(String field, String v) {
    setState(() {
      switch (field) {
        case 'whyHere': q.whyHere = v; break;
        case 'fiveYearVision': q.fiveYearVision = v; break;
        case 'freeSunday': q.freeSunday = v; break;
        case 'groupRole': q.groupRole = v; break;
        case 'jobBothers': q.jobBothers = v; break;
        case 'difficultSubject': q.difficultSubject = v; break;
        case 'studyExperience': q.studyExperience = v; break;
        case 'externalValidation': q.externalValidation = v; break;
        case 'familyBudget': q.familyBudget = v; break;
        case 'planningStyle': q.planningStyle = v; break;
        case 'stressResponse': q.stressResponse = v; break;
        case 'surpriseReaction': q.surpriseReaction = v; break;
        case 'studyLocation': q.studyLocation = [v]; break;
      }
    });
  }

  List<String> _multi(String field) => switch (field) {
        'favoriteSubjects' => q.favoriteSubjects,
        'outsideActivities' => q.outsideActivities,
        'careerValues' => q.careerValues,
        _ => const [],
      };

  void _toggleMulti(String field, String value, int max) {
    final list = _multi(field);
    setState(() {
      if (list.contains(value)) {
        list.remove(value);
        if (field == 'favoriteSubjects') q.subjectMarks.remove(value);
      } else if (list.length < max) {
        list.add(value);
      }
    });
  }

  bool get _canAdvance {
    switch (_q.kind) {
      case QKind.single:
        return _single(_q.field) != null;
      case QKind.multi:
        return _multi(_q.field).length >= _q.minSelect;
      case QKind.text:
        return true; // optional
      case QKind.marks:
        return q.favoriteSubjects.every((s) => q.subjectMarks.containsKey(s));
    }
  }

  void _saveText() {
    if (_q.kind != QKind.text) return;
    final t = _controllerFor(_q.field).text;
    switch (_q.field) {
      case 'careerThinking': q.careerThinking = t; break;
      case 'careerRuledOut': q.careerRuledOut = t; break;
      case 'selfInitiated': q.selfInitiated = t; break;
    }
  }

  Future<void> _next({bool skip = false}) async {
    if (skip && _q.kind == QKind.text) {
      _controllerFor(_q.field).clear();
    }
    _saveText();

    // Persist answers + position after every question so an app kill mid-flow
    // never loses work.
    ref.read(assessmentStatusProvider.notifier).setQuestionIndex(_index);
    await persistAssessment(ref);

    final endModule = _moduleEnd[_q.number];
    if (endModule != null) {
      await _showModuleFeedback(endModule);
    } else {
      setState(() => _index++);
      ref.read(assessmentStatusProvider.notifier).setQuestionIndex(_index);
      await persistAssessment(ref);
    }
  }

  Future<void> _showModuleFeedback(int module) async {
    setState(() {
      _showFeedback = true;
      _feedbackLoading = true;
      _feedbackText = '';
      _feedbackModule = module;
      // Trait chips computed from the answers so far — honest, no backend call.
      _feedbackTraits = traitsFromAnswers(q);
    });
    try {
      final fb = await ref.read(apiClientProvider).generateModuleFeedback(
            moduleNumber: module,
            answersSoFar: q.answersSoFar(module),
          );
      final insight = _clampWords(fb, 45);
      // Persist the exact insight shown so the Career Report can display it
      // below that module's answers. (Only real AI insights are stored — a
      // generic fallback below is left out of the report.)
      _storeModuleInsight(module, insight);
      if (mounted) setState(() => _feedbackText = insight);
    } catch (_) {
      if (mounted) {
        setState(() => _feedbackText =
            "Great progress — your answers are helping us understand how you think. Let's keep going.");
      }
    } finally {
      if (mounted) setState(() => _feedbackLoading = false);
    }
  }

  /// Save a module's shown insight onto the shared questionnaire data, keyed by
  /// module number (1-6). Also persists locally so an app kill mid-assessment
  /// doesn't lose it.
  void _storeModuleInsight(int module, String insight) {
    switch (module) {
      case 1:
        q.module1Insight = insight;
        break;
      case 2:
        q.module2Insight = insight;
        break;
      case 3:
        q.module3Insight = insight;
        break;
      case 4:
        q.module4Insight = insight;
        break;
      case 5:
        q.module5Insight = insight;
        break;
      case 6:
        q.module6Insight = insight;
        break;
    }
    persistAssessment(ref);
  }

  /// Backstop for over-long AI feedback: keep the note tight even if the model
  /// ignores its word budget.
  String _clampWords(String text, int maxWords) {
    final cleaned = text.trim();
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.length <= maxWords) return cleaned;
    var out = words.take(maxWords).join(' ');
    if (!out.endsWith('.')) out += '…';
    return out;
  }

  void _continueFromFeedback() {
    if (_q.number >= 20) {
      Navigator.of(context).pushNamed(Routes.games);
      return;
    }
    setState(() {
      _showFeedback = false;
      _index++;
    });
  }

  void _back() {
    if (_showFeedback) return;
    if (_index == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _index--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GuidanziaAppBar(
        centerTitle: false,
        titleWidget: Text(
          'Module ${_q.module} · ${moduleTitles[_q.module]}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _showFeedback ? null : _back,
        ),
      ),
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: ProgressRail(
                  current: _q.number,
                  total: kQuestions.length,
                  label:
                      'Module ${_q.module} · Question ${_q.number} of ${kQuestions.length}'
                      '${_q.note != null ? ' · ${_q.note}' : ''}',
                ),
              ),
              Expanded(
                child: _showFeedback ? _feedbackView() : _questionView(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _showFeedback ? null : _bottomBar(),
    );
  }

  Widget _bottomBar() {
    final isLast = _q.number == 20;
    final label = isLast
        ? 'Complete Assessment'
        : (_moduleEnd.containsKey(_q.number) ? 'Complete Module' : 'Next Question');
    final isOptionalText = _q.kind == QKind.text && _q.optional;
    return BottomActionBar(
      onBack: _back,
      onContinue: () => _next(),
      continueEnabled: isOptionalText ? true : _canAdvance,
      continueLabel: label,
      onSkip: isOptionalText ? () => _next(skip: true) : null,
    );
  }

  // -------------------- Question view --------------------

  Widget _questionView() {
    // Reserve space for the floating BottomActionBar (~82px + safe-area) so the
    // last option always clears the bar and long questions can scroll. Without
    // this, extendBody makes the scroll viewport full-height, so content that
    // ends behind the bar is both hidden and un-scrollable.
    final barInset = 96 + MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      key: ValueKey('q${_q.number}'),
      padding: EdgeInsets.fromLTRB(24, 8, 24, barInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_q.title, style: AppText.hero(30)),
          const SizedBox(height: 20),
          _questionBody().animate().fadeIn(duration: 220.ms),
        ],
      ),
    );
  }

  Widget _questionBody() {
    switch (_q.kind) {
      case QKind.single:
        return _singleBody();
      case QKind.multi:
        return _multiBody();
      case QKind.text:
        return _textBody();
      case QKind.marks:
        return _marksBody();
    }
  }

  List<QOption> _optionsForCurrent() {
    if (_q.field == 'favoriteSubjects' || _q.field == 'difficultSubject') {
      return subjectOptions();
    }
    return _q.options;
  }

  bool get _isSubjectGrid =>
      _q.field == 'favoriteSubjects' || _q.field == 'difficultSubject';

  Widget _singleBody() {
    final options = _optionsForCurrent();
    final selected = _single(_q.field);
    if (_isSubjectGrid) {
      // Q9 difficult subject — ranking-row look, single pick (rank 1) for now.
      return SubjectRankList(
        options: options,
        selected: selected == null ? const [] : [selected],
        max: 1,
        onToggle: (o) => _setSingle(_q.field, o.value),
      );
    }
    return Column(
      children: options
          .map((o) => OptionCard(
                label: o.label,
                icon: o.icon,
                selected: selected == o.value,
                onTap: () => _setSingle(_q.field, o.value),
              ))
          .toList(),
    );
  }

  Widget _multiBody() {
    final options = _optionsForCurrent();
    final list = _multi(_q.field);

    // Q8 favourite subjects — 2-column icon-card grid with rank summary.
    if (_isSubjectGrid) {
      return SubjectRankGrid(
        options: options,
        selected: list,
        max: _q.maxSelect,
        onToggle: (o) => _toggleMulti(_q.field, o.value, _q.maxSelect),
      );
    }

    // Ranked (Q17 careerValues): colour-coded numbered rows.
    if (_q.ranked) {
      return RankingList(
        options: options,
        rankedOrder: list,
        max: _q.maxSelect,
        onToggle: (o) => _toggleMulti(_q.field, o.value, _q.maxSelect),
      );
    }

    // Plain multi (Q12 outsideActivities): 2-column icon-tile grid.
    return MultiSelectTileGrid(
      options: options,
      selected: list,
      max: _q.maxSelect,
      onToggle: (o) => _toggleMulti(_q.field, o.value, _q.maxSelect),
    );
  }

  Widget _textBody() {
    final g = Theme.of(context).guidanzia;
    final controller = _controllerFor(_q.field);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: controller,
            maxLines: _q.maxLen > 100 ? 4 : 3,
            maxLength: _q.maxLen,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(_q.maxLen)],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _q.placeholder,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
            ),
          ),
          Text('${controller.text.length}/${_q.maxLen}',
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _marksBody() {
    final g = Theme.of(context).guidanzia;
    if (q.favoriteSubjects.isEmpty) {
      return Text('Pick your favorite subjects first (Question 8).',
          style: TextStyle(color: g.onSurfaceVariant));
    }
    return Column(
      children: q.favoriteSubjects.map((subject) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject.toUpperCase(),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: g.gold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: marksBands.map((band) {
                  final sel = q.subjectMarks[subject] == band.value;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => q.subjectMarks[subject] = band.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? g.gold : g.surfaceElevated,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: sel ? g.gold : g.outline,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Text(band.label,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: sel ? g.goldInk : g.onSurface)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // -------------------- Feedback view --------------------

  Widget _feedbackView() {
    final g = Theme.of(context).guidanzia;
    // Stitch `module_insight_loading` / `module_insight_result`: an outlined
    // module numeral (lime while loading, gold when done), the title, then
    // either shimmer skeletons + progress bar (loading) or the AI text + trait
    // chips (result), with the CTA pinned to the bottom.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              children: [
                const SizedBox(height: 24),
                _ghostNumeral(_feedbackModule, _feedbackLoading ? g.lime : g.gold),
                if (!_feedbackLoading) ...[
                  const SizedBox(height: 10),
                  Text('MODULE COMPLETE',
                      style: TextStyle(
                          color: g.lime,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                ],
                const SizedBox(height: 16),
                Text("Here's what we're seeing",
                    textAlign: TextAlign.center, style: AppText.hero(30)),
                const SizedBox(height: 24),
                if (_feedbackLoading)
                  _loadingBody(g)
                else ...[
                  Text(_feedbackText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16, height: 1.55, color: g.onSurfaceVariant)),
                  if (_feedbackTraits.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    TraitChips(traits: _feedbackTraits),
                  ],
                ],
              ],
            ),
          ),
        ),
        Padding(
          // Reserve the system nav-bar / gesture inset so the CTA never hides
          // behind the phone's on-screen control buttons.
          padding: EdgeInsets.fromLTRB(24, 8, 24, 20 + MediaQuery.of(context).padding.bottom),
          child: _feedbackLoading
              ? Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: g.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: g.outline),
                  ),
                  child: Text('Keep going',
                      style: TextStyle(
                          color: g.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                )
              : PrimaryButton(
                  label: _q.number >= 20 ? 'Continue to the games' : 'Keep going',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _continueFromFeedback,
                ),
        ),
      ],
    );
  }

  /// Outlined (stroked) module numeral, per the insight mockups.
  Widget _ghostNumeral(int n, Color color) {
    return Text('$n',
        style: TextStyle(
          fontFamily: 'Sora',
          fontSize: 88,
          height: 1.0,
          fontWeight: FontWeight.w700,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = color,
        ));
  }

  /// Loading skeletons + thin progress line (Stitch `module_insight_loading`).
  Widget _loadingBody(GuidanziaColors g) {
    Widget bar(double f) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: f,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: g.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
            duration: 1200.ms, color: g.lime.withValues(alpha: 0.35));
    return Column(
      children: [
        bar(1.0),
        bar(0.85),
        bar(0.6),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: g.surfaceMuted,
            valueColor: AlwaysStoppedAnimation(g.lime),
          ),
        ),
      ],
    );
  }
}

