import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/token_storage.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _flow('non-demo restore rotates credentials before loading account data', (
    fixture,
  ) async {
    var app = fixture.createApp();
    await app.read(authControllerProvider.future);
    await app
        .read(authControllerProvider.notifier)
        .login(email: 'employee-a@example.test', password: 'fixture-only');
    expect(app.read(requestContextProvider)?.employeeId, 'employee-a');
    fixture.disposeApp(app);

    fixture.expireAccess = true;
    fixture.refreshedMeGate = Completer<void>();
    app = fixture.createApp();
    final restore = app.read(authControllerProvider.future);
    await fixture.refreshedMeStarted.future;
    expect(app.read(authControllerProvider).isLoading, isTrue);
    expect(app.read(requestContextProvider), isNull);
    expect(fixture.balanceRequests, isEmpty);
    fixture.refreshedMeGate!.complete();
    final restored = await restore;
    expect(restored?.userName, 'Employee Fixture A');
    expect(restored?.accessToken, 'fixture-access-a-next');
    expect(await fixture.storage.readRefreshToken(), 'fixture-refresh-a-next');
    expect(fixture.refreshCalls, 1);
    expect(fixture.meAuthorizations, [
      'Bearer fixture-access-a',
      'Bearer fixture-access-a',
      'Bearer fixture-access-a-next',
    ]);
    final dashboard = await app.read(dashboardRepositoryProvider).refresh();
    expect(dashboard.employee.name, 'Employee Fixture A');
    expect(dashboard.leaveBalances.single.total, 12);
    expect(dashboard.leaveBalances.single.used, 2);
    expect(fixture.balanceRequests.single, (
      employeeId: 'employee-a',
      authorization: 'Bearer fixture-access-a-next',
    ));

    final oldDio = app.read(featureDioProvider);
    await app.read(authControllerProvider.notifier).logout();
    expect(app.read(requestContextProvider), isNull);
    expect(await fixture.storage.readSession(), isNull);
    await app
        .read(authControllerProvider.notifier)
        .login(email: 'employee-b@example.test', password: 'fixture-only');
    expect(app.read(requestContextProvider)?.activeCompanyId, 'company-b');
    final nextDashboard = await app.read(dashboardRepositoryProvider).refresh();
    expect(nextDashboard.employee.name, 'Employee Fixture B');
    expect(nextDashboard.leaveBalances.single.total, 6);
    expect(fixture.balanceRequests.last, (
      employeeId: 'employee-b',
      authorization: 'Bearer fixture-access-b',
    ));
    final requestsBefore = fixture.balanceRequests.length;
    await expectLater(
      oldDio.get<dynamic>('/leave/balances/employee'),
      throwsA(isA<DioException>()),
    );
    expect(fixture.balanceRequests.length, requestsBefore);
    expect(await fixture.storage.readAccessToken(), 'fixture-access-b');
  });

  _flow(
    'failed non-demo bootstrap retains credentials but publishes no identity',
    (fixture) async {
      var app = fixture.createApp();
      await app.read(authControllerProvider.future);
      await app
          .read(authControllerProvider.notifier)
          .login(email: 'employee-a@example.test', password: 'fixture-only');
      fixture.disposeApp(app);

      fixture.meUnavailable = true;
      app = fixture.createApp();
      await expectLater(
        app.read(authControllerProvider.future),
        throwsA(
          isA<ServerFailure>().having(
            (error) => error.statusCode,
            'status',
            503,
          ),
        ),
      );
      expect(app.read(requestContextProvider), isNull);
      expect(app.read(authControllerProvider).hasError, isTrue);
      expect(await fixture.storage.readAccessToken(), 'fixture-access-a');
      expect(fixture.refreshCalls, 0);
      final unavailable = await app.read(dashboardRepositoryProvider).refresh();
      expect(unavailable.leaveBalances, isEmpty);
      expect(fixture.balanceRequests, isEmpty);

      fixture.meUnavailable = false;
      app.invalidate(authControllerProvider);
      final recovered = await app.read(authControllerProvider.future);
      expect(recovered?.employeeId, 'employee-a');
      final dashboard = await app.read(dashboardRepositoryProvider).refresh();
      expect(dashboard.leaveBalances.single.total, 12);
      expect(fixture.refreshCalls, 0);
    },
  );

  _flow('failed me retry cannot publish the refreshed bootstrap identity', (
    fixture,
  ) async {
    var app = fixture.createApp();
    await app.read(authControllerProvider.future);
    await app
        .read(authControllerProvider.notifier)
        .login(email: 'employee-a@example.test', password: 'fixture-only');
    fixture.disposeApp(app);

    fixture.expireAccess = true;
    fixture.refreshedMeGate = Completer<void>();
    app = fixture.createApp();
    final restore = app.read(authControllerProvider.future);
    await fixture.refreshedMeStarted.future;
    expect(app.read(authControllerProvider).isLoading, isTrue);
    expect(app.read(requestContextProvider), isNull);
    fixture.meUnavailable = true;
    final failed = expectLater(restore, throwsA(isA<ServerFailure>()));
    fixture.refreshedMeGate!.complete();
    await failed;
    expect(app.read(requestContextProvider), isNull);
    expect(app.read(authControllerProvider).hasError, isTrue);
    expect(await fixture.storage.readAccessToken(), 'fixture-access-a-next');
    final dashboard = await app.read(dashboardRepositoryProvider).refresh();
    expect(dashboard.leaveBalances, isEmpty);
    expect(fixture.balanceRequests, isEmpty);
  });

  _flow('rejected refresh during bootstrap clears the previous account', (
    fixture,
  ) async {
    var app = fixture.createApp();
    await app.read(authControllerProvider.future);
    await app
        .read(authControllerProvider.notifier)
        .login(email: 'employee-a@example.test', password: 'fixture-only');
    fixture.disposeApp(app);

    fixture.expireAccess = true;
    fixture.rejectRefresh = true;
    app = fixture.createApp();
    expect(await app.read(authControllerProvider.future), isNull);
    expect(app.read(requestContextProvider), isNull);
    expect(await fixture.storage.readSession(), isNull);
    expect(await fixture.storage.readAccessToken(), isNull);
    expect(await fixture.storage.readRefreshToken(), isNull);
    expect(fixture.refreshCalls, 1);
    final dashboard = await app.read(dashboardRepositoryProvider).refresh();
    expect(dashboard.leaveBalances, isEmpty);
    expect(fixture.balanceRequests, isEmpty);
  });
}

