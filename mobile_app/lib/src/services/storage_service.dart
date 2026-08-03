import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the logged-in user (securely) and lightweight preferences.
///
/// TECH DEBT (deferred, see MOBILE_APP_NOTES.md): the backend still stores
/// passwords in plaintext and has no real token/session. We store only the
/// username locally; there is no bearer token to protect yet.
class StorageService {
  static const _kUsername = 'edubot_username';
  static const _kName = 'edubot_name';
  static const _kLocale = 'edubot_locale';
  static const _kThemeMode = 'edubot_theme_mode';
  static const _kAssessment = 'edubot_assessment';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveUser(String username, String name) async {
    await _secure.write(key: _kUsername, value: username);
    await _secure.write(key: _kName, value: name);
  }

  Future<({String username, String name})?> readUser() async {
    // Secure storage sits on the Android Keystore, which can hang or throw on
    // some devices (e.g. after a reinstall corrupts the keystore blob). Never
    // let that freeze app start: cap the read and, on any failure, treat the
    // user as logged out rather than blocking the loading screen forever.
    try {
      const limit = Duration(seconds: 4);
      final username =
          await _secure.read(key: _kUsername).timeout(limit);
      if (username == null || username.isEmpty) return null;
      final name =
          (await _secure.read(key: _kName).timeout(limit)) ?? username;
      return (username: username, name: name);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    await _secure.delete(key: _kUsername);
    await _secure.delete(key: _kName);
  }

  Future<void> saveLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, code);
  }

  Future<String> readLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLocale) ?? 'en';
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode);
  }

  /// Returns 'light' or 'dark'. Defaults to 'light' (product default) rather
  /// than following the OS, per product decision.
  Future<String> readThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kThemeMode) ?? 'light';
  }

  // ---------------------------------------------------------------- assessment
  // In-progress assessment (answers + stage + position), persisted so that an
  // accidental app close does not destroy the user's work.

  Future<void> saveAssessment(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAssessment, json);
  }

  Future<String?> readAssessment() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAssessment);
  }

  Future<void> clearAssessment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAssessment);
  }
}
