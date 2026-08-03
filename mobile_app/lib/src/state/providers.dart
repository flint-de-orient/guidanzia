import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/career_recommendation.dart';
import '../models/questionnaire_data.dart';
import '../services/storage_service.dart';

/// Shared singletons.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final storageProvider = Provider<StorageService>((ref) => StorageService());

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class AuthUser {
  const AuthUser({required this.username, required this.name});
  final String username;
  final String name;
}

class AuthState {
  const AuthState({this.user, this.loading = true});
  final AuthUser? user;
  final bool loading;

  bool get isAuthenticated => user != null;

  AuthState copyWith({AuthUser? user, bool? loading, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _restore();
  }

  final Ref _ref;
  ApiClient get _api => _ref.read(apiClientProvider);
  StorageService get _storage => _ref.read(storageProvider);

  Future<void> _restore() async {
    final saved = await _storage.readUser();
    state = AuthState(
      user: saved == null
          ? null
          : AuthUser(username: saved.username, name: saved.name),
      loading: false,
    );
  }

  Future<void> login(String username, String password) async {
    final res = await _api.login(username, password);
    await _storage.saveUser(username, res.name);
    state = AuthState(
      user: AuthUser(username: username, name: res.name),
      loading: false,
    );
  }

  Future<void> signup(String username, String password) async {
    await _api.signup(username, password);
    // Auto-login after successful signup.
    await login(username, password);
  }

  /// Reflect a profile-name change locally (after `/api/update-profile`).
  Future<void> updateName(String name) async {
    final user = state.user;
    if (user == null) return;
    await _storage.saveUser(user.username, name);
    state = AuthState(
      user: AuthUser(username: user.username, name: name),
      loading: false,
    );
  }

  Future<void> logout() async {
    final username = state.user?.username;
    if (username != null) await _api.logout(username);
    await _storage.clearUser();
    // Wipe the saved assessment so the next user starts clean.
    await _storage.clearAssessment();
    _ref.read(assessmentStatusProvider.notifier).reset();
    _ref.invalidate(questionnaireProvider);
    state = const AuthState(user: null, loading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);

// ---------------------------------------------------------------------------
// Assessment (shared across onboarding → questionnaire → games)
// ---------------------------------------------------------------------------

/// A single mutable [QuestionnaireData] shared for the duration of the
/// assessment flow. Screens mutate it directly, then it is saved at the end.
final questionnaireProvider = Provider<QuestionnaireData>((ref) {
  return QuestionnaireData();
});

/// Where the user currently is in the assessment funnel. Drives the "Resume"
/// entry point on Home and the primary-CTA label. Held in memory only
/// (within-session) — a crash or app-kill restarts the assessment.
enum AssessmentStage { none, onboarding, questionnaire, games }

class AssessmentStatus {
  const AssessmentStatus({
    this.stage = AssessmentStage.none,
    this.completed = false,
    this.questionIndex = 0,
    this.gameIndex = 1,
  });

  /// The furthest stage currently in progress (none = nothing started).
  final AssessmentStage stage;

  /// True once the user has finished at least one assessment. Permanent for
  /// the session — a completed user always keeps the full four-tab nav, even
  /// while re-taking.
  final bool completed;

  /// Resume pointers (in-memory). Where to re-enter the questionnaire (exact
  /// question, since it is not timed) and the games (which game — the current
  /// game restarts with its timer reset, per the resume rule).
  final int questionIndex;
  final int gameIndex;

  bool get inProgress => stage != AssessmentStage.none;

  AssessmentStatus copyWith({
    AssessmentStage? stage,
    bool? completed,
    int? questionIndex,
    int? gameIndex,
  }) =>
      AssessmentStatus(
        stage: stage ?? this.stage,
        completed: completed ?? this.completed,
        questionIndex: questionIndex ?? this.questionIndex,
        gameIndex: gameIndex ?? this.gameIndex,
      );
}

class AssessmentStatusNotifier extends StateNotifier<AssessmentStatus> {
  AssessmentStatusNotifier() : super(const AssessmentStatus());

  /// Mark the user as being at [stage] of an in-progress assessment.
  void enter(AssessmentStage stage) =>
      state = state.copyWith(stage: stage);

  /// Remember the current questionnaire position so Resume returns to it.
  void setQuestionIndex(int index) =>
      state = state.copyWith(questionIndex: index);

  /// Remember which game the user is on (1-4) for Resume.
  void setGameIndex(int index) => state = state.copyWith(gameIndex: index);

  /// Assessment finished — clear in-progress, reset pointers, flip completed.
  void finish() => state = state.copyWith(
        stage: AssessmentStage.none,
        completed: true,
        questionIndex: 0,
        gameIndex: 1,
      );

  /// A returning user already has results (e.g. recommendations loaded) — treat
  /// them as completed so they get the full nav, without a fresh run.
  void markCompleted() {
    if (!state.completed) state = state.copyWith(completed: true);
  }

  /// Abandon the in-progress run without marking complete (old results, if any,
  /// stay intact — this only clears the in-progress pointer).
  void abandon() => state = state.copyWith(stage: AssessmentStage.none);

  /// Restore a previously-persisted assessment state (after an app restart).
  void restore({
    required AssessmentStage stage,
    required bool completed,
    required int questionIndex,
    required int gameIndex,
  }) {
    state = AssessmentStatus(
      stage: stage,
      completed: completed,
      questionIndex: questionIndex,
      gameIndex: gameIndex,
    );
  }

  /// Wipe all assessment state (on logout).
  void reset() => state = const AssessmentStatus();
}

final assessmentStatusProvider =
    StateNotifierProvider<AssessmentStatusNotifier, AssessmentStatus>(
  (ref) => AssessmentStatusNotifier(),
);

/// The currently-selected tab in the logged-in shell. Held in a provider (not
/// local shell state) so a tab tapped from a pushed assessment screen can set
/// it and return to the shell.
final shellTabProvider = StateProvider<int>((ref) => 0);

// ---------------------------------------------------------------------------
// Assessment persistence — survives an accidental app close
// ---------------------------------------------------------------------------

/// Restores any locally-saved in-progress assessment (answers + stage +
/// position) into [questionnaireProvider] / [assessmentStatusProvider].
/// Awaited once at launch so the user never loses their work.
final assessmentRestoreProvider = FutureProvider<void>((ref) async {
  final raw = await ref.read(storageProvider).readAssessment();
  if (raw == null || raw.isEmpty) return;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final qJson = (map['questionnaire'] as Map?)?.cast<String, dynamic>();
    if (qJson != null) ref.read(questionnaireProvider).applyJson(qJson);

    final stageName = map['stage'] as String?;
    final stage = AssessmentStage.values.firstWhere(
      (s) => s.name == stageName,
      orElse: () => AssessmentStage.none,
    );
    ref.read(assessmentStatusProvider.notifier).restore(
          stage: stage,
          completed: map['completed'] == true,
          questionIndex: (map['questionIndex'] as num?)?.toInt() ?? 0,
          gameIndex: (map['gameIndex'] as num?)?.toInt() ?? 1,
        );
  } catch (_) {
    // Corrupt payload — ignore and start fresh rather than crash.
  }
});

/// Persists the current assessment (answers + progress) to local storage.
/// Call after each answered question and after each game.
Future<void> persistAssessment(WidgetRef ref) async {
  final q = ref.read(questionnaireProvider);
  final st = ref.read(assessmentStatusProvider);
  final payload = jsonEncode({
    'questionnaire': q.toJson(),
    'stage': st.stage.name,
    'completed': st.completed,
    'questionIndex': st.questionIndex,
    'gameIndex': st.gameIndex,
  });
  await ref.read(storageProvider).saveAssessment(payload);
}

/// Clears the locally-saved assessment (after a successful server save, or on
/// logout).
Future<void> clearPersistedAssessment(WidgetRef ref) async {
  await ref.read(storageProvider).clearAssessment();
}

// ---------------------------------------------------------------------------
// Locale
// ---------------------------------------------------------------------------

class LocaleNotifier extends StateNotifier<String> {
  LocaleNotifier(this._ref) : super('en') {
    _restore();
  }
  final Ref _ref;

  Future<void> _restore() async {
    state = await _ref.read(storageProvider).readLocale();
  }

  Future<void> setLocale(String code) async {
    state = code;
    await _ref.read(storageProvider).saveLocale(code);
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, String>((ref) => LocaleNotifier(ref));

// ---------------------------------------------------------------------------
// Theme mode
// ---------------------------------------------------------------------------

/// Boot value, read from storage in `main()` before `runApp` and injected via a
/// ProviderScope override. Seeding synchronously avoids a light→dark flash for
/// a returning dark-mode user (the Flutter analogue of a no-FOUC script).
final bootThemeModeProvider = Provider<ThemeMode>((_) => ThemeMode.light);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._ref) : super(_ref.read(bootThemeModeProvider));
  final Ref _ref;

  Future<void> toggle() =>
      setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _ref
        .read(storageProvider)
        .saveThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
        (ref) => ThemeModeNotifier(ref));

// ---------------------------------------------------------------------------
// Recommendations
// ---------------------------------------------------------------------------

/// Fetches the top-3 careers for the logged-in user. Auto-runs once; call
/// `ref.invalidate(recommendationsProvider)` to regenerate.
final recommendationsProvider =
    FutureProvider<List<CareerRecommendation>>((ref) async {
  final auth = ref.watch(authProvider);
  final username = auth.user?.username;
  if (username == null) return [];
  return ref.read(apiClientProvider).getTop3Careers(username);
});
