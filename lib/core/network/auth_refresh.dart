import 'package:dio/dio.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/network/platform_http.dart';
import 'package:hrm_app/core/security/cookie_session.dart';
import 'package:hrm_app/core/security/session_cookie_store.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/security/token_storage.dart';

class AuthRefreshCoordinator {
  AuthRefreshCoordinator({
    required this.storage,
    required this.lifecycle,
    required this.config,
    required this.cookieStore,
  });

  final TokenStorage storage;
  final SessionLifecycle lifecycle;
  final AppConfig config;
  final SessionCookieStore cookieStore;
  Future<DioException?>? _refreshing;
  int? _revision;
  int _credentialRevision = 0;

  int get credentialRevision => _credentialRevision;

  Future<Map<String, String>> readHeaders(Uri uri, {required String method}) =>
      cookieStore.headersFor(uri, method: method);

  Future<DioException?> refresh(int revision, RequestOptions failedRequest) {
    final active = _refreshing;
    if (active != null && _revision == revision) return active;
    _revision = revision;
    final operation = () async {
      try {
        await _performRefresh(revision, failedRequest);
        return null;
      } on DioException catch (error) {
        return error;
      } catch (error, stack) {
        return DioException(
          requestOptions: failedRequest,
          error: error,
          stackTrace: stack,
        );
      }
    }();
    _refreshing = operation;
    operation.whenComplete(() {
      if (identical(_refreshing, operation)) _refreshing = null;
    });
    return operation;
  }

  Future<void> _performRefresh(
    int revision,
    RequestOptions failedRequest,
  ) async {
    final snapshot = await lifecycle.protect(
      revision,
      () async => (
        requestHeaders: await readHeaders(
          failedRequest.uri,
          method: failedRequest.method,
        ),
        refreshHeaders: await readHeaders(
          Uri.parse(
            '${config.baseUrl.replaceFirst(RegExp(r'/+$'), '')}/auth/refresh',
          ),
          method: 'POST',
        ),
        refresh: await storage.readRefreshToken(),
      ),
    );
    if (snapshot == null || !lifecycle.isCurrent(revision)) {
      throw DioException(
        requestOptions: failedRequest,
        type: DioExceptionType.cancel,
      );
    }
    final requestCredentialRevision =
        failedRequest.extra['authCredentialRevision'];
    if (requestCredentialRevision is int &&
        requestCredentialRevision != _credentialRevision) {
      return;
    }
    // A delayed 401 may arrive after another request already rotated tokens.
    if (_accessCredential(snapshot.requestHeaders) !=
            _accessCredential(failedRequest.headers) &&
        _accessCredential(snapshot.requestHeaders) != null) {
      return;
    }
    final cookie = snapshot.refreshHeaders['Cookie'];
    final hasRefreshCookie =
        usesBrowserCookieStore && cookieValue(cookie, 'rt') != null;
    if (!cookieStore.usesBrowserCookies &&
        !hasRefreshCookie &&
        (snapshot.refresh == null || snapshot.refresh!.isEmpty)) {
      throw DioException(
        requestOptions: failedRequest,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: failedRequest,
          statusCode: 401,
          data: {
            'code': 'TOKEN_EXPIRED',
            'message': 'Sesi berakhir. Silakan masuk kembali.',
          },
        ),
      );
    }
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        headers: {'Accept': 'application/json'},
        followRedirects: false,
      ),
    );
    configurePlatformHttp(refreshDio);
    try {
      final response = await refreshDio.post<dynamic>(
        '/auth/refresh',
        data: hasRefreshCookie || cookieStore.usesBrowserCookies
            ? null
            : {'refreshToken': snapshot.refresh},
        options: Options(
          headers: {
            if (!usesBrowserCookieStore) 'X-Client-Type': 'mobile',
            if (usesBrowserCookieStore) 'Cookie': ?cookie,
            if (usesBrowserCookieStore)
              'X-CSRF-Token': ?snapshot.refreshHeaders['X-CSRF-Token'],
          },
          followRedirects: false,
        ),
      );
      if (!lifecycle.isCurrent(revision)) return;
      final envelope = response.data;
      final data = envelope is Map<String, dynamic> ? envelope['data'] : null;
      if (envelope is! Map<String, dynamic> ||
          envelope['success'] != true ||
          data is! Map<String, dynamic>) {
        throw _invalidResponse(response);
      }
      final rawTokens = data['tokens'] ?? data;
      if (rawTokens is! Map<String, dynamic>) throw _invalidResponse(response);
      final access = _nonEmptyString(rawTokens['accessToken']);
      final issuedRefresh = _nonEmptyString(rawTokens['refreshToken']);
      final refresh = issuedRefresh ?? snapshot.refresh;
      final responseCookie = cookieHeaderFromResponse(response.headers);
      final issuedAccessCookie = cookieValue(responseCookie, 'at');
      final issuedRefreshCookie = cookieValue(responseCookie, 'rt');
      final issuedCsrfCookie = cookieValue(responseCookie, 'csrf');
      final nextCookie = mergeCookieHeaders(cookie, responseCookie);
      final csrf =
          cookieValue(nextCookie, 'csrf') ??
          _nonEmptyString(data['csrfToken']) ??
          snapshot.refreshHeaders['X-CSRF-Token'];
      final cookieAuth = usesBrowserCookieStore;
      if ((!usesBrowserCookieStore &&
              (access == null || issuedRefresh == null)) ||
          (access == null && !cookieAuth) ||
          (hasRefreshCookie && !cookieAuth) ||
          (!cookieStore.usesBrowserCookies &&
              hasRefreshCookie &&
              (issuedAccessCookie == null ||
                  issuedRefreshCookie == null ||
                  issuedCsrfCookie == null)) ||
          (!cookieStore.usesBrowserCookies &&
              cookieAuth &&
              (csrf == null || csrf.isEmpty))) {
        throw _invalidResponse(response);
      }
      await lifecycle.protect(revision, () async {
        if (!cookieStore.usesBrowserCookies && cookieAuth) {
          final accepted = await cookieStore.capture(
            response.headers,
            response.requestOptions.uri,
            requireAuthBundle: hasRefreshCookie,
          );
          if (hasRefreshCookie &&
              !accepted.containsAll(const {'at', 'rt', 'csrf'})) {
            throw _invalidResponse(response);
          }
        }
        if (access != null) {
          await storage.saveTokens(accessToken: access, refreshToken: refresh);
        }
        final session = await storage.readSession();
        if (session != null) {
          await storage.saveSession({
            ...session,
            'accessToken': ?access,
            'refreshToken': ?refresh,
            if (cookieAuth) 'usesCookieAuth': true,
            if (rawTokens['expiresIn'] is int)
              'expiresIn': rawTokens['expiresIn'],
          });
        }
        _credentialRevision++;
      });
    } finally {
      refreshDio.close(force: true);
    }
  }

  String? _accessCredential(Map<String, dynamic> headers) =>
      cookieValue(headers['Cookie'] as String?, 'at') ??
      headers['Authorization'] as String?;

  String? _nonEmptyString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  DioException _invalidResponse(Response<dynamic> response) => DioException(
    requestOptions: response.requestOptions,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: response.requestOptions,
      statusCode: response.statusCode,
      data: {
        'code': 'INVALID_REFRESH_RESPONSE',
        'message': 'Respons refresh tidak memuat kredensial yang valid.',
      },
    ),
  );
}
