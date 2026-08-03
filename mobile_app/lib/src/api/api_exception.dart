/// Thrown when a backend call fails at the transport level or returns
/// `{success: false}`.
///
/// The backend now returns real HTTP statuses for AI failures, so callers can
/// tell "busy, try again shortly" (429/503, [retryable] == true) apart from
/// "your input was rejected" (400, [retryable] == false).
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.retryable = false,
  });

  final String message;
  final int? statusCode;

  /// Machine-readable reason from the backend, e.g. `quota_exhausted`,
  /// `unavailable`, `bad_request`.
  final String? code;

  /// True when retrying the same request later could succeed.
  final bool retryable;

  /// The AI service is busy / out of quota — a wait-and-retry situation.
  bool get isBusy => statusCode == 429 || statusCode == 503;

  @override
  String toString() => message;
}
