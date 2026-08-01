import { useState, useEffect, useRef, useMemo } from "react";
import { motion } from "motion/react";
import { Button } from "./ui/button";
import { TranslatedText } from "./TranslatedText";
import { CheckCircle2, X, Lightbulb } from "lucide-react";

// ─── Game 5 — Sliding Tile (Persistence) ────────────────────────────────────

export type TileTelemetry = {
  tier: number;
  totalMoves: number;
  optimalMoves: number;
  ratio: number;
  timeToFirstMove: number;   // ms
  reversals: number;         // moves reversed within 3s
  hintsUsed: number;
  solved: boolean;
  quitTime: number | null;   // ms since tier start, null if solved
  manhattanLog: number[];    // distance logged every 5 moves
  configIndex: number;       // which config from the bank was used
};

export type PersistenceResult = {
  highestTier: number;
  tierTelemetry: TileTelemetry[];
  effortRating: string;
  approachStyle: string;
  counselorFlags: string[];
};

type TileConfig = {
  state: number[];           // 9 numbers, 0 = empty
  optimal: number;
  tier: number;
  solution: string[];        // optimal move directions (never shown)
};

// Fixed configuration bank — all verified solvable, optimal counts hardcoded
const TILE_CONFIGS: TileConfig[] = [
  {
    tier: 1,
    state: [1, 3, 8, 4, 6, 2, 0, 7, 5],
    optimal: 12,
    solution: ['right','up','right','up','left','down','down','right','up','left','down','right'],
  },
  {
    tier: 2,
    state: [5, 4, 1, 3, 0, 8, 7, 6, 2],
    optimal: 16,
    solution: ['right','down','left','up','left','up','right','right','down','left','left','up','right','right','down','down'],
  },
  {
    tier: 3,
    state: [2, 3, 4, 8, 0, 5, 1, 6, 7],
    optimal: 22,
    solution: ['left','down','right','right','up','up','left','left','down','right','down','left','up','right','right','down','left','left','up','right','right','down'],
  },
  {
    tier: 4,
    state: [3, 8, 1, 7, 0, 4, 2, 6, 5],
    optimal: 24,
    solution: ['up','left','down','right','right','up','left','down','right','down','left','left','up','up','right','down','down','left','up','up','right','down','right','down'],
  },
];

const GOAL_STATE = [1, 2, 3, 4, 5, 6, 7, 8, 0];

function manhattan(state: number[]): number {
  let total = 0;
  for (let i = 0; i < state.length; i++) {
    const val = state[i];
    if (val === 0) continue;
    const goalIdx = val - 1;
    total += Math.abs(Math.floor(i / 3) - Math.floor(goalIdx / 3)) + Math.abs((i % 3) - (goalIdx % 3));
  }
  return total;
}

function isSolved(state: number[]): boolean {
  return state.every((v, i) => v === GOAL_STATE[i]);
}

// Returns index of empty tile
function emptyIdx(state: number[]): number {
  return state.indexOf(0);
}

// Returns new state after sliding tile at `tileIdx` into empty space, or null if invalid
function applyMove(state: number[], tileIdx: number): number[] | null {
  const empty = emptyIdx(state);
  const er = Math.floor(empty / 3), ec = empty % 3;
  const tr = Math.floor(tileIdx / 3), tc = tileIdx % 3;
  const adjacent = (Math.abs(er - tr) + Math.abs(ec - tc)) === 1;
  if (!adjacent) return null;
  const next = [...state];
  next[empty] = next[tileIdx];
  next[tileIdx] = 0;
  return next;
}

// Convert direction string to a state transition
function applyDirection(state: number[], dir: string): number[] | null {
  const empty = emptyIdx(state);
  const er = Math.floor(empty / 3), ec = empty % 3;
  const moves: Record<string, [number, number]> = {
    up:    [er + 1, ec],
    down:  [er - 1, ec],
    left:  [er, ec + 1],
    right: [er, ec - 1],
  };
  const [nr, nc] = moves[dir] ?? [-1, -1];
  if (nr < 0 || nr > 2 || nc < 0 || nc > 2) return null;
  return applyMove(state, nr * 3 + nc);
}

interface SlidingTileProps {
  onComplete: (result: PersistenceResult) => void;
  onSkip: () => void;
}

