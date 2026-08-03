import 'dart:math';
import 'game_models.dart';

/// Question banks ported verbatim from the web `aptitude-games.tsx`.
/// Word Sense (game 2) is generated at runtime by the backend, so it has no
/// static bank here.

const String _img = 'assets/games';

// ------------------- Game 1: Number Sense (16 questions) -------------------
const List<AptQuestion> numberSenseBank = [
  AptQuestion(id: 'A1', type: 'sequence', question: '2, 6, 18, 54, ?', options: [108, 180, 162, 216], correct: 162, difficulty: 2),
  AptQuestion(id: 'A2', type: 'sequence', question: '5, 10, 20, 40, ?', options: [80, 60, 120, 70], correct: 80, difficulty: 2),
  AptQuestion(id: 'A3', type: 'sequence', question: '96, 48, 24, 12, ?', options: [8, 10, 6, 4], correct: 6, difficulty: 2),
  AptQuestion(id: 'A4', type: 'sequence', question: '4, 12, 36, 108, ?', options: [432, 324, 180, 216], correct: 324, difficulty: 3),
  AptQuestion(id: 'B1', type: 'sequence', question: '1, 4, 9, 16, 25, ?', options: [34, 36, 38, 35], correct: 36, difficulty: 2),
  AptQuestion(id: 'B2', type: 'sequence', question: '3, 7, 13, 21, 31, ?', options: [42, 43, 41, 44], correct: 43, difficulty: 2),
  AptQuestion(id: 'B3', type: 'sequence', question: '50, 48, 44, 38, 30, ?', options: [24, 18, 20, 22], correct: 20, difficulty: 3),
  AptQuestion(id: 'B4', type: 'sequence', question: '2, 7, 14, 23, 34, ?', options: [46, 48, 45, 47], correct: 47, difficulty: 3),
  AptQuestion(id: 'C1', type: 'arithmetic', question: 'A shopkeeper buys goods for ₹120 and sells them for ₹150. What is the profit percentage?', options: ['30%', '15%', '25%', '20%'], correct: '25%', difficulty: 2),
  AptQuestion(id: 'C2', type: 'arithmetic', question: 'Principal ₹5,000 at 8% per year for 3 years. What is the simple interest?', options: ['₹400', '₹6,200', '₹1,200', '₹120'], correct: '₹1,200', difficulty: 2),
  AptQuestion(id: 'C3', type: 'arithmetic', question: '40% of a number is 80. What is the number?', options: [180, 220, 200, 32], correct: 200, difficulty: 3),
  AptQuestion(id: 'C4', type: 'arithmetic', question: '₹480 is shared between two people in the ratio 3:5. What is the smaller share?', options: ['₹300', '₹180', '₹240', '₹288'], correct: '₹180', difficulty: 3),
  AptQuestion(id: 'D1', type: 'reasoning', question: '4 people can paint 4 walls in 4 hours. How long for 8 people to paint 8 walls?', options: ['2 hours', '8 hours', '4 hours', '16 hours'], correct: '4 hours', difficulty: 3),
  AptQuestion(id: 'D2', type: 'reasoning', question: 'A price increases by 20%, then decreases by 20%. What is the net change?', options: ['4% gain', '2% loss', '0%', '4% loss'], correct: '4% loss', difficulty: 3),
  AptQuestion(id: 'D3', type: 'reasoning', question: '6 workers finish a job in 12 days. How many days for 9 workers?', options: ['18 days', '8 days', '15 days', '9 days'], correct: '8 days', difficulty: 3),
  AptQuestion(id: 'D4', type: 'reasoning', question: 'Riya scores 72 in test 1 and 78 in test 2. What must she score in test 3 to average 80 across all three tests?', options: [85, 80, 75, 90], correct: 90, difficulty: 3),
];

