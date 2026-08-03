import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/guidanzia_colors.dart';
import '../widgets/primary_button.dart';
import 'rules_card.dart';

/// Game 5, Task 2 — Constraint Grid, ported 1:1 from the web `ConstraintGrid`.
/// A 4×4 colour+letter Latin square with prefilled cells. It measures how a
/// student handles ambiguity — do they scan before acting, find the most
/// constrained cell, reach for a hint immediately, or freeze (30s no attempt) —
/// not whether they solve it. No visible timer (the 30s shutdown check is
/// internal). Scoring strings are verbatim so the backend keys off them.

class ConstraintGridResult {
  const ConstraintGridResult({
    required this.solved,
    required this.approachLabel,
    required this.counselorFlag,
  });
  final bool solved;
  final String approachLabel;
  final String? counselorFlag;
}

const _cgColors = ['🔴', '🟡', '🔵', '🟢'];
const _cgSymbols = ['A', 'B', 'C', 'D'];
// Solution (4×4 row-major); value v encodes (colour, letter): colour = ceil(v/4).
const _cgSolution = [1, 6, 11, 16, 7, 4, 13, 10, 12, 15, 2, 5, 14, 9, 8, 3];
const _cgPrefilled = {1, 2, 3, 4, 6, 8, 9, 11, 13, 15};

String _cgColor(int v) => _cgColors[((v + 3) ~/ 4) - 1];
String _cgSymbol(int v) => _cgSymbols[(v - 1) % 4];

List<int?> _makeCGGrid() =>
    [for (var i = 0; i < _cgSolution.length; i++) _cgPrefilled.contains(i) ? _cgSolution[i] : null];

/// The most-constrained empty cell (fewest valid options) — a "systematic"
/// solver tends to touch this first.
int _getMostConstrainedEmptyCell() {
  final emptyCells = [for (var i = 0; i < _cgSolution.length; i++) if (!_cgPrefilled.contains(i)) i];
  var minOptions = 1 << 30;
  var bestCell = emptyCells.first;
  for (final idx in emptyCells) {
    final row = idx ~/ 4, col = idx % 4;
    final usedInRow = <int>{};
    final usedInCol = <int>{};
    for (var c = 0; c < 4; c++) {
      if (_cgPrefilled.contains(row * 4 + c)) usedInRow.add(_cgSolution[row * 4 + c]);
    }
    for (var r = 0; r < 4; r++) {
      if (_cgPrefilled.contains(r * 4 + col)) usedInCol.add(_cgSolution[r * 4 + col]);
    }
    var options = 0;
    for (var v = 1; v <= 16; v++) {
      if (!usedInRow.contains(v) && !usedInCol.contains(v)) options++;
    }
    if (options < minOptions) {
      minOptions = options;
      bestCell = idx;
    }
  }
  return bestCell;
}

final _cgEasyEntry = _getMostConstrainedEmptyCell();

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

class ConstraintGridGame extends StatefulWidget {
  const ConstraintGridGame({super.key, required this.onComplete, required this.onSkip});
  final ValueChanged<ConstraintGridResult> onComplete;
  final VoidCallback onSkip;

  @override
  State<ConstraintGridGame> createState() => _ConstraintGridGameState();
}

class _ConstraintGridGameState extends State<ConstraintGridGame> {
  bool _started = false;
  final List<int?> _grid = _makeCGGrid();
  int? _selected;
  int _mistakes = 0;
  int _mistakesUndone = 0;
  bool _hintUsed = false;
  int? _firstInteractionTime;
  int? _firstCellTouched;
  bool _shutdownFlag = false;
  int _cgStart = 0;
  Timer? _cgTimer;

  @override
  void dispose() {
    _cgTimer?.cancel();
    super.dispose();
  }

