// Models for the aptitude games — ported to match the web
// `aptitude-games.tsx` structure (Number / Word / Shape / Logic).

/// One question. `options`/`correct` are dynamic because the web mixes
/// numbers and strings; image questions use [questionImage] + [optionImages]
/// with `correct` being "Option A".."Option D".
class AptQuestion {
  const AptQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.options = const [],
    required this.correct,
    this.difficulty = 2,
    this.questionImage,
    this.optionImages,
  });

  final String id;
  final String type;
  final String question;
  final List<Object> options;
  final Object correct;
  final int difficulty; // 1..3
  final String? questionImage; // asset path
  final List<String>? optionImages; // asset paths (4)

  bool get isImageQuestion => optionImages != null && questionImage != null;
}

/// A single answered response (used for scoring and Number Sense selection).
class GameResponse {
  const GameResponse({
    required this.questionId,
    required this.isCorrect,
    required this.responseTimeMs,
    required this.difficulty,
  });
  final String questionId;
  final bool isCorrect;
  final int responseTimeMs;
  final int difficulty;
}

/// Weighted score for one game (0-8): correct+fast (<5s) = 2, correct+slow = 1,
/// wrong = 0 — matching the web's generateGameFeedback.
const int kFastThresholdMs = 5000;

int weightedScore(List<GameResponse> answers) {
  var sum = 0;
  for (final a in answers) {
    if (!a.isCorrect) continue;
    sum += a.responseTimeMs < kFastThresholdMs ? 2 : 1;
  }
  return sum;
}

/// Exact per-game feedback message (ported from web generateGameFeedback).
String gameFeedback(int gameType, List<GameResponse> answers) {
  const labels = ['', 'quantitative reasoning', 'verbal reasoning', 'spatial reasoning', 'abstract reasoning'];
  final label = labels[gameType];
  final score = weightedScore(answers);
  final correctCount = answers.where((a) => a.isCorrect).length;
  final allCorrect = correctCount == 4;
  final avg = answers.isEmpty
      ? 0
      : answers.map((a) => a.responseTimeMs).reduce((a, b) => a + b) / answers.length;
  final fast = avg < kFastThresholdMs;

  String cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  if (score >= 7) {
    return 'Exceptional $label — you were both fast and accurate. This is natural '
        'fluency, not just learned skill. Careers that demand quick $label under '
        'pressure would suit you well.';
  } else if (score >= 5) {
    if (allCorrect && !fast) {
      return 'Strong $label — you got everything right but took your time. Accuracy '
          'is there; fluency is still building. You\'d do well in roles where '
          'precision matters more than speed.';
    }
    return 'Good $label — solid accuracy with decent pace. You can handle careers '
        'that rely on this skill, though high-pressure, fast-turnaround roles may '
        'need more practice.';
  } else if (score >= 3) {
    if (correctCount >= 3 && !fast) {
      return 'Moderate $label — you\'re accurate but slow. That tells us this doesn\'t '
          'come naturally yet — you\'re working it out rather than seeing it '
          'instantly. Careers requiring this skill are still possible with '
          'deliberate practice.';
    }
    return 'Developing $label — some correct answers but inconsistent. This isn\'t a '
        'natural strength right now. We\'ll weight your other aptitude scores more '
        'heavily in recommendations.';
  }
  return '${cap(label)} isn\'t your natural strength — that\'s honest data. Many '
      'successful careers don\'t depend on this skill. Your other scores will carry '
      'more weight in your recommendations.';
}