// ------------------- Game 3: Shape Sense (4 questions) -------------------
const List<AptQuestion> shapeSenseBank = [
  AptQuestion(
    id: 'S1', type: 'rotation', difficulty: 1,
    question: 'Which of these is the same L-shaped block simply rotated (not flipped)?',
    questionImage: '$_img/g3_q1_question.png',
    optionImages: ['$_img/g3_q1_option_A.png', '$_img/g3_q1_option_B.png', '$_img/g3_q1_option_C.png', '$_img/g3_q1_option_D.png'],
    correct: 'Option A',
  ),
  AptQuestion(
    id: 'S2', type: 'cube-counting', difficulty: 2,
    question: 'A 3×3×3 stack with one column of 3 removed. How many small cubes are here?',
    options: [21, 23, 24, 27], correct: 24,
  ),
  AptQuestion(
    id: 'S3', type: 'net-folding', difficulty: 2,
    question: 'Which of these boxes can be folded from this net?',
    questionImage: '$_img/g3_q3_question.png',
    optionImages: ['$_img/g3_q3_option_A.png', '$_img/g3_q3_option_B.png', '$_img/g3_q3_option_C.png', '$_img/g3_q3_option_D.png'],
    correct: 'Option A',
  ),
  AptQuestion(
    id: 'S4', type: 'mental-assembly', difficulty: 3,
    question: 'Which single shape do these two pieces make if joined along the marked edge?',
    questionImage: '$_img/g3_q4_question.png',
    optionImages: ['$_img/g3_q4_option_A.png', '$_img/g3_q4_option_B.png', '$_img/g3_q4_option_C.png', '$_img/g3_q4_option_D.png'],
    correct: 'Option B',
  ),
];

// ------------------- Game 4: Logic Sense (4 questions) -------------------
const List<AptQuestion> logicSenseBank = [
  AptQuestion(
    id: 'L1', type: 'matrix', difficulty: 1,
    question: 'Three rows of dots: row 1 has 1-2-3, row 2 has 2-3-4, row 3 has 3-4-?',
    options: [4, 5, 6, 7], correct: 5,
  ),
  AptQuestion(
    id: 'L2', type: 'rule-finding', difficulty: 2,
    question: 'If ◆◆ = 4, ◆◆◆ = 9, ◆◆◆◆ = 16, then ◆◆◆◆◆ = ?',
    options: [18, 20, 25, 30], correct: 25,
  ),
  AptQuestion(
    id: 'L3', type: 'pattern-series', difficulty: 2,
    question: 'A figure rotates 90° clockwise and gains one dot at each step. What comes next?',
    questionImage: '$_img/g4_q3_question.png',
    optionImages: ['$_img/g4_q3_option_A.png', '$_img/g4_q3_option_B.png', '$_img/g4_q3_option_C.png', '$_img/g4_q3_option_D.png'],
    correct: 'Option C',
  ),
  AptQuestion(
    id: 'L4', type: 'deduction', difficulty: 3,
    question: 'All bloops are razzies. All razzies are lazzies. Are all bloops definitely lazzies?',
    options: ['Yes', 'No', 'Cannot say'], correct: 'Yes',
  ),
];

/// Word Sense item types, one per round (backend-generated at difficulty 3).
const wordSenseTypes = ['odd_one_out', 'analogy', 'meaning_in_context', 'same_meaning'];

// ------------------- Number Sense round selection (ported) -------------------
const _mediumIds = ['A1', 'A2', 'A3', 'B1', 'B2', 'C1', 'C2'];
const _mediumHardIds = ['A4', 'B3', 'B4', 'C3', 'C4', 'D1', 'D2', 'D3', 'D4'];
const _dIds = ['D1', 'D2', 'D3', 'D4'];

final _rng = Random();

AptQuestion? selectNumberQuestion(
  int round,
  List<GameResponse> responses,
  Set<String> used,
) {
  final mediumCorrect = responses.where((r) {
    final q = numberSenseBank.firstWhere((x) => x.id == r.questionId,
        orElse: () => numberSenseBank.first);
    return r.isCorrect && q.difficulty == 2;
  }).length;

  List<AptQuestion> avail(List<String> ids) =>
      numberSenseBank.where((q) => ids.contains(q.id) && !used.contains(q.id)).toList();

  AptQuestion? pick(List<AptQuestion> items) =>
      items.isEmpty ? null : items[_rng.nextInt(items.length)];

  switch (round) {
    case 0:
    case 1:
      return pick(avail(_mediumIds));
    case 2:
      return mediumCorrect >= 2 ? pick(avail(_mediumHardIds)) : pick(avail(_mediumIds));
    case 3:
      return mediumCorrect >= 2 ? pick(avail(_dIds)) : pick(avail(_mediumHardIds));
    default:
      return null;
  }
}
