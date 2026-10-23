import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';

void main() {
  test('maps validation error and retains field messages', () {
    final failure = mapApiException(
      const ApiException(
        'Validation failed',
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        fieldErrors: {'email': 'Invalid email format'},
      ),
    );

    expect(failure, isA<ValidationFailure>());
    expect(
      (failure as ValidationFailure).fieldErrors['email'],
      'Invalid email format',
    );
  });

  test('maps token expiry to authentication failure', () {
    final failure = mapApiException(
      const ApiException('Expired', statusCode: 401, code: 'TOKEN_EXPIRED'),
    );

    expect(failure, isA<AuthenticationFailure>());
  });

  for (final code in ['PAYROLL_UNLOCK_REQUIRED', 'PAYROLL_REAUTH_FAILED']) {
    test('keeps payroll 401 $code outside session authentication', () {
      final failure = mapApiException(
        ApiException(
          'Payroll verification required',
          statusCode: 401,
          code: code,
        ),
      );

      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).code, code);
      expect(failure.statusCode, 401);
    });
  }

  for (final code in [
    'PAYSLIP_PIN_REAUTH_FAILED',
    'PAYSLIP_PIN_INVALID',
    'PAYSLIP_PIN_NOT_SET',
    'PAYSLIP_UNLOCK_INVALID',
    'PAYSLIP_PDF_TOO_LARGE',
    'PAYSLIP_PIN_LOCKED',
  ]) {
    test('preserves employee payslip error $code for feature recovery', () {
      final failure = mapApiException(
        ApiException('Payslip failure', statusCode: 403, code: code),
      );

      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).code, code);
    });
  }

  test('preserves rate-limit retry duration for user-facing recovery', () {
    final request = RequestOptions(path: '/attendance/me/check-in');
    final exception = mapDioException(
      DioException(
        requestOptions: request,
        response: Response<dynamic>(
          requestOptions: request,
          statusCode: 429,
          data: {
            'success': false,
            'code': 'TOO_MANY_REQUESTS',
            'message': 'Terlalu banyak percobaan verifikasi wajah.',
          },
          headers: Headers.fromMap({
            'retry-after': ['300'],
          }),
        ),
      ),
    );

    final failure = mapApiException(exception);

    expect(failure, isA<RateLimitFailure>());
    expect((failure as RateLimitFailure).retryAfterSeconds, 300);
    expect(failure.message, contains('5 menit'));
  });
}
