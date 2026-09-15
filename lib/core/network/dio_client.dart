import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/network/auth_refresh.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/network/platform_http.dart';
import 'package:hrm_app/core/network/safe_network_log_interceptor.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/security/session_cookie_store.dart';
import 'package:hrm_app/core/security/token_storage.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(),
);
final sessionInvalidationProvider = StateProvider<int>((ref) => 0);

final sessionCookieStoreProvider = Provider<SessionCookieStore>(
  (ref) => SessionCookieStore(
    storage: ref.watch(tokenStorageProvider),
    baseUrl: ref.watch(appConfigProvider).baseUrl,
  ),
);

final authRefreshProvider = Provider<AuthRefreshCoordinator>(
  (ref) => AuthRefreshCoordinator(
    storage: ref.watch(tokenStorageProvider),
    lifecycle: ref.read(sessionLifecycleProvider),
    config: ref.watch(appConfigProvider),
    cookieStore: ref.watch(sessionCookieStoreProvider),
  ),
);

final dioProvider = Provider<Dio>((ref) => _createDio(ref));
final featureDioProvider = Provider<Dio>(
  (ref) => _createDio(ref, session: ref.watch(featureSessionProvider)),
);

Dio _createDio(Ref ref, {FeatureSession? session}) {
  final config = ref.watch(appConfigProvider);
  final contextState = ref.read(requestContextProvider.notifier);
  final invalidationState = ref.read(sessionInvalidationProvider.notifier);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      headers: const {'Accept': 'application/json'},
    ),
  );
  configurePlatformHttp(dio);
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      config: config,
      storage: ref.watch(tokenStorageProvider),
      lifecycle: ref.read(sessionLifecycleProvider),
      session: session,
      refreshCoordinator: ref.watch(authRefreshProvider),
      cookieStore: ref.watch(sessionCookieStoreProvider),
      onSessionInvalidated: () {
        contextState.state = null;
        invalidationState.state++;
      },
    ),
  );
  if (kDebugMode && config.enableNetworkLogs) {
    dio.interceptors.add(SafeNetworkLogInterceptor(debugPrint));
  }
  ref.onDispose(() => dio.close(force: true));
  return dio;
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._dio,
    required AppConfig config,
    required TokenStorage storage,
    required this._onSessionInvalidated,
    SessionLifecycle? lifecycle,
    this.session,
    AuthRefreshCoordinator? refreshCoordinator,
    SessionCookieStore? cookieStore,
  }) : _storage = storage,
       _lifecycle = lifecycle ?? SessionLifecycle(),
       _cookies =
           cookieStore ??
           SessionCookieStore(storage: storage, baseUrl: config.baseUrl) {
    _refresh =
        refreshCoordinator ??
        AuthRefreshCoordinator(
          storage: storage,
          lifecycle: _lifecycle,
          config: config,
          cookieStore: _cookies,
        );
  }

  final Dio _dio;
  final TokenStorage _storage;
  final void Function() _onSessionInvalidated;
  final SessionLifecycle _lifecycle;
  final SessionCookieStore _cookies;
  final FeatureSession? session;
  late final AuthRefreshCoordinator _refresh;

  bool _current(RequestOptions request) =>
      request.extra['sessionRevision'] == _lifecycle.revision &&
      (session?.isCurrent ?? true);

  bool _authEndpoint(RequestOptions request) => const [
    '/auth/login',
    '/auth/refresh',
    '/auth/logout',
  ].any(request.uri.path.endsWith);

  DioException _cancelled(RequestOptions request) => DioException(
    requestOptions: request,
    type: DioExceptionType.cancel,
    message: 'Session changed.',
  );

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.extra.putIfAbsent(
      'sessionRevision',
      () => session?.revision ?? _lifecycle.revision,
    );
    if (options.extra['logoutSnapshot'] == true) {
      handler.next(options);
      return;
    }
    if (!_current(options)) {
      handler.reject(_cancelled(options));
      return;
    }
    try {
      final storedHeaders = await _lifecycle.protect(
        options.extra['sessionRevision'] as int,
        () => _refresh.readHeaders(options.uri, method: options.method),
      );
      if (!_current(options)) {
        handler.reject(_cancelled(options));
        return;
      }
      final headers = <String, String>{...?storedHeaders};
      if (!usesBrowserCookieStore) {
        headers
          ..remove('Cookie')
          ..remove('X-CSRF-Token');
      }
      if (options.uri.path.endsWith('/auth/login')) {
        headers
          ..remove('Authorization')
          ..remove('Cookie');
      }
      options.headers
        ..remove('Authorization')
        ..remove('Cookie')
        ..remove('X-CSRF-Token')
        ..addAll(headers);
      options.extra['authCredentialRevision'] = _refresh.credentialRevision;
      if (_authEndpoint(options) ||
          options.headers.containsKey('Authorization') ||
          options.headers.containsKey('Cookie') ||
          options.headers.containsKey('X-CSRF-Token') ||
          _cookies.usesBrowserCookies) {
        options.followRedirects = false;
      }
      handler.next(options);
    } catch (error, stack) {
      handler.reject(
        DioException(requestOptions: options, error: error, stackTrace: stack),
      );
    }
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final request = response.requestOptions;
    if (request.extra['logoutSnapshot'] == true) {
      handler.next(response);
      return;
    }
    if (!_current(request)) {
      handler.reject(_cancelled(request));
      return;
    }
    try {
      if (usesBrowserCookieStore && !request.uri.path.endsWith('/auth/login')) {
        await _lifecycle.protect(
          request.extra['sessionRevision'] as int,
          () => _cookies.capture(response.headers, request.uri),
        );
      }
      if (!_current(request)) {
        handler.reject(_cancelled(request));
        return;
      }
      handler.next(response);
    } catch (error, stack) {
      handler.reject(
        DioException(requestOptions: request, error: error, stackTrace: stack),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (request.extra['logoutSnapshot'] == true || _authEndpoint(request)) {
      handler.next(err);
      return;
    }
    if (!_current(request)) {
      handler.next(_cancelled(request));
      return;
    }
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    final result = await _recover(err);
    final response = result.response;
    if (response != null) {
      handler.resolve(response);
    } else {
      handler.next(result.error!);
    }
  }

  Future<({Response<dynamic>? response, DioException? error})> _recover(
    DioException firstError,
  ) async {
    final request = firstError.requestOptions;
    final revision = request.extra['sessionRevision'] as int;
    if (request.extra['authRetried'] == true) {
      await _invalidate(revision);
      return (response: null, error: firstError);
    }
    final refreshError = await _refresh.refresh(revision, request);
    if (refreshError != null) {
      if (!_current(request)) {
        return (response: null, error: _cancelled(request));
      }
      if (refreshError.response?.statusCode == 401 ||
          refreshError.response?.statusCode == 403) {
        await _invalidate(revision);
      }
      return (
        response: null,
        error: refreshError.copyWith(requestOptions: request),
      );
    }
    if (!_current(request)) {
      return (response: null, error: _cancelled(request));
    }
    if (request.cancelToken?.isCancelled ?? false) {
      return (response: null, error: request.cancelToken!.cancelError!);
    }
    final body = request.data;
    if (body is Stream) {
      return (
        response: null,
        error: DioException(
          requestOptions: request,
          message: 'Request stream tidak dapat diulang. Silakan kirim ulang.',
        ),
      );
    }
    final retry = request.copyWith(
      data: body is FormData ? body.clone() : body,
      extra: {
        ...request.extra,
        'authRetried': true,
        'authCredentialRevision': _refresh.credentialRevision,
      },
    );
    try {
      final headers = await _refresh.readHeaders(
        request.uri,
        method: request.method,
      );
      retry.headers
        ..remove('Authorization')
        ..remove('Cookie')
        ..remove('X-CSRF-Token')
        ..addAll(headers);
      return (response: await _dio.fetch<dynamic>(retry), error: null);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) await _invalidate(revision);
      return (response: null, error: error);
    } catch (error, stack) {
      return (
        response: null,
        error: DioException(
          requestOptions: request,
          error: error,
          stackTrace: stack,
        ),
      );
    }
  }

  Future<void> _invalidate(int revision) async {
    if (!_lifecycle.isCurrent(revision)) return;
    final invalidated = _lifecycle.advance();
    await _lifecycle.protect(invalidated, _storage.clear);
    if (_lifecycle.isCurrent(invalidated)) _onSessionInvalidated();
  }
}
