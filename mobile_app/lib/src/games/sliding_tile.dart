import 'package:flutter/material.dart';

import '../theme/guidanzia_colors.dart';
import '../widgets/primary_button.dart';
import 'rules_card.dart';

/// Game 5, Task 1 — Sliding-Tile persistence puzzle, ported 1:1 from the web
/// `SlidingTile`. It measures HOW a student engages a hard problem (move
/// efficiency, reversals, distance trajectory, when they quit), not whether
/// they solve it. Deliberately timer-less: a countdown would pressure the
/// player and corrupt the `timeToFirstMove` / `quitTime` signals the scoring
/// reads. Styled to `behavioral_puzzle_task` (dark tiles, gold borders).
///
/// The scoring strings are copied verbatim from the web because the backend's
/// recommendation filter and `generate_game5_insights` key off the exact text.

class PersistenceResult {
  const PersistenceResult({
    required this.highestTier,
    required this.effortRating,
    required this.approachStyle,
    required this.counselorFlags,
  });
  final int highestTier;
  final String effortRating;
  final String approachStyle;
  final List<String> counselorFlags;
}

class _TileTelemetry {
  const _TileTelemetry({
    required this.tier,
    required this.totalMoves,
    required this.ratio,
    required this.timeToFirstMove,
    required this.reversals,
    required this.hintsUsed,
    required this.solved,
    required this.quitTime,
    required this.manhattanLog,
  });
  final int tier;
  final int totalMoves;
  final double ratio;
  final int timeToFirstMove;
  final int reversals;
  final int hintsUsed;
  final bool solved;
  final int? quitTime;
  final List<int> manhattanLog;
}

class _TileConfig {
  const _TileConfig({required this.tier, required this.state, required this.optimal, required this.solution});
  final int tier;
  final List<int> state;
  final int optimal;
  final List<String> solution;
}

// Fixed, verified-solvable bank; optimal move counts hardcoded (from the web).
const _tileConfigs = <_TileConfig>[
  _TileConfig(tier: 1, state: [1, 3, 8, 4, 6, 2, 0, 7, 5], optimal: 12, solution: [
    'right', 'up', 'right', 'up', 'left', 'down', 'down', 'right', 'up', 'left', 'down', 'right'
  ]),
  _TileConfig(tier: 2, state: [5, 4, 1, 3, 0, 8, 7, 6, 2], optimal: 16, solution: [
    'right', 'down', 'left', 'up', 'left', 'up', 'right', 'right', 'down', 'left', 'left', 'up', 'right', 'right', 'down', 'down'
  ]),
  _TileConfig(tier: 3, state: [2, 3, 4, 8, 0, 5, 1, 6, 7], optimal: 22, solution: [
    'left', 'down', 'right', 'right', 'up', 'up', 'left', 'left', 'down', 'right', 'down', 'left', 'up', 'right', 'right', 'down', 'left', 'left', 'up', 'right', 'right', 'down'
  ]),
  _TileConfig(tier: 4, state: [3, 8, 1, 7, 0, 4, 2, 6, 5], optimal: 24, solution: [
    'up', 'left', 'down', 'right', 'right', 'up', 'left', 'down', 'right', 'down', 'left', 'left', 'up', 'up', 'right', 'down', 'down', 'left', 'up', 'up', 'right', 'down', 'right', 'down'
  ]),
];

const _goalState = [1, 2, 3, 4, 5, 6, 7, 8, 0];

int _manhattan(List<int> state) {
  var total = 0;
  for (var i = 0; i < state.length; i++) {
    final val = state[i];
    if (val == 0) continue;
    final goalIdx = val - 1;
    total += ((i ~/ 3) - (goalIdx ~/ 3)).abs() + ((i % 3) - (goalIdx % 3)).abs();
  }
  return total;
}

bool _isSolved(List<int> state) {
  for (var i = 0; i < state.length; i++) {
    if (state[i] != _goalState[i]) return false;
  }
  return true;
}

List<int>? _applyMove(List<int> state, int tileIdx) {
  final empty = state.indexOf(0);
  final er = empty ~/ 3, ec = empty % 3;
  final tr = tileIdx ~/ 3, tc = tileIdx % 3;
  if (((er - tr).abs() + (ec - tc).abs()) != 1) return null;
  final next = [...state];
  next[empty] = next[tileIdx];
  next[tileIdx] = 0;
  return next;
}

List<int>? _applyDirection(List<int> state, String dir) {
  final empty = state.indexOf(0);
  final er = empty ~/ 3, ec = empty % 3;
  final m = <String, List<int>>{
    'up': [er + 1, ec],
    'down': [er - 1, ec],
    'left': [er, ec + 1],
    'right': [er, ec - 1],
  }[dir] ?? const [-1, -1];
  final nr = m[0], nc = m[1];
  if (nr < 0 || nr > 2 || nc < 0 || nc > 2) return null;
  return _applyMove(state, nr * 3 + nc);
}

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

