import 'package:flutter/material.dart';

import '../theme/guidanzia_colors.dart';
import '../widgets/primary_button.dart';
import 'rules_card.dart';

/// Game 5, Task 3 — Secret Agent Cipher, ported 1:1 from the web
/// `SecretAgentCipher`. Three tiers of a hidden coding rule: study worked
/// examples, then decode a test message. It measures information-gathering
/// (patient vs impulsive — how many examples viewed before attempting),
/// persistence (give-ups / retries), and rule-adaptability (Tier 2). Scoring
/// labels are verbatim so `generate_game5_insights` keys off them.
///
/// Self-managed: fetches the tiers via [fetchQuestions] (showing loading/error)
/// and validates Tier-3 words via [validateWord].

class SecretAgentResult {
  const SecretAgentResult({
    required this.informationGathering,
    required this.persistence,
    required this.ruleAdaptability,
    required this.solved,
    required this.counselorFlags,
  });
  final String informationGathering;
  final String persistence;
  final String ruleAdaptability;
  final bool solved;
  final List<String> counselorFlags;
}

class _CipherExample {
  const _CipherExample(this.message, this.decoded);
  final String message;
  final String decoded;
}

class _CipherTier {
  const _CipherTier({
    required this.tier,
    required this.examples,
    required this.testMessage,
    required this.validAnswers,
  });
  final int tier;
  final List<_CipherExample> examples;
  final String testMessage;
  final List<String> validAnswers;
}

class _CipherAttempt {
  const _CipherAttempt(this.input, this.correct, this.errorType, this.timestampMs);
  final String input;
  final bool correct;
  final String? errorType; // 'rule_error' | 'vocab_error' | 'wrong' | null
  final int timestampMs;
}

class _CipherTierResult {
  const _CipherTierResult({
    required this.tier,
    required this.examplesSeenBeforeTest,
    required this.totalExamples,
    required this.attempts,
    required this.solved,
    required this.timeToFirstAttemptMs,
    required this.gaveUp,
  });
  final int tier;
  final int examplesSeenBeforeTest;
  final int totalExamples;
  final List<_CipherAttempt> attempts;
  final bool solved;
  final int timeToFirstAttemptMs;
  final bool gaveUp;
}

const _tierLabels = {1: 'Transmission Echo', 2: 'Transmission Foxtrot', 3: 'Transmission Tango'};
const _tierMissions = {
  1: 'Crack the access code to enter the building.',
  2: 'Decode the intercepted transmission.',
  3: 'Break the enemy cipher.',
};
const _maxAttempts = 3;

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

String _getLetterCount(String message) => message
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) => w.replaceAll(RegExp(r'[^a-zA-Z]'), '').length)
    .join();

String _getFirstLetters(String message) => message
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) {
      final c = w.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      return c.isEmpty ? '' : c[0].toUpperCase();
    })
    .where((s) => s.isNotEmpty)
    .join();

String _sortedLetters(String str) {
  final chars = str.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '').split('')..sort();
  return chars.join();
}

_CipherTier _parseTier(Map<String, dynamic> m) {
  final examples = (m['examples'] as List? ?? [])
      .map((e) {
        final em = (e as Map).cast<String, dynamic>();
        return _CipherExample((em['message'] ?? '').toString(), (em['decoded'] ?? '').toString());
      })
      .toList();
  return _CipherTier(
    tier: (m['tier'] as num?)?.toInt() ?? 1,
    examples: examples,
    testMessage: (m['testMessage'] ?? '').toString(),
    validAnswers: (m['validAnswers'] as List? ?? []).map((e) => e.toString()).toList(),
  );
}

enum _CipherPhase { briefing, examples, test, between }

class SecretAgentCipherGame extends StatefulWidget {
  const SecretAgentCipherGame({
    super.key,
    required this.fetchQuestions,
    required this.validateWord,
    required this.onComplete,
    required this.onSkip,
  });

  final Future<Map<String, dynamic>> Function() fetchQuestions;
  final Future<bool> Function(String) validateWord;
  final ValueChanged<SecretAgentResult> onComplete;
  final VoidCallback onSkip;

  @override
  State<SecretAgentCipherGame> createState() => _SecretAgentCipherGameState();
}

class _SecretAgentCipherGameState extends State<SecretAgentCipherGame> {
  bool _loading = true;
  bool _loadError = false;
  List<_CipherTier> _tiers = const [];

