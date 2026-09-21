import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/services/app_metadata.dart';
import 'package:hrm_app/core/services/clock.dart';
import 'package:hrm_app/core/services/location_gateway.dart';
import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/features/attendance/attendance_dependencies.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/calendar/calendar_dependencies.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';
import 'package:hrm_app/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:hrm_app/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';
import 'package:hrm_app/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:hrm_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/domain/entities/request_command.dart';
import 'package:hrm_app/features/self_service/domain/repositories/request_repository.dart';
import 'package:hrm_app/features/self_service/self_service_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> createRedesignFlowFixture({
  bool rejectAttendance = false,
  Clock? clock,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      if (clock != null) clockProvider.overrideWithValue(clock),
      sharedPreferencesProvider.overrideWithValue(preferences),
      appConfigProvider.overrideWithValue(
        const AppConfig(
          baseUrl: 'https://fixture.invalid/api/v1',
          connectTimeout: Duration(seconds: 1),
          receiveTimeout: Duration(seconds: 1),
          enableNetworkLogs: false,
        ),
      ),
      authRepositoryProvider.overrideWithValue(_Auth()),
      appVersionProvider.overrideWith((ref) async => 'Fixture build'),
      locationServiceProvider.overrideWithValue(const _Location()),
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
      attendanceRepositoryProvider.overrideWith(
        (ref) => FixtureAttendance(
          ref.watch(featureSessionProvider).context,
          reject: rejectAttendance,
        ),
      ),
      requestRepositoryProvider.overrideWith((ref) {
        ref.watch(featureSessionProvider);
        return _Requests();
      }),
      calendarRepositoryProvider.overrideWith((ref) {
        ref.watch(featureSessionProvider);
        return _Calendar();
      }),
      notificationRepositoryProvider.overrideWith((ref) {
        ref.watch(featureSessionProvider);
        return _Notifications();
      }),
    ],
  );
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
  }) async {
    final account = email.startsWith('fixture-b') ? 'B' : 'A';
    return Success(
      AuthSession(
        accessToken: 'fixture-token-$account',
        userId: 'fixture-user-$account',
        employeeId: 'fixture-employee-$account',
        companyId: 'fixture-company-$account',
        companyScope: ['fixture-company-$account'],
        permissions: const ['leave:create', 'payroll:read'],
        userName: 'Fixture Employee $account',
        email: email,
      ),
    );
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnsupportedError('Fixture does not change passwords.');
  @override
  Future<void> logout() async {}
}

class FixtureAttendance extends AttendanceRepository {
  FixtureAttendance(this.context, {required this.reject});
  final RequestContext? context;
  final bool reject;
  int submissions = 0;
  AttendanceEntity? recorded;
  @override
  Future<Result<AttendanceEntity>> getToday() async => Success(
    recorded ??
        AttendanceEntity(
          id: '',
          userId: context?.employeeId ?? '',
          checkedInAt: null,
          status: AttendanceStatus.notStarted,
          latitude: 0,
          longitude: 0,
        ),
  );
  @override
  Future<Result<AttendanceContext>> getContext() async => Success(
    AttendanceContext(
      employeeId: context?.employeeId ?? '',
      companyId: context?.activeCompanyId ?? '',
      branchName: 'Fixture Kantor',
      allowedMethods: const {AttendanceCaptureMethod.mobileGps},
      requiresLocation: true,
      requiresSelfie: false,
      isWorkingDay: true,
      allowHolidayAttendance: true,
      allowWeekendAttendance: true,
      warnings: const [],
    ),
  );
  @override
  Future<Result<AttendanceEntity>> clockIn(AttendanceCommand command) async {
    submissions++;
    if (reject) {
      return const FailureResult(
        ServerFailure('Fixture penolakan server', statusCode: 400),
      );
    }
    recorded = AttendanceEntity(
      id: 'fixture-attendance',
      userId: context!.employeeId!,
      checkedInAt: command.capturedAt,
      status: AttendanceStatus.onTime,
      latitude: command.latitude,
      longitude: command.longitude,
    );
    return Success(recorded!);
  }

  @override
  Future<Result<AttendanceEntity>> clockOut(AttendanceCommand command) =>
      throw UnsupportedError('Fixture does not check out.');
}

class _Location implements LocationGateway {
  const _Location();
  @override
  Future<GeoCoordinate> currentPosition() async =>
      GeoCoordinate(-6.2, 106.8, accuracyMeters: 8, capturedAt: DateTime.now());
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

class _Requests extends RequestRepository {
  final _items = <EmployeeRequest>[];
  @override
  List<EmployeeRequest> get current => List.unmodifiable(_items);
  @override
  Future<List<EmployeeRequest>> refresh() async => current;
  @override
  Future<List<LeaveTypeOption>> getLeaveTypes() async => const [
    LeaveTypeOption(id: 'fixture-leave-type', name: 'Fixture cuti tahunan'),
  ];
  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) async {
    final item = EmployeeRequest(
      id: 'fixture-leave',
      type: 'Fixture cuti tahunan',
      dateRange: 'Fixture periode',
      submittedOn: 'Fixture tanggal',
      status: RequestStatus.pending,
      reason: command.reason,
      startDate: command.startDate,
      endDate: command.endDate,
    );
    _items.add(item);
    return item;
  }
}

class _Calendar implements CalendarRepository {
  @override
  CalendarData get current => CalendarData(
    focusedDate: DateTime.now(),
    eventsByDay: {
      DateTime.now().day: const [
        CalendarEvent('Fixture jadwal', CalendarEventTone.primary),
      ],
    },
  );
  @override
  Future<CalendarData> loadMonth(int year, int month) async => current;
}

class _Notifications implements NotificationRepository {
  @override
  Future<void> delete(String id) async {}

  bool _read = false;
  @override
  Future<List<NotificationItem>> load({required int limit}) async => [
    NotificationItem(
      id: 'fixture-notification',
      title: 'Fixture informasi',
      message: 'Fixture, bukan informasi server.',
      isRead: _read,
    ),
  ];
  @override
  Future<int> unreadCount() async => _read ? 0 : 1;
  @override
  Future<void> read(List<String> ids) async => _read = true;
  @override
  Future<void> readAll() async => _read = true;
}
