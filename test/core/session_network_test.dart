import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/token_storage.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    (path: 'refresh', status: 200, loginB: false),
    (path: 'refresh', status: 200, loginB: true),
    (path: 'refresh', status: 401, loginB: true),
    (path: 'refresh', status: 401, loginB: false),
    (path: 'slow', status: 200, loginB: true),
    (path: 'logout', status: 200, loginB: true),
    (path: 'logout', status: 503, loginB: true),
  ]) {
    test(
      'late ${scenario.path} ${scenario.status}, login B=${scenario.loginB}',
      () => HttpOverrides.runWithHttpOverrides(() async {
        FlutterSecureStorage.setMockInitialValues({});
        const storage = SecureTokenStorage(FlutterSecureStorage());
        final blocked = Completer<void>();
        final release = Completer<void>();
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final received =
            <
              ({
                String path,
                String body,
                String? auth,
                String? cookie,
                String? clientType,
              })
            >[];
        server.listen((request) async {
          final body = await utf8.decoder.bind(request).join();
          final path = request.uri.path.split('/').last;
          received.add((
            path: path,
            body: body,
            auth: request.headers.value('authorization'),
            cookie: request.headers.value('cookie'),
            clientType: request.headers.value('x-client-type'),
          ));
          request.response.headers.contentType = ContentType.json;
          if (path == scenario.path) {
            blocked.complete();
            await release.future;
            request.response.statusCode = scenario.status;
          }
          if (path == 'protected') {
            request.response.statusCode = 401;
            request.response.write(
              jsonEncode({'success': false, 'message': 'expired'}),
            );
          } else if (path == 'login' || path == 'refresh') {
            final id = path == 'login'
                ? (jsonDecode(body) as Map)['email'] as String
                : 'late-A';
            request.response.write(
              jsonEncode({
                'success': true,
                'data': {
                  'user': {
                    'id': id,
                    'name': id,
                    'employeeId': 'employee-$id',
                    'companyId': 'company-$id',
                    'companyScope': ['company-$id'],
                  },
                  'tokens': {
                    'accessToken': 'token-$id',
                    'refreshToken': 'refresh-$id',
                    'expiresIn': 900,
                  },
                },
              }),
            );
          } else if (path == 'me') {
            final access = request.headers.value('authorization');
            final id = access?.replaceFirst('Bearer token-', '') ?? 'unknown';
            request.response.write(
              jsonEncode({
                'success': true,
                'data': {
                  'id': id,
                  'name': id,
                  'employeeId': 'employee-$id',
                  'companyId': 'company-$id',
                  'companyScope': ['company-$id'],
                },
              }),
            );
          } else if (path == 'logout') {
            request.response.write(jsonEncode({'success': true, 'data': null}));
          } else {
            request.response.headers.add('set-cookie', 'at=late-A; Path=/');
            request.response.headers.add('set-cookie', 'csrf=late-A; Path=/');
            request.response.write(
              jsonEncode({
                'success': true,
                'data': {'owner': 'A'},
              }),
            );
          }
          await request.response.close();
        });
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig(
                baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
                enableNetworkLogs: false,
              ),
            ),
            tokenStorageProvider.overrideWithValue(storage),
          ],
        );
        addTearDown(container.dispose);
        await container.read(authControllerProvider.future);
        final controller = container.read(authControllerProvider.notifier);
        await controller.login(email: 'A', password: 'fixture');
        final oldFeatureClient = container.read(featureDioProvider);
        final Future<Object?> pending;
        if (scenario.path == 'logout') {
          pending = controller.logout();
        } else {
          // Use the unscoped transport here so the late HTTP response reaches
          // the epoch guard; feature transports are also closed on disposal.
          pending = container
              .read(dioProvider)
              .get<dynamic>(scenario.path == 'refresh' ? '/protected' : '/slow')
              .then<Object?>(
                (response) => response,
                onError: (Object error) => error,
              );
        }
        await blocked.future;
        final expiresCurrent =
            scenario.path == 'refresh' &&
            scenario.status == 401 &&
            !scenario.loginB;
        if (!expiresCurrent) {
          if (scenario.path != 'logout') await controller.logout();
          expect(container.read(requestContextProvider), isNull);
          expect(await storage.readSession(), isNull);
          expect(await storage.readCookieHeader(), isNull);
        }
        if (scenario.loginB) {
          await controller.login(email: 'B', password: 'fixture');
        }
        release.complete();
        final outcome = await pending;
        if (expiresCurrent) await container.read(authControllerProvider.future);
        if (scenario.path != 'logout') {
          expect(
            outcome,
            isA<DioException>().having(
              (e) => e.type,
              'type',
              expiresCurrent
                  ? DioExceptionType.badResponse
                  : DioExceptionType.cancel,
            ),
          );
        }
        expect(
          await storage.readAccessToken(),
          scenario.loginB ? 'token-B' : null,
        );
        expect(await storage.readCsrfToken(), isNull);
        expect(
          (await storage.readSession())?['id'],
          scenario.loginB ? 'B' : null,
        );
        expect(
          container.read(authControllerProvider).requireValue?.userId,
          scenario.loginB ? 'B' : null,
        );
        expect(
          container.read(requestContextProvider)?.userId,
          scenario.loginB ? 'B' : null,
        );
        expect(
          container.read(sessionInvalidationProvider),
          expiresCurrent ? 1 : 0,
        );
        expect(
          received.where((r) => r.path == 'protected').length,
          scenario.path == 'refresh' ? 1 : 0,
        );
        if (!expiresCurrent) {
          final logout = received.firstWhere((r) => r.path == 'logout');
          expect(logout.auth, isNull);
          expect(logout.cookie, isNull);
          expect(jsonDecode(logout.body), {'refreshToken': 'refresh-A'});
        }
        expect(
          received
              .where((r) => r.path == 'login')
              .every(
                (r) =>
                    r.cookie == null &&
                    r.auth == null &&
                    r.clientType == 'mobile',
              ),
          isTrue,
        );
        expect(
          received
              .where((r) => r.path == 'refresh')
              .every((r) => r.clientType == 'mobile'),
          isTrue,
        );
        final count = received.length;
        await expectLater(
          oldFeatureClient.get<dynamic>('/must-not-send'),
          throwsA(isA<DioException>()),
        );
        expect(received.length, count);
      }, _LocalHttpOverrides()),
    );
  }
}

class _LocalHttpOverrides extends HttpOverrides {}
