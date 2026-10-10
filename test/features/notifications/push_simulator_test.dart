import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/app/providers/push_lifecycle.dart';
import 'package:hrm_app/app/router/app_router.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';
import 'package:hrm_app/features/notifications/presentation/widgets/push_status_panel.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';
import 'package:hrm_app/features/notifications/push/push_coordinator.dart';
import 'package:hrm_app/features/notifications/push/push_providers.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:hrm_app/demo/demo_overrides.dart';
import 'package:hrm_app/main.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:hrm_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_route_test.dart' show InboxRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'real app route uses simulator hint but never opens payslip or payload URL',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final store = DemoStore(prefs);
      await store.load();
      final repo = InboxRepository()
        ..items = [
          const NotificationItem(
            id: 'n1',
            title: 'Server item',
            isRead: false,
            resource: 'payslip',
            referenceId: 'private',
          ),
        ];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(productionBuild: false),
          ),
          ...demoOverrides(store),
          notificationRepositoryProvider.overrideWithValue(repo),
          featureDioProvider.overrideWith(
            (_) => throw StateError('No demo HTTP'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const HrmsApp()),
      );
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/notifications');
      await tester.pumpAndSettle();
      expect(find.byType(PushStatusPanel), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'n1');
      await _tap(tester, 'Tap / background');
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/notifications',
      );
      expect(find.byType(NotificationsScreen), findsOneWidget);
      repo.items = [
        const NotificationItem(
          id: 'n2',
          title: 'Server attendance',
          isRead: true,
          resource: 'attendance',
        ),
      ];
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'n2');
      await _tap(tester, 'Tap / background');
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/attendance',
      );
      expect(find.byType(AttendanceScreen), findsOneWidget);
      expect(repo.reads, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'app bridge retains initial hint through restore and refetches only active providers',
    () async {
      final auth = _Auth();
      final repo = InboxRepository();
      final locations = <String>[];
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(
              productionBuild: false,
              values: {'PUSH_MODE': 'dummy'},
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          sessionArtifactCleanerProvider.overrideWithValue((_) async {}),
          notificationRepositoryProvider.overrideWithValue(repo),
          pushNavigateProvider.overrideWithValue(locations.add),
          featureDioProvider.overrideWith(
            (_) => throw StateError('No dummy network'),
          ),
          dioProvider.overrideWith((_) => throw StateError('No dummy network')),
        ],
      );
      addTearDown(container.dispose);
      container.read(pushLifecycleProvider);
      final adapter = container.read(pushAdapterProvider) as DummyPushAdapter;
      adapter.emit(
        const PushEvent(
          notificationId: 'n1',
          messageId: 'm1',
          kind: PushEventKind.initial,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(locations, isEmpty);
      expect(repo.loads, isEmpty);
      auth.restore.complete(
        const Success(
          AuthSession(
            userId: 'A',
            employeeId: 'employee-A',
            companyId: 'company',
          ),
        ),
      );
      await container.read(authControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(locations, ['/requests/leave/leave-1']);
      final lookupCount = repo.loads.length;
      expect(container.exists(notificationInboxProvider), isFalse);
      adapter.emit(const PushEvent(kind: PushEventKind.foreground));
      await Future<void>.delayed(Duration.zero);
      expect(repo.loads.length, lookupCount);
      final sub = container.listen(notificationInboxProvider, (_, _) {});
      await container.read(notificationInboxProvider.future);
      adapter.emit(const PushEvent(kind: PushEventKind.foreground));
      await Future<void>.delayed(Duration.zero);
      await container.read(notificationInboxProvider.future);
      expect(repo.loads.length, lookupCount + 2);
      sub.close();
      adapter.emit(
        const PushEvent(notificationId: 'n1', kind: PushEventKind.opened),
      );
      await container.read(authControllerProvider.notifier).logout();
      await Future<void>.delayed(Duration.zero);
      expect(locations, hasLength(1));
      adapter.emit(
        const PushEvent(notificationId: 'n1', kind: PushEventKind.opened),
      );
      await Future<void>.delayed(Duration.zero);
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'B', password: 'fixture');
      await Future<void>.delayed(Duration.zero);
      expect(locations, hasLength(1));
      adapter.emit(
        const PushEvent(notificationId: 'n1', kind: PushEventKind.opened),
      );
      await Future<void>.delayed(Duration.zero);
      expect(locations, hasLength(2));
    },
  );

  test(
    'pending hint for blocked employee is cleared by logout before B login',
    () async {
      final auth = _Auth();
      final repo = InboxRepository();
      final locations = <String>[];
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(
              productionBuild: false,
              values: {'PUSH_MODE': 'dummy'},
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          sessionArtifactCleanerProvider.overrideWithValue((_) async {}),
          notificationRepositoryProvider.overrideWithValue(repo),
          pushNavigateProvider.overrideWithValue(locations.add),
        ],
      );
      addTearDown(container.dispose);
      container.read(pushLifecycleProvider);
      final adapter = container.read(pushAdapterProvider) as DummyPushAdapter;
      adapter.emit(
        const PushEvent(notificationId: 'n1', kind: PushEventKind.initial),
      );
      await Future<void>.delayed(Duration.zero);
      auth.restore.complete(
        const Success(
          AuthSession(
            userId: 'blocked',
            companyId: 'company',
            mustChangePassword: true,
          ),
        ),
      );
      await container.read(authControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(locations, isEmpty);
      expect(repo.loads, isEmpty);
      await container.read(authControllerProvider.notifier).logout();
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'B', password: 'fixture');
      await Future<void>.delayed(Duration.zero);
      expect(locations, isEmpty);
      expect(repo.loads, isEmpty);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('simulator controls work at 320dp text200 dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final registry = DummyDeviceRegistrationRepository();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(
              productionBuild: false,
              values: {'PUSH_MODE': 'dummy'},
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          deviceRegistrationRepositoryProvider.overrideWithValue(registry),
          featureDioProvider.overrideWith(
            (_) => throw StateError('No dummy network'),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(requestContextProvider.notifier)
          .state = const RequestContext(
        userId: 'A',
        employeeId: 'employee-A',
        activeCompanyId: 'company',
        companyScope: ['company'],
      );
      final coordinator = container.read(pushCoordinatorProvider);
      await coordinator.bind(container.read(featureSessionProvider));
      final events = <PushEvent>[];
      final subscription = coordinator.events.listen(events.add);
      addTearDown(subscription.cancel);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(child: PushStatusPanel()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Simulasi push lokal'), findsOneWidget);
      for (final button in tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      )) {
        final theme = Theme.of(tester.element(find.byWidget(button)));
        final border =
            button.style?.side?.resolve({}) ??
            theme.outlinedButtonTheme.style!.side!.resolve({})!;
        final a = border.color.computeLuminance();
        final b = theme.scaffoldBackgroundColor.computeLuminance();
        final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(ratio, greaterThanOrEqualTo(3));
      }
      await tester.enterText(find.byType(TextField), 'n1');
      for (final label in [
        'Foreground',
        'Tap / background',
        'Initial / terminated',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(events.map((e) => e.kind), PushEventKind.values);
      expect(events.every((e) => e.notificationId == 'n1'), isTrue);
      await tester.ensureVisible(find.text('Foreground'));
      Focus.of(tester.element(find.text('Foreground'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(events, hasLength(4));
      expect(events.last.kind, PushEventKind.foreground);
      expect(find.textContaining('bukan kill/relaunch OS'), findsOneWidget);
      final oldToken = registry.registrations.values.single.token;
      await _tap(tester, 'Rotasi token');
      expect(registry.registrations.values.single.token, isNot(oldToken));
      await _tap(tester, 'Tolak izin');
      expect(coordinator.status, PushStatus.denied);
      await _tap(tester, 'Izinkan');
      expect(coordinator.status, PushStatus.simulated);
      await _tap(tester, 'Gagalkan registrasi');
      expect(coordinator.status, PushStatus.failed);
      expect(registry.failRegistration, isFalse);
      await _tap(tester, 'Coba aktivasi lagi');
      expect(coordinator.status, PushStatus.simulated);
      expect(registry.failRegistration, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('disabled panel has no simulator or SDK initialization', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushModeProvider.overrideWithValue(PushMode.disabled),
          pushAdapterProvider.overrideWith((_) => throw StateError('No SDK')),
        ],
        child: MaterialApp(home: const Scaffold(body: PushStatusPanel())),
      ),
    );
    expect(find.text('Push belum diaktifkan'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Simulasi push lokal'), findsNothing);
  });
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

class _Auth implements AuthRepository {
  final restore = Completer<Result<AuthSession?>>();
  @override
  Future<Result<AuthSession?>> restoreSession() => restore.future;
  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) async => Success(
    AuthSession(
      userId: email,
      employeeId: 'employee-$email',
      companyId: 'company',
    ),
  );
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<void> logout() async {}
  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => const Success(null);
}
