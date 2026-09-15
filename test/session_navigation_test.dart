import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/core/widgets/app_navigation.dart';
import 'package:hrm_app/features/attendance/attendance_dependencies.dart';
import 'package:hrm_app/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:hrm_app/features/attendance/data/dto/attendance_dto.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';
import 'package:hrm_app/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:hrm_app/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';
import 'package:hrm_app/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:hrm_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:hrm_app/features/self_service/self_service_providers.dart';
import 'package:hrm_app/features/self_service/self_service_dependencies.dart';
import 'package:hrm_app/features/self_service/data/datasources/request_local_datasource.dart';
import 'package:hrm_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'logout removes A routes and drafts; B starts at Home with theme retained',
    (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authRepositoryProvider.overrideWithValue(_Repository()),
          dashboardRepositoryProvider.overrideWith((ref) {
            final session = ref.watch(featureSessionProvider);
            return DashboardRepositoryImpl(
              DemoDashboardLocalDataSource(),
              null,
              () => session.context,
            );
          }),
          profileRepositoryProvider.overrideWith((ref) {
            final session = ref.watch(featureSessionProvider);
            return ProfileRepositoryImpl(
              DemoProfileLocalDataSource(),
              null,
              () => session.context,
            );
          }),
          attendanceDataSourceProvider.overrideWith((ref) {
            ref.watch(featureSessionProvider);
            return _AttendanceRemote();
          }),
          requestLocalDataSourceProvider.overrideWith((ref) {
            ref.watch(featureSessionProvider);
            return DemoRequestLocalDataSource();
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const HrmsApp()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Account A'), findsOneWidget);
      expect(
        tester
            .widget<AppFloatingNavigation>(find.byType(AppFloatingNavigation))
            .selectedIndex,
        3,
      );
      await container
          .read(requestControllerProvider.notifier)
          .submit('Private request A');
      final context = tester.element(find.byType(AppFloatingNavigation));
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Private draft A')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private draft A'), findsOneWidget);

      final controller = container.read(authControllerProvider.notifier);
      await controller.logout();
      await tester.pumpAndSettle();
      expect(find.text('Private draft A'), findsNothing);
      expect(find.text('Account A'), findsNothing);
      expect(find.text('EMAIL KANTOR'), findsOneWidget);
      await controller.login(email: 'B', password: 'fixture');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppFloatingNavigation>(find.byType(AppFloatingNavigation))
            .selectedIndex,
        0,
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        container.read(requestControllerProvider).map((r) => r.type),
        isNot(contains('Private request A')),
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Account B'), findsOneWidget);
      expect(find.text('Account A'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Repository implements AuthRepository {
  AuthSession _session(String id) => AuthSession(
    accessToken: 'fixture-$id',
    userId: id,
    employeeId: id,
    companyId: id,
    userName: 'Account $id',
  );
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<Result<AuthSession?>> restoreSession() async => Success(_session('A'));
  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) async => Success(_session(email));
  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => const Success(null);
  @override
  Future<void> logout() async {}
}

class _AttendanceRemote extends AttendanceRemoteDataSource {
  @override
  Future<AttendanceDto> getToday() async => const AttendanceDto(
    id: '',
    employeeId: 'employee',
    checkedInAt: null,
    status: 'notStarted',
    latitude: 0,
    longitude: 0,
  );

  @override
  Future<AttendanceContext> getContext() async => const AttendanceContext(
    employeeId: 'employee',
    companyId: 'company',
    allowedMethods: {AttendanceCaptureMethod.mobileGps},
    requiresLocation: true,
    requiresSelfie: false,
    isWorkingDay: true,
    allowHolidayAttendance: false,
    allowWeekendAttendance: false,
    warnings: [],
  );

  @override
  Future<AttendanceDto> clockIn(AttendanceCommand command) =>
      throw UnimplementedError();

  @override
  Future<AttendanceDto> clockOut(AttendanceCommand command) =>
      throw UnimplementedError();
}
