import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/cookie_session.dart';
import 'package:hrm_app/core/security/token_storage.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/data/dto/auth_session_dto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final cookieAuth in [false]) {
    _localTest(
      'restore retains rotated credentials, cookie=$cookieAuth',
      () async {
        final fixture = await _Server.start(cookieAuth: cookieAuth);
        final result = await fixture.container
            .read(authRepositoryProvider)
            .restoreSession();
        expect(result, isA<Success>());
        expect(fixture.refreshCalls, 1);
        expect(fixture.calls('/auth/me'), 2);
        if (cookieAuth) {
          expect(
            cookieValue(await fixture.storage.readCookieHeader(), 'at'),
            'new-access',
          );
          expect(await fixture.storage.readCsrfToken(), 'new-csrf');
        } else {
          expect(await fixture.storage.readAccessToken(), 'new-access');
          expect(await fixture.storage.readRefreshToken(), 'new-refresh');
          expect(
            (await fixture.storage.readSession())?['accessToken'],
            'new-access',
          );
          expect(
            (await fixture.storage.readSession())?['refreshToken'],
            'new-refresh',
          );
        }
        expect(
          (await fixture.storage.readSession())?['name'],
          'Updated employee',
        );
        expect((await fixture.storage.readSession())?['expiresIn'], 900);
      },
    );
  }

  _localTest('native restore removes a legacy cookie-only session', () async {
    final fixture = await _Server.start(cookieAuth: true);

    final result = await fixture.container
        .read(authRepositoryProvider)
        .restoreSession();

    expect(result, isA<Success>());
    expect((result as Success).value, isNull);
    expect(fixture.refreshCalls, 0);
    expect(fixture.calls('/auth/me'), 0);
    expect(await fixture.storage.readSession(), isNull);
    expect(await fixture.storage.readCookieHeader(), isNull);
  });

  _localTest(
    'concurrent 401 across auth and feature clients shares one refresh',
    () async {
      final fixture = await _Server.start();
      fixture.refreshRelease = Completer<void>();
      final requests = Future.wait([
        fixture.dio.get<dynamic>('/one'),
        fixture.container.read(featureDioProvider).get<dynamic>('/two'),
        fixture.dio.get<dynamic>('/three'),
      ]);
      await fixture.threeOldRequests.future.timeout(const Duration(seconds: 3));
      fixture.refreshRelease!.complete();
      await requests;
      expect(fixture.refreshCalls, 1);
      for (final path in ['/one', '/two', '/three']) {
        expect(fixture.calls(path), 2);
      }
    },
  );

  _localTest(
    'final retry 401 invalidates once and does not refresh again',
    () async {
      final fixture = await _Server.start();
      fixture.retryStatus = 401;
      await expectLater(
        fixture.dio.get<dynamic>('/one'),
        throwsA(isA<DioException>()),
      );
      expect(fixture.calls('/one'), 2);
      expect(fixture.refreshCalls, 1);
      expect(await fixture.storage.readSession(), isNull);
      expect(await fixture.storage.readAccessToken(), isNull);
      expect(fixture.container.read(requestContextProvider), isNull);
      expect(fixture.container.read(sessionInvalidationProvider), 1);
    },
  );

  _localTest(
    'refresh 503 preserves credentials and can be retried later',
    () async {
      final fixture = await _Server.start();
      fixture.refreshStatus = 503;
      final failure = await fixture.container
          .read(authRepositoryProvider)
          .restoreSession();
      expect(
        failure,
        isA<FailureResult>().having(
          (r) => r.failure,
          'failure',
          isA<ServerFailure>(),
        ),
      );
      expect(await fixture.storage.readAccessToken(), 'old-access');
      expect(await fixture.storage.readSession(), isNotNull);
      expect(fixture.container.read(sessionInvalidationProvider), 0);
      fixture.refreshStatus = 200;
      expect(
        await fixture.container.read(authRepositoryProvider).restoreSession(),
        isA<Success>(),
      );
      expect(await fixture.storage.readAccessToken(), 'new-access');
    },
  );

  _localTest(
    'delayed old 401 uses the tokens already rotated by another request',
    () async {
      final fixture = await _Server.start();
      fixture.lateRelease = Completer<void>();
      final late = fixture.dio.get<dynamic>('/late');
      await fixture.lateStarted.future;
      await fixture.dio.get<dynamic>('/one');
      expect(fixture.refreshCalls, 1);
      fixture.lateRelease!.complete();
      await late;
      expect(fixture.refreshCalls, 1);
      expect(fixture.calls('/late'), 2);
    },
  );

  for (final status in [401, 403]) {
    _localTest(
      'refresh $status clears rejected session without a protected retry',
      () async {
        final fixture = await _Server.start();
        fixture.refreshStatus = status;
        await expectLater(
          fixture.dio.get<dynamic>('/one'),
          throwsA(isA<DioException>()),
        );
        expect(fixture.calls('/one'), 1);
        expect(fixture.refreshCalls, 1);
        expect(await fixture.storage.readSession(), isNull);
        expect(fixture.container.read(sessionInvalidationProvider), 1);
      },
    );
  }

  for (final status in [403, 429, 503]) {
    _localTest(
      'protected retry $status is returned without logout or another retry',
      () async {
        final fixture = await _Server.start();
        fixture.retryStatus = status;
        await expectLater(
          fixture.dio.get<dynamic>('/one'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'status',
              status,
            ),
          ),
        );
        expect(fixture.calls('/one'), 2);
        expect(fixture.refreshCalls, 1);
        expect(await fixture.storage.readAccessToken(), 'new-access');
        expect(fixture.container.read(sessionInvalidationProvider), 0);
      },
    );
  }

  _localTest(
    'refresh timeout returns NetworkFailure and preserves stored session',
    () async {
      final fixture = await _Server.start(
        timeout: const Duration(milliseconds: 300),
      );
      fixture.refreshRelease = Completer<void>();
      final result = await fixture.container
          .read(authRepositoryProvider)
          .restoreSession();
      expect(
        result,
        isA<FailureResult>().having(
          (r) => r.failure,
          'failure',
          isA<NetworkFailure>(),
        ),
      );
      expect(await fixture.storage.readAccessToken(), 'old-access');
      expect(await fixture.storage.readSession(), isNotNull);
      expect(fixture.container.read(sessionInvalidationProvider), 0);
      fixture.refreshRelease!.complete();
    },
  );

  _localTest('login 401 never refreshes an existing session', () async {
    final fixture = await _Server.start();
    final result = await fixture.container
        .read(authRepositoryProvider)
        .login(email: 'fixture@example.test', password: 'wrong-fixture');
    expect(
      result,
      isA<FailureResult>().having(
        (r) => r.failure,
        'failure',
        isA<AuthenticationFailure>(),
      ),
    );
    expect(fixture.refreshCalls, 0);
    expect(fixture.calls('/auth/login'), 1);
    final request = fixture.requests.single;
    expect(request.auth, isNull);
    expect(request.cookie, isNull);
    expect(fixture.container.read(sessionInvalidationProvider), 0);
  });

  _localTest(
    'login connection error is distinct from invalid credentials',
    () async {
      final fixture = await _Server.start();
      await fixture.server.close(force: true);
      final result = await fixture.container
          .read(authRepositoryProvider)
          .login(email: 'fixture@example.test', password: 'fixture');
      expect(
        result,
        isA<FailureResult>().having(
          (r) => r.failure,
          'failure',
          isA<NetworkFailure>(),
        ),
      );
      expect(fixture.refreshCalls, 0);
    },
  );

  _localTest(
    'POST retry preserves method, query, body and custom headers',
    () async {
      final fixture = await _Server.start();
      await fixture.dio.post<dynamic>(
        '/submit',
        queryParameters: {'companyId': 'company-A'},
        data: {'employeeId': 'employee-A', 'notes': 'fixture'},
        options: Options(headers: {'Idempotency-Key': 'fixture-request-id'}),
      );
      final calls = fixture.requests.where((r) => r.path == '/submit').toList();
      expect(calls, hasLength(2));
      for (final call in calls) {
        expect(call.method, 'POST');
        expect(call.query, 'companyId=company-A');
        expect(call.key, 'fixture-request-id');
        expect(jsonDecode(call.body), {
          'employeeId': 'employee-A',
          'notes': 'fixture',
        });
      }
      expect(calls.last.csrf, isNull);
      expect(calls.last.cookie, isNull);
      expect(calls.last.auth, 'Bearer new-access');
    },
  );

  _localTest(
    'missing refresh credentials invalidates without calling refresh endpoint',
    () async {
      final fixture = await _Server.start();
      await fixture.storage.clear();
      await fixture.storage.saveTokens(accessToken: 'old-access');
      await expectLater(
        fixture.dio.get<dynamic>('/one'),
        throwsA(isA<DioException>()),
      );
      expect(fixture.refreshCalls, 0);
      expect(fixture.calls('/one'), 1);
      expect(await fixture.storage.readAccessToken(), isNull);
      expect(fixture.container.read(sessionInvalidationProvider), 1);
    },
  );

  for (final invalid in [
    'success-false',
    'missing-token',
    'wrong-token-type',
  ]) {
    _localTest(
      'invalid refresh response $invalid cannot overwrite credentials or retry',
      () async {
        final fixture = await _Server.start();
        fixture.invalidRefresh = invalid;
        final result = await fixture.container
            .read(authRepositoryProvider)
            .restoreSession();
        expect(
          result,
          isA<FailureResult>().having(
            (r) => r.failure,
            'failure',
            isA<ServerFailure>(),
          ),
        );
        expect(fixture.calls('/auth/me'), 1);
        expect(fixture.refreshCalls, 1);
        expect((await fixture.storage.readSession())?['expiresIn'], 1);
        expect(await fixture.storage.readAccessToken(), 'old-access');
        expect(fixture.container.read(sessionInvalidationProvider), 0);
      },
    );
  }

  _localTest(
    'concurrent refresh rejection invalidates once and completes every waiter',
    () async {
      final fixture = await _Server.start();
      fixture.refreshRelease = Completer<void>();
      fixture.refreshStatus = 401;
      final requests = Future.wait([
        for (final path in ['/one', '/two', '/three'])
          fixture.dio
              .get<dynamic>(path)
              .then<Object?>((r) => r, onError: (Object e) => e),
      ]);
      await fixture.threeOldRequests.future;
      await fixture.refreshStarted.future;
      fixture.refreshRelease!.complete();
      expect(await requests, everyElement(isA<DioException>()));
      expect(fixture.refreshCalls, 1);
      expect(fixture.container.read(sessionInvalidationProvider), 1);
      expect(await fixture.storage.readSession(), isNull);
    },
  );

  _localTest(
    'cancelling one waiter does not cancel refresh for other requests',
    () async {
      final fixture = await _Server.start();
      fixture.refreshRelease = Completer<void>();
      final cancellation = CancelToken();
      final cancelled = fixture.dio
          .get<dynamic>('/cancelled', cancelToken: cancellation)
          .then<Object?>((r) => r, onError: (Object e) => e);
      final others = Future.wait([
        fixture.dio.get<dynamic>('/two'),
        fixture.dio.get<dynamic>('/three'),
      ]);
      await fixture.threeOldRequests.future;
      await fixture.refreshStarted.future;
      cancellation.cancel('fixture cancellation');
      fixture.refreshRelease!.complete();
      await others;
      expect(
        await cancelled,
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      );
      expect(fixture.calls('/cancelled'), 1);
      expect(fixture.refreshCalls, 1);
      expect(fixture.container.read(sessionInvalidationProvider), 0);
    },
  );

  for (final status in [401, 503]) {
    _localTest(
      'auth bootstrap with refresh $status finishes without a restore loop',
      () async {
        final fixture = await _Server.start();
        fixture.refreshStatus = status;
        final future = fixture.container.read(authControllerProvider.future);
        if (status == 401) {
          expect(
            await future.timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw StateError('auth future did not settle'),
            ),
            isNull,
          );
          await Future<void>.delayed(Duration.zero);
          expect(
            fixture.container.read(authControllerProvider).requireValue,
            isNull,
          );
          expect(await fixture.storage.readSession(), isNull);
        } else {
          await expectLater(future, throwsA(isA<ServerFailure>()));
          expect(
            fixture.container.read(authControllerProvider).hasError,
            isTrue,
          );
          expect(await fixture.storage.readSession(), isNotNull);
        }
        expect(fixture.calls('/auth/me'), 1);
        expect(fixture.refreshCalls, 1);
      },
    );
  }

  _localTest('multipart retry clones consumed form data', () async {
    final fixture = await _Server.start();
    await fixture.dio.post<dynamic>(
      '/upload',
      data: FormData.fromMap({
        'employeeId': 'employee-A',
        'attachment': MultipartFile.fromString(
          'fixture-file-content',
          filename: 'fixture.txt',
        ),
      }),
    );
    final calls = fixture.requests.where((r) => r.path == '/upload');
    expect(calls, hasLength(2));
    for (final call in calls) {
      expect(call.body, contains('employee-A'));
      expect(call.body, contains('fixture-file-content'));
    }
    expect(fixture.refreshCalls, 1);
  });
}