  void _handleStart() {
    setState(() {
      _started = true;
      _cgStart = _nowMs();
    });
    _cgTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _firstInteractionTime == null) setState(() => _shutdownFlag = true);
    });
  }

  void _handleCellClick(int idx) {
    if (_cgPrefilled.contains(idx)) return;
    if (_firstInteractionTime == null) {
      _firstInteractionTime = _nowMs() - _cgStart;
      _cgTimer?.cancel();
    }
    _firstCellTouched ??= idx;
    setState(() => _selected = idx == _selected ? null : idx);
  }

  void _handleValueSelect(int v) {
    if (_selected == null) return;
    final sel = _selected!;
    final prev = _grid[sel];
    if (prev != null && prev != _cgSolution[sel]) _mistakesUndone++;
    if (v != _cgSolution[sel]) _mistakes++;
    setState(() {
      _grid[sel] = v;
      _selected = null;
    });
    if (_complete()) _finalize(false);
  }

  void _handleHint() {
    if (_selected == null) return;
    final sel = _selected!;
    setState(() {
      _hintUsed = true;
      _grid[sel] = _cgSolution[sel];
      _selected = null;
    });
    if (_complete()) _finalize(false);
  }

  bool _complete() {
    for (var i = 0; i < _cgSolution.length; i++) {
      if (_grid[i] != _cgSolution[i]) return false;
    }
    return true;
  }

  void _finalize(bool shutdown) {
    _cgTimer?.cancel();
    final scanTime = _firstInteractionTime ?? (_nowMs() - _cgStart);
    final solved = _complete();
    final foundEasy = _firstCellTouched == _cgEasyEntry;
    var approachLabel = 'intuitive-adaptive';
    String? counselorFlag;

    if (shutdown || _firstInteractionTime == null) {
      approachLabel = 'complexity-shutdown';
      counselorFlag =
          'Student looked at constraint grid 30s+ without attempting — anxiety of not knowing where to start. High-priority counselor flag before committing to any ambiguous-problem path.';
    } else if (scanTime < 2000 && _hintUsed) {
      approachLabel = 'low-ambiguity-tolerance';
      counselorFlag =
          'Immediate hint use (scan < 2s) — low tolerance for ambiguity. Better suited to clearly defined roles with step-by-step processes.';
    } else if (scanTime > 5000 && foundEasy) {
      approachLabel = 'systematic-analytical';
    } else if (scanTime > 5000 && !foundEasy) {
      approachLabel = 'cautious';
    } else if (_mistakes > 0 && _mistakesUndone >= (_mistakes * 0.5).ceil()) {
      approachLabel = 'intuitive-adaptive';
    }

    widget.onComplete(ConstraintGridResult(
        solved: solved, approachLabel: approachLabel, counselorFlag: counselorFlag));
  }

  // ---------------------------------------------------------------- render
  @override
  Widget build(BuildContext context) => _started ? _boardView() : _intro();

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
              color: g.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.grid_view_rounded, color: g.gold, size: 34),
          ),
          const SizedBox(height: 20),
          const Text('Constraint Grid',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(
            'A 4×4 grid of coloured symbols. Each row and each column must contain '
            'each colour and each letter exactly once. Some cells are already filled '
            '— find what completes it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: g.onSurfaceVariant, fontSize: 15, height: 1.5),
          ),
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
                Text('Tap an empty cell, then choose the colour + letter that fits. '
                    'A hint is available if you get stuck.',
                    style: TextStyle(color: g.onSurfaceVariant, fontSize: 13.5, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _ghostButton('Skip', widget.onSkip)),
              const SizedBox(width: 12),
              Expanded(child: PrimaryButton(label: 'Start Puzzle', onPressed: _handleStart)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boardView() {
    final g = Theme.of(context).guidanzia;
    final emptyCount = _cgSolution.length - _cgPrefilled.length;
    final filled = [
      for (var i = 0; i < _grid.length; i++)
        if (!_cgPrefilled.contains(i) && _grid[i] != null) i
    ].length;
    final progress = ((filled / emptyCount) * 100).round();

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
                    const Text('Constraint Grid',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Each row and column: each colour and letter exactly once',
                        style: TextStyle(color: g.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$progress%',
                      style: TextStyle(
                          color: g.gold, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('filled', style: TextStyle(color: g.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const RulesCard(
            bullets: [
              'Fill every empty cell with a colour + a letter.',
              'Each colour appears exactly once in every row and column.',
              'Each letter appears exactly once in every row and column.',
              'Tap an empty cell, then pick the colour and letter that fit.',
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: List.generate(16, (idx) => _cell(g, idx)),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: g.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: g.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select colour + letter',
                      style: TextStyle(
                          color: g.gold, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: List.generate(16, (i) {
                      final v = i + 1;
                      return GestureDetector(
                        onTap: () => _handleValueSelect(v),
                        child: Container(
                          decoration: BoxDecoration(
                            color: g.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: g.outline),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_cgColor(v), style: const TextStyle(fontSize: 15)),
                              Text(_cgSymbol(v),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: g.onSurface)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_selected == null || _hintUsed) ? null : _handleHint,
                  icon: Icon(Icons.lightbulb_outline, size: 18, color: g.gold),
                  label: Text(_hintUsed ? 'Hint used' : 'Hint',
                      style: TextStyle(color: g.gold, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    side: BorderSide(color: g.gold.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _ghostButton("I'm done", () => _finalize(_shutdownFlag))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(GuidanziaColors g, int idx) {
    final val = _grid[idx];
    final prefilled = _cgPrefilled.contains(idx);
    final selected = _selected == idx;
    final wrong = val != null && !prefilled && val != _cgSolution[idx];
    return GestureDetector(
      onTap: prefilled ? null : () => _handleCellClick(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: prefilled ? g.surfaceMuted : (selected ? g.gold.withValues(alpha: 0.12) : g.surfaceElevated),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? g.gold
                : wrong
                    ? g.danger
                    : g.outline,
            width: selected || wrong ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: val != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_cgColor(val), style: const TextStyle(fontSize: 17)),
                  Text(_cgSymbol(val),
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: g.onSurface)),
                ],
              )
            : Text('?', style: TextStyle(fontSize: 18, color: g.onSurfaceVariant)),
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