export function SlidingTile({ onComplete, onSkip }: SlidingTileProps) {
  const [phase, setPhase] = useState<'intro' | 'warmup' | 'playing' | 'tier-complete' | 'done'>('intro');
  const [currentTierIdx, setCurrentTierIdx] = useState(0); // 0=warmup(T1), 1=T2, 2=T3, 3=T4
  const [board, setBoard] = useState<number[]>([]);
  const [moveCount, setMoveCount] = useState(0);
  const [hintsUsed, setHintsUsed] = useState(0);
  const [reversals, setReversals] = useState(0);
  const [manhattanLog, setManhattanLog] = useState<number[]>([]);
  const [tierTelemetry, setTierTelemetry] = useState<TileTelemetry[]>([]);
  const [lastMoveTime, setLastMoveTime] = useState<number>(0);
  const [lastBoard, setLastBoard] = useState<number[]>([]);
  const [tierStartTime, setTierStartTime] = useState<number>(0);
  const [firstMoveTime, setFirstMoveTime] = useState<number | null>(null);
  const [tierComplete, setTierComplete] = useState(false);
  const firstMoveDone = useRef(false);

  const config = TILE_CONFIGS[currentTierIdx];
  const isWarmup = currentTierIdx === 0;

  // Start a tier
  const startTier = (tierIdx: number) => {
    const cfg = TILE_CONFIGS[tierIdx];
    setBoard([...cfg.state]);
    setMoveCount(0);
    setHintsUsed(0);
    setReversals(0);
    setManhattanLog([manhattan(cfg.state)]);
    setLastMoveTime(0);
    setLastBoard([]);
    setTierStartTime(Date.now());
    setFirstMoveTime(null);
    firstMoveDone.current = false;
    setTierComplete(false);
    setCurrentTierIdx(tierIdx);
    setPhase(tierIdx === 0 ? 'warmup' : 'playing');
  };

  const handleTileClick = (tileIdx: number) => {
    if (tierComplete) return;
    const next = applyMove(board, tileIdx);
    if (!next) return;

    const now = Date.now();

    // Time to first move
    if (!firstMoveDone.current) {
      setFirstMoveTime(now - tierStartTime);
      firstMoveDone.current = true;
    }

    // Reversal detection — did this move undo the previous move?
    let newReversals = reversals;
    if (lastBoard.length > 0 && lastMoveTime > 0) {
      const timeSinceLast = now - lastMoveTime;
      const isReversal = next.every((v, i) => v === lastBoard[i]);
      if (isReversal && timeSinceLast <= 3000) newReversals += 1;
    }

    const newMoveCount = moveCount + 1;

    // Manhattan log every 5 moves
    const newLog = [...manhattanLog];
    if (newMoveCount % 5 === 0) newLog.push(manhattan(next));

    setLastBoard(board);
    setLastMoveTime(now);
    setBoard(next);
    setMoveCount(newMoveCount);
    setReversals(newReversals);
    setManhattanLog(newLog);

    if (isSolved(next)) handleSolved(newMoveCount, newReversals, newLog, hintsUsed, now);
  };

  const handleHint = () => {
    // Reveal next optimal move direction as a highlight
    const cfg = TILE_CONFIGS[currentTierIdx];
    const nextDir = cfg.solution[moveCount];
    if (!nextDir) return;
    const next = applyDirection(board, nextDir);
    if (!next) return;
    const newHints = hintsUsed + 1;
    const newMoveCount = moveCount + 1;
    const newLog = [...manhattanLog];
    if (newMoveCount % 5 === 0) newLog.push(manhattan(next));
    setBoard(next);
    setMoveCount(newMoveCount);
    setHintsUsed(newHints);
    setManhattanLog(newLog);
    if (isSolved(next)) handleSolved(newMoveCount, reversals, newLog, newHints, Date.now());
  };

  const handleSolved = (
    moves: number, revs: number, log: number[], hints: number, solveTime: number
  ) => {
    const cfg = TILE_CONFIGS[currentTierIdx];
    // Always append final distance (0 when solved) so log has ≥2 points
    const finalLog = [...log];
    if (finalLog[finalLog.length - 1] !== 0) finalLog.push(0);
    const telemetry: TileTelemetry = {
      tier: cfg.tier,
      totalMoves: moves,
      optimalMoves: cfg.optimal,
      ratio: moves / cfg.optimal,
      timeToFirstMove: firstMoveTime ?? 0,
      reversals: revs,
      hintsUsed: hints,
      solved: true,
      quitTime: null,
      manhattanLog: finalLog,
      configIndex: currentTierIdx,
    };
    const newTelemetry = [...tierTelemetry, telemetry];
    setTierTelemetry(newTelemetry);
    setTierComplete(true);

    if (isWarmup) {
      // Warmup done — move to Tier 2 automatically after brief pause
      setTimeout(() => startTier(1), 1200);
      return;
    }

    // Check tier promotion
    const threshold = cfg.optimal * 2.0;
    const nextTierIdx = currentTierIdx + 1;
    if (moves <= threshold && nextTierIdx < TILE_CONFIGS.length) {
      setPhase('tier-complete');
    } else {
      finalize(newTelemetry);
    }
  };

  const handleQuit = () => {
    const cfg = TILE_CONFIGS[currentTierIdx];
    const now = Date.now();
    // Always append current distance at quit time
    const finalLog = [...manhattanLog];
    const currentDist = manhattan(board);
    if (finalLog[finalLog.length - 1] !== currentDist) finalLog.push(currentDist);
    const telemetry: TileTelemetry = {
      tier: cfg.tier,
      totalMoves: moveCount,
      optimalMoves: cfg.optimal,
      ratio: moveCount / cfg.optimal,
      timeToFirstMove: firstMoveTime ?? 0,
      reversals,
      hintsUsed,
      solved: false,
      quitTime: now - tierStartTime,
      manhattanLog: finalLog,
      configIndex: currentTierIdx,
    };
    finalize([...tierTelemetry, telemetry]);
  };

  const finalize = (allTelemetry: TileTelemetry[]) => {
    const result = buildProfile(allTelemetry);
    setPhase('done');
    onComplete(result);
  };

  const buildProfile = (allTelemetry: TileTelemetry[]): PersistenceResult => {
    const measured = allTelemetry.filter(t => t.tier >= 2);
    const highestTier = Math.max(...allTelemetry.map(t => t.tier));
    const counselorFlags: string[] = [];
    const primary = measured[0];

    // ── Step 1: Determine profile label ──
    type ProfileLabel =
      | 'strategic-high-persistence'
      | 'high-persistence-low-efficiency'
      | 'pragmatic-help-seeking'
      | 'low-frustration-early-quit'
      | 'mid-quit'
      | 'genuine-effort-late-quit';

    let profileLabel: ProfileLabel;

    if (!primary) {
      profileLabel = 'low-frustration-early-quit';
    } else if (primary.solved && primary.hintsUsed > 0) {
      profileLabel = 'pragmatic-help-seeking';
    } else if (primary.solved && primary.hintsUsed === 0 && primary.ratio <= 2.0) {
      profileLabel = 'strategic-high-persistence';
    } else if (primary.solved && primary.hintsUsed === 0 && primary.ratio > 2.0) {
      profileLabel = 'high-persistence-low-efficiency';
    } else if (!primary.solved && primary.quitTime !== null && primary.quitTime < 30000) {
      profileLabel = 'low-frustration-early-quit';
    } else if (!primary.solved && primary.quitTime !== null && primary.quitTime >= 180000) {
      profileLabel = 'genuine-effort-late-quit';
    } else {
      profileLabel = 'mid-quit';
    }

    // ── Step 2: Derive effortRating from profileLabel ──
    const effortRatingMap: Record<ProfileLabel, string> = {
      'strategic-high-persistence':     'You tend to stick with hard problems longer than most students.',
      'high-persistence-low-efficiency': 'You tend to stick with hard problems longer than most students.',
      'pragmatic-help-seeking':          'You persist well but use external support when stuck — which is healthy.',
      'low-frustration-early-quit':      'You move on quickly when a problem feels unsolvable — which has both strengths and costs depending on the career.',
      'mid-quit':                        'You engage with familiar problems confidently but step back from unfamiliar ones.',
      'genuine-effort-late-quit':        'You tend to stick with hard problems longer than most students.',
    };
    const effortRating = effortRatingMap[profileLabel];

    // ── Step 3: Determine approachStyle using reversals + manhattan pattern ──
    const avgFirstMove = measured.reduce((s, t) => s + t.timeToFirstMove, 0) / (measured.length || 1);
    const totalReversals = measured.reduce((s, t) => s + t.reversals, 0);

    let manhattanPattern: 'decreasing' | 'oscillating' | 'increasing' = 'oscillating';
    if (primary && primary.manhattanLog.length >= 2) {
      const log = primary.manhattanLog;
      const diffs = log.slice(1).map((v, i) => v - log[i]);
      const nInc = diffs.filter(d => d > 0).length;
      const nDec = diffs.filter(d => d < 0).length;
      if (nDec > nInc * 1.5) manhattanPattern = 'decreasing';
      else if (nInc > nDec * 1.5) manhattanPattern = 'increasing';
      let consecutiveInc = 0;
      for (const d of diffs) {
        if (d > 0) {
          consecutiveInc++;
          if (consecutiveInc >= 3) {
            counselorFlags.push('Manhattan distance increased 3+ consecutive readings — student was lost, not just slow.');
            break;
          }
        } else consecutiveInc = 0;
      }
    }

    let approachStyle: string;
    // Reversals ≥3 + decreasing = thinking ahead and correcting → Systematic
    if (totalReversals >= 3 && manhattanPattern === 'decreasing') {
      approachStyle = 'Systematic — you gather information before acting.';
    } else if (totalReversals >= 3 && manhattanPattern !== 'decreasing') {
      // High reversals but not making progress = Cautious/confused
      approachStyle = 'Cautious — you prefer to understand the full picture before committing to any move.';
    } else if (avgFirstMove > 4000 && manhattanPattern === 'decreasing') {
      approachStyle = 'Systematic — you gather information before acting.';
    } else if (avgFirstMove > 4000 && manhattanPattern !== 'decreasing') {
      approachStyle = 'Cautious — you prefer to understand the full picture before committing to any move.';
    } else {
      approachStyle = 'Intuitive — you act first and adjust from feedback.';
    }

    // ── Step 4: Counselor flags ──
    if (profileLabel === 'low-frustration-early-quit') {
      counselorFlags.push('Early quit on Tier 2 within 30 seconds — low frustration tolerance flag. Review before recommending NEET/JEE/UPSC.');
    }
    if (profileLabel === 'genuine-effort-late-quit') {
      counselorFlags.push('Late quit on Tier 2 after genuine effort (3+ minutes) — high persistence even without success.');
    }
    if (profileLabel === 'high-persistence-low-efficiency') {
      counselorFlags.push('Solved but move ratio > 2× optimal — high effort, poor strategy. Student works hard but needs guidance on method.');
    }
    if (highestTier >= 4) {
      counselorFlags.push('Reached Tier 4 — strong persistence signal regardless of outcome.');
    }

    return { highestTier, tierTelemetry: allTelemetry, effortRating, approachStyle, counselorFlags };
  };

  // ── Render ──
  if (phase === 'intro') {
    return (
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}
        className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8 text-center"
      >
        <div className="w-16 h-16 bg-gradient-to-br from-teal-500 to-cyan-600 rounded-2xl flex items-center justify-center mx-auto mb-6">
          <span className="text-3xl">🧩</span>
        </div>
        <h2 className="text-2xl font-bold text-gray-900 mb-4">One last game — this one is a bit different.</h2>
        <p className="text-lg text-gray-600 mb-6 leading-relaxed">
          No time limit. No streak. Just a puzzle.<br />
          <span className="text-gray-500 text-base">See how far you get.</span>
        </p>
        <div className="bg-teal-50 border border-teal-200 rounded-xl p-4 mb-8 text-left">
          <p className="text-sm text-teal-800 font-medium mb-2">How it works:</p>
          <p className="text-sm text-teal-700">Slide the numbered tiles into order (1–8). Tap a tile next to the empty space to move it. A hint button is available if you get stuck.</p>
        </div>
        <div className="flex gap-3">
          <Button onClick={onSkip} variant="outline" className="flex-1 h-12 text-gray-500">Skip this game</Button>
          <Button onClick={() => startTier(0)} className="flex-1 h-12 bg-gradient-to-r from-teal-600 to-cyan-600 hover:from-teal-700 hover:to-cyan-700">
            Start Puzzle
          </Button>
        </div>
      </motion.div>
    );
  }

  if (phase === 'tier-complete') {
    const nextTierIdx = currentTierIdx + 1;
    const cfg = TILE_CONFIGS[nextTierIdx];
    return (
      <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
        className="bg-gradient-to-br from-teal-50 to-cyan-50 rounded-2xl border-2 border-teal-200 shadow-xl p-8 text-center"
      >
        <div className="w-16 h-16 bg-gradient-to-br from-teal-600 to-cyan-600 rounded-full flex items-center justify-center mx-auto mb-4">
          <CheckCircle2 className="w-8 h-8 text-white" />
        </div>
        <h2 className="text-2xl font-bold text-gray-900 mb-2">Nice — you unlocked the next level.</h2>
        <p className="text-gray-600 mb-6">This one is harder. Same rules — no time limit, no pressure.</p>
        <div className="flex gap-3">
          <Button onClick={() => finalize(tierTelemetry)} variant="outline" className="flex-1 h-12">I'm done</Button>
          <Button onClick={() => startTier(nextTierIdx)} className="flex-1 h-12 bg-gradient-to-r from-teal-600 to-cyan-600 hover:from-teal-700 hover:to-cyan-700">
            Try the next level
          </Button>
        </div>
      </motion.div>
    );
  }

  // Warmup or playing
  const distanceNow = manhattan(board);

  return (
    <motion.div key={`tile-${currentTierIdx}`} initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}
      className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
    >
       <div className="mb-4">
        <h3 className="text-xl font-bold text-gray-900">
          {isWarmup ? 'Warmup Round' : `Puzzle — Level ${config.tier - 1}`}
        </h3>
        <p className="text-sm text-gray-500">
          {isWarmup ? 'Get familiar with the controls' : 'Arrange tiles 1–8 in order'}
        </p>
      </div>

      {/* Board */}
      <div className="grid grid-cols-3 gap-2 mb-6 max-w-xs mx-auto">
        {board.map((val, idx) => (
          <button
            key={idx}
            onClick={() => handleTileClick(idx)}
            disabled={val === 0 || tierComplete}
            className={`h-20 rounded-xl text-2xl font-bold transition-all ${
              val === 0
                ? 'bg-gray-100 border-2 border-dashed border-gray-300 cursor-default'
                : tierComplete
                ? 'bg-teal-100 border-2 border-teal-400 text-teal-800 cursor-default'
                : 'bg-white border-2 border-gray-300 text-gray-900 hover:border-teal-400 hover:bg-teal-50 active:scale-95 cursor-pointer'
            }`}
          >
            {val !== 0 ? val : ''}
          </button>
        ))}
      </div>

      {/* Controls */}
      {!tierComplete && (
        <div className="flex gap-3">
          <Button
            onClick={handleHint}
            variant="outline"
            className="flex-1 h-11 border-amber-300 text-amber-700 hover:bg-amber-50"
            disabled={moveCount >= config.solution.length}
          >
            <Lightbulb className="w-4 h-4 mr-2" />
            Hint ({hintsUsed} used)
          </Button>
          {!isWarmup && (
            <Button onClick={handleQuit} variant="outline" className="flex-1 h-11 text-gray-500">
              I'm done with this
            </Button>
          )}
        </div>
      )}

      {tierComplete && !isWarmup && (
        <div className="text-center p-4 bg-teal-50 rounded-xl border border-teal-200">
          <p className="text-teal-800 font-semibold">Solved in {moveCount} moves ✓</p>
        </div>
      )}
    </motion.div>
  );
}