enum _TilePhase { intro, warmup, playing, tierComplete, done }

class SlidingTileGame extends StatefulWidget {
  const SlidingTileGame({super.key, required this.onComplete, required this.onSkip});
  final ValueChanged<PersistenceResult> onComplete;
  final VoidCallback onSkip;

  @override
  State<SlidingTileGame> createState() => _SlidingTileGameState();
}

class _SlidingTileGameState extends State<SlidingTileGame> {
  _TilePhase _phase = _TilePhase.intro;
  int _tierIdx = 0; // 0 = warmup (T1), 1 = T2, 2 = T3, 3 = T4
  List<int> _board = const [];
  int _moveCount = 0;
  int _hintsUsed = 0;
  int _reversals = 0;
  List<int> _manhattanLog = const [];
  final List<_TileTelemetry> _telemetry = [];
  int _lastMoveTime = 0;
  List<int> _lastBoard = const [];
  int _tierStartTime = 0;
  int? _firstMoveTime;
  bool _tierComplete = false;
  bool _firstMoveDone = false;

  _TileConfig get _config => _tileConfigs[_tierIdx];
  bool get _isWarmup => _tierIdx == 0;

  void _startTier(int tierIdx) {
    final cfg = _tileConfigs[tierIdx];
    setState(() {
      _tierIdx = tierIdx;
      _board = [...cfg.state];
      _moveCount = 0;
      _hintsUsed = 0;
      _reversals = 0;
      _manhattanLog = [_manhattan(cfg.state)];
      _lastMoveTime = 0;
      _lastBoard = const [];
      _tierStartTime = _nowMs();
      _firstMoveTime = null;
      _firstMoveDone = false;
      _tierComplete = false;
      _phase = tierIdx == 0 ? _TilePhase.warmup : _TilePhase.playing;
    });
  }

  void _handleTileClick(int tileIdx) {
    if (_tierComplete) return;
    final next = _applyMove(_board, tileIdx);
    if (next == null) return;
    final now = _nowMs();
    if (!_firstMoveDone) {
      _firstMoveTime = now - _tierStartTime;
      _firstMoveDone = true;
    }
    var newReversals = _reversals;
    if (_lastBoard.isNotEmpty && _lastMoveTime > 0) {
      if (_listEq(next, _lastBoard) && (now - _lastMoveTime) <= 3000) newReversals += 1;
    }
    final newMoveCount = _moveCount + 1;
    final newLog = [..._manhattanLog];
    if (newMoveCount % 5 == 0) newLog.add(_manhattan(next));
    setState(() {
      _lastBoard = _board;
      _lastMoveTime = now;
      _board = next;
      _moveCount = newMoveCount;
      _reversals = newReversals;
      _manhattanLog = newLog;
    });
    if (_isSolved(next)) _handleSolved(newMoveCount, newReversals, newLog, _hintsUsed);
  }

  void _handleHint() {
    final cfg = _config;
    if (_moveCount >= cfg.solution.length) return;
    final next = _applyDirection(_board, cfg.solution[_moveCount]);
    if (next == null) return;
    final newHints = _hintsUsed + 1;
    final newMoveCount = _moveCount + 1;
    final newLog = [..._manhattanLog];
    if (newMoveCount % 5 == 0) newLog.add(_manhattan(next));
    setState(() {
      _board = next;
      _moveCount = newMoveCount;
      _hintsUsed = newHints;
      _manhattanLog = newLog;
    });
    if (_isSolved(next)) _handleSolved(newMoveCount, _reversals, newLog, newHints);
  }

