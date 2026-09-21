import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_cookie_store.dart';
import 'package:hrm_app/core/security/token_storage.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:hrm_app/features/authentication/data/dto/auth_session_dto.dart';
import 'package:hrm_app/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';

final _fixture =
    jsonDecode(File('test/fixtures/auth/auth_contract.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _user(String name) =>
    Map<String, dynamic>.from(_fixture['users'][name] as Map);

Map<String, List<String>> _headers(String name) =>
    (_fixture[name] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, List<String>.from(value as List)),
    );

Map<String, dynamic> _loginBody(String name) => {
  'success': true,
  'message': 'Login successful',
  'data': {
    'user': _user(name),
    'tokens': {
      'accessToken': 'fixture-access',
      'refreshToken': 'fixture-refresh',
      'expiresIn': 900,
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final role in ['employee', 'manager', 'admin']) {
    test(
      'restores $role identity into request context without invented IDs',
      () async {
        final session = AuthSessionDto.fromLoginJson(
          _loginBody(role)['data'] as Map<String, dynamic>,
        ).toEntity();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _StoredSessionRepository(session),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(authControllerProvider.future);
        final context = container.read(requestContextProvider)!;
        expect(context.userId, _user(role)['id']);
        expect(context.employeeId, _user(role)['employeeId']);
        expect(context.activeCompanyId, _user(role)['companyId']);
        expect(context.companyScope, _user(role)['companyScope']);
        expect(context.permissions, _user(role)['permissions']);
        expect(context.hasGlobalRole, _user(role)['hasGlobalRole']);
        expect(context.maxRolePriority, _user(role)['maxRolePriority']);
        if (role == 'manager') {
          expect(
            context.selectCompany('company-b').maxRolePriority,
            session.maxRolePriority,
          );
          expect(
            () => context.selectCompany('company-outside'),
            throwsArgumentError,
          );
        }
      },
    );

    test('parses final mobile bearer login for $role', () async {
      final adapter = _FixtureAdapter(
        body: _loginBody(role),
        headers: _headers('loginHeaders'),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final dto = await DioAuthRemoteDataSource(dio).login(
        email: _user(role)['email'] as String,
        password: 'fixture-password',
      );

      expect(adapter.request?.method, 'POST');
      expect(adapter.request?.path, '/auth/login');
      expect(adapter.request?.data, {
        'email': _user(role)['email'],
        'password': 'fixture-password',
      });
      expect(adapter.request?.headers['X-Client-Type'], 'mobile');
      expect(dto.accessToken, 'fixture-access');
      expect(dto.refreshToken, 'fixture-refresh');
      expect(dto.usesCookieAuth, isFalse);
      expect(dto.authCookie, isNull);
      expect(dto.csrfToken, isNull);
      expect(dto.expiresIn, 900);
      final entity = dto.toEntity();
      expect(entity.userId, _user(role)['id']);
      expect(entity.employeeId, _user(role)['employeeId']);
      expect(entity.companyId, _user(role)['companyId']);
      expect(entity.companyScope, _user(role)['companyScope']);
      expect(entity.permissions, _user(role)['permissions']);
      expect(entity.roles, _user(role)['roles']);
      expect(entity.groupId, _user(role)['groupId']);
      expect(entity.hasGlobalRole, _user(role)['hasGlobalRole']);
      expect(entity.maxRolePriority, _user(role)['maxRolePriority']);
      expect(entity.mustChangePassword, _user(role)['mustChangePassword']);
      expect(
        AuthSessionDto.fromStoredJson(dto.toStoredJson()).toStoredJson(),
        dto.toStoredJson(),
      );
    });
  }

  test(
    '/me is a direct user object and can remove employee affiliation',
    () async {
      final admin = {
        ..._user('admin'),
        'id': _user('employee')['id'],
        'email': _user('employee')['email'],
        'lastLoginAt': '2026-09-10T08:00:00Z',
      };
      final adapter = _FixtureAdapter(body: {'success': true, 'data': admin});
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final me = await DioAuthRemoteDataSource(dio).me();
      final previous = AuthSessionDto.fromLoginJson(
        _loginBody('employee')['data'] as Map<String, dynamic>,
      );
      final updated = previous.mergeUser(me);

      expect(adapter.request?.method, 'GET');
      expect(adapter.request?.path, '/auth/me');
      expect(me, admin);
      expect(updated.employeeId, isNull);
      expect(updated.companyId, isNull);
      expect(updated.groupId, isNull);
      expect(updated.companyScope, isEmpty);
      expect(updated.hasGlobalRole, isTrue);
      expect(updated.permissions, _user('admin')['permissions']);
    },
  );

  for (final cookie in [
    'csrf=fixture',
    'rt=fixture; csrf=fixture',
    'at=; csrf=fixture',
  ]) {
    test('rejects missing access credentials: $cookie', () {
      expect(
        () => AuthSessionDto.fromLoginJson({
          'tokens': {'expiresIn': 900},
          'user': _user('employee'),
        }, authCookie: cookie),
        throwsFormatException,
      );
    });
  }

  test('rejects cookie login without CSRF and login without user ID', () {
    expect(
      () => AuthSessionDto.fromLoginJson({
        'tokens': {'expiresIn': 900},
        'user': _user('employee'),
      }, authCookie: 'at=fixture; rt=fixture'),
      throwsFormatException,
    );
    expect(
      () => AuthSessionDto.fromLoginJson({
        'tokens': {'accessToken': 'fixture'},
        'user': {'email': 'employee@example.test'},
      }),
      throwsFormatException,
    );
  });

  test('CSRF cookie takes precedence over the legacy body field', () {
    final dto = AuthSessionDto.fromLoginJson({
      ..._loginBody('employee')['data'] as Map<String, dynamic>,
      'csrfToken': 'old-body-csrf',
    }, authCookie: 'at=fixture; csrf=new%2Bcookie.signature');
    expect(dto.csrfToken, 'new+cookie.signature');
  });

  test('login sends MFA only after the user supplies a code', () async {
    final adapter = _FixtureAdapter(
      body: _loginBody('employee'),
      headers: _headers('loginHeaders'),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioAuthRemoteDataSource(dio);

    await remote.login(
      email: 'employee@example.test',
      password: 'fixture-password',
      totp: ' 123456 ',
    );

    expect(adapter.request?.data, {
      'email': 'employee@example.test',
      'password': 'fixture-password',
      'totp': '123456',
    });
  });

  test('native login rejects a response without rotated token pair', () async {
    final body = _loginBody('employee');
    final data = body['data'] as Map<String, dynamic>;
    data['tokens'] = {'accessToken': 'access-only', 'expiresIn': 900};
    final adapter = _FixtureAdapter(body: body);
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);

    await expectLater(
      DioAuthRemoteDataSource(
        dio,
      ).login(email: 'employee@example.test', password: 'fixture-password'),
      throwsFormatException,
    );

    expect(adapter.request?.headers['X-Client-Type'], 'mobile');
  });

  test('change password uses the verified backend contract', () async {
    final adapter = _FixtureAdapter(
      body: const {'success': true, 'data': null},
    );
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);

    await DioAuthRemoteDataSource(dio).changePassword(
      currentPassword: 'OldPassword1!',
      newPassword: 'NewPassword2@',
    );

    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.path, '/auth/change-password');
    expect(adapter.request?.data, {
      'oldPassword': 'OldPassword1!',
      'newPassword': 'NewPassword2@',
    });
  });

  test('change password and logout reject HTTP 200 success=false', () async {
    final changeDio = Dio()
      ..httpClientAdapter = _FixtureAdapter(
        body: const {
          'success': false,
          'message': 'Password was not changed',
          'data': null,
        },
      );
    addTearDown(changeDio.close);
    await expectLater(
      DioAuthRemoteDataSource(changeDio).changePassword(
        currentPassword: 'OldPassword1!',
        newPassword: 'NewPassword2@',
      ),
      throwsFormatException,
    );

    final logoutDio = Dio()
      ..httpClientAdapter = _FixtureAdapter(
        body: const {
          'success': false,
          'message': 'Refresh token was not revoked',
          'data': null,
        },
      );
    addTearDown(logoutDio.close);
    await expectLater(
      DioAuthRemoteDataSource(
        logoutDio,
      ).logout(refreshToken: 'fixture-refresh'),
      throwsFormatException,
    );
  });

  for (final raw in _fixture['errors'] as List) {
    final error = raw as Map<String, dynamic>;
    final body = error['body'] as Map<String, dynamic>;
    test(
      'preserves ${error['status']} ${body['code']}: ${body['message']}',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FixtureAdapter(
            body: body,
            statusCode: error['status'] as int,
          );
        addTearDown(dio.close);
        await expectLater(
          DioAuthRemoteDataSource(
            dio,
          ).login(email: 'fixture@example.test', password: 'fixture-password'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', error['status'])
                .having((e) => e.code, 'code', body['code'])
                .having((e) => e.message, 'message', body['message'])
                .having(
                  (e) => e.fieldErrors,
                  'fields',
                  body['code'] == 'VALIDATION_ERROR'
                      ? {'email': 'Invalid email format'}
                      : isEmpty,
                ),
          ),
        );
      },
    );
  }

  test('HTTP 200 with success=false does not create a login session', () async {
    final dio = Dio()
      ..httpClientAdapter = _FixtureAdapter(
        body: {..._loginBody('employee'), 'success': false},
        headers: _headers('loginHeaders'),
      );
    addTearDown(dio.close);
    await expectLater(
      DioAuthRemoteDataSource(
        dio,
      ).login(email: 'fixture@example.test', password: 'fixture'),
      throwsFormatException,
    );
  });

  test(
    'native local HTTP login, me, bearer refresh and logout contract',
    () => HttpOverrides.runWithHttpOverrides(() async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = SecureTokenStorage(FlutterSecureStorage());
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests =
          <
            ({
              String path,
              String method,
              String? cookie,
              String? csrf,
              String? auth,
              String? clientType,
              String body,
            })
          >[];
      var meCalls = 0;
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        final path = request.uri.path;
        requests.add((
          path: path,
          method: request.method,
          cookie: request.headers.value('cookie'),
          csrf: request.headers.value('x-csrf-token'),
          auth: request.headers.value('authorization'),
          clientType: request.headers.value('x-client-type'),
          body: body,
        ));
        request.response.headers.contentType = ContentType.json;
        String? headerFixture;
        Map<String, dynamic> response;
        if (path.endsWith('/login')) {
          response = _loginBody('employee');
          headerFixture = 'loginHeaders';
        } else if (path.endsWith('/me')) {
          meCalls++;
          if (meCalls == 2) {
            request.response.statusCode = 401;
            response = {
              'success': false,
              'code': 'TOKEN_EXPIRED',
              'message': 'Token has expired',
            };
          } else {
            response = {'success': true, 'data': _user('employee')};
          }
        } else if (path.endsWith('/refresh')) {
          response = {
            'success': true,
            'message': 'Token refreshed successfully',
            'data': {
              'user': _user('employee'),
              'tokens': {
                'accessToken': 'fixture-access-next',
                'refreshToken': 'fixture-refresh-next',
                'expiresIn': 900,
              },
            },
          };
        } else if (path.endsWith('/logout')) {
          response = {
            'success': true,
            'message': 'Logout successful',
            'data': null,
          };
          headerFixture = 'logoutHeaders';
        } else {
          request.response.statusCode = 404;
          response = {'success': false};
        }
        if (headerFixture != null) {
          for (final cookie in _headers(headerFixture)['set-cookie']!) {
            request.response.headers.add('set-cookie', cookie);
          }
        }
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      final config = AppConfig(
        baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        enableNetworkLogs: false,
      );
      var invalidations = 0;
      final lifecycle = SessionLifecycle();
      addTearDown(lifecycle.dispose);
      final dio = Dio(BaseOptions(baseUrl: config.baseUrl));
      addTearDown(dio.close);
      final cookieStore = SessionCookieStore(
        storage: storage,
        baseUrl: config.baseUrl,
      );
      dio.interceptors.add(
        AuthInterceptor(
          dio: dio,
          config: config,
          storage: storage,
          lifecycle: lifecycle,
          cookieStore: cookieStore,
          onSessionInvalidated: () => invalidations++,
        ),
      );
      final remote = DioAuthRemoteDataSource(dio, lifecycle: lifecycle);
      final repository = AuthRepositoryImpl(
        remote,
        storage,
        lifecycle: lifecycle,
        cookieStore: cookieStore,
      );

      final result = await repository.login(
        email: 'employee-a@example.test',
        password: 'fixture-password',
      );
      expect(result, isA<Success>());
      expect(await storage.readAccessToken(), 'fixture-access');
      expect(await storage.readRefreshToken(), 'fixture-refresh');
      expect(await storage.readCsrfToken(), isNull);
      expect(await remote.me(), _user('employee'));
      expect(await remote.me(), _user('employee'));
      expect(await storage.readAccessToken(), 'fixture-access-next');
      expect(await storage.readRefreshToken(), 'fixture-refresh-next');
      await repository.logout();

      expect(requests.map((r) => r.path), [
        '/api/v1/auth/login',
        '/api/v1/auth/me',
        '/api/v1/auth/me',
        '/api/v1/auth/refresh',
        '/api/v1/auth/me',
        '/api/v1/auth/me',
        '/api/v1/auth/logout',
      ]);
      expect(jsonDecode(requests.first.body), {
        'email': 'employee-a@example.test',
        'password': 'fixture-password',
      });
      expect(requests.first.clientType, 'mobile');
      expect(requests[1].csrf, isNull);
      expect(requests[1].cookie, isNull);
      expect(requests[1].auth, 'Bearer fixture-access');
      expect(requests[3].method, 'POST');
      expect(requests[3].clientType, 'mobile');
      expect(jsonDecode(requests[3].body), {'refreshToken': 'fixture-refresh'});
      expect(requests[3].cookie, isNull);
      expect(requests[3].csrf, isNull);
      expect(requests[4].csrf, isNull);
      expect(requests[4].auth, 'Bearer fixture-access-next');
      expect(requests.last.method, 'POST');
      expect(jsonDecode(requests.last.body), {
        'refreshToken': 'fixture-refresh-next',
      });
      expect(requests.last.auth, isNull);
      expect(requests.last.cookie, isNull);
      expect(requests.last.csrf, isNull);
      expect(await storage.readSession(), isNull);
      expect(await storage.readCookieHeader(), isNull);
      expect(await storage.readCsrfToken(), isNull);
      expect(invalidations, 0);
    }, _LocalHttpOverrides()),
  );
}

class _LocalHttpOverrides extends HttpOverrides {}

class _StoredSessionRepository implements AuthRepository {
  const _StoredSessionRepository(this.session);
  final AuthSession session;

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<Result<AuthSession?>> restoreSession() async => Success(session);

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();
}

class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter({
    required this.body,
    this.headers = const {},
    this.statusCode = 200,
  });
  final Map<String, dynamic> body;
  final Map<String, List<String>> headers;
  final int statusCode;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