// Type definitions
type NumberSenseQuestion = {
  id: string;
  sessionType: string;
  type: string;
  question: string;
  options: (number | string)[];
  correct: number | string;
  difficulty: number;
  difficultyLabel: string;
  explanation: string;
};

type WordSenseQuestion = {
  id: string;
  sessionType: string;
  type: string;
  question: string;
  options: string[];
  correct: string;
  difficulty: number;
  difficultyLabel: string;
  explanation: string;
};

type ShapeSenseQuestion = {
  type: string;
  question: string;
  options?: number[];
  correct?: number | string;
  difficulty: string;
  questionImage?: string;
  optionImages?: string[];
};

type LogicSenseQuestion = {
  type: string;
  question: string;
  options?: (number | string)[];
  correct?: number | string;
  difficulty: string;
  questionImage?: string;
  optionImages?: string[];
};

type GameQuestion = NumberSenseQuestion | WordSenseQuestion | ShapeSenseQuestion | LogicSenseQuestion;

// Game 1 - Number Sense Questions
const numberSenseQuestions: NumberSenseQuestion[] = [
  {
    "id": "A1",
    "sessionType": "A",
    "type": "sequence",
    "question": "2, 6, 18, 54, ?",
    "options": [108, 180, 162, 216],
    "correct": 162,
    "difficulty": 2,
    "difficultyLabel": "medium",
    "explanation": "Each term is multiplied by 3. 54 × 3 = 162."
  },
  {
    "id": "A2",
    "sessionType": "A",
    "type": "sequence",
    "question": "5, 10, 20, 40, ?",
    "options": [80, 60, 120, 70],
    "correct": 80,
    "difficulty": 2,
    "difficultyLabel": "medium",
    "explanation": "Each term is multiplied by 2. 40 × 2 = 80."
  },
  {
    "id": "A3",
    "sessionType": "A",
    "type": "sequence",
    "question": "96, 48, 24, 12, ?",
    "options": [8, 10, 6, 4],
    "correct": 6,
    "difficulty": 2,
    "difficultyLabel": "medium",
    "explanation": "Each term is divided by 2. 12 ÷ 2 = 6."
  },
  {
    "id": "A4",
    "sessionType": "A",
    "type": "sequence",
    "question": "4, 12, 36, 108, ?",
    "options": [432, 324, 180, 216],
    "correct": 324,
    "difficulty": 3,
    "difficultyLabel": "medium-hard",
    "explanation": "Each term is multiplied by 3. 108 × 3 = 324."
  },
  {
    "id": "B1",
    "sessionType": "B",
    "type": "sequence",
    "question": "1, 4, 9, 16, 25, ?",
    "options": [34, 36, 38, 35],
    "correct": 36,
    "difficulty": 2,
    "difficultyLabel": "medium",
    "explanation": "The gaps are +3, +5, +7, +9. Next gap is +11, so 25 + 11 = 36."
  },
  {
    "id": "B2",
    "sessionType": "B",
    "type": "sequence",
    "question": "3, 7, 13, 21, 31, ?",
    "options": [42, 43, 41, 44],
    "correct": 43,
    "difficulty": 2,
    "difficultyLabel": "medium",
    "explanation": "The gaps are +4, +6, +8, +10. Next gap is +12, so 31 + 12 = 43."
  },
  {
    "id": "B3",
    "sessionType": "B",
    "type": "sequence",
    "question": "50, 48, 44, 38, 30, ?",
    "options": [24, 18, 20, 22],
    "correct": 20,
    "difficulty": 3,
    "difficultyLabel": "medium-hard",
    "explanation": "The gaps are -2, -4, -6, -8. Next gap is -10, so 30 - 10 = 20."
  },
  {
    "id": "B4",
    "sessionType": "B",
    "type": "sequence",
    "question": "2, 7, 14, 23, 34, ?",
    "options": [46, 48, 45, 47],
    "correct": 47,
    "difficulty": 3,
    "difficultyLabel": "medium-hard",
    "explanation": "The gaps are +5, +7, +9, +11. Next gap is +13, so 34 + 13 = 47."
  },
  {
    "id": "C1",
    "sessionType": "C",
    "type": "arithmetic",
    "question": "A shopkeeper buys goods for ₹120 and sells them for ₹150. What is the profit percentage?",
    "options": ["30%", "15%", "25%", "20%"],
    "correct": "25%",
    "difficulty": 2,
    "difficultyLabel": "medium",
    "explanation": "Profit = ₹150 - ₹120 = ₹30. Profit % = (30 ÷ 120) × 100 = 25%."
  },
  {
    "id": "C2",
    "sessionType": "C",
    "type": "arithmetic",
    "question": "Principal ₹5,000 at 8% per year for 3 years. What is the simple interest?",
    "options": ["₹400", "₹6,200", "₹1,200", "₹120"],
    "correct": "₹1,200",
    "difficulty": 2,
    "difficultyLabel": "medium",
    "explanation": "Simple Interest = (5000 × 8 × 3) ÷ 100 = ₹1,200."
  },
  {
    "id": "C3",
    "sessionType": "C",
    "type": "arithmetic",
    "question": "40% of a number is 80. What is the number?",
    "options": [180, 220, 200, 32],
    "correct": 200,
    "difficulty": 3,
    "difficultyLabel": "medium-hard",
    "explanation": "40% of x = 80. Therefore x = 80 ÷ 0.4 = 200."
  },
  {
    "id": "C4",
    "sessionType": "C",
    "type": "arithmetic",
    "question": "₹480 is shared between two people in the ratio 3:5. What is the smaller share?",
    "options": ["₹300", "₹180", "₹240", "₹288"],
    "correct": "₹180",
    "difficulty": 3,
    "difficultyLabel": "medium-hard",
    "explanation": "Total parts = 3 + 5 = 8. Smaller share = (3/8) × 480 = ₹180."
  },
  {
    "id": "D1",
    "sessionType": "D",
    "type": "reasoning",
    "question": "4 people can paint 4 walls in 4 hours. How long for 8 people to paint 8 walls?",
    "options": ["2 hours", "8 hours", "4 hours", "16 hours"],
    "correct": "4 hours",
    "difficulty": 3,
    "difficultyLabel": "medium-hard",
    "explanation": "Both the number of workers and the amount of work double, so the time remains unchanged at 4 hours."
  },
  {
    "id": "D2",
    "sessionType": "D",
    "type": "reasoning",
    "question": "A price increases by 20%, then decreases by 20%. What is the net change?",
    "options": ["4% gain", "2% loss", "0%", "4% loss"],
    "correct": "4% loss",
    "difficulty": 3,
    "difficultyLabel": "medium-hard",
    "explanation": "Assume price = 100. After +20% → 120. After -20% → 96. Net change = 4% loss."
  },
  {
    "id": "D3",
    "sessionType": "D",
    "type": "reasoning",
    "question": "6 workers finish a job in 12 days. How many days for 9 workers?",
    "options": ["18 days", "8 days", "15 days", "9 days"],
    "correct": "8 days",
    "difficulty": 3,
    "difficultyLabel": "medium-hard",
    "explanation": "Workers and days are inversely proportional. Days = (6 × 12) ÷ 9 = 8."
  },
  {
    "id": "D4",
    "sessionType": "D",
    "type": "reasoning",
    "question": "Riya scores 72 in test 1 and 78 in test 2. What must she score in test 3 to average 80 across all three tests?",
    "options": [85, 80, 75, 90],
    "correct": 90,
    "difficulty": 3,
    "difficultyLabel": "medium-hard",
    "explanation": "Required total = 80 × 3 = 240. Current total = 72 + 78 = 150. Needed = 240 - 150 = 90."
  }
];

