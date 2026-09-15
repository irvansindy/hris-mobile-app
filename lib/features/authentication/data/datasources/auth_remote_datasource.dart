import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/platform_http.dart';
import 'package:hrm_app/core/security/cookie_session.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/authentication/data/dto/auth_session_dto.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthSessionDto> login({
    required String email,
    required String password,
    String? totp,
  });
  Future<Map<String, dynamic>> me();
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> logout({String? refreshToken, Map<String, String>? headers});
}

class DioAuthRemoteDataSource implements AuthRemoteDataSource {
  const DioAuthRemoteDataSource(this._dio, {this._lifecycle});
  final Dio _dio;
  final SessionLifecycle? _lifecycle;

  Options get _options => Options(
    extra: {if (_lifecycle != null) 'sessionRevision': _lifecycle.revision},
  );

  @override
  Future<AuthSessionDto> login({
    required String email,
    required String password,
    String? totp,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          if (totp != null && totp.trim().isNotEmpty) 'totp': totp.trim(),
        },
        options: Options(
          headers: {if (!usesBrowserCookieStore) 'X-Client-Type': 'mobile'},
          extra: _options.extra,
        ),
      );
      return AuthSessionDto.fromLoginJson(
        ApiEnvelope.fromJson(response.data ?? const {}).requireObjectData(),
        authCookie: usesBrowserCookieStore
            ? cookieHeaderFromResponse(response.headers)
            : null,
        authSetCookies: usesBrowserCookieStore
            ? setCookieHeadersFromResponse(response.headers)
            : const [],
        assumeBrowserCookieAuth: usesBrowserCookieStore,
        requireBearerTokens: !usesBrowserCookieStore,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/auth/change-password',
        data: {'oldPassword': currentPassword, 'newPassword': newPassword},
        options: _options,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<Map<String, dynamic>> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/auth/me',
        options: _options,
      );
      return ApiEnvelope.fromJson(
        response.data ?? const {},
      ).requireObjectData();
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<void> logout({
    String? refreshToken,
    Map<String, String>? headers,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/auth/logout',
        data: refreshToken == null ? null : {'refreshToken': refreshToken},
        options: Options(
          headers: headers,
          extra: {'logoutSnapshot': true},
          followRedirects: false,
        ),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
