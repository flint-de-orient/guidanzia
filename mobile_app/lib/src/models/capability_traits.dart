import 'questionnaire_data.dart';

/// Client-side capability/trait derivation — turns data the app already has
/// (aptitude game scores, or the answers given so far) into a small set of
/// human trait labels. No backend call: these are computed from the user's own
/// answers, so the trait chips in the module-insight card, the results strengths
/// row and the career-report summary stay honest.

const _aptitudeLabels = <String, String>{
  'number': 'Numerical',
  'word': 'Verbal',
  'shape': 'Creative',
  'logic': 'Analytical',
};

/// The user's top two strengths from the four aptitude scores (0-8 each).
/// Returns `[]` when fewer than two dimensions are present (e.g. games not done
/// yet), so callers can simply hide the row. Deterministic: ties break by the
/// fixed dimension order below.
List<String> strengthsFromAptitude({int? number, int? word, int? shape, int? logic}) {
  final scored = <MapEntry<String, int>>[];
  void add(String key, int? v) {
    if (v != null) scored.add(MapEntry(_aptitudeLabels[key]!, v));
  }

  add('number', number);
  add('word', word);
  add('shape', shape);
  add('logic', logic);

  if (scored.length < 2) return const [];
  scored.sort((a, b) => b.value.compareTo(a.value));
  return scored.take(2).map((e) => e.key).toList();
}

/// Same as [strengthsFromAptitude] but reading the mindset-report `aptitude`
/// map shape (`numberSense` / `wordSense` / `shapeSense` / `logicSense`).
List<String> strengthsFromReportAptitude(Map<String, dynamic> aptitude) {
  int? asInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v');
  return strengthsFromAptitude(
    number: asInt(aptitude['numberSense']),
    word: asInt(aptitude['wordSense']),
    shape: asInt(aptitude['shapeSense']),
    logic: asInt(aptitude['logicSense']),
  );
}

/// Up to three trait labels inferred from the answers given so far — used mid
/// assessment (module-insight card) where aptitude scores don't exist yet.
/// Reads a few high-signal single-choice fields and maps their answer codes to
/// plain trait words; deduped and capped at three.
List<String> traitsFromAnswers(QuestionnaireData q) {
  final out = <String>[];
  void add(String t) {
    if (!out.contains(t)) out.add(t);
  }

  switch (q.fiveYearVision) {
    case 'conventional':
      add('Focused');
    case 'enterprising':
      add('Leader');
    case 'artistic':
      add('Creative');
    case 'entrepreneurial':
      add('Independent');
  }
  switch (q.freeSunday) {
    case 'puzzle':
      add('Analytical');
    case 'friends':
      add('Social');
    case 'create':
      add('Creative');
    case 'build':
      add('Hands-on');
    case 'organize':
      add('Organised');
    case 'read':
      add('Curious');
  }
  switch (q.groupRole) {
    case 'plan':
      add('Organiser');
    case 'research':
      add('Analytical');
    case 'present':
      add('Communicator');
    case 'motivate':
      add('Collaborative');
    case 'execute':
      add('Doer');
  }
  switch (q.studyExperience) {
    case 'flow':
      add('Focused');
    case 'videos':
      add('Visual learner');
  }

  return out.take(3).toList();
}