  _CipherPhase _phase = _CipherPhase.briefing;
  int _tierIdx = 0;
  int _examplesRevealed = 1;
  int _examplesSeenBeforeTest = 0;
  final _input = TextEditingController();
  List<_CipherAttempt> _attempts = [];
  final List<_CipherTierResult> _results = [];
  bool _isValidating = false;
  String? _feedbackMsg;
  bool _feedbackOk = false;

  int _testStartTime = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final q = await widget.fetchQuestions();
      final tiers = [
        _parseTier((q['tier1'] as Map).cast<String, dynamic>()),
        _parseTier((q['tier2'] as Map).cast<String, dynamic>()),
        _parseTier((q['tier3'] as Map).cast<String, dynamic>()),
      ];
      if (!mounted) return;
      setState(() {
        _tiers = tiers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  int get _tierNum => _tierIdx + 1;
  _CipherTier get _q => _tiers[_tierIdx];
  int get _maxExamples => _q.examples.length;

  void _enterExamples() {
    setState(() {
      _examplesRevealed = 1;
      _examplesSeenBeforeTest = 0;
      _attempts = [];
      _input.clear();
      _feedbackMsg = null;
      _feedbackOk = false;
      _phase = _CipherPhase.examples;
    });
  }

  void _enterTest(int fromExampleCount) {
    setState(() {
      _testStartTime = _nowMs();
      _examplesSeenBeforeTest = fromExampleCount;
      _feedbackMsg = null;
      _feedbackOk = false;
      _phase = _CipherPhase.test;
    });
  }

  void _revealNext() {
    if (_examplesRevealed < _maxExamples) setState(() => _examplesRevealed++);
  }

  Future<void> _submit() async {
    final raw = _input.text.trim();
    if (raw.isEmpty || _isValidating) return;
    setState(() => _isValidating = true);
    final now = _nowMs();
    var correct = false;
    String? errorType;
    var msg = '';

    if (_tierNum == 1) {
      correct = raw == _getLetterCount(_q.testMessage);
      if (!correct) {
        msg = 'Not the right code. Count every letter in each word, then write the counts together with no spaces.';
      }
    } else if (_tierNum == 2) {
      correct = _q.validAnswers.any((a) => a.toUpperCase() == raw.toUpperCase());
      if (!correct) {
        msg = '"${raw.toUpperCase()}" is not the right word. Check which letter you are extracting from each word.';
      }
    } else {
      final lettersMatch = _sortedLetters(raw) == _sortedLetters(_getFirstLetters(_q.testMessage));
      final isWord = await widget.validateWord(raw.toLowerCase());
      if (!mounted) return;
      if (lettersMatch && isWord) {
        correct = true;
      } else if (!lettersMatch && isWord) {
        errorType = 'rule_error';
        msg = '"${raw.toUpperCase()}" is a real word, but those are not the right letters. Re-check which letter you take from each word.';
      } else if (lettersMatch && !isWord) {
        errorType = 'vocab_error';
        msg = 'You have the right letters. "${raw.toUpperCase()}" is not a recognised word — try rearranging them differently.';
      } else {
        errorType = 'wrong';
        msg = 'Check both steps: extract the first letter from every word, then rearrange all of them to form a real word.';
      }
    }

    final newAttempts = [..._attempts, _CipherAttempt(raw, correct, errorType, now)];
    setState(() {
      _attempts = newAttempts;
      _isValidating = false;
    });

    if (correct) {
      setState(() {
        _feedbackMsg = 'Transmission decoded.';
        _feedbackOk = true;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _advanceTier(newAttempts, false);
      });
    } else if (newAttempts.length >= _maxAttempts) {
      setState(() {
        _feedbackMsg = 'Maximum attempts reached. Moving to the next transmission.';
        _feedbackOk = false;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _advanceTier(newAttempts, true);
      });
    } else {
      setState(() {
        _feedbackMsg = msg;
        _feedbackOk = false;
        _input.clear();
      });
    }
  }

  void _giveUp() => _advanceTier(_attempts, true);

  void _advanceTier(List<_CipherAttempt> finalAttempts, bool gaveUp) {
    _results.add(_CipherTierResult(
      tier: _tierNum,
      examplesSeenBeforeTest: _examplesSeenBeforeTest,
      totalExamples: _maxExamples,
      attempts: finalAttempts,
      solved: !gaveUp && (finalAttempts.isNotEmpty && finalAttempts.last.correct),
      timeToFirstAttemptMs:
          finalAttempts.isNotEmpty ? finalAttempts.first.timestampMs - _testStartTime : 0,
      gaveUp: gaveUp,
    ));
    if (_tierIdx < 2) {
      setState(() {
        _tierIdx++;
        _phase = _CipherPhase.between;
      });
    } else {
      _finalize();
    }
  }

  void _finalize() {
    final flags = <String>[];
    final avgRatio = _results.fold<double>(0, (sum, r) {
          return sum + (r.totalExamples > 0 ? r.examplesSeenBeforeTest / r.totalExamples : 0);
        }) /
        _results.length;
    final informationGathering = avgRatio < 0.35 ? 'impulsive' : avgRatio < 0.75 ? 'moderate' : 'patient';
    if (informationGathering == 'impulsive') {
      flags.add('Attempted all three ciphers before seeing most examples — tendency to act on limited information. May benefit from structured analysis frameworks in high-stakes decisions.');
    }

    final gaveUpCount = _results.where((r) => r.gaveUp).length;
    final triedAfterWrong = _results.any((r) => r.attempts.length > 1);
    final persistence = gaveUpCount >= 2
        ? 'low'
        : gaveUpCount == 1
            ? 'medium'
            : !triedAfterWrong
                ? 'medium'
                : 'high';
    if (persistence == 'low') {
      flags.add('Gave up on 2 or more transmissions — low frustration tolerance under ambiguity. High-grind paths (NEET, JEE, UPSC) carry elevated risk without additional support strategies.');
    } else if (persistence == 'high') {
      flags.add('Persisted through wrong answers without giving up — strong grit signal. Suited to long-preparation paths that reward sustained effort.');
    }

    final tier2 = _results.where((r) => r.tier == 2).toList();
    final t2First = tier2.isNotEmpty && tier2.first.attempts.isNotEmpty && tier2.first.attempts.first.correct;
    final t2Count = tier2.isNotEmpty ? tier2.first.attempts.length : 0;
    final ruleAdaptability = t2First ? 'fast' : t2Count <= 2 ? 'moderate' : 'slow';
    if (ruleAdaptability == 'slow') {
      flags.add('Multiple wrong attempts when cipher rule type changed — possible preference for consistent rule environments.');
    }
    if (ruleAdaptability == 'fast') {
      flags.add('Adapted to a completely different rule type on the first attempt at Transmission 2 — strong cognitive flexibility signal.');
    }

    final tier3 = _results.where((r) => r.tier == 3).toList();
    final t3 = tier3.isNotEmpty ? tier3.first : null;
    final vocabErrors = t3?.attempts.where((a) => a.errorType == 'vocab_error').length ?? 0;
    final ruleErrors = t3?.attempts.where((a) => a.errorType == 'rule_error').length ?? 0;
    if (vocabErrors >= 2) {
      flags.add('Extracted correct letters on Transmission Tango but struggled to form a valid English word — vocabulary constraint, not a reasoning deficit.');
    }
    if (ruleErrors >= 1 && (t3?.solved ?? false)) {
      flags.add('Initially applied incorrect extraction rule on Transmission Tango but self-corrected and solved it — good hypothesis-revision under failure.');
    }

    widget.onComplete(SecretAgentResult(
      informationGathering: informationGathering,
      persistence: persistence,
      ruleAdaptability: ruleAdaptability,
      solved: _results.every((r) => r.solved),
      counselorFlags: flags,
    ));
  }

  // ---------------------------------------------------------------- render
  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).guidanzia;
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: g.gold),
            const SizedBox(height: 18),
            Text('Preparing your mission briefing…',
                style: TextStyle(color: g.onSurfaceVariant)),
          ],
        ),
      );
    }
    if (_loadError || _tiers.length < 3) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: g.onSurfaceVariant),
            const SizedBox(height: 14),
            Text('Could not load the mission. You can skip this one.',
                textAlign: TextAlign.center, style: TextStyle(color: g.onSurfaceVariant)),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Skip', onPressed: widget.onSkip),
          ],
        ),
      );
    }
    return switch (_phase) {
      _CipherPhase.briefing => _briefing(),
      _CipherPhase.between => _between(),
      _CipherPhase.examples => _examplesView(),
      _CipherPhase.test => _testView(),
    };
  }

  Widget _briefing() {
    final g = Theme.of(context).guidanzia;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF283569), Color(0xFF12143A)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: Text('🕵️', style: TextStyle(fontSize: 30))),
          ),
          const SizedBox(height: 18),
          const Text('Secret Agent Cipher',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('Three transmissions. Each uses a hidden rule. Study the examples, '
              'crack the pattern, decode the message.',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 15, height: 1.5)),
          const SizedBox(height: 20),
          for (final t in [1, 2, 3]) _briefingRow(t),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _ghostButton('Skip', widget.onSkip)),
              const SizedBox(width: 12),
              Expanded(child: PrimaryButton(label: 'Start Mission', onPressed: _enterExamples)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _briefingRow(int t) {
    final g = Theme.of(context).guidanzia;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: g.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: g.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(_tierLabels[t]!),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_tierMissions[t]!,
                style: TextStyle(color: g.onSurfaceVariant, fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _between() {
    final g = Theme.of(context).guidanzia;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, size: 56, color: g.lime),
          const SizedBox(height: 16),
          const Text('Transmission complete.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_tierMissions[_tierNum]!,
              textAlign: TextAlign.center,
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 13.5)),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Next transmission', onPressed: _enterExamples),
        ],
      ),
    );
  }

  Widget _examplesView() {
    final g = Theme.of(context).guidanzia;
    final visible = _q.examples.take(_examplesRevealed).toList();
    final allRevealed = _examplesRevealed >= _maxExamples;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _badge(_tierLabels[_tierNum]!),
                    const SizedBox(height: 8),
                    Text(_tierMissions[_tierNum]!,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Text('${_tierIdx + 1} of 3',
                  style: TextStyle(color: g.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Text('STUDY THE PATTERN',
              style: TextStyle(
                  color: g.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          for (final ex in visible)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: g.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: g.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(ex.message,
                        style: TextStyle(fontFamily: 'monospace', color: g.onSurface, fontSize: 13.5)),
                  ),
                  const SizedBox(width: 12),
                  Text('→ ${ex.decoded}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: g.gold)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!allRevealed) ...[
                Expanded(
                  child: _ghostButton('Show next ($_examplesRevealed/$_maxExamples)', _revealNext),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: PrimaryButton(
                  label: allRevealed ? "I've got it — test me" : 'Test me now',
                  onPressed: () => _enterTest(_examplesRevealed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _testView() {
    final g = Theme.of(context).guidanzia;
    final attemptsLeft = _maxAttempts - _attempts.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(_tierLabels[_tierNum]!),
              const Spacer(),
              Text('$attemptsLeft attempt${attemptsLeft != 1 ? 's' : ''} left',
                  style: TextStyle(color: g.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          const RulesCard(
            bullets: [
              'Study the worked examples to crack the hidden rule.',
              "Each tier hides a different rule — don't assume it stays the same.",
              'Type your decoded answer and Submit. You get 3 attempts per tier.',
              'No timer — take the time you need to be sure.',
            ],
          ),
          const SizedBox(height: 16),
          Text('DECODE THIS MESSAGE',
              style: TextStyle(
                  color: g.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: g.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: g.gold.withValues(alpha: 0.4)),
            ),
            child: Text(_q.testMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: g.onSurface)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            enabled: !_isValidating && !_feedbackOk,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: _tierNum == 1 ? 'Type the number string…' : 'Type the decoded word…',
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (_feedbackMsg != null) ...[
            const SizedBox(height: 10),
            Text(_feedbackMsg!,
                style: TextStyle(
                    color: _feedbackOk ? g.lime : g.danger,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _ghostButton('Give up', (_isValidating || _feedbackOk) ? () {} : _giveUp),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: _isValidating ? 'Checking…' : 'Submit',
                  onPressed: (_isValidating || _feedbackOk) ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label) {
    final g = Theme.of(context).guidanzia;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: g.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: g.gold.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: g.gold, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  Widget _ghostButton(String label, VoidCallback onTap) {
    final g = Theme.of(context).guidanzia;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        foregroundColor: g.onSurfaceVariant,
        side: BorderSide(color: g.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
