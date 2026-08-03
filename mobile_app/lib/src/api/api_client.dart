import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/career_recommendation.dart';
import '../models/onboarding_data.dart';
import '../models/questionnaire_data.dart';
import 'api_exception.dart';

/// Thin, typed wrapper over the Flask backend. Mirrors the existing REST
/// contract exactly — the web app and this app share the same endpoints.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _base = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _base;

  Uri _uri(String path) => Uri.parse('$_base$path');

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    http.Response res;
    try {
      res = await _client
          .post(
            _uri(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout ?? AppConfig.requestTimeout);
    } catch (e) {
      throw ApiException(
        'Cannot reach the server. Is the backend running and the API URL correct?\n($e)',
      );
    }

    // Parse the body FIRST — the backend sends a structured, human-readable
    // reason with its error statuses (429 quota / 503 unavailable / 400 bad
    // prompt). Throwing a generic "Server error" before parsing would discard it.
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      json = null;
    }

    if (res.statusCode >= 400) {
      final message = (json?['message'] as String?) ??
          switch (res.statusCode) {
            429 => 'The AI service is busy. Please try again in a minute.',
            503 => 'The AI service is temporarily unavailable. Please try again shortly.',
            400 => 'The server rejected this request.',
            _ => 'Server error (${res.statusCode}).',
          };
      throw ApiException(
        message,
        statusCode: res.statusCode,
        code: json?['code'] as String?,
        retryable: (json?['retryable'] as bool?) ??
            (res.statusCode == 429 || res.statusCode >= 500),
      );
    }

    if (json == null) {
      throw ApiException('Unexpected response from server.',
          statusCode: res.statusCode);
    }
    return json;
  }

  // ---- Auth ----

  Future<({String name, String? profileImage})> login(
      String username, String password) async {
    final json = await _post('/login', {
      'username': username,
      'password': password,
    });
    if (json['success'] != true) {
      throw ApiException((json['message'] ?? 'Login failed').toString());
    }
    return (
      name: (json['name'] ?? username).toString(),
      profileImage: json['profileImage']?.toString(),
    );
  }

  Future<void> signup(String username, String password) async {
    final json = await _post('/signup', {
      'username': username,
      'password': password,
    });
    if (json['success'] != true) {
      throw ApiException((json['message'] ?? 'Signup failed').toString());
    }
  }

  Future<void> logout(String username) async {
    try {
      await _post('/logout', {'username': username});
    } catch (_) {
      // Best-effort; local logout proceeds regardless.
    }
  }

  // ---- Profile ----

  /// Update the user's display name and/or password (`/api/update-profile`).
  /// A password change requires [currentPassword] to match on the server.
  Future<void> updateProfile({
    required String username,
    String? name,
    String? currentPassword,
    String? newPassword,
  }) async {
    final json = await _post('/api/update-profile', {
      'username': username,
      'name': ?name,
      'currentPassword': ?currentPassword,
      'newPassword': ?newPassword,
    });
    if (json['success'] != true) {
      throw ApiException(
          (json['message'] ?? 'Failed to update profile').toString());
    }
  }

  // ---- Job-role report cache (server-side, avoids regenerating AI sections) ----

  /// Persist already-generated report sections (`/api/save-job-role`).
  /// [detailData] is keyed by the backend's camelCase section names.
  Future<void> saveJobRole({
    required String username,
    required String roleId,
    required String roleTitle,
    required Map<String, dynamic> detailData,
  }) async {
    final json = await _post('/api/save-job-role', {
      'username': username,
      'roleId': roleId,
      'roleTitle': roleTitle,
      'detailData': detailData,
    });
    if (json['success'] != true) {
      throw ApiException(
          (json['message'] ?? 'Failed to save job role').toString());
    }
  }

  /// Load previously-generated report sections for a role, or null if the
  /// server has none cached for it (`/api/load-job-role`).
  Future<Map<String, dynamic>?> loadJobRole({
    required String username,
    required String roleId,
  }) async {
    final json = await _post('/api/load-job-role', {
      'username': username,
      'roleId': roleId,
    });
    if (json['success'] != true) return null;
    final detail = json['detail'];
    if (detail is Map) return detail.cast<String, dynamic>();
    return null;
  }

  // ---- Onboarding ----

  Future<void> saveOnboarding(String username, OnboardingData data) async {
    final json = await _post('/api/save-onboarding', data.toRequest(username));
    if (json['success'] != true) {
      throw ApiException((json['message'] ?? 'Failed to save onboarding').toString());
    }
  }

  Future<OnboardingData?> getOnboarding(String username) async {
    final json = await _post('/api/get-onboarding', {'username': username});
    if (json['success'] != true) return null;
    final data = json['data'];
    if (data is Map<String, dynamic>) return OnboardingData.fromJson(data);
    return null;
  }

  // ---- Questionnaire / assessment ----

  Future<void> saveQuestionnaire(String username, QuestionnaireData q) async {
    final json = await _post('/api/save-questionnaire', q.toRequest(username));
    if (json['success'] != true) {
      throw ApiException((json['message'] ?? 'Failed to save assessment').toString());
    }
  }

  /// Per-module personalised feedback ("Here's what we noticed").
  Future<String> generateModuleFeedback({
    required int moduleNumber,
    required Map<String, dynamic> answersSoFar,
  }) async {
    final json = await _post('/api/generate-module-feedback', {
      'module_number': moduleNumber,
      'answers_so_far': answersSoFar,
    }, timeout: AppConfig.aiTimeout);
    if (json['success'] != true) {
      throw ApiException((json['error'] ?? 'Failed to generate feedback').toString());
    }
    return (json['feedback'] ?? '').toString();
  }

  /// Word Sense game items are generated by the backend.
  Future<Map<String, dynamic>> generateWordItem({
    required String itemType,
    required int difficulty,
    String language = 'English',
  }) async {
    final json = await _post('/api/generate-word-item', {
      'item_type': itemType,
      'difficulty': difficulty,
      'language': language,
    }, timeout: AppConfig.aiTimeout);
    if (json['success'] != true) {
      throw ApiException((json['error'] ?? 'Failed to generate item').toString());
    }
    return (json['item'] as Map).cast<String, dynamic>();
  }

  /// Game 5, Task 3 — the three cipher tiers (examples + test message + valid
  /// answers). Answers are re-derived server-side at validation time.
  Future<Map<String, dynamic>> generateCipherQuestions() async {
    final json = await _post('/api/generate-cipher-questions', {},
        timeout: AppConfig.aiTimeout);
    if (json['success'] != true) {
      throw ApiException((json['error'] ?? 'Failed to load the cipher').toString());
    }
    return (json['questions'] as Map).cast<String, dynamic>();
  }

  /// Tier-3 word check — is the student's anagram a real English word?
  Future<bool> validateWord(String word) async {
    try {
      final json = await _post('/api/validate-word', {'word': word});
      return json['valid'] == true;
    } catch (_) {
      return false;
    }
  }

  // ---- Recommendations ----

  Future<List<CareerRecommendation>> getTop3Careers(String username) async {
    final json = await _post(
      '/api/get-top-3-careers',
      {'username': username},
      timeout: AppConfig.aiTimeout,
    );
    if (json['success'] != true) {
      throw ApiException((json['message'] ?? 'Failed to generate recommendations').toString());
    }
    final list = (json['careers'] as List? ?? []);
    return list
        .map((e) => CareerRecommendation.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// The Mindset Report — a full psychometric profile synthesised from the
  /// assessment (motivation, cognitive style, academic, aptitude, etc.).
  Future<Map<String, dynamic>> getMindsetReport(String username) async {
    final json = await _post(
      '/api/get-mindset-report',
      {'username': username},
      timeout: AppConfig.aiTimeout,
    );
    if (json['success'] != true) {
      throw ApiException((json['message'] ?? 'Failed to load report').toString());
    }
    final report = json['report'];
    if (report is Map) return report.cast<String, dynamic>();
    return {};
  }

  // ---- Career report (per-section AI content) ----

  Future<Map<String, dynamic>> getCareerSection({
    required String careerTitle,
    required String sectionType,
    required Map<String, dynamic> profile,
  }) async {
    final json = await _post('/api/career-details', {
      'career_title': careerTitle,
      'section_type': sectionType,
      'profile': profile,
    }, timeout: AppConfig.aiTimeout);
    if (json['success'] != true) {
      throw ApiException((json['error'] ?? 'Failed to load section').toString());
    }
    final content = json['content'];
    if (content is Map) return content.cast<String, dynamic>();
    return {};
  }

  // ---- Translation (AI-generated content only) ----

  Future<String> translate(String text, String target, {String source = 'en'}) async {
    if (text.trim().isEmpty || target == source) return text;
    final json = await _post('/api/translate', {
      'text': text,
      'target_language': target,
      'source_language': source,
    });
    return (json['translated_text'] ?? text).toString();
  }

  Future<List<String>> translateBatch(
      List<String> texts, String target, {String source = 'en'}) async {
    if (texts.isEmpty || target == source) return texts;
    final json = await _post('/api/translate-batch', {
      'texts': texts,
      'target_language': target,
      'source_language': source,
    });
    final result = json['translations'];
    if (result is List) return result.map((e) => e.toString()).toList();
    return texts;
  }

  void dispose() => _client.close();
}
