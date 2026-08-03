/// App-wide configuration.
///
/// The backend runs on your laptop (dev-only). Reach it from:
///   - Android emulator:  http://10.0.2.2:8080   (default below)
///   - Physical Android:  `http://<your-LAN-IP>:8080`
///
/// Override at run time without editing code:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8080
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Network timeout for normal requests.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// AI generation endpoints can be slow (live Gemini calls).
  static const Duration aiTimeout = Duration(seconds: 120);
}