void _localTest(String name, Future<void> Function() body) => test(
  name,
  () => HttpOverrides.runWithHttpOverrides(body, _LocalHttpOverrides()),
);

class _LocalHttpOverrides extends HttpOverrides {}

class _Server {
  _Server(this.server, this.container, this.cookieAuth);
  final HttpServer server;
  final ProviderContainer container;
  final bool cookieAuth;
  final storage = const SecureTokenStorage(FlutterSecureStorage());
  final requests =
      <
        ({
          String path,
          String method,
          String body,
          String? auth,
          String? cookie,
          String? csrf,
          String query,
          String? key,
        })
      >[];
  int refreshCalls = 0;
  int refreshStatus = 200;
  int retryStatus = 200;
  Completer<void>? refreshRelease;
  Completer<void>? lateRelease;
  final lateStarted = Completer<void>();
  final refreshStarted = Completer<void>();
  String? invalidRefresh;
  final threeOldRequests = Completer<void>();
  int _oldRequests = 0;
  Dio get dio => container.read(dioProvider);
  int calls(String path) => requests.where((r) => r.path == path).length;

  static Future<_Server> start({
    bool cookieAuth = false,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = SecureTokenStorage(FlutterSecureStorage());
    if (!cookieAuth) {
      await storage.saveTokens(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );
    }
    await storage.saveSession(
      AuthSessionDto(
        userId: 'A',
        employeeId: 'employee-A',
        companyId: 'company-A',
        userName: 'Cached employee',
        accessToken: cookieAuth ? null : 'old-access',
        refreshToken: cookieAuth ? null : 'old-refresh',
        usesCookieAuth: cookieAuth,
        expiresIn: 1,
      ).toStoredJson(),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final baseUrl = 'http://127.0.0.1:${server.port}';
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 2),
            receiveTimeout: timeout,
            enableNetworkLogs: false,
          ),
        ),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
    if (cookieAuth) {
      await container
          .read(sessionCookieStoreProvider)
          .capture(
            Headers.fromMap({
              'set-cookie': _authCookies(
                access: 'old-access',
                refresh: 'old-refresh',
                csrf: 'old-csrf',
                refreshPath: '/auth',
              ),
            }),
            Uri.parse('$baseUrl/auth/login'),
          );
    }
    container
        .read(requestContextProvider.notifier)
        .state = const RequestContext(
      userId: 'A',
      employeeId: 'employee-A',
      activeCompanyId: 'company-A',
      companyScope: ['company-A'],
    );
    final fixture = _Server(server, container, cookieAuth);
    server.listen(fixture._handle);
    addTearDown(() async {
      container.dispose();
      await server.close(force: true);
    });
    return fixture;
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final body = await utf8.decoder.bind(request).join();
    final auth = request.headers.value('authorization');
    final cookie = request.headers.value('cookie');
    requests.add((
      path: path,
      method: request.method,
      body: body,
      auth: auth,
      cookie: cookie,
      csrf: request.headers.value('x-csrf-token'),
      query: request.uri.query,
      key: request.headers.value('idempotency-key'),
    ));
    request.response.headers.contentType = ContentType.json;
    if (path == '/auth/refresh') {
      refreshCalls++;
      if (!refreshStarted.isCompleted) refreshStarted.complete();
      await refreshRelease?.future;
      request.response.statusCode = refreshStatus;
      if (refreshStatus == 200) {
        if (cookieAuth && invalidRefresh == null) {
          for (final value in _authCookies(
            access: 'new-access',
            refresh: 'new-refresh',
            csrf: 'new-csrf',
            refreshPath: '/auth',
          )) {
            request.response.headers.add('set-cookie', value);
          }
        }
        if (invalidRefresh == 'non-auth-cookie') {
          request.response.headers.add(
            'set-cookie',
            'csrf=invalid-new-csrf; Path=/',
          );
        }
        if (invalidRefresh == 'malformed-cookie-bundle') {
          for (final value in [
            'at=untrusted-access; Max-Age=900; Path=/; HttpOnly; SameSite=Lax',
            'rt=untrusted-refresh; Max-Age=604800; Path=/; HttpOnly; SameSite=Lax',
            'csrf=untrusted-csrf; Path=/; SameSite=Lax',
          ]) {
            request.response.headers.add('set-cookie', value);
          }
        }
        request.response.write(
          jsonEncode({
            'success': invalidRefresh != 'success-false',
            'data': {
              'tokens': {
                if (!cookieAuth && invalidRefresh != 'missing-token')
                  'accessToken': invalidRefresh == 'wrong-token-type'
                      ? 123
                      : 'new-access',
                if (!cookieAuth) 'refreshToken': 'new-refresh',
                'expiresIn': 900,
              },
            },
          }),
        );
      } else {
        request.response.write(
          jsonEncode({'success': false, 'message': 'Refresh unavailable'}),
        );
      }
    } else {
      final isOld = cookieAuth
          ? cookieValue(cookie, 'at') != 'new-access'
          : auth != 'Bearer new-access';
      if (isOld) {
        if (path == '/late' && lateRelease != null) {
          lateStarted.complete();
          await lateRelease!.future;
        }
        _oldRequests++;
        if (_oldRequests == 3) threeOldRequests.complete();
      }
      request.response.statusCode = isOld ? 401 : retryStatus;
      request.response.write(
        jsonEncode({
          'success': !isOld && retryStatus == 200,
          'message': 'Protected response',
          'data': {
            'id': 'A',
            'employeeId': 'employee-A',
            'companyId': 'company-A',
            'name': 'Updated employee',
          },
        }),
      );
    }
    await request.response.close();
  }
}

List<String> _authCookies({
  required String access,
  required String refresh,
  required String csrf,
  required String refreshPath,
}) => [
  'at=$access; Max-Age=900; Path=/; HttpOnly; SameSite=Lax',
  'rt=$refresh; Max-Age=604800; Path=$refreshPath; HttpOnly; SameSite=Lax',
  'csrf=$csrf; Path=/; SameSite=Lax',
];