// Game 2 - Word Sense Questions (dynamically generated, static array removed)
// Game 3 - Shape Sense Questions (spatial reasoning)
const shapeSenseQuestions: ShapeSenseQuestion[] = [
  { 
    type: "rotation", 
    question: "Which of these is the same L-shaped block simply rotated (not flipped)?",
    questionImage: "/images/g3_q1_question.png",
    optionImages: [
      "/images/g3_q1_option_A.png",
      "/images/g3_q1_option_B.png",
      "/images/g3_q1_option_C.png",
      "/images/g3_q1_option_D.png"
    ],
    correct: "Option A",
    difficulty: "easy"
  },
  { 
    type: "cube-counting", 
    question: "A 3×3×3 stack with one column of 3 removed. How many small cubes are here?", 
    options: [21, 23, 24, 27], 
    correct: 24,
    difficulty: "medium"
  },
  { 
    type: "net-folding", 
    question: "Which of these boxes can be folded from this net?",
    questionImage: "/images/g3_q3_question.png",
    optionImages: [
      "/images/g3_q3_option_A.png",
      "/images/g3_q3_option_B.png",
      "/images/g3_q3_option_C.png",
      "/images/g3_q3_option_D.png"
    ],
    correct: "Option A",
    difficulty: "medium"
  },
  { 
    type: "mental-assembly", 
    question: "Which single shape do these two pieces make if joined along the marked edge?",
    questionImage: "/images/g3_q4_question.png",
    optionImages: [
      "/images/g3_q4_option_A.png",
      "/images/g3_q4_option_B.png",
      "/images/g3_q4_option_C.png",
      "/images/g3_q4_option_D.png"
    ],
    correct: "Option B",
    difficulty: "hard"
  },
];

// Game 4 - Logic Sense Questions (abstract reasoning)
const logicSenseQuestions: LogicSenseQuestion[] = [
  { 
    type: "matrix", 
    question: "Three rows of dots: row 1 has 1-2-3, row 2 has 2-3-4, row 3 has 3-4-?", 
    options: [4, 5, 6, 7], 
    correct: 5,
    difficulty: "easy"
  },
  { 
    type: "rule-finding", 
    question: "If ◆◆ = 4, ◆◆◆ = 9, ◆◆◆◆ = 16, then ◆◆◆◆◆ = ?", 
    options: [18, 20, 25, 30], 
    correct: 25,
    difficulty: "medium"
  },
  { 
    type: "pattern-series", 
    question: "A figure rotates 90° clockwise and gains one dot at each step. What comes next?",
    questionImage: "/images/g4_q3_question.png",
    optionImages: [
      "/images/g4_q3_option_A.png",
      "/images/g4_q3_option_B.png",
      "/images/g4_q3_option_C.png",
      "/images/g4_q3_option_D.png"
    ],
    correct: "Option C",
    difficulty: "medium"
  },
  { 
    type: "deduction", 
    question: "All bloops are razzies. All razzies are lazzies. Are all bloops definitely lazzies?", 
    options: ["Yes", "No", "Cannot say"], 
    correct: "Yes",
    difficulty: "hard"
  },
];

interface AptitudeGamesProps {
  gameType: 1 | 2 | 3 | 4; // 1 = Number Sense, 2 = Word Sense, 3 = Shape Sense, 4 = Logic Sense
  difficulty: 1 | 2 | 3 | 4 |5; // 1 = easy, 2 = easy-medium, 3 = medium, 4 = medium-hard, 5 = hard
  round: number; // 0-3 (4 questions per game, no practice)
  onAnswer: (result: {
    questionId: string;
    sessionType: string;
    difficulty: number;
    selectedAnswer: any;
    correctAnswer: any;
    isCorrect: boolean;
    responseTimeMs: number;
  }) => void;
}

