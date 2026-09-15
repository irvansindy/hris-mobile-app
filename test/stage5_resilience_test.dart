import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/services/app_metadata.dart';
import 'package:hrm_app/core/services/clock.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/authentication/presentation/screens/change_password_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/employee_access_unavailable_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/login_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/session_splash_screen.dart';
import 'package:hrm_app/features/calendar/calendar_dependencies.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:hrm_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:hrm_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:hrm_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';
import 'package:hrm_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:hrm_app/features/profile/domain/entities/employee.dart';
import 'package:hrm_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:hrm_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/domain/entities/request_command.dart';
import 'package:hrm_app/features/self_service/domain/repositories/request_repository.dart';
import 'package:hrm_app/features/self_service/presentation/screens/request_form_screen.dart';
import 'package:hrm_app/features/self_service/presentation/screens/requests_screen.dart';
import 'package:hrm_app/features/self_service/self_service_dependencies.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3, 1.5, 2.0]) {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final size in [const Size(320, 568), const Size(430, 932)]) {
          testWidgets(
            'UI fixture matrix: dark=$dark, scale=$scale, $platform, $size',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final screens = <Widget>[
                HomeScreen(
                  onOpenAttendance: () {},
                  onOpenCalendar: () {},
                  onOpenRequests: () {},
                  onOpenNotifications: () {},
                ),
                const CalendarScreen(),
                const NotificationsScreen(),
                ProfileScreen(
                  onThemeToggle: () {},
                  onSignOut: () {},
                  isDarkMode: dark,
                ),
                const RequestsScreen(),
                const RequestFormScreen(kind: RequestKind.leave),
                const RequestFormScreen(kind: RequestKind.permission),
                const LoginScreen(),
                ChangePasswordScreen(onSignOut: () {}),
                EmployeeAccessUnavailableScreen(onSignOut: () {}),
                const SessionSplashScreen(),
                for (final kind in AppViewStateKind.values)
                  Scaffold(
                    body: SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: AppStateView(
                          kind: kind,
                          title: 'Fixture status dengan judul yang panjang',
                          message:
                              'Fixture keterangan untuk memeriksa layout status layanan, bukan data dari server.',
                          actionLabel: kind == AppViewStateKind.loading
                              ? null
                              : 'Muat ulang data',
                          onAction: kind == AppViewStateKind.loading
                              ? null
                              : () {},
                        ),
                      ),
                    ),
                  ),
              ];
              for (final screen in screens) {
                await tester.pumpWidget(
                  ProviderScope(
                    key: UniqueKey(),
                    overrides: [
                      clockProvider.overrideWithValue(
                        () => DateTime(2026, 9, 14),
                      ),
                      requestContextProvider.overrideWith(
                        (ref) => const RequestContext(
                          userId: 'fixture-user',
                          employeeId: 'fixture-employee',
                          activeCompanyId: 'fixture-company',
                          companyScope: ['fixture-company'],
                          permissions: ['leave:create', 'payroll:read'],
                        ),
                      ),
                      dashboardRepositoryProvider.overrideWithValue(
                        _Dashboard(),
                      ),
                      calendarRepositoryProvider.overrideWithValue(_Calendar()),
                      notificationRepositoryProvider.overrideWithValue(
                        _Notifications(),
                      ),
                      profileRepositoryProvider.overrideWithValue(_Profile()),
                      requestRepositoryProvider.overrideWithValue(_Requests()),
                      authRepositoryProvider.overrideWithValue(_Auth()),
                      appVersionProvider.overrideWith(
                        (ref) async => 'Fixture build',
                      ),
                    ],
                    child: MaterialApp(
                      theme: (dark ? AppTheme.dark : AppTheme.light).copyWith(
                        platform: platform,
                      ),
                      locale: const Locale('id', 'ID'),
                      supportedLocales: const [Locale('id', 'ID')],
                      localizationsDelegates:
                          GlobalMaterialLocalizations.delegates,
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale),
                          padding: const EdgeInsets.only(top: 44, bottom: 34),
                        ),
                        child: child!,
                      ),
                      home: screen,
                    ),
                  ),
                );
                await tester.pump(const Duration(milliseconds: 200));
                await tester.pump(const Duration(milliseconds: 200));
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '${screen.runtimeType} initial layout',
                );
                if (find.byType(Scrollable).evaluate().isNotEmpty) {
                  await tester.drag(
                    find.byType(Scrollable).first,
                    const Offset(0, -1600),
                  );
                  await tester.pump(const Duration(milliseconds: 500));
                  expect(
                    tester.takeException(),
                    isNull,
                    reason: '${screen.runtimeType} scrolled layout',
                  );
                }
                expect(find.text('Rp 99.999.999'), findsNothing);
              }
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }
  }
}

