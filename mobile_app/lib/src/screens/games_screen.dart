import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../games/game_bank.dart';
import '../games/game_models.dart';
import '../games/sliding_tile.dart';
import '../games/constraint_grid.dart';
import '../games/secret_agent_cipher.dart';
import '../router/app_routes.dart';
import '../state/providers.dart';
import '../widgets/gradient_background.dart';
import '../widgets/theme_toggle.dart';
import 'home_shell.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/common_widgets.dart';
import '../theme/guidanzia_colors.dart';

enum _Phase { intro, wordLoading, wordError, playing, gameDone, tile, tileDone, grid, gridDone, cipher, cipherDone, saving, saveError }

/// The four aptitude sense-games (Number / Word / Shape / Logic), ported to
/// match the web: real question banks, AI-generated Word Sense, image-based
/// Shape/Logic questions, response timing, weighted 0-8 scoring, and the exact
/// per-game feedback. (Game 5 behavioural suite is a later batch.)
class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  _Phase _phase = _Phase.intro;
  int _gameType = 1; // 1..4
  int _round = 0;
  final List<GameResponse> _responses = [];
  final Set<String> _usedNumberIds = {};
  final List<int> _scores = [];

  AptQuestion? _current;
  Object? _selected;
  int _questionStart = 0;

  // Word Sense (game 2) items, pre-fetched from the backend.
  List<AptQuestion?> _wordItems = [null, null, null, null];
  int _wordLoaded = 0; // how many of the 4 word items have finished (real progress)

  String? _saveError;

  // Game 5, Task 1 — Sliding-Tile persistence result (shown in feedback).
  PersistenceResult? _persistence;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assessmentStatusProvider.notifier).enter(AssessmentStage.games);
    });
  }

  static const _accents = <List<Color>>[
    [], // 0 unused
    [Color(0xFFE0A92E), Color(0xFFB8860B)], // number – gold
    [Color(0xFF7FA300), Color(0xFF5F7D00)], // word   – lime
    [Color(0xFF12A5A5), Color(0xFF006A6A)], // shape  – cyan
    [Color(0xFFF59E0B), Color(0xFFD97706)], // logic  – amber
  ];
  static const _names = ['', 'Number Sense', 'Word Sense', 'Shape Sense', 'Logic Sense'];
  static const _taglines = [
    '',
    'Sequences and arithmetic — quantitative reasoning',
    'Analogies and meanings — verbal reasoning',
    'Rotation and visualization — spatial reasoning',
    'Patterns and deduction — abstract reasoning',
  ];

  List<Color> get _accent => _accents[_gameType];

  int _now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> _startGame(int type) async {
    setState(() {
      _gameType = type;
      _round = 0;
      _responses.clear();
      _selected = null;
    });
    if (type == 2) {
      await _prefetchWord();
      if (_phase == _Phase.wordError) return;
    }
    _beginRound();
  }

  Future<void> _prefetchWord() async {
    setState(() {
      _phase = _Phase.wordLoading;
      _wordItems = [null, null, null, null];
      _wordLoaded = 0;
    });
    final api = ref.read(apiClientProvider);
    final results = await Future.wait(
      List.generate(4, (i) async {
        try {
          final item = await api.generateWordItem(
              itemType: wordSenseTypes[i], difficulty: 3);
          final opts = (item['options'] as List).map((e) => e.toString()).toList();
          final ci = (item['correct_index'] as num).toInt();
          return AptQuestion(
            id: 'W2-${wordSenseTypes[i]}',
            type: wordSenseTypes[i],
            question: (item['question'] ?? '').toString(),
            options: opts,
            correct: opts[ci.clamp(0, opts.length - 1)],
            difficulty: 3,
          );
        } catch (_) {
          return null;
        } finally {
          // Each item resolves independently → honest "X of 4" progress.
          if (mounted) setState(() => _wordLoaded++);
        }
      }),
    );
    if (!mounted) return;
    _wordItems = results;
    if (results.every((r) => r == null)) {
      setState(() => _phase = _Phase.wordError);
    }
  }

  void _beginRound() {
    AptQuestion? q;
    switch (_gameType) {
      case 1:
        q = selectNumberQuestion(_round, _responses, _usedNumberIds);
        break;
      case 2:
        q = _wordItems[_round];
        break;
      case 3:
        q = shapeSenseBank[_round];
        break;
      case 4:
        q = logicSenseBank[_round];
        break;
    }
    setState(() {
      _current = q;
      _selected = null;
      _phase = _Phase.playing;
      _questionStart = _now();
    });
  }

  void _answer(Object option) {
    if (_selected != null || _current == null) return;
    final rt = _now() - _questionStart;
    final isCorrect = option == _current!.correct;
    setState(() => _selected = option);

    final q = _current!;
    if (_gameType == 1) _usedNumberIds.add(q.id);
    _responses.add(GameResponse(
      questionId: q.id,
      isCorrect: isCorrect,
      responseTimeMs: rt,
      difficulty: q.difficulty,
    ));

    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      if (_round >= 3) {
        _scores.add(weightedScore(_responses));
        // Persist the finished game's score so an app kill doesn't lose it.
        _writeScores();
        ref.read(assessmentStatusProvider.notifier).setGameIndex(_gameType);
        await persistAssessment(ref);
        if (!mounted) return;
        setState(() => _phase = _Phase.gameDone);
      } else {
        setState(() => _round++);
        _beginRound();
      }
    });
  }

  /// Copy the scores collected so far onto the shared questionnaire data.
  void _writeScores() {
    final q = ref.read(questionnaireProvider);
    if (_scores.isNotEmpty) q.numberSenseScore = _scores[0];
    if (_scores.length > 1) q.wordSenseScore = _scores[1];
    if (_scores.length > 2) q.shapeSenseScore = _scores[2];
    if (_scores.length > 3) q.logicSenseScore = _scores[3];
  }

  void _skipMissingWord() {
    // A single Word item failed to generate — record as wrong and move on.
    _responses.add(GameResponse(
        questionId: 'W2-missing', isCorrect: false, responseTimeMs: 0, difficulty: 3));
    if (_round >= 3) {
      _scores.add(weightedScore(_responses));
      // Mirror the normal answer path: write this game's score and checkpoint
      // progress, so a skipped final item doesn't silently drop the result.
      _writeScores();
      ref.read(assessmentStatusProvider.notifier).setGameIndex(_gameType);
      persistAssessment(ref);
      setState(() => _phase = _Phase.gameDone);
    } else {
      setState(() => _round++);
      _beginRound();
    }
  }

  void _continueAfterGame() {
    if (_gameType < 4) {
      _startGame(_gameType + 1);
    } else {
      // Aptitude games done — go to Game 5, Task 1 (Sliding-Tile persistence).
      setState(() => _phase = _Phase.tile);
    }
  }

  void _onTileComplete(PersistenceResult r) {
    final q = ref.read(questionnaireProvider);
    q.persistenceEffortRating = r.effortRating;
    q.persistenceApproachStyle = r.approachStyle;
    q.persistenceCounselorFlags = r.counselorFlags;
    q.persistenceHighestTier = r.highestTier;
    setState(() {
      _persistence = r;
      _phase = _Phase.tileDone;
    });
  }

  // Skipping the tile still proceeds to Task 2 (matches the web flow).
  void _onTileSkip() => setState(() => _phase = _Phase.grid);

  void _onGridComplete(ConstraintGridResult r) {
    final q = ref.read(questionnaireProvider);
    q.constraintGridApproach = r.approachLabel;
    q.constraintGridSolved = r.solved;
    q.constraintGridCounselorFlag = r.counselorFlag;
    // Aggregate into the shared counselor-flag list (matches the web save).
    if (r.counselorFlag != null) {
      q.persistenceCounselorFlags = [...q.persistenceCounselorFlags, r.counselorFlag!];
    }
    setState(() => _phase = _Phase.gridDone);
  }

  // Skipping the grid still proceeds to Task 3.
  void _onGridSkip() => setState(() => _phase = _Phase.cipher);

  void _onCipherComplete(SecretAgentResult r) {
    final q = ref.read(questionnaireProvider);
    q.cipherInformationGathering = r.informationGathering;
    q.cipherPersistence = r.persistence;
    q.cipherRuleAdaptability = r.ruleAdaptability;
    q.cipherSolved = r.solved;
    q.cipherCounselorFlags = r.counselorFlags;
    q.persistenceCounselorFlags = [...q.persistenceCounselorFlags, ...r.counselorFlags];
    setState(() => _phase = _Phase.cipherDone);
  }

  void _onCipherSkip() => _saveAll();

  Future<void> _saveAll() async {
    setState(() {
      _phase = _Phase.saving;
      _saveError = null;
    });
    _writeScores();
    final q = ref.read(questionnaireProvider);
    final username = ref.read(authProvider).user!.username;
    try {
      await ref.read(apiClientProvider).saveQuestionnaire(username, q);
      // Saved on the server — the local in-progress copy is no longer needed.
      await clearPersistedAssessment(ref);
      // Assessment finished — mark complete, regenerate recommendations for the
      // freshly-saved profile, and land the user on the **Matches** tab (not
      // Home) so they immediately see their career recommendations.
      ref.read(assessmentStatusProvider.notifier).finish();
      ref.invalidate(recommendationsProvider);
      ref.read(shellTabProvider.notifier).state = ShellTab.matches;
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (_) => false);
      }
    } on ApiException catch (e) {
      setState(() {
        _phase = _Phase.saveError;
        _saveError = e.message;
      });
    } catch (_) {
      setState(() {
        _phase = _Phase.saveError;
        _saveError = 'Could not save your results. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aptitude Games'),
        automaticallyImplyLeading: false,
        actions: const [ThemeToggle(), SizedBox(width: 8)],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: switch (_phase) {
            _Phase.intro => _introView(),
            _Phase.wordLoading => CountLoader(
                loaded: _wordLoaded,
                total: 4,
                label: 'Preparing your Word Sense questions'),
            _Phase.wordError => ErrorStateView(
                message: 'Could not generate the Word Sense questions.',
                onRetry: () => _startGame(2),
              ),
            _Phase.playing => _playingView(),
            _Phase.gameDone => _gameDoneView(),
            _Phase.tile =>
              SlidingTileGame(onComplete: _onTileComplete, onSkip: _onTileSkip),
            _Phase.tileDone => _tileDoneView(),
            _Phase.grid =>
              ConstraintGridGame(onComplete: _onGridComplete, onSkip: _onGridSkip),
            _Phase.gridDone => _gridDoneView(),
            _Phase.cipher => SecretAgentCipherGame(
                fetchQuestions: () => ref.read(apiClientProvider).generateCipherQuestions(),
                validateWord: (w) => ref.read(apiClientProvider).validateWord(w),
                onComplete: _onCipherComplete,
                onSkip: _onCipherSkip,
              ),
            _Phase.cipherDone => _cipherDoneView(),
            _Phase.saving => const LoadingState(
                message: 'Saving your results and preparing your profile…'),
            _Phase.saveError => ErrorStateView(
                message: _saveError ?? 'Something went wrong.', onRetry: _saveAll),
          },
        ),
      ),
    );
  }

  // -------------------- Intro (combined "Four Quick Games") --------------------
  Widget _introView() {
    final g = Theme.of(context).guidanzia;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4FC08D), Color(0xFF2E9E6E)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Four Quick Games',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            'These tell us how your mind actually works — your aptitude pattern is the '
            'single hardest thing to fake, and it sharpens our recommendations significantly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: g.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 24),
          for (var i = 1; i <= 4; i++) _introRow(i),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Start Games',
            icon: Icons.play_arrow_rounded,
            onPressed: () => _startGame(1),
          ),
        ],
      ),
    );
  }

  Widget _introRow(int type) {
    final g = Theme.of(context).guidanzia;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accents[type].last.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _accents[type].last,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text('$type',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_names[type],
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${_taglines[type]} (4 questions)',
                    style: TextStyle(color: g.onSurfaceVariant, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- Playing --------------------
  Widget _playingView() {
    final g = Theme.of(context).guidanzia;
    final q = _current;
    if (q == null) {
      // A single Word item failed to generate.
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.help_outline, size: 44, color: g.onSurfaceVariant),
            const SizedBox(height: 14),
            Text("This question couldn't be generated.",
                textAlign: TextAlign.center,
                style: TextStyle(color: g.onSurfaceVariant)),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Continue', onPressed: _skipMissingWord),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      key: ValueKey('g${_gameType}r$_round'),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_iconFor(_gameType), color: _accent.last),
              const SizedBox(width: 8),
              Text('${_names[_gameType]} — Question ${_round + 1} of 4',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= _round ? _accent.last : g.onSurfaceVariant.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          if (q.isImageQuestion) ..._imageQuestion(q) else ..._textQuestion(q),
        ],
      ).animate().fadeIn(duration: 200.ms),
    );
  }

  List<Widget> _textQuestion(AptQuestion q) {
    final isWord = _gameType == 2;
    return [
      GlassCard(
        padding: const EdgeInsets.all(22),
        child: Text(
          q.question,
          textAlign: isWord ? TextAlign.left : TextAlign.center,
          style: TextStyle(
              fontSize: isWord ? 17 : 22,
              fontWeight: FontWeight.w700,
              height: 1.35),
        ),
      ),
      const SizedBox(height: 20),
      if (isWord)
        Column(
          children: q.options
              .map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TextOption(
                      label: o.toString(),
                      selected: _selected == o,
                      accent: _accent.last,
                      onTap: () => _answer(o),
                    ),
                  ))
              .toList(),
        )
      else
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: q.options
              .map((o) => _TextOption(
                    label: o.toString(),
                    selected: _selected == o,
                    accent: _accent.last,
                    center: true,
                    big: true,
                    onTap: () => _answer(o),
                  ))
              .toList(),
        ),
    ];
  }

  List<Widget> _imageQuestion(AptQuestion q) {
    final g = Theme.of(context).guidanzia;
    const labels = ['Option A', 'Option B', 'Option C', 'Option D'];
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _accent.last.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(q.question,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 14),
            Image.asset(q.questionImage!, height: 130, fit: BoxFit.contain),
          ],
        ),
      ),
      const SizedBox(height: 18),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
        children: List.generate(4, (i) {
          final label = labels[i];
          final sel = _selected == label;
          return GestureDetector(
            onTap: () => _answer(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: g.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: sel ? _accent.last : g.outline,
                    width: sel ? 2 : 1),
              ),
              child: Column(
                children: [
                  Expanded(child: Image.asset(q.optionImages![i], fit: BoxFit.contain)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: sel ? _accent.last : g.onSurfaceVariant)),
                ],
              ),
            ),
          );
        }),
      ),
    ];
  }

  IconData _iconFor(int type) => switch (type) {
        1 => Icons.calculate_rounded,
        2 => Icons.menu_book_rounded,
        3 => Icons.category_rounded,
        _ => Icons.extension_rounded,
      };

  // -------------------- Per-game feedback --------------------
  Widget _gameDoneView() {
    final g = Theme.of(context).guidanzia;
    final score = _scores.last;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _accent),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _accent.last.withValues(alpha: 0.4), blurRadius: 28, offset: const Offset(0, 14)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$score',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800)),
                const Text('/ 8', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          ).animate().scale(duration: 420.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 22),
          Text('${_names[_gameType]} Complete',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          GlassCard(
            child: Text(
              gameFeedback(_gameType, _responses),
              style: TextStyle(fontSize: 15, height: 1.5, color: g.onSurface),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _gameType < 4 ? 'Next Game' : 'Mind game',
            icon: Icons.arrow_forward_rounded,
            onPressed: _continueAfterGame,
          ),
        ],
      ),
    );
  }

  // -------------------- Game 5, Task 1 feedback --------------------
  Widget _tileDoneView() {
    final g = Theme.of(context).guidanzia;
    final r = _persistence;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF12A5A5), Color(0xFF006A6A)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 22),
          const Text('Puzzle complete',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (r != null)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.effortRating,
                      style: TextStyle(fontSize: 15, height: 1.5, color: g.onSurface)),
                  const SizedBox(height: 12),
                  Text(r.approachStyle,
                      style: TextStyle(
                          fontSize: 15, height: 1.5, color: g.onSurfaceVariant)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => setState(() => _phase = _Phase.grid),
          ),
        ],
      ),
    );
  }

  // -------------------- Game 5, Task 2 transition --------------------
  Widget _gridDoneView() {
    final g = Theme.of(context).guidanzia;
    final q = ref.read(questionnaireProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: g.gold, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, color: g.goldInk, size: 34),
          ),
          const SizedBox(height: 22),
          const Text('Puzzle complete',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          GlassCard(
            child: Text(
              _constraintSummary(q.constraintGridApproach, q.constraintGridSolved),
              style: TextStyle(fontSize: 15, height: 1.5, color: g.onSurface),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => setState(() => _phase = _Phase.cipher),
          ),
        ],
      ),
    );
  }

  /// Friendly 2-3 line read-back of the Constraint-Grid signal we just stored
  /// (mirrors the label the report's Game-5 section keys off).
  String _constraintSummary(String? approach, bool solved) {
    final head = switch (approach) {
      'systematic-analytical' =>
        'You worked methodically — reading the constraints and reasoning out each cell before committing.',
      'cautious' =>
        'You took a careful, considered approach — checking the rules before making your moves.',
      'complexity-shutdown' =>
        'This one got dense fast, and you stepped back rather than forcing it — an honest signal about how you meet heavy ambiguity.',
      'low-ambiguity-tolerance' =>
        'You prefer clear, well-defined problems — the open-ended constraints here felt less comfortable, which is useful to know.',
      _ =>
        'You adapted as you went — trying moves and adjusting from what the grid told you.',
    };
    final tail = solved
        ? ' You saw it through to a complete grid.'
        : ' You did not fully complete it — and that is fine; how you engaged is what we read here.';
    return head + tail;
  }

  // -------------------- Game 5, Task 3 transition (suite complete) ----------
  Widget _cipherDoneView() {
    final g = Theme.of(context).guidanzia;
    final q = ref.read(questionnaireProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: g.gold, shape: BoxShape.circle),
            child: Icon(Icons.verified_rounded, color: g.goldInk, size: 34),
          ),
          const SizedBox(height: 22),
          const Text('Mission complete',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          GlassCard(
            child: Text(
              _cipherSummary(
                q.cipherInformationGathering,
                q.cipherPersistence,
                q.cipherRuleAdaptability,
              ),
              style: TextStyle(fontSize: 15, height: 1.5, color: g.onSurface),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'View my career profile',
            icon: Icons.arrow_forward_rounded,
            onPressed: _saveAll,
          ),
        ],
      ),
    );
  }

  /// Friendly 2-3 line read-back of the Cipher signal we just stored
  /// (information-gathering, persistence, rule-adaptability).
  String _cipherSummary(String? gathering, String? persistence, String? adaptability) {
    final g = switch (gathering) {
      'patient' => 'You studied the clues carefully before committing to an answer.',
      'impulsive' => 'You jumped in fast, working it out as you went.',
      _ => 'You balanced studying the clues with acting on them.',
    };
    final p = switch (persistence) {
      'high' => 'You kept at it even when a code resisted you.',
      'low' => 'You moved on quickly when a code felt stuck.',
      _ => 'You pushed through the tricky codes with steady effort.',
    };
    final a = switch (adaptability) {
      'fast' => 'And when the rule changed, you spotted the shift almost immediately.',
      'slow' => 'When the rule changed, it took a little while to adjust — worth knowing.',
      _ => 'When the rule changed, you re-tuned your thinking to match.',
    };
    return '$g $p $a';
  }
}

class _TextOption extends StatelessWidget {
  const _TextOption({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.center = false,
    this.big = false,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final bool center;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        alignment: center ? Alignment.center : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : g.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? accent : g.outline, width: selected ? 1.8 : 1),
        ),
        child: Text(
          label,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: big ? 20 : 15,
            fontWeight: big ? FontWeight.w800 : FontWeight.w600,
            color: g.onSurface,
          ),
        ),
      ),
    );
  }
}
