import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/app/router/app_router.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/core/widgets/app_navigation.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/approvals/approval_dependencies.dart';
import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';
import 'package:hrm_app/features/approvals/domain/repositories/approval_repository.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';
import 'package:hrm_app/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:hrm_app/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:hrm_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:hrm_app/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:hrm_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const config = AppConfig(
    baseUrl: 'https://example.test',
    connectTimeout: Duration(seconds: 1),
    receiveTimeout: Duration(seconds: 1),
    enableNetworkLogs: false,
  );

  Future<ProviderContainer> containerFor(AuthRepository repository) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appConfigProvider.overrideWithValue(config),
        authRepositoryProvider.overrideWithValue(repository),
        approvalRepositoryProvider.overrideWithValue(_Approvals()),
        notificationRepositoryProvider.overrideWithValue(_Notifications()),
        dashboardRepositoryProvider.overrideWith((ref) {
          final session = ref.watch(featureSessionProvider);
          return DashboardRepositoryImpl(
            EmptyDashboardLocalDataSource(),
            null,
            () => session.context,
          );
        }),
        profileRepositoryProvider.overrideWith((ref) {
          final session = ref.watch(featureSessionProvider);
          return ProfileRepositoryImpl(
            EmptyProfileLocalDataSource(),
            null,
            () => session.context,
          );
        }),
      ],
    );
  }

  testWidgets('splash remains only while session restoration is pending', (
    tester,
  ) async {
    final repository = _AuthRepository()..restoreGate = Completer();
    final container = await containerFor(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HrmsApp()),
    );
    await tester.pump();

    expect(find.text('Memulihkan sesi...'), findsOneWidget);
    repository.restoreGate!.complete(const Success(null));
    await tester.pumpAndSettle();
    expect(find.text('EMAIL KANTOR'), findsOneWidget);
    expect(find.text('Memulihkan sesi...'), findsNothing);
  });

  testWidgets('shell keeps four branches and hides navigation on requests', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final container = await containerFor(
      _AuthRepository(restoredSession: _employeeSession('employee-a')),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HrmsApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppFloatingNavigation), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    final homeContext = tester.element(find.byType(HomeScreen));
    expect(Localizations.localeOf(homeContext), const Locale('id', 'ID'));
    expect(MaterialLocalizations.of(homeContext).cancelButtonLabel, 'Batal');
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Ajukan cuti'), findsNothing);
    expect(find.text('Klaim lembur'), findsNothing);
    expect(find.text('Reimbursement'), findsNothing);
    expect(find.text('Slip gaji'), findsNothing);

    final homeScroll = PrimaryScrollController.of(
      tester.element(find.byType(HomeScreen)),
    );
    homeScroll.jumpTo(homeScroll.position.maxScrollExtent);
    expect(homeScroll.offset, greaterThan(0));
    tester
        .widget<AppFloatingNavigation>(find.byType(AppFloatingNavigation))
        .onDestinationSelected(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(homeScroll.offset, 0);

    await tester.tap(find.byTooltip('Buka absensi'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<AppFloatingNavigation>(find.byType(AppFloatingNavigation))
          .selectedIndex,
      1,
    );

    container.read(appRouterProvider).push('/requests');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Pengajuan'), findsOneWidget);
    expect(find.byType(AppFloatingNavigation), findsNothing);

    container.read(appRouterProvider).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AppFloatingNavigation), findsOneWidget);

    container.read(appRouterProvider).go('/profile');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<AppFloatingNavigation>(find.byType(AppFloatingNavigation))
          .selectedIndex,
      3,
    );
  });

  testWidgets('login success is shown only with bootstrapped employee name', (
    tester,
  ) async {
    final repository = _AuthRepository();
    final container = await containerFor(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HrmsApp()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'employee@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'Password1!',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Berhasil masuk'), findsOneWidget);
    expect(find.text('Selamat datang, Employee Nyata.'), findsOneWidget);
    expect(find.byType(AppFloatingNavigation), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Berhasil masuk'), findsNothing);
  });

  testWidgets(
    'reduced motion skips success overlay and reselected tab jumps immediately',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final container = await containerFor(_AuthRepository());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const HrmsApp()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'employee@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Password1!',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Berhasil masuk'), findsNothing);
      final scroll = PrimaryScrollController.of(
        tester.element(find.byType(HomeScreen)),
      );
      scroll.jumpTo(scroll.position.maxScrollExtent);
      expect(scroll.offset, greaterThan(0));
      tester
          .widget<AppFloatingNavigation>(find.byType(AppFloatingNavigation))
          .onDestinationSelected(0);
      expect(scroll.offset, 0);
      await tester.tap(find.byTooltip('Buka absensi'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppFloatingNavigation>(find.byType(AppFloatingNavigation))
            .selectedIndex,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manager opens Approval Center while employee route is guarded', (
    tester,
  ) async {
    final managerContainer = await containerFor(
      _AuthRepository(restoredSession: _managerSession()),
    );
    addTearDown(managerContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: managerContainer,
        child: const HrmsApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Approval'), findsOneWidget);
    await tester.tap(find.text('Approval'));
    await tester.pumpAndSettle();
    expect(find.text('Approval Center'), findsOneWidget);
    expect(find.text('Tidak ada approval menunggu'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final employeeContainer = await containerFor(
      _AuthRepository(restoredSession: _employeeSession('employee-a')),
    );
    addTearDown(employeeContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: employeeContainer,
        child: const HrmsApp(),
      ),
    );
    await tester.pumpAndSettle();
    employeeContainer.read(appRouterProvider).go('/approvals');
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Approval Center'), findsNothing);
  });

  testWidgets(
    'notification badge opens inbox outside shell, reads item and back restores Home',
    (tester) async {
      final container = await containerFor(
        _AuthRepository(restoredSession: _employeeSession('employee-a')),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const HrmsApp()),
      );
      await tester.pumpAndSettle();
      expect(container.read(notificationUnreadCountProvider).requireValue, 1);
      await tester.tap(find.byTooltip('Buka notifikasi'));
      await tester.pumpAndSettle();
      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.byType(AppFloatingNavigation), findsNothing);
      await tester.tap(find.text('Fixture pengumuman'));
      await tester.pumpAndSettle();
      expect(container.read(notificationUnreadCountProvider).requireValue, 0);
      expect(
        find.text('Detail terkait belum tersedia di aplikasi mobile.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.byType(AppFloatingNavigation), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}

class _Notifications implements NotificationRepository {
  @override
  Future<void> delete(String id) async {}

  int count = 1;
  @override
  Future<List<NotificationItem>> load({required int limit}) async => [
    const NotificationItem(
      id: 'n1',
      title: 'Fixture pengumuman',
      isRead: false,
    ),
  ];
  @override
  Future<int> unreadCount() async => count;
  @override
  Future<void> read(List<String> ids) async {
    count = 0;
  }

  @override
  Future<void> readAll() async {
    count = 0;
  }
}

AuthSession _employeeSession(String id) => AuthSession(
  accessToken: 'fixture-$id',
  userId: id,
  employeeId: id,
  companyId: 'company-a',
  userName: id == 'employee@example.test' ? 'Employee Nyata' : id,
);

AuthSession _managerSession() => const AuthSession(
  accessToken: 'fixture-manager-a',
  userId: 'manager-a',
  employeeId: 'manager-a',
  companyId: 'company-a',
  userName: 'Manager A',
  permissions: ['workflow:approve'],
);

class _Approvals implements ApprovalRepository {
  @override
  Future<WorkflowApprovalPage> getQueue({required int page, int limit = 20}) =>
      Future.value(
        WorkflowApprovalPage(
          items: const [],
          page: page,
          totalPages: 1,
          total: 0,
        ),
      );

  @override
  Future<void> applyAction({
    required String instanceId,
    required WorkflowApprovalAction action,
    String? comment,
  }) => throw UnimplementedError();

  @override
  Future<WorkflowBulkResult> applyBulkAction({
    required List<String> instanceIds,
    required WorkflowApprovalAction action,
    String? comment,
  }) => throw UnimplementedError();

  @override
  Future<List<ApprovalDelegation>> getDelegations() async => const [];

  @override
  Future<ApprovalDelegation> createDelegation(
    CreateApprovalDelegation command,
  ) => throw UnimplementedError();

  @override
  Future<ApprovalDelegation> revokeDelegation(String id) =>
      throw UnimplementedError();
}

class _AuthRepository implements AuthRepository {
  _AuthRepository({this.restoredSession});

  final AuthSession? restoredSession;
  Completer<Result<AuthSession?>>? restoreGate;

  @override
  Future<bool> hasSession() async => restoredSession != null;

  @override
  Future<Result<AuthSession?>> restoreSession() =>
      restoreGate?.future ?? Future.value(Success(restoredSession));

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) async => Success(_employeeSession(email));

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() async {}
}