void _flow(String name, Future<void> Function(_Fixture) body) {
  test(
    name,
    () => HttpOverrides.runWithHttpOverrides(() async {
      FlutterSecureStorage.setMockInitialValues({});
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final fixture = _Fixture(server);
      server.listen(fixture.respond);
      try {
        await body(fixture);
      } finally {
        if (fixture.refreshedMeGate?.isCompleted == false) {
          fixture.refreshedMeGate!.complete();
        }
        for (final app in fixture.apps) {
          app.dispose();
        }
        await server.close(force: true);
      }
    }, _LocalHttpOverrides()),
  );
}

class _LocalHttpOverrides extends HttpOverrides {}

class _Fixture {
  _Fixture(this.server);

  final HttpServer server;
  final storage = const SecureTokenStorage(FlutterSecureStorage());
  bool expireAccess = false;
  bool meUnavailable = false;
  bool rejectRefresh = false;
  int refreshCalls = 0;
  Completer<void>? refreshedMeGate;
  final refreshedMeStarted = Completer<void>();
  final apps = <ProviderContainer>[];
  final meAuthorizations = <String?>[];
  final balanceRequests = <({String? employeeId, String? authorization})>[];

  ProviderContainer createApp() {
    final app = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(
            baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
            enableNetworkLogs: false,
          ),
        ),
        tokenStorageProvider.overrideWithValue(storage),
        sessionArtifactCleanerProvider.overrideWithValue((_) async {}),
      ],
    );
    apps.add(app);
    return app;
  }

  void disposeApp(ProviderContainer app) {
    apps.remove(app);
    app.dispose();
  }

  Future<void> respond(HttpRequest request) async {
    final rawBody = await utf8.decoder.bind(request).join();
    final body = rawBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawBody) as Map;
    final authorization = request.headers.value('authorization');
    expect(request.headers.value('cookie'), isNull);
    expect(request.headers.value('x-csrf-token'), isNull);
    final account = authorization?.contains('access-b') == true ? 'b' : 'a';
    Object? data;
    var success = true;
    String? code;
    switch (request.uri.path) {
      case '/api/v1/auth/login':
        expect(authorization, isNull);
        expect(request.headers.value('x-client-type'), 'mobile');
        final loginAccount = body['email'] == 'employee-b@example.test'
            ? 'b'
            : 'a';
        data = _login(loginAccount);
      case '/api/v1/auth/me':
        meAuthorizations.add(authorization);
        expect(
          authorization,
          isIn([
            'Bearer fixture-access-a',
            'Bearer fixture-access-a-next',
            'Bearer fixture-access-b',
          ]),
        );
        if (authorization == 'Bearer fixture-access-a-next' &&
            refreshedMeGate != null) {
          if (!refreshedMeStarted.isCompleted) refreshedMeStarted.complete();
          await refreshedMeGate!.future;
        }
        if (meUnavailable) {
          request.response.statusCode = 503;
          success = false;
          code = 'SERVICE_UNAVAILABLE';
        } else if (expireAccess && authorization == 'Bearer fixture-access-a') {
          request.response.statusCode = 401;
          success = false;
          code = 'TOKEN_EXPIRED';
        } else {
          data = _user(account);
        }
      case '/api/v1/auth/refresh':
        refreshCalls++;
        expect(body, {'refreshToken': 'fixture-refresh-a'});
        expect(request.headers.value('x-client-type'), 'mobile');
        if (rejectRefresh) {
          request.response.statusCode = 401;
          success = false;
          code = 'AUTHENTICATION_FAILED';
        } else {
          data = _login('a', rotated: true);
        }
      case '/api/v1/auth/logout':
        expect(authorization, isNull);
        expect(body, {'refreshToken': 'fixture-refresh-a-next'});
      case '/api/v1/leave/balances/employee':
        balanceRequests.add((
          employeeId: request.uri.queryParameters['employeeId'],
          authorization: authorization,
        ));
        data = [
          {
            'leaveType': {'name': 'Fixture annual leave'},
            'quota': account == 'a' ? 12 : 6,
            'used': 2,
          },
        ];
      case '/api/v1/notifications':
        data = {'items': [], 'unreadCount': 0};
      default:
        request.response.statusCode = 404;
        success = false;
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({'success': success, 'data': data, 'code': ?code}),
    );
    await request.response.close();
  }

  Map<String, Object?> _login(String account, {bool rotated = false}) => {
    'user': _user(account),
    'tokens': {
      'accessToken': 'fixture-access-$account${rotated ? '-next' : ''}',
      'refreshToken': 'fixture-refresh-$account${rotated ? '-next' : ''}',
      'expiresIn': 900,
    },
  };

  Map<String, Object?> _user(String account) => {
    'id': 'user-$account',
    'employeeId': 'employee-$account',
    'email': 'employee-$account@example.test',
    'name': account == 'a' ? 'Employee Fixture A' : 'Employee Fixture B',
    'companyId': 'company-$account',
    'companyScope': ['company-$account'],
    'roles': ['EMPLOYEE'],
    'permissions': ['leave:read'],
    'hasGlobalRole': false,
    'maxRolePriority': 10,
    'mustChangePassword': false,
  };
}