class _Dashboard implements DashboardRepository {
  @override
  DashboardSnapshot get current => const DashboardSnapshot(
    employee: DashboardEmployee(
      name: 'Fixture Employee dengan nama yang panjang',
      initials: 'FE',
      avatarColorIndex: 0,
    ),
    leaveBalancesAvailable: true,
    announcementsAvailable: true,
    leaveBalances: [
      LeaveBalance(
        type: 'Fixture cuti tahunan panjang',
        total: 12,
        used: 3,
        colorIndex: 0,
      ),
    ],
    announcements: [
      Announcement(
        title: 'Fixture pengumuman dengan judul yang panjang',
        body:
            'Fixture isi pengumuman untuk regresi visual, bukan informasi server.',
        time: '14 September 2026',
        category: 'Fixture',
      ),
    ],
  );
  @override
  Future<DashboardSnapshot> refresh() async => current;
}

class _Calendar implements CalendarRepository {
  @override
  CalendarData get current => CalendarData(
    focusedDate: DateTime(2026, 9, 14),
    eventsByDay: const {
      14: [
        CalendarEvent(
          'Fixture agenda dengan judul panjang',
          CalendarEventTone.primary,
          time: '08:00 - 17:00',
          detail: 'Fixture kantor dan catatan jadwal panjang',
        ),
      ],
    },
  );
  @override
  Future<CalendarData> loadMonth(int year, int month) async => current;
}

class _Notifications implements NotificationRepository {
  @override
  Future<List<NotificationItem>> load({required int limit}) async => const [
    NotificationItem(
      id: 'fixture-n',
      title: 'Fixture notifikasi dengan judul panjang',
      message: 'Fixture pesan untuk memeriksa layout, bukan informasi server.',
      isRead: false,
    ),
  ];
  @override
  Future<int> unreadCount() async => 1;
  @override
  Future<void> read(List<String> ids) async {}
  @override
  Future<void> readAll() async {}
}

class _Profile implements ProfileRepository {
  @override
  Employee get currentEmployee => const Employee(
    id: 'FIXTURE-EMPLOYEE',
    name: 'Fixture Employee dengan nama yang panjang',
    role: 'Fixture posisi jabatan dengan nama yang panjang',
    department: 'Fixture departemen operasional panjang',
    email: 'fixture.employee.panjang@example.test',
    phone: '+62 812 3456 7890',
    location: 'Fixture kantor pusat dengan nama yang panjang',
    joinDate: '14 September 2026',
    salary: 99999999,
    initials: 'FE',
    avatarColorIndex: 0,
  );
  @override
  Future<Employee> refresh() async => currentEmployee;
}

class _Requests extends RequestRepository {
  @override
  List<EmployeeRequest> get current => const [
    EmployeeRequest(
      id: 'fixture-request',
      type: 'Fixture cuti tahunan panjang',
      dateRange: '14 September 2026 sampai 16 September 2026',
      submittedOn: '14 September 2026',
      status: RequestStatus.pending,
      reason:
          'Fixture alasan yang panjang untuk memeriksa layout detail pengajuan.',
    ),
  ];
  @override
  Future<List<EmployeeRequest>> refresh() async => current;
  @override
  Future<List<LeaveTypeOption>> getLeaveTypes() async => const [
    LeaveTypeOption(
      id: 'fixture-type',
      name: 'Fixture jenis cuti tahunan dengan nama yang panjang',
    ),
  ];
  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) =>
      throw UnsupportedError('Fixture does not submit requests.');
}

class _Auth implements AuthRepository {
  @override
  Future<bool> hasSession() async => false;
  @override
  Future<Result<AuthSession?>> restoreSession() async => const Success(null);
  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) => throw UnsupportedError('Fixture does not log in.');
  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnsupportedError('Fixture does not change passwords.');
  @override
  Future<void> logout() async {}
}