export function AptitudeGames({ gameType, difficulty, round, onAnswer }: AptitudeGamesProps) {
  // const [selectedAnswer, setSelectedAnswer] = useState<any>(null);
  // const [currentDifficulty, setCurrentDifficulty] = useState(3);
  // const [usedQuestionIds, setUsedQuestionIds] = useState<string[]>([]);
  // const [currentTypeIndex, setCurrentTypeIndex] = useState(0);
  const questionStartTime = useRef(Date.now());
  const [selectedAnswer, setSelectedAnswer] = useState<any>(null);
  const [usedQuestionIds, setUsedQuestionIds] = useState<string[]>([]);

  const [responses, setResponses] = useState<
    {
      questionId: string;
      isCorrect: boolean;
      responseTimeMs: number;
    }[]
  >([]);
  const [generatedQuestions, setGeneratedQuestions] = useState<(WordSenseQuestion | null)[]>([null, null, null, null]);
  const [word2Loading, setWord2Loading] = useState(false);
  const [word2Error, setWord2Error] = useState(false);

  const typeOrder = ["A", "B", "C", "D"];
  const word2Types = ['odd_one_out', 'analogy', 'meaning_in_context', 'same_meaning'];
  const API_BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8080';

  // Pre-fetch all 4 word items when gameType is 2
  useEffect(() => {
    if (gameType !== 2) return;
    setWord2Loading(true);
    setWord2Error(false);
    const language = 'English';
    Promise.all(
      word2Types.map((itemType, i) =>
        fetch(`${API_BASE}/api/generate-word-item`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ item_type: itemType, difficulty: 3, language }),
        })
          .then(r => r.json())
          .then(data => {
            if (!data.success) return null;
            const item = data.item;
            return {
              id: `W2-${itemType}-${i}`,
              sessionType: typeOrder[i],
              type: itemType,
              question: item.question,
              options: item.options,
              correct: item.options[item.correct_index],
              difficulty: 3,
              difficultyLabel: 'medium',
              explanation: item.explanation,
            } as WordSenseQuestion;
          })
          .catch(() => null)
      )
    ).then(results => {
      setGeneratedQuestions(results);
      setWord2Loading(false);
      if (results.every(r => r === null)) setWord2Error(true);
    });
  }, [gameType]);

  const MEDIUM_IDS = ['A1', 'A2', 'A3', 'B1', 'B2', 'C1', 'C2'];
  const MEDIUM_HARD_IDS = ['A4', 'B3', 'B4', 'C3', 'C4', 'D1', 'D2', 'D3', 'D4'];
  const D_IDS = ['D1', 'D2', 'D3', 'D4'];

  function getQuestion(round: number): NumberSenseQuestion | null {
    const mediumCorrectCount = responses.filter(r => {
      const q = numberSenseQuestions.find(x => x.id === r.questionId);
      return r.isCorrect && q?.difficulty === 2;
    }).length;

    const availableMedium = numberSenseQuestions.filter(
      q =>
        MEDIUM_IDS.includes(q.id) &&
        !usedQuestionIds.includes(q.id)
    );

    const availableMediumHard = numberSenseQuestions.filter(
      q =>
        MEDIUM_HARD_IDS.includes(q.id) &&
        !usedQuestionIds.includes(q.id)
    );

    const availableD = numberSenseQuestions.filter(
      q =>
        D_IDS.includes(q.id) &&
        !usedQuestionIds.includes(q.id)
    );

    const pickRandom = (items: NumberSenseQuestion[]) =>
      items[Math.floor(Math.random() * items.length)] ?? null;

    if (round === 0) {
      return pickRandom(availableMedium);
    }

    if (round === 1) {
      return pickRandom(availableMedium);
    }

    if (round === 2) {
      return mediumCorrectCount >= 2
        ? pickRandom(availableMediumHard)
        : pickRandom(availableMedium);
    }

    if (round === 3) {
      return mediumCorrectCount >= 2
        ? pickRandom(availableD)
        : pickRandom(availableMediumHard);
    }

    return null;
  }

  // Get current question based on game type and round
  const getCurrentQuestion = (): GameQuestion | null => {
    if (gameType === 1) return getQuestion(round);
    if (gameType === 2) return generatedQuestions[round] ?? null;
    if (gameType === 3) return shapeSenseQuestions[round];
    if (gameType === 4) return logicSenseQuestions[round];
    return null;
  };

  const question = getCurrentQuestion();
  if (gameType === 2 && word2Loading) {
    return (
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
        className="bg-white rounded-2xl border border-gray-200 shadow-lg p-8 text-center"
      >
        <p className="text-gray-500 text-lg">Loading questions...</p>
      </motion.div>
    );
  }
  if (gameType === 2 && word2Error) {
    return (
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
        className="bg-white rounded-2xl border border-gray-200 shadow-lg p-8 text-center"
      >
        <p className="text-red-500 text-lg">Could not load questions. Please try again.</p>
      </motion.div>
    );
  }
  if (!question) return null;

  const handleAnswer = (answer: any) => {
    setSelectedAnswer(answer);
    const responseTimeMs =
      Date.now() - questionStartTime.current;
    const isCorrect = answer === question.correct;

    if (gameType === 1) {
      const q = question as NumberSenseQuestion;
      setUsedQuestionIds(prev => [...prev, q.id]);
      setResponses(prev => [...prev,
        {
          questionId: q.id,
          isCorrect,
          responseTimeMs
        }
      ]);
      setTimeout(() => {
        onAnswer({
          questionId: q.id,
          sessionType: q.sessionType,
          difficulty: q.difficulty,
          selectedAnswer: answer,
          correctAnswer: q.correct,
          isCorrect,
          responseTimeMs,
        });
        questionStartTime.current = Date.now();
        setSelectedAnswer(null);
      }, 300);
    } else {
      setTimeout(() => {
        onAnswer({
          questionId: '',
          sessionType: '',
          difficulty: 0,
          selectedAnswer: answer,
          correctAnswer: question.correct,
          isCorrect,
          responseTimeMs,
        });
        questionStartTime.current = Date.now();
        setSelectedAnswer(null);
      }, 300);
    }
  };

  const gameNames = ["", "Number Sense", "Word Sense", "Shape Sense", "Logic Sense"];
  const gameColors = ["", "indigo", "purple", "green", "orange"];
  const currentColor = gameColors[gameType];

  return (
    <motion.div
      key={`${gameType}-${round}`}
      initial={{ opacity: 0, x: 20 }}
      animate={{ opacity: 1, x: 0 }}
      className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
    >
      <div className="mb-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-bold text-gray-900">
            <TranslatedText>{`${gameNames[gameType]} - Question ${String(round + 1)} of 4`}</TranslatedText>
          </h3>
          <div className="flex gap-1">
            {Array.from({ length: 4 }).map((_, i) => (
              <div
                key={i}
                className={`w-2 h-2 rounded-full ${
                  i <= round ? `bg-${currentColor}-600` : "bg-gray-300"
                }`}
              />
            ))}
          </div>
        </div>
      </div>

      {/* Game 1 - Number Sense */}
      {gameType === 1 && 'options' in question && question.options && (
        <div className="space-y-6">
          <div className="p-6 bg-indigo-50 rounded-xl">
            <p className="text-2xl font-bold text-center text-gray-900">{question.question}</p>
          </div>
          <div className="grid grid-cols-2 gap-4">
            {(question.options as (number | string)[]).map((option, idx) => (
              <button
                key={idx}
                onClick={() => handleAnswer(option)}
                disabled={selectedAnswer !== null}
                className={`p-6 rounded-xl border-2 text-center transition-all hover:scale-105 ${
                  selectedAnswer === option
                    ? "border-indigo-600 bg-indigo-50"
                    : "border-gray-200 hover:border-indigo-300"
                }`}
              >
                <span className="text-2xl font-bold text-gray-900">{option}</span>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Game 2 - Word Sense (dynamically generated) */}
      {gameType === 2 && 'options' in question && question.options && (
        <div className="space-y-6">
          <p className="text-lg font-semibold text-gray-900 mb-4 text-center">{question.question}</p>
          <div className="grid grid-cols-1 gap-3">
            {(question.options as string[]).map((option, idx) => (
              <button
                key={idx}
                onClick={() => handleAnswer(option)}
                disabled={selectedAnswer !== null}
                className={`p-4 rounded-xl border-2 text-left transition-all hover:scale-[1.02] ${
                  selectedAnswer === option
                    ? 'border-purple-600 bg-purple-50'
                    : 'border-gray-200 hover:border-purple-300'
                }`}
              >
                <span className="text-base font-medium text-gray-900">{option}</span>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Game 3 - Shape Sense */}
      {gameType === 3 && (
        <div className="space-y-6">
          <p className="text-lg font-semibold text-gray-900 mb-4 text-center">{question.question}</p>
          
          {question.type === "cube-counting" && 'options' in question && question.options && (
            <div className="grid grid-cols-2 gap-4">
              {(question.options as number[]).map((option, idx) => (
                <button
                  key={idx}
                  onClick={() => handleAnswer(option)}
                  disabled={selectedAnswer !== null}
                  className={`p-6 rounded-xl border-2 text-center transition-all hover:scale-105 ${
                    selectedAnswer === option
                      ? "border-indigo-600 bg-indigo-50"
                      : "border-gray-200 hover:border-indigo-300"
                  }`}
                >
                  <span className="text-2xl font-bold text-gray-900">{option}</span>
                </button>
              ))}
            </div>
          )}
          
          {(question.type === "rotation" || question.type === "net-folding" || question.type === "mental-assembly") && 'questionImage' in question && question.questionImage && 'optionImages' in question && question.optionImages && (
            <div className="space-y-6">
              {/* Question Image */}
              <div className="flex justify-center p-4 bg-green-50 rounded-xl">
                <img 
                  src={question.questionImage} 
                  alt="Question" 
                  className="max-w-full h-auto max-h-40 object-contain"
                />
              </div>
              
              {/* Option Images */}
              <div className="grid grid-cols-2 gap-4">
                {["Option A", "Option B", "Option C", "Option D"].map((option, idx) => (
                  <button
                    key={idx}
                    onClick={() => handleAnswer(option)}
                    disabled={selectedAnswer !== null}
                    className={`p-3 rounded-xl border-2 bg-white transition-all hover:scale-105 ${
                      selectedAnswer === option
                        ? "border-indigo-600 bg-indigo-50"
                        : "border-gray-200 hover:border-indigo-300"
                    }`}
                  >
                    <img 
                      src={question.optionImages![idx]} 
                      alt={option} 
                      className="w-full h-auto max-h-24 object-contain mb-2"
                    />
                    <span className="text-sm font-semibold text-gray-900">{option}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Game 4 - Logic Sense */}
      {gameType === 4 && (
        <div className="space-y-6">
          <p className="text-lg font-semibold text-gray-900 mb-4 text-center">{question.question}</p>
          
          {(question.type === "matrix" || question.type === "rule-finding" || question.type === "deduction") && 'options' in question && question.options && (
            <div className="grid grid-cols-2 gap-4">
              {(question.options as (number | string)[]).map((option, idx) => (
                <button
                  key={idx}
                  onClick={() => handleAnswer(option)}
                  disabled={selectedAnswer !== null}
                  className={`p-6 rounded-xl border-2 text-center transition-all hover:scale-105 ${
                    selectedAnswer === option
                      ? "border-indigo-600 bg-indigo-50"
                      : "border-gray-200 hover:border-indigo-300"
                  }`}
                >
                  <span className="text-2xl font-bold text-gray-900">{option}</span>
                </button>
              ))}
            </div>
          )}
          
          {question.type === "pattern-series" && 'questionImage' in question && question.questionImage && 'optionImages' in question && question.optionImages && (
            <div className="space-y-6">
              {/* Question Image */}
              <div className="flex justify-center p-4 bg-orange-50 rounded-xl">
                <img 
                  src={question.questionImage} 
                  alt="Question" 
                  className="max-w-full h-auto max-h-40 object-contain"
                />
              </div>
              
              {/* Option Images */}
              <div className="grid grid-cols-2 gap-4">
                {["Option A", "Option B", "Option C", "Option D"].map((option, idx) => (
                  <button
                    key={idx}
                    onClick={() => handleAnswer(option)}
                    disabled={selectedAnswer !== null}
                    className={`p-3 rounded-xl border-2 bg-white transition-all hover:scale-105 ${
                      selectedAnswer === option
                        ? "border-indigo-600 bg-indigo-50"
                        : "border-gray-200 hover:border-indigo-300"
                    }`}
                  >
                    <img 
                      src={question.optionImages![idx]} 
                      alt={option} 
                      className="w-full h-auto max-h-24 object-contain mb-2"
                    />
                    <span className="text-sm font-semibold text-gray-900">{option}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </motion.div>
  );
}

// ─── Task 2 — Constraint Grid ────────────────────────────────────────────────

export type ConstraintGridResult = {
  scanTimeMs: number;
  foundEasyEntryFirst: boolean;
  mistakesMade: number;
  mistakesUndone: number;
  hintUsed: boolean;
  solved: boolean;
  shutdownWithoutAttempt: boolean;
  approachLabel: string;
  counselorFlag: string | null;
};

const CG_COLORS = ['🔴', '🟡', '🔵', '🟢'];
const CG_SYMBOLS = ['A', 'B', 'C', 'D'];
// Solution (4×4 row-major). encode: (color1-4, symbol0-3) => (color-1)*4+symbol+1
// Row0:(1,A)(2,B)(3,C)(4,D) Row1:(2,C)(1,D)(4,A)(3,B) Row2:(3,D)(4,C)(1,B)(2,A) Row3:(4,B)(3,A)(2,D)(1,C)
const CG_SOLUTION: number[] = [1,6,11,16, 7,4,13,10, 12,15,2,5, 14,9,8,3];
const CG_PREFILLED = new Set([1,2,3,4,6,8,9,11,13,15]);

function makeCGGrid(): (number | null)[] {
  return CG_SOLUTION.map((v, i) => CG_PREFILLED.has(i) ? v : null);
}

// Derive the most constrained empty cell (fewest valid options given prefilled cells)
function getMostConstrainedEmptyCell(): number {
  const emptyCells = CG_SOLUTION
    .map((_, i) => i)
    .filter(i => !CG_PREFILLED.has(i));

  let minOptions = Infinity;
  let bestCell = emptyCells[0];

  for (const idx of emptyCells) {
    const row = Math.floor(idx / 4);
    const col = idx % 4;

    // Collect values already used in this row and column
    const usedInRow = new Set<number>();
    const usedInCol = new Set<number>();
    for (let c = 0; c < 4; c++) {
      const v = CG_SOLUTION[row * 4 + c];
      if (CG_PREFILLED.has(row * 4 + c)) usedInRow.add(v);
    }
    for (let r = 0; r < 4; r++) {
      const v = CG_SOLUTION[r * 4 + col];
      if (CG_PREFILLED.has(r * 4 + col)) usedInCol.add(v);
    }

    // Count valid options = values not blocked by row or col
    let options = 0;
    for (let v = 1; v <= 16; v++) {
      if (!usedInRow.has(v) && !usedInCol.has(v)) options++;
    }

    if (options < minOptions) {
      minOptions = options;
      bestCell = idx;
    }
  }
  return bestCell;
}

const CG_EASY_ENTRY = getMostConstrainedEmptyCell();

interface ConstraintGridProps {
  onComplete: (result: ConstraintGridResult) => void;
  onSkip: () => void;
}

export function ConstraintGrid({ onComplete, onSkip }: ConstraintGridProps) {
  const [started, setStarted] = useState(false);
  const [grid, setGrid] = useState<(number | null)[]>(makeCGGrid);
  const [selected, setSelected] = useState<number | null>(null);
  const [mistakes, setMistakes] = useState(0);
  const [mistakesUndone, setMistakesUndone] = useState(0);
  const [hintUsed, setHintUsed] = useState(false);
  const [firstInteractionTime, setFirstInteractionTime] = useState<number | null>(null);
  const [firstCellTouched, setFirstCellTouched] = useState<number | null>(null);
  const [shutdownFlag, setShutdownFlag] = useState(false);
  const cgStart = useRef<number>(0);
  const cgTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Start scan timer only when student clicks Start (not on mount)
  const handleStart = () => {
    setStarted(true);
    cgStart.current = Date.now();
    cgTimer.current = setTimeout(() => {
      if (firstInteractionTime === null) setShutdownFlag(true);
    }, 30000);
  };

  useEffect(() => {
    return () => { if (cgTimer.current) clearTimeout(cgTimer.current); };
  }, []);

  const handleCellClick = (idx: number) => {
    if (CG_PREFILLED.has(idx)) return;
    if (firstInteractionTime === null) {
      setFirstInteractionTime(Date.now() - cgStart.current);
      if (cgTimer.current) clearTimeout(cgTimer.current);
    }
    if (firstCellTouched === null) setFirstCellTouched(idx);
    setSelected(idx === selected ? null : idx);
  };

  const handleValueSelect = (val: number) => {
    if (selected === null) return;
    const newGrid = [...grid];
    const prev = newGrid[selected];
    if (prev !== null && prev !== CG_SOLUTION[selected]) setMistakesUndone(m => m + 1);
    if (val !== CG_SOLUTION[selected]) setMistakes(m => m + 1);
    newGrid[selected] = val;
    setGrid(newGrid);
    setSelected(null);
    if (newGrid.every((v, i) => v === CG_SOLUTION[i])) finalizeCG(newGrid, false);
  };

  const handleCGHint = () => {
    if (selected === null) return;
    setHintUsed(true);
    const newGrid = [...grid];
    newGrid[selected] = CG_SOLUTION[selected];
    setGrid(newGrid);
    setSelected(null);
    if (newGrid.every((v, i) => v === CG_SOLUTION[i])) finalizeCG(newGrid, false);
  };

  const finalizeCG = (finalGrid: (number | null)[], shutdown: boolean) => {
    const scanTime = firstInteractionTime ?? (Date.now() - cgStart.current);
    const solved = finalGrid.every((v, i) => v === CG_SOLUTION[i]);
    const foundEasy = firstCellTouched === CG_EASY_ENTRY;
    let approachLabel = 'intuitive-adaptive';
    let counselorFlag: string | null = null;

    if (shutdown || firstInteractionTime === null) {
      // Never touched anything after 30s
      approachLabel = 'complexity-shutdown';
      counselorFlag = 'Student looked at constraint grid 30s+ without attempting — anxiety of not knowing where to start. High-priority counselor flag before committing to any ambiguous-problem path.';
    } else if (scanTime < 2000 && hintUsed) {
      // Tapped hint almost immediately — low ambiguity tolerance
      approachLabel = 'low-ambiguity-tolerance';
      counselorFlag = 'Immediate hint use (scan < 2s) — low tolerance for ambiguity. Better suited to clearly defined roles with step-by-step processes.';
    } else if (scanTime > 5000 && foundEasy) {
      // Scanned carefully AND found the most constrained cell first
      approachLabel = 'systematic-analytical';
    } else if (scanTime > 5000 && !foundEasy) {
      // Scanned but didn’t find easy entry
      approachLabel = 'cautious';
    } else if (mistakes > 0 && mistakesUndone >= Math.ceil(mistakes * 0.5)) {
      // Jumped in, made mistakes, but corrected at least half of them
      approachLabel = 'intuitive-adaptive';
    }
    // else: default intuitive-adaptive

    onComplete({ scanTimeMs: scanTime, foundEasyEntryFirst: foundEasy, mistakesMade: mistakes, mistakesUndone, hintUsed, solved, shutdownWithoutAttempt: shutdown || firstInteractionTime === null, approachLabel, counselorFlag });
  };

  const emptyCells = CG_SOLUTION.length - CG_PREFILLED.size;
  const filledEmpty = grid.filter((v, i) => !CG_PREFILLED.has(i) && v !== null).length;
  const progress = Math.round((filledEmpty / emptyCells) * 100);

  if (!started) {
    return (
      <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}
        className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8 text-center"
      >
        <div className="w-16 h-16 bg-gradient-to-br from-violet-500 to-purple-600 rounded-2xl flex items-center justify-center mx-auto mb-6">
          <span className="text-3xl">🧩</span>
        </div>
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Constraint Grid</h2>
        <p className="text-gray-600 mb-6 leading-relaxed">
          A 4×4 grid of colored symbols. Each row and each column must contain each color and each letter exactly once.
          Some cells are already filled. Find the right cells to complete it.
        </p>
        <div className="bg-violet-50 border border-violet-200 rounded-xl p-4 mb-8 text-left">
          <p className="text-sm text-violet-800 font-medium mb-1">How it works:</p>
          <p className="text-sm text-violet-700">Tap an empty cell, then choose the color + letter that fits. A hint is available if you get stuck.</p>
        </div>
        <div className="flex gap-3">
          <Button onClick={onSkip} variant="outline" className="flex-1 h-12 text-gray-500">Skip</Button>
          <Button onClick={handleStart} className="flex-1 h-12 bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-700 hover:to-purple-700">
            Start Puzzle
          </Button>
        </div>
      </motion.div>
    );
  }

  return (
    <motion.div initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}
      className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
    >
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-xl font-bold text-gray-900">Constraint Grid</h3>
          <p className="text-sm text-gray-500">Each row and column must have each color and letter exactly once</p>
        </div>
        <div className="text-right">
          <p className="text-lg font-bold text-violet-600">{progress}%</p>
          <p className="text-xs text-gray-500">filled</p>
        </div>
      </div>

      <div className="grid grid-cols-4 gap-1 mb-4 max-w-xs mx-auto">
        {grid.map((val, idx) => {
          const isPrefilled = CG_PREFILLED.has(idx);
          const isSelected = selected === idx;
          const isWrong = val !== null && !isPrefilled && val !== CG_SOLUTION[idx];
          const color = val ? CG_COLORS[Math.ceil(val / 4) - 1] : null;
          const symbol = val ? CG_SYMBOLS[(val - 1) % 4] : null;
          return (
            <button key={idx} onClick={() => handleCellClick(idx)} disabled={isPrefilled}
              className={`h-14 rounded-lg border-2 flex flex-col items-center justify-center transition-all ${
                isPrefilled ? 'bg-gray-100 border-gray-300 cursor-default'
                : isSelected ? 'border-violet-500 bg-violet-50 scale-105'
                : 'border-dashed border-gray-300 hover:border-violet-300 hover:bg-violet-50'
              }`}
            >
              {val !== null
                ? <><span className="text-base leading-none">{color}</span><span className="text-xs font-bold text-gray-700">{symbol}</span></>
                : <span className="text-gray-300 text-lg">?</span>}
            </button>
          );
        })}
      </div>

      {selected !== null && (
        <div className="mb-4 p-3 bg-violet-50 rounded-xl border border-violet-200">
          <p className="text-xs text-violet-700 font-semibold mb-2">Select color + letter:</p>
          <div className="grid grid-cols-4 gap-2">
            {CG_SOLUTION.map((_, vi) => {
              const v = vi + 1;
              return (
                <button key={v} onClick={() => handleValueSelect(v)}
                  className="h-10 rounded-lg border-2 border-violet-200 bg-white hover:border-violet-500 flex flex-col items-center justify-center transition-all"
                >
                  <span className="text-sm leading-none">{CG_COLORS[Math.ceil(v / 4) - 1]}</span>
                  <span className="text-xs font-bold text-gray-700">{CG_SYMBOLS[(v - 1) % 4]}</span>
                </button>
              );
            })}
          </div>
        </div>
      )}

      <div className="flex gap-3">
        <Button onClick={handleCGHint} variant="outline"
          className="flex-1 h-11 border-amber-300 text-amber-700 hover:bg-amber-50"
          disabled={selected === null || hintUsed}
        >
          <Lightbulb className="w-4 h-4 mr-2" />{hintUsed ? 'Hint used' : 'Hint'}
        </Button>
        <Button onClick={() => finalizeCG(grid, shutdownFlag)} variant="outline" className="flex-1 h-11 text-gray-500">
          I'm done
        </Button>
      </div>
    </motion.div>
  );
}

// ─── Task 3 — Secret Agent Cipher ───────────────────────────────────────────

export type CipherTier = 1 | 2 | 3;

export type CipherExample = {
  message: string;
  decoded: string;
};

export type CipherQuestion = {
  tier: CipherTier;
  id: string;
  examples: CipherExample[];
  testMessage: string;
  validAnswers: string[];
};

export type CipherAttempt = {
  input: string;
  correct: boolean;
  errorType: 'rule_error' | 'vocab_error' | 'wrong' | null;
  timestampMs: number;
};

export type CipherTierResult = {
  tier: CipherTier;
  examplesSeenBeforeTest: number;
  totalExamples: number;
  attempts: CipherAttempt[];
  solved: boolean;
  timeToFirstAttemptMs: number;
  totalTimeMs: number;
  gaveUp: boolean;
};

export type SecretAgentResult = {
  tierResults: CipherTierResult[];
  informationGathering: 'patient' | 'moderate' | 'impulsive';
  persistence: 'high' | 'medium' | 'low';
  ruleAdaptability: 'fast' | 'moderate' | 'slow';
  counselorFlags: string[];
};

interface SecretAgentCipherProps {
  questions: {
    tier1: CipherQuestion;
    tier2: CipherQuestion;
    tier3: CipherQuestion;
  } | null;
  loading: boolean;
  onValidateWord: (word: string) => Promise<boolean>;
  onComplete: (result: SecretAgentResult) => void;
  onSkip: () => void;
}

const TIER_META = {
  1: { label: 'Transmission Echo',    missionTitle: 'Crack the access code to enter the building.',    color: 'from-cyan-600 to-teal-700',    border: 'border-cyan-200',    badge: 'bg-cyan-50 text-cyan-700 border-cyan-200' },
  2: { label: 'Transmission Foxtrot', missionTitle: 'Decode the intercepted transmission.',            color: 'from-violet-600 to-purple-700', border: 'border-violet-200', badge: 'bg-violet-50 text-violet-700 border-violet-200' },
  3: { label: 'Transmission Tango',   missionTitle: 'Break the enemy cipher before time runs out.',   color: 'from-amber-500 to-orange-600',  border: 'border-amber-200',  badge: 'bg-amber-50 text-amber-700 border-amber-200' },
} as const;

const MAX_ATTEMPTS = 3;

function getLetterCount(message: string): string {
  return message.trim().split(/\s+/).map(w => w.replace(/[^a-zA-Z]/g, '').length).join('');
}

function getFirstLetters(message: string): string {
  return message.trim().split(/\s+/).map(w => w.replace(/[^a-zA-Z]/g, '')[0]?.toUpperCase() ?? '').filter(Boolean).join('');
}

function sortedLetters(str: string): string {
  return str.toUpperCase().replace(/[^A-Z]/g, '').split('').sort().join('');
}

export function SecretAgentCipher({ questions, loading, onValidateWord, onComplete, onSkip }: SecretAgentCipherProps) {

  const [phase, setPhase] = useState<'briefing' | 'examples' | 'test' | 'between'>('briefing');
  const [currentTierIdx, setCurrentTierIdx] = useState(0);
  const [examplesRevealed, setExamplesRevealed] = useState(1);
  const [examplesSeenBeforeTest, setExamplesSeenBeforeTest] = useState(0);
  const [testInput, setTestInput] = useState('');
  const [attempts, setAttempts] = useState<CipherAttempt[]>([]);
  const [tierResults, setTierResults] = useState<CipherTierResult[]>([]);
  const [isValidating, setIsValidating] = useState(false);
  const [feedbackMsg, setFeedbackMsg] = useState<string | null>(null);
  const [feedbackOk, setFeedbackOk] = useState(false);

  const tierStartTime = useRef(0);
  const testStartTime = useRef(0);
  const inputRef = useRef<HTMLInputElement>(null);

  const tierNum = (currentTierIdx + 1) as CipherTier;
  const meta = TIER_META[tierNum];
  const allQ = questions ? [questions.tier1, questions.tier2, questions.tier3] : [];
  const currentQ = allQ[currentTierIdx] ?? null;
  const maxExamples = currentQ?.examples.length ?? 0;

  const enterExamples = () => {
    tierStartTime.current = Date.now();
    setExamplesRevealed(1);
    setExamplesSeenBeforeTest(0);
    setAttempts([]);
    setTestInput('');
    setFeedbackMsg(null);
    setFeedbackOk(false);
    setPhase('examples');
  };

  const enterTest = (fromExampleCount: number) => {
    testStartTime.current = Date.now();
    setExamplesSeenBeforeTest(fromExampleCount);
    setFeedbackMsg(null);
    setFeedbackOk(false);
    setPhase('test');
    setTimeout(() => inputRef.current?.focus(), 100);
  };

  const handleRevealNext = () => {
    if (examplesRevealed < maxExamples) {
      setExamplesRevealed(prev => prev + 1);
    }
  };

  const handleSubmit = async () => {
    if (!currentQ || !testInput.trim() || isValidating) return;
    setIsValidating(true);
    const rawInput = testInput.trim();
    const now = Date.now();
    let correct = false;
    let errorType: CipherAttempt['errorType'] = null;
    let msg = '';

    if (tierNum === 1) {
      const expected = getLetterCount(currentQ.testMessage);
      correct = rawInput === expected;
      if (!correct) msg = `Not the right code. Count every letter in each word, then write the counts together with no spaces.`;
    } else if (tierNum === 2) {
      correct = currentQ.validAnswers.some(a => a.toUpperCase() === rawInput.toUpperCase());
      if (!correct) msg = `"${rawInput.toUpperCase()}" is not the right word. Check which letter you are extracting from each word.`;
    } else {
      const expectedLetters = getFirstLetters(currentQ.testMessage);
      const lettersMatch = sortedLetters(rawInput) === sortedLetters(expectedLetters);
      const isWord = await onValidateWord(rawInput.toLowerCase());
      if (lettersMatch && isWord) {
        correct = true;
      } else if (!lettersMatch && isWord) {
        errorType = 'rule_error';
        msg = `"${rawInput.toUpperCase()}" is a real word, but those are not the right letters. Re-check which letter you take from each word.`;
      } else if (lettersMatch && !isWord) {
        errorType = 'vocab_error';
        msg = `You have the right letters. "${rawInput.toUpperCase()}" is not a recognised word — try rearranging them differently.`;
      } else {
        errorType = 'wrong';
        msg = `Check both steps: extract the first letter from every word, then rearrange all of them to form a real word.`;
      }
    }

    const attempt: CipherAttempt = { input: rawInput, correct, errorType, timestampMs: now };
    const newAttempts = [...attempts, attempt];
    setAttempts(newAttempts);
    setIsValidating(false);

    if (correct) {
      setFeedbackMsg('Transmission decoded.');
      setFeedbackOk(true);
      setTimeout(() => advanceTier(newAttempts, false), 1200);
    } else if (newAttempts.length >= MAX_ATTEMPTS) {
      setFeedbackMsg(`Maximum attempts reached. Moving to the next transmission.`);
      setFeedbackOk(false);
      setTimeout(() => advanceTier(newAttempts, true), 1500);
    } else {
      setFeedbackMsg(msg);
      setFeedbackOk(false);
      setTestInput('');
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  };

  const handleGiveUp = () => {
    if (!currentQ) return;
    advanceTier(attempts, true);
  };

  const advanceTier = (finalAttempts: CipherAttempt[], gaveUp: boolean) => {
    if (!currentQ) return;
    const now = Date.now();
    const result: CipherTierResult = {
      tier: tierNum,
      examplesSeenBeforeTest,
      totalExamples: maxExamples,
      attempts: finalAttempts,
      solved: !gaveUp && (finalAttempts[finalAttempts.length - 1]?.correct ?? false),
      timeToFirstAttemptMs: finalAttempts.length > 0 ? finalAttempts[0].timestampMs - testStartTime.current : 0,
      totalTimeMs: now - tierStartTime.current,
      gaveUp,
    };
    const newResults = [...tierResults, result];
    setTierResults(newResults);
    if (currentTierIdx < 2) {
      setCurrentTierIdx(prev => prev + 1);
      setPhase('between');
    } else {
      finalize(newResults);
    }
  };

  const finalize = (results: CipherTierResult[]) => {
    const flags: string[] = [];

    const avgRatio = results.reduce((sum, r) => {
      const ratio = r.totalExamples > 0 ? r.examplesSeenBeforeTest / r.totalExamples : 0;
      return sum + ratio;
    }, 0) / results.length;
    const informationGathering: SecretAgentResult['informationGathering'] =
      avgRatio < 0.35 ? 'impulsive' : avgRatio < 0.75 ? 'moderate' : 'patient';
    if (informationGathering === 'impulsive')
      flags.push('Attempted all three ciphers before seeing most examples — tendency to act on limited information. May benefit from structured analysis frameworks in high-stakes decisions.');

    const gaveUpCount = results.filter(r => r.gaveUp).length;
    const triedAfterWrong = results.some(r => r.attempts.length > 1);
    const persistence: SecretAgentResult['persistence'] =
      gaveUpCount >= 2 ? 'low' : gaveUpCount === 1 ? 'medium' : !triedAfterWrong ? 'medium' : 'high';
    if (persistence === 'low')
      flags.push('Gave up on 2 or more transmissions — low frustration tolerance under ambiguity. High-grind paths (NEET, JEE, UPSC) carry elevated risk without additional support strategies.');
    else if (persistence === 'high')
      flags.push('Persisted through wrong answers without giving up — strong grit signal. Suited to long-preparation paths that reward sustained effort.');

    const tier2 = results.find(r => r.tier === 2);
    const tier2FirstCorrect = tier2?.attempts[0]?.correct ?? false;
    const tier2Count = tier2?.attempts.length ?? 0;
    const ruleAdaptability: SecretAgentResult['ruleAdaptability'] =
      tier2FirstCorrect ? 'fast' : tier2Count <= 2 ? 'moderate' : 'slow';
    if (ruleAdaptability === 'slow')
      flags.push('Multiple wrong attempts when cipher rule type changed — possible preference for consistent rule environments.');
    if (ruleAdaptability === 'fast')
      flags.push('Adapted to a completely different rule type on the first attempt at Transmission 2 — strong cognitive flexibility signal.');

    const tier3 = results.find(r => r.tier === 3);
    const vocabErrors = tier3?.attempts.filter(a => a.errorType === 'vocab_error').length ?? 0;
    const ruleErrors = tier3?.attempts.filter(a => a.errorType === 'rule_error').length ?? 0;
    if (vocabErrors >= 2)
      flags.push('Extracted correct letters on Transmission Tango but struggled to form a valid English word — vocabulary constraint, not a reasoning deficit.');
    if (ruleErrors >= 1 && tier3?.solved)
      flags.push('Initially applied incorrect extraction rule on Transmission Tango but self-corrected and solved it — good hypothesis-revision under failure.');

    onComplete({ tierResults: results, informationGathering, persistence, ruleAdaptability, counselorFlags: flags });
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') handleSubmit();
  };

  // ── Loading / error states ────────────────────────────────────────────────
  if (loading) {
    return (
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
        className="bg-white rounded-2xl border border-gray-200 shadow-lg p-8 text-center"
      >
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600 mx-auto mb-4" />
        <p className="text-gray-500 text-lg">Preparing your mission briefing...</p>
      </motion.div>
    );
  }

  if (!questions) {
    return (
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
        className="bg-white rounded-2xl border border-gray-200 shadow-lg p-8 text-center"
      >
        <p className="text-red-500 text-lg">Could not load mission data. Please try again.</p>
        <Button onClick={onSkip} variant="outline" className="mt-4">Skip</Button>
      </motion.div>
    );
  }

  // ── Briefing (intro) ─────────────────────────────────────────────────────
  if (phase === 'briefing') {
    return (
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}
        className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
      >
        <div className="text-center mb-6">
          <div className="w-16 h-16 bg-gradient-to-br from-slate-700 to-slate-900 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <span className="text-3xl">🕵️</span>
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Secret Agent Cipher</h2>
          <p className="text-gray-600 leading-relaxed">Three transmissions. Each uses a hidden rule. Study the examples, crack the pattern, decode the message.</p>
        </div>
        <div className="space-y-3 mb-8">
          {([1, 2, 3] as CipherTier[]).map(t => (
            <div key={t} className={`flex items-start gap-3 p-4 rounded-xl border ${TIER_META[t].border} bg-white`}>
              <span className={`text-xs font-bold px-2 py-1 rounded border ${TIER_META[t].badge} flex-shrink-0 mt-0.5`}>{TIER_META[t].label}</span>
              <p className="text-sm text-gray-700">{TIER_META[t].missionTitle}</p>
            </div>
          ))}
        </div>
        <div className="flex gap-3">
          <Button onClick={onSkip} variant="outline" className="flex-1 h-12 text-gray-500">Skip</Button>
          <Button onClick={enterExamples} className="flex-1 h-12 bg-gradient-to-r from-slate-700 to-slate-900 hover:from-slate-800 hover:to-black text-white">
            Start Mission
          </Button>
        </div>
      </motion.div>
    );
  }

  // ── Between tiers ────────────────────────────────────────────────────────
  if (phase === 'between') {
    const nextMeta = TIER_META[(currentTierIdx + 1) as CipherTier];
    return (
      <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
        className="bg-white rounded-2xl border border-gray-200 shadow-lg p-8 text-center"
      >
        <CheckCircle2 className="w-12 h-12 text-green-500 mx-auto mb-4" />
        <p className="text-xl font-bold text-gray-900 mb-2">Transmission complete.</p>
        <p className="text-gray-500 text-sm mb-6">{nextMeta.missionTitle}</p>
        <Button onClick={enterExamples} className={`h-11 px-8 bg-gradient-to-r ${nextMeta.color} text-white`}>
          Next Transmission
        </Button>
      </motion.div>
    );
  }

  // ── Examples phase ────────────────────────────────────────────────────────
  if (phase === 'examples' && currentQ) {
    const visibleExamples = currentQ.examples.slice(0, examplesRevealed);
    const allRevealed = examplesRevealed >= maxExamples;
    return (
      <motion.div key={`examples-${currentTierIdx}`} initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}
        className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
      >
        <div className="flex items-center justify-between mb-4">
          <div>
            <span className={`text-xs font-bold px-2 py-1 rounded border ${meta.badge}`}>{meta.label}</span>
            <h3 className="text-lg font-bold text-gray-900 mt-2">{meta.missionTitle}</h3>
          </div>
          <span className="text-xs text-gray-400">Transmission {currentTierIdx + 1} of 3</span>
        </div>

        <p className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">Study the pattern</p>
        <div className="space-y-2 mb-6">
          {visibleExamples.map((ex, i) => (
            <div key={i} className="flex items-center justify-between p-3 bg-gray-50 rounded-xl border border-gray-200">
              <span className="text-sm text-gray-700 font-mono">{ex.message}</span>
              <span className="text-sm font-bold text-indigo-700 ml-4 flex-shrink-0">→ {ex.decoded}</span>
            </div>
          ))}
        </div>

        <div className="flex gap-3">
          {!allRevealed && (
            <Button onClick={handleRevealNext} variant="outline" className="flex-1 h-11">
              Show next example ({examplesRevealed}/{maxExamples})
            </Button>
          )}
          <Button
            onClick={() => enterTest(examplesRevealed)}
            className={`flex-1 h-11 bg-gradient-to-r ${meta.color} text-white`}
          >
            {allRevealed ? "I've got it — test me" : "Skip examples — test me now"}
          </Button>
        </div>
      </motion.div>
    );
  }

  // ── Test phase ────────────────────────────────────────────────────────────
  if (phase === 'test' && currentQ) {
    const attemptsLeft = MAX_ATTEMPTS - attempts.length;
    return (
      <motion.div key={`test-${currentTierIdx}`} initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }}
        className="bg-white rounded-2xl border border-gray-200 shadow-lg p-6 sm:p-8"
      >
        <div className="flex items-center justify-between mb-4">
          <span className={`text-xs font-bold px-2 py-1 rounded border ${meta.badge}`}>{meta.label}</span>
          <span className="text-xs text-gray-400">{attemptsLeft} attempt{attemptsLeft !== 1 ? 's' : ''} left</span>
        </div>

        <p className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">Decode this message</p>
        <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 mb-6">
          <p className="text-lg font-mono font-semibold text-gray-900 text-center">{currentQ.testMessage}</p>
        </div>

        <div className="space-y-3 mb-4">
          <input
            ref={inputRef}
            type="text"
            value={testInput}
            onChange={e => setTestInput(e.target.value)}
            onKeyDown={handleKeyDown}
            disabled={isValidating || feedbackOk}
            placeholder={tierNum === 1 ? 'Type the number string...' : 'Type the decoded word...'}
            className="w-full h-12 px-4 rounded-xl border-2 border-gray-200 focus:border-indigo-400 focus:outline-none text-gray-900 font-mono text-lg uppercase"
          />
          {feedbackMsg && (
            <p className={`text-sm font-medium ${feedbackOk ? 'text-green-600' : 'text-red-500'}`}>
              {feedbackMsg}
            </p>
          )}
        </div>

        <div className="flex gap-3">
          <Button
            onClick={handleGiveUp}
            variant="outline"
            className="h-11 text-gray-400 border-gray-200"
            disabled={isValidating || feedbackOk}
          >
            Give up
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={!testInput.trim() || isValidating || feedbackOk}
            className={`flex-1 h-11 bg-gradient-to-r ${meta.color} text-white`}
          >
            {isValidating ? 'Checking...' : 'Submit'}
          </Button>
        </div>
      </motion.div>
    );
  }

  return null;
}
