import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/account_security/account_security_providers.dart';
import 'package:hrm_app/features/account_security/data/account_security_repository_impl.dart';
import 'package:hrm_app/features/account_security/domain/entities/account_security.dart';
import 'package:hrm_app/features/account_security/domain/repositories/account_security_repository.dart';
import 'package:hrm_app/features/account_security/presentation/screens/account_security_screen.dart';

const _context = RequestContext(
  userId: 'u1',
  employeeId: 'e1',
  activeCompanyId: 'c1',
  companyScope: ['c1'],
);

const _qrDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

final _session = AccountSession(
  id: 'session-1',
  userAgent: 'Android test device',
  ipAddress: '192.0.2.10',
  createdAt: DateTime.utc(2026, 9, 18, 8),
  expiresAt: DateTime.utc(2026, 9, 25, 8),
  isCurrent: true,
);

void main() {
  test(
    'account security uses documented auth methods and strict responses',
    () async {
      final adapter = _SecurityAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repo = DioAccountSecurityRepository(dio, _context);

      final setup = await repo.setupMfa();
      expect(setup.secret, 'TOP-SECRET');
      final enabled = await repo.enableMfa('123456');
      expect(enabled.recoveryCodes, ['recovery-1', 'recovery-2']);
      await repo.disableMfa('recovery-1');
      final sessions = await repo.loadSessions();
      expect(sessions.single.isCurrent, isNull);
      await repo.revokeSession('session-1');

      expect(
        adapter.requests.map((request) => '${request.method} ${request.path}'),
        [
          'POST /auth/mfa/setup',
          'POST /auth/mfa/enable',
          'POST /auth/mfa/disable',
          'GET /auth/sessions',
          'DELETE /auth/sessions/session-1',
        ],
      );
      expect(adapter.requests[1].data, {'code': '123456'});
      expect(adapter.requests[2].data, {'code': 'recovery-1'});
    },
  );

  for (final defect in [
    'setup-secret',
    'setup-qr',
    'recovery',
    'session-id',
    'session-date',
    'session-current',
    'failure',
  ]) {
    test('account security rejects $defect response', () async {
      final dio = Dio()..httpClientAdapter = _SecurityAdapter(defect: defect);
      addTearDown(dio.close);
      final repo = DioAccountSecurityRepository(dio, _context);
      final operation = switch (defect) {
        'setup-secret' || 'setup-qr' => repo.setupMfa(),
        'recovery' => repo.enableMfa('123456'),
        'session-id' ||
        'session-date' ||
        'session-current' => repo.loadSessions(),
        _ => repo.disableMfa('123456'),
      };
      await expectLater(operation, throwsFormatException);
    });
  }

  test('MFA controller never stores setup secret or recovery codes', () async {
    final repo = _SecurityRepo();
    final container = ProviderContainer(
      overrides: [accountSecurityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final setup = await container.read(mfaControllerProvider.notifier).setup();
    expect(setup?.secret, 'TOP-SECRET');
    expect(
      container.read(mfaControllerProvider).status,
      MfaRuntimeStatus.unknown,
    );
    final enabled = await container
        .read(mfaControllerProvider.notifier)
        .enable('123456');
    expect(enabled?.recoveryCodes, ['recovery-1']);
    final state = container.read(mfaControllerProvider);
    expect(state.status, MfaRuntimeStatus.enabled);
    expect(state.toString(), isNot(contains('TOP-SECRET')));
    expect(state.toString(), isNot(contains('recovery-1')));
  });

  test('late session list cannot contaminate the next account', () async {
    final first = _SecurityRepo()
      ..pendingSessions = Completer<List<AccountSession>>();
    final second = _SecurityRepo(
      sessions: [
        AccountSession(
          id: 'session-2',
          createdAt: DateTime.utc(2026, 9, 19),
          expiresAt: DateTime.utc(2026, 9, 26),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        accountSecurityRepositoryProvider.overrideWith((ref) {
          return ref.watch(requestContextProvider)?.userId == 'u1'
              ? first
              : second;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(requestContextProvider.notifier).state = _context;
    final sub = container.listen(accountSessionsProvider, (_, _) {});
    addTearDown(sub.close);
    final firstLoad = container.read(accountSessionsProvider.future);
    container
        .read(requestContextProvider.notifier)
        .state = const RequestContext(
      userId: 'u2',
      employeeId: 'e2',
      activeCompanyId: 'c2',
      companyScope: ['c2'],
    );
    expect(
      (await container.read(accountSessionsProvider.future)).items.single.id,
      'session-2',
    );
    first.pendingSessions!.complete([_session]);
    expect((await firstLoad).items.single.id, 'session-2');
    expect(
      container.read(accountSessionsProvider).requireValue.items.single.id,
      'session-2',
    );
  });

  testWidgets(
    'explicit current-session revoke invokes local sign-out callback',
    (tester) async {
      var signOuts = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSecurityRepositoryProvider.overrideWithValue(
              _SecurityRepo(sessions: [_session]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: AccountSecurityScreen(
              onCurrentSessionRevoked: () async => signOuts++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cabut sesi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cabut sesi'));
      await tester.pumpAndSettle();
      expect(signOuts, 1);
    },
  );

  testWidgets(
    'MFA setup, recovery acknowledgement, and disable click through',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSecurityRepositoryProvider.overrideWithValue(
              _SecurityRepo(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: AccountSecurityScreen(onCurrentSessionRevoked: () async {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Siapkan MFA'));
      await tester.pumpAndSettle();
      expect(find.text('Kunci manual'), findsOneWidget);
      expect(find.text('TOP-SECRET'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kode autentikator'),
        '123456',
      );
      await tester.tap(find.text('Verifikasi dan aktifkan'));
      await tester.pumpAndSettle();
      expect(find.text('recovery-1'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nonaktifkan'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Kode verifikasi'),
        '123456',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Nonaktifkan'));
      await tester.pumpAndSettle();
      expect(find.text('MFA dinonaktifkan oleh server.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('security screen fits 320dp and 200% text, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSecurityRepositoryProvider.overrideWithValue(
              _SecurityRepo(sessions: [_session]),
            ),
          ],
          child: MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(top: 30),
              ),
              child: child!,
            ),
            home: AccountSecurityScreen(onCurrentSessionRevoked: () async {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Keamanan akun'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Keamanan akun')).dy,
        greaterThanOrEqualTo(46),
      );
      await tester.scrollUntilVisible(find.text('Cabut sesi'), 350);
      expect(tester.takeException(), isNull);
    });
  }
}

class _SecurityRepo implements AccountSecurityRepository {
  _SecurityRepo({this.sessions = const []});

  final List<AccountSession> sessions;
  Completer<List<AccountSession>>? pendingSessions;

  @override
  Future<MfaSetup> setupMfa() async =>
      const MfaSetup(secret: 'TOP-SECRET', qrDataUrl: _qrDataUrl);

  @override
  Future<MfaEnableResult> enableMfa(String code) async =>
      const MfaEnableResult(recoveryCodes: ['recovery-1']);

  @override
  Future<void> disableMfa(String code) async {}

  @override
  Future<List<AccountSession>> loadSessions() async =>
      pendingSessions == null ? sessions : pendingSessions!.future;

  @override
  Future<void> revokeSession(String id) async {}
}

class _SecurityAdapter implements HttpClientAdapter {
  _SecurityAdapter({this.defect});

  final String? defect;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Object? data;
    if (options.path.endsWith('/mfa/setup')) {
      data = {
        'secret': defect == 'setup-secret' ? '' : 'TOP-SECRET',
        'qrDataUrl': defect == 'setup-qr' ? 'not-a-data-url' : _qrDataUrl,
      };
    } else if (options.path.endsWith('/mfa/enable')) {
      data = {
        'recoveryCodes': defect == 'recovery'
            ? <String>[]
            : ['recovery-1', 'recovery-2'],
      };
    } else if (options.path.endsWith('/sessions') && options.method == 'GET') {
      data = [
        {
          'id': defect == 'session-id' ? '' : 'session-1',
          'userAgent': 'Android test device',
          'ipAddress': '192.0.2.10',
          'createdAt': defect == 'session-date'
              ? 'invalid'
              : '2026-09-18T08:00:00.000Z',
          'expiresAt': '2026-09-25T08:00:00.000Z',
          if (defect == 'session-current') 'current': 'yes',
        },
      ];
    }
    return ResponseBody.fromString(
      jsonEncode({'success': defect != 'failure', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
