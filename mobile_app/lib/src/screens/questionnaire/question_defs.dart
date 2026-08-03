import 'package:flutter/material.dart';

/// Exact Module 1-6 questionnaire ported verbatim from the web
/// `onboarding-new.tsx` — same wording, options (value codes), order and
/// input types, so the mobile assessment matches the web system 1:1.

enum QKind { single, multi, text, marks }

class QOption {
  const QOption(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

class Question {
  const Question({
    required this.number,
    required this.module,
    required this.field,
    required this.title,
    this.note,
    required this.kind,
    this.options = const [],
    this.maxSelect = 1,
    this.minSelect = 1,
    this.optional = false,
    this.maxLen = 50,
    this.placeholder = '',
    this.ranked = false,
  });

  final int number; // 1..20
  final int module; // 1..6
  final String field; // logical field name in QuestionnaireData
  final String title;
  final String? note; // e.g. "Optional", "Select up to 3"
  final QKind kind;
  final List<QOption> options;
  final int maxSelect;
  final int minSelect;
  final bool optional;
  final int maxLen;
  final String placeholder;
  final bool ranked;
}

const moduleTitles = <int, String>{
  1: 'Opening Questions',
  2: 'How Your Mind Works',
  3: "What You're Actually Good At",
  4: 'Life Outside Marks',
  5: 'The Constraints',
  6: 'The Final Calibration',
};

const _subjects = [
  'Physics', 'Chemistry', 'Biology', 'Mathematics',
  'English', 'Bengali', 'Computer Science', 'Economics',
  'Geography', 'History', 'Political Science', 'Accountancy',
];

List<QOption> _subjectOptions() =>
    _subjects.map((s) => QOption(s, s, Icons.menu_book_outlined)).toList();

const kQuestions = <Question>[
  // ---------------- Module 1 ----------------
  Question(
    number: 1, module: 1, field: 'whyHere',
    title: 'Why are you here today?',
    kind: QKind.single,
    options: [
      QOption('no-idea', 'I have no idea what to do after class 12', Icons.help_outline),
      QOption('validate', "I have a plan but want to check if it's right", Icons.check_circle_outline),
      QOption('disagree', 'My parents and I disagree about my career', Icons.person_outline),
      QOption('explore', 'I want to explore options before deciding', Icons.track_changes_outlined),
    ],
  ),
  Question(
    number: 2, module: 1, field: 'fiveYearVision',
    title: 'When you imagine yourself five years from now, which feels closest?',
    kind: QKind.single,
    options: [
      QOption('conventional', 'Wearing a uniform or lab coat, doing focused expert work', Icons.work_outline),
      QOption('enterprising', 'Leading a team, presenting ideas, making decisions', Icons.track_changes_outlined),
      QOption('artistic', 'Creating something — designing, writing, building, performing', Icons.palette_outlined),
      QOption('entrepreneurial', "Running my own thing, even if it's small", Icons.rocket_launch_outlined),
    ],
  ),
  Question(
    number: 3, module: 1, field: 'careerThinking',
    title: "What's the one career you've been thinking about most?",
    note: 'Optional', kind: QKind.text, optional: true, maxLen: 50,
    placeholder: 'e.g., Doctor, Software Engineer, Designer...',
  ),
  Question(
    number: 4, module: 1, field: 'careerRuledOut',
    title: "And one career you've ruled out?",
    note: 'Optional', kind: QKind.text, optional: true, maxLen: 50,
    placeholder: 'e.g., Engineering, Medicine, Teaching...',
  ),

  // ---------------- Module 2 ----------------
  Question(
    number: 5, module: 2, field: 'freeSunday',
    title: 'You have a free Sunday. Which sounds most fun?',
    kind: QKind.single,
    options: [
      QOption('puzzle', 'Solving a tricky puzzle or strategy game', Icons.lightbulb_outline),
      QOption('friends', 'Hanging out with friends and meeting new people', Icons.groups_outlined),
      QOption('create', 'Making something — drawing, music, video, writing', Icons.palette_outlined),
      QOption('build', 'Fixing or building something with your hands', Icons.handyman_outlined),
      QOption('organize', 'Organizing my room, my notes, my life', Icons.dashboard_customize_outlined),
      QOption('read', 'Reading about how the world works', Icons.menu_book_outlined),
    ],
  ),
  Question(
    number: 6, module: 2, field: 'groupRole',
    title: 'A group project lands in your lap. Without thinking, which role do you grab?',
    kind: QKind.single,
    options: [
      QOption('plan', 'The one who plans and divides the work', Icons.track_changes_outlined),
      QOption('research', 'The one who does the research and analysis', Icons.menu_book_outlined),
      QOption('present', 'The one who makes it look good in the final presentation', Icons.slideshow_outlined),
      QOption('motivate', 'The one who keeps everyone motivated and unstuck', Icons.favorite_outline),
      QOption('execute', 'The one who actually builds or executes it', Icons.build_outlined),
    ],
  ),
  Question(
    number: 7, module: 2, field: 'jobBothers',
    title: 'Which of these would bother you most in a future job?',
    kind: QKind.single,
    options: [
      QOption('repetitive', 'Repeating the same task every day', Icons.repeat),
      QOption('decisions', "Being responsible for big decisions and the blame if they're wrong", Icons.balance_outlined),
      QOption('alone', 'Working alone without much human contact', Icons.person_off_outlined),
      QOption('no-result', 'Not being able to see a clear result of my work', Icons.visibility_outlined),
      QOption('strict-rules', 'Having to follow strict rules and procedures', Icons.shield_outlined),
    ],
  ),

  // ---------------- Module 3 ----------------
  Question(
    number: 8, module: 3, field: 'favoriteSubjects',
    title: 'Pick your three favorite subjects this year',
    note: 'Select up to 3', kind: QKind.multi, maxSelect: 3, minSelect: 1,
  ),
  Question(
    number: 9, module: 3, field: 'difficultSubject',
    title: 'Now pick the subject you find most difficult',
    kind: QKind.single,
  ),
  Question(
    number: 10, module: 3, field: 'subjectMarks',
    title: 'Your marks in the subjects you picked as favorites',
    note: 'Pick the closest band', kind: QKind.marks,
  ),
  Question(
    number: 11, module: 3, field: 'studyExperience',
    title: 'When you study a subject you genuinely enjoy, what happens?',
    kind: QKind.single,
    options: [
      QOption('flow', 'I lose track of time and hours pass', Icons.access_time),
      QOption('work', 'I do well but it still feels like work', Icons.trending_up),
      QOption('class-only', 'I enjoy the class but struggle to study alone', Icons.groups_outlined),
      QOption('videos', 'I prefer learning from videos and discussion over textbooks', Icons.ondemand_video_outlined),
    ],
  ),

  // ---------------- Module 4 ----------------
  Question(
    number: 12, module: 4, field: 'outsideActivities',
    title: 'Outside studies, what do you actually spend time on?',
    note: 'Select up to 3', kind: QKind.multi, maxSelect: 3, minSelect: 1,
    options: [
      QOption('sports', 'Sports / physical activity', Icons.fitness_center),
      QOption('creative', 'Music, art, or creative hobbies', Icons.music_note_outlined),
      QOption('gaming', 'Gaming', Icons.sports_esports_outlined),
      QOption('reading', 'Reading (non-textbook)', Icons.menu_book_outlined),
      QOption('social-media', 'Social media and chatting with friends', Icons.chat_bubble_outline),
      QOption('helping', 'Helping at home, family business, or in the community', Icons.home_outlined),
      QOption('tech', 'Building / coding / experimenting with tech', Icons.code),
      QOption('none', 'Honestly, just studies and rest — no time for hobbies', Icons.coffee_outlined),
    ],
  ),
  Question(
    number: 13, module: 4, field: 'externalValidation',
    title: 'Has anyone ever told you "you\'d be great at ___"?',
    kind: QKind.single,
    options: [
      QOption('agree', 'Yes, and I agree', Icons.thumb_up_outlined),
      QOption('unsure', "Yes, but I'm not sure", Icons.sentiment_neutral_outlined),
      QOption('disagree', "Yes, but I don't want to do that", Icons.thumb_down_outlined),
      QOption('no', 'No, not really', Icons.help_outline),
    ],
  ),
  Question(
    number: 14, module: 4, field: 'selfInitiated',
    title: 'Tell me about something you did in the last year without anyone asking you to',
    note: 'Optional', kind: QKind.text, optional: true, maxLen: 200,
    placeholder: 'e.g., Started a YouTube channel, organized a school event, learned a new skill...',
  ),

  // ---------------- Module 5 ----------------
  Question(
    number: 15, module: 5, field: 'studyLocation',
    title: 'Where are you open to studying?',
    note: 'Select one option', kind: QKind.single,
    options: [
      QOption('kolkata', 'Only Kolkata', Icons.location_on_outlined),
      QOption('west-bengal', 'Anywhere in West Bengal', Icons.map_outlined),
      QOption('india', 'Anywhere in India', Icons.location_on_outlined),
      QOption('abroad', 'Open to studying abroad if it works out', Icons.public),
    ],
  ),
  Question(
    number: 16, module: 5, field: 'familyBudget',
    title: 'Have you talked to your family about the cost of higher education?',
    kind: QKind.single,
    options: [
      QOption('clear-budget', 'Yes, and we have a clear budget', Icons.check_circle_outline),
      QOption('depends', 'Yes, but it depends on the course', Icons.help_outline),
      QOption('not-really', 'Not really', Icons.sentiment_neutral_outlined),
      QOption('no-money-factor', "I'd rather not factor money into this right now", Icons.auto_awesome_outlined),
    ],
  ),
  Question(
    number: 17, module: 5, field: 'careerValues',
    title: 'When you think about your career, which feels most important?',
    note: 'Select your top 2', kind: QKind.multi, maxSelect: 2, minSelect: 2, ranked: true,
    options: [
      QOption('earning', 'Earning well, sooner rather than later', Icons.trending_up),
      QOption('interest', 'Doing work that genuinely interests me', Icons.favorite_outline),
      QOption('family-pride', 'A career my family will be proud of', Icons.emoji_events_outlined),
      QOption('stability', 'Stability and security', Icons.shield_outlined),
      QOption('impact', 'Making a real impact on people or society', Icons.groups_outlined),
    ],
  ),

  // ---------------- Module 6 ----------------
  Question(
    number: 18, module: 6, field: 'planningStyle',
    title: 'Pick the statement that sounds most like you',
    kind: QKind.single,
    options: [
      QOption('clear-plan', "I'd rather have a clear plan and follow it", Icons.description_outlined),
      QOption('options', "I'd rather have options and figure it out as I go", Icons.navigation_outlined),
      QOption('others', "I'd rather have someone tell me what's worked for others", Icons.groups_outlined),
      QOption('try-things', "I'd rather try things and see what fits", Icons.bolt_outlined),
    ],
  ),
  Question(
    number: 19, module: 6, field: 'stressResponse',
    title: 'When something is stressful, what do you usually do?',
    kind: QKind.single,
    options: [
      QOption('power-through', 'Power through and finish it', Icons.bolt_outlined),
      QOption('take-break', 'Take a break and come back to it', Icons.pause_circle_outline),
      QOption('talk', 'Talk to someone about it', Icons.chat_outlined),
      QOption('procrastinate', 'Get overwhelmed and procrastinate, honestly', Icons.trending_down),
    ],
  ),
  Question(
    number: 20, module: 6, field: 'surpriseReaction',
    title: 'Last one — if your career assessment told you something surprising, would you...?',
    kind: QKind.single,
    options: [
      QOption('excited', 'Be excited to explore it', Icons.sentiment_satisfied_outlined),
      QOption('skeptical', 'Be skeptical but curious', Icons.help_outline),
      QOption('wrong', 'Feel like the system got it wrong', Icons.close),
      QOption('counselor', 'Want to talk to a counselor about it', Icons.chat_outlined),
    ],
  ),
];

/// Subject list for Q8 (favorites) and Q9 (difficult).
List<QOption> subjectOptions() => _subjectOptions();

/// Human-readable label for a stored answer code (e.g. 'validate' ->
/// "I have a plan but want to check if it's right"). Used by the Career
/// (Mindset) Report to display coded values. Falls back to the raw code.
String labelForField(String field, String? code) {
  if (code == null || code.isEmpty) return '—';
  for (final q in kQuestions) {
    if (q.field == field) {
      final opts = q.options.isNotEmpty ? q.options : subjectOptions();
      for (final o in opts) {
        if (o.value == code) return o.label;
      }
    }
  }
  return code;
}

/// Maps a list of codes for a field to their labels.
List<String> labelsForField(String field, List<dynamic>? codes) {
  if (codes == null) return const [];
  return codes.map((c) => labelForField(field, c.toString())).toList();
}

/// Label for a marks band code (e.g. '90+' -> 'Above 90').
String labelForMark(String? code) {
  for (final b in marksBands) {
    if (b.value == code) return b.label;
  }
  return code ?? '—';
}

/// Marks bands for Q10.
const marksBands = <QOption>[
  QOption('90+', 'Above 90', Icons.star),
  QOption('80-90', '80-90', Icons.star),
  QOption('70-80', '70-80', Icons.star),
  QOption('60-70', '60-70', Icons.star),
  QOption('below-60', 'Below 60', Icons.star),
];
