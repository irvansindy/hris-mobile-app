class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, String> fieldErrors;
  final int? retryAfterSeconds;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