  void _handleSolved(int moves, int revs, List<int> log, int hints) {
    final cfg = _config;
    final finalLog = [...log];
    if (finalLog.isEmpty || finalLog.last != 0) finalLog.add(0);
    _telemetry.add(_TileTelemetry(
      tier: cfg.tier,
      totalMoves: moves,
      ratio: moves / cfg.optimal,
      timeToFirstMove: _firstMoveTime ?? 0,
      reversals: revs,
      hintsUsed: hints,
      solved: true,
      quitTime: null,
      manhattanLog: finalLog,
    ));
    setState(() => _tierComplete = true);

    if (_isWarmup) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _startTier(1);
      });
      return;
    }
    final nextTierIdx = _tierIdx + 1;
    if (moves <= cfg.optimal * 2.0 && nextTierIdx < _tileConfigs.length) {
      setState(() => _phase = _TilePhase.tierComplete);
    } else {
      _finalize();
    }
  }

  void _handleQuit() {
    final cfg = _config;
    final finalLog = [..._manhattanLog];
    final currentDist = _manhattan(_board);
    if (finalLog.isEmpty || finalLog.last != currentDist) finalLog.add(currentDist);
    _telemetry.add(_TileTelemetry(
      tier: cfg.tier,
      totalMoves: _moveCount,
      ratio: _moveCount / cfg.optimal,
      timeToFirstMove: _firstMoveTime ?? 0,
      reversals: _reversals,
      hintsUsed: _hintsUsed,
      solved: false,
      quitTime: _nowMs() - _tierStartTime,
      manhattanLog: finalLog,
    ));
    _finalize();
  }

  void _finalize() {
    final result = _buildProfile();
    setState(() => _phase = _TilePhase.done);
    widget.onComplete(result);
  }

  PersistenceResult _buildProfile() {
    final measured = _telemetry.where((t) => t.tier >= 2).toList();
    final highestTier =
        _telemetry.map((t) => t.tier).fold<int>(0, (a, b) => a > b ? a : b);
    final counselorFlags = <String>[];
    final primary = measured.isNotEmpty ? measured.first : null;

    String profileLabel;
    if (primary == null) {
      profileLabel = 'low-frustration-early-quit';
    } else if (primary.solved && primary.hintsUsed > 0) {
      profileLabel = 'pragmatic-help-seeking';
    } else if (primary.solved && primary.hintsUsed == 0 && primary.ratio <= 2.0) {
      profileLabel = 'strategic-high-persistence';
    } else if (primary.solved && primary.hintsUsed == 0 && primary.ratio > 2.0) {
      profileLabel = 'high-persistence-low-efficiency';
    } else if (!primary.solved && primary.quitTime != null && primary.quitTime! < 30000) {
      profileLabel = 'low-frustration-early-quit';
    } else if (!primary.solved && primary.quitTime != null && primary.quitTime! >= 180000) {
      profileLabel = 'genuine-effort-late-quit';
    } else {
      profileLabel = 'mid-quit';
    }

    const effortRatingMap = <String, String>{
      'strategic-high-persistence': 'You tend to stick with hard problems longer than most students.',
      'high-persistence-low-efficiency': 'You tend to stick with hard problems longer than most students.',
      'pragmatic-help-seeking': 'You persist well but use external support when stuck — which is healthy.',
      'low-frustration-early-quit': 'You move on quickly when a problem feels unsolvable — which has both strengths and costs depending on the career.',
      'mid-quit': 'You engage with familiar problems confidently but step back from unfamiliar ones.',
      'genuine-effort-late-quit': 'You tend to stick with hard problems longer than most students.',
    };
    final effortRating = effortRatingMap[profileLabel]!;

    final avgFirstMove = measured.isEmpty
        ? 0.0
        : measured.fold<int>(0, (s, t) => s + t.timeToFirstMove) / measured.length;
    final totalReversals = measured.fold<int>(0, (s, t) => s + t.reversals);

    var manhattanPattern = 'oscillating';
    if (primary != null && primary.manhattanLog.length >= 2) {
      final log = primary.manhattanLog;
      final diffs = <int>[];
      for (var i = 1; i < log.length; i++) {
        diffs.add(log[i] - log[i - 1]);
      }
      final nInc = diffs.where((d) => d > 0).length;
      final nDec = diffs.where((d) => d < 0).length;
      if (nDec > nInc * 1.5) {
        manhattanPattern = 'decreasing';
      } else if (nInc > nDec * 1.5) {
        manhattanPattern = 'increasing';
      }
      var consecutiveInc = 0;
      for (final d in diffs) {
        if (d > 0) {
          consecutiveInc++;
          if (consecutiveInc >= 3) {
            counselorFlags.add('Manhattan distance increased 3+ consecutive readings — student was lost, not just slow.');
            break;
          }
        } else {
          consecutiveInc = 0;
        }
      }
    }

    String approachStyle;
    if (totalReversals >= 3 && manhattanPattern == 'decreasing') {
      approachStyle = 'Systematic — you gather information before acting.';
    } else if (totalReversals >= 3 && manhattanPattern != 'decreasing') {
      approachStyle = 'Cautious — you prefer to understand the full picture before committing to any move.';
    } else if (avgFirstMove > 4000 && manhattanPattern == 'decreasing') {
      approachStyle = 'Systematic — you gather information before acting.';
    } else if (avgFirstMove > 4000 && manhattanPattern != 'decreasing') {
      approachStyle = 'Cautious — you prefer to understand the full picture before committing to any move.';
    } else {
      approachStyle = 'Intuitive — you act first and adjust from feedback.';
    }

    if (profileLabel == 'low-frustration-early-quit') {
      counselorFlags.add('Early quit on Tier 2 within 30 seconds — low frustration tolerance flag. Review before recommending NEET/JEE/UPSC.');
    }
    if (profileLabel == 'genuine-effort-late-quit') {
      counselorFlags.add('Late quit on Tier 2 after genuine effort (3+ minutes) — high persistence even without success.');
    }
    if (profileLabel == 'high-persistence-low-efficiency') {
      counselorFlags.add('Solved but move ratio > 2× optimal — high effort, poor strategy. Student works hard but needs guidance on method.');
    }
    if (highestTier >= 4) {
      counselorFlags.add('Reached Tier 4 — strong persistence signal regardless of outcome.');
    }

    return PersistenceResult(
      highestTier: highestTier,
      effortRating: effortRating,
      approachStyle: approachStyle,
      counselorFlags: counselorFlags,
    );
  }

  // ---------------------------------------------------------------- render
  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _TilePhase.intro:
        return _intro();
      case _TilePhase.tierComplete:
        return _tierCompleteView();
      case _TilePhase.warmup:
      case _TilePhase.playing:
        return _boardView();
      case _TilePhase.done:
        return const SizedBox.shrink();
    }
  }

  Widget _intro() {
    final g = Theme.of(context).guidanzia;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: g.cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.extension_rounded, color: g.cyan, size: 34),
          ),
          const SizedBox(height: 20),
          const Text('Mind game — this one is a bit different.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.25)),
          const SizedBox(height: 12),
          Text('No time limit. No streak. Just a puzzle.\nSee how far you get.',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 15.5, height: 1.5)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: g.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: g.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How it works',
                    style: TextStyle(fontWeight: FontWeight.w800, color: g.onSurface)),
                const SizedBox(height: 6),
                Text(
                  'Slide the numbered tiles into order (1–8). Tap a tile next to the '
                  'empty space to move it. A hint button is available if you get stuck.',
                  style: TextStyle(color: g.onSurfaceVariant, fontSize: 13.5, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _ghostButton('Skip this game', widget.onSkip)),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(label: 'Start Puzzle', onPressed: () => _startTier(0)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tierCompleteView() {
    final g = Theme.of(context).guidanzia;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: g.gold, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, color: g.goldInk, size: 34),
          ),
          const SizedBox(height: 18),
          const Text('Nice — you unlocked the next level.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('This one is harder. Same rules — no time limit, no pressure.',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.onSurfaceVariant, height: 1.45)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _ghostButton("I'm done", _finalize)),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                    label: 'Try the next level', onPressed: () => _startTier(_tierIdx + 1)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boardView() {
    final g = Theme.of(context).guidanzia;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(_isWarmup ? 'Practice Round' : 'Puzzle — Level ${_config.tier - 1}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              if (_isWarmup) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: g.lime.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('PRACTICE',
                      style: TextStyle(
                          color: g.limeInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
              _isWarmup
                  ? "Won't count — just a practice round to get familiar with the controls."
                  : 'Arrange the tiles in ascending order.',
              style: TextStyle(color: g.onSurfaceVariant, fontSize: 14, height: 1.35)),
          const SizedBox(height: 16),
          const RulesCard(
            bullets: [
              'Slide the numbered tiles into order, 1–8.',
              'Tap a tile next to the empty space to move it.',
              'Stuck? Use the Hint button — it plays the next best move.',
              'No timer, no streak. How you approach it is what matters.',
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: List.generate(9, (idx) {
              final val = _board.length > idx ? _board[idx] : 0;
              final empty = val == 0;
              return GestureDetector(
                onTap: empty || _tierComplete ? null : () => _handleTileClick(idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: empty ? g.surfaceMuted : g.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: empty
                          ? g.outline
                          : (_tierComplete ? g.lime : g.gold),
                      width: empty ? 1 : 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: empty
                      ? const SizedBox.shrink()
                      : Text('$val',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: g.onSurface)),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('MOVES',
                  style: TextStyle(
                      color: g.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
              const SizedBox(width: 8),
              Text('$_moveCount',
                  style: TextStyle(
                      color: g.onSurface, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          if (!_tierComplete)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _moveCount >= _config.solution.length ? null : _handleHint,
                    icon: Icon(Icons.lightbulb_outline, size: 18, color: g.gold),
                    label: Text('Hint ($_hintsUsed used)',
                        style: TextStyle(color: g.gold, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      side: BorderSide(color: g.gold.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                if (!_isWarmup) ...[
                  const SizedBox(width: 12),
                  Expanded(child: _ghostButton("I'm done with this", _handleQuit)),
                ],
              ],
            ),
          if (_tierComplete && !_isWarmup)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: g.lime.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text('Solved in $_moveCount moves ✓',
                  style: TextStyle(color: g.limeInk, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
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
