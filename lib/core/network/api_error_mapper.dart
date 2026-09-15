import 'package:dio/dio.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/network/api_exception.dart';

ApiException mapDioException(DioException error) {
  final body = error.response?.data;
  final json = body is Map<String, dynamic> ? body : const <String, dynamic>{};
  final errors = <String, String>{};
  final rawErrors = json['errors'];
  if (rawErrors is List) {
    for (final item in rawErrors.whereType<Map>()) {
      final field = item['field'];
      final message = item['message'];
      if (field is String && message is String) errors[field] = message;
    }
  }
  return ApiException(
    json['message'] as String? ?? _networkMessage(error.type),
    statusCode: error.response?.statusCode,
    code:
        json['code'] as String? ??
        switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.connectionError => 'NETWORK_ERROR',
          _ => null,
        },
    fieldErrors: errors,
    retryAfterSeconds: _retryAfterSeconds(error, json),
  );
}

Failure mapApiException(ApiException error) => switch (error.code) {
  'NETWORK_ERROR' => NetworkFailure(error.message),
  'AUTHENTICATION_FAILED' ||
  'TOKEN_EXPIRED' ||
  'MFA_REQUIRED' => AuthenticationFailure(error.message, code: error.code),
  'FORBIDDEN' => ForbiddenFailure(error.message),
  'VALIDATION_ERROR' => ValidationFailure(
    error.message,
    fieldErrors: error.fieldErrors,
  ),
  'TOO_MANY_REQUESTS' => _rateLimitFailure(error),
  _ when error.statusCode == 401 => AuthenticationFailure(
    error.message,
    code: error.code,
  ),
  _ when error.statusCode == 403 => ForbiddenFailure(error.message),
  _ when error.statusCode == 422 => ValidationFailure(
    error.message,
    fieldErrors: error.fieldErrors,
  ),
  _ when error.statusCode == 429 => _rateLimitFailure(error),
  _ => ServerFailure(
    error.message,
    statusCode: error.statusCode,
    code: error.code,
    fieldErrors: error.fieldErrors,
  ),
};

RateLimitFailure _rateLimitFailure(ApiException error) {
  final seconds = error.retryAfterSeconds;
  final suffix = seconds == null
      ? ''
      : ' Coba lagi dalam ${_durationLabel(seconds)}.';
  return RateLimitFailure(
    '${error.message}$suffix',
    retryAfterSeconds: seconds,
  );
}

int? _retryAfterSeconds(DioException error, Map<String, dynamic> json) {
  final data = json['data'];
  final nested = data is Map<String, dynamic>
      ? data
      : const <String, dynamic>{};
  for (final value in [
    json['retryAfterSeconds'],
    json['retryAfter'],
    nested['retryAfterSeconds'],
    nested['retryAfter'],
    error.response?.headers.value('retry-after'),
  ]) {
    if (value is num && value >= 0) return value.ceil();
    if (value is String) {
      final seconds = num.tryParse(value);
      if (seconds != null && seconds >= 0) return seconds.ceil();
      final date = DateTime.tryParse(value)?.toUtc();
      if (date != null) {
        return date
            .difference(DateTime.now().toUtc())
            .inSeconds
            .clamp(0, 86400);
      }
    }
  }
  return null;
}

String _durationLabel(int seconds) {
  if (seconds < 60) return '$seconds detik';
  final minutes = (seconds / 60).ceil();
  return '$minutes menit';
}

String _networkMessage(DioExceptionType type) => switch (type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout => 'Koneksi ke server habis waktu.',
  DioExceptionType.connectionError => 'Tidak dapat terhubung ke server.',
  _ => 'Terjadi kesalahan pada layanan HRMS.',
};
