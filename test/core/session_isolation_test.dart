import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/attendance/attendance_dependencies.dart';
import 'package:hrm_app/features/attendance/attendance_providers.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/calendar/calendar_dependencies.dart';
import 'package:hrm_app/features/calendar/calendar_providers.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';
import 'package:hrm_app/features/dashboard/dashboard_providers.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:hrm_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';
import 'package:hrm_app/features/profile/profile_providers.dart';
import 'package:hrm_app/features/profile/domain/entities/employee.dart';
import 'package:hrm_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:hrm_app/features/self_service/self_service_providers.dart';
import 'package:hrm_app/features/self_service/self_service_dependencies.dart';
import 'package:hrm_app/features/self_service/data/datasources/request_local_datasource.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/domain/entities/request_command.dart';
import 'package:hrm_app/features/self_service/domain/repositories/request_repository.dart';

void main() {
  test('request submitted by A is absent after logout and login B', () async {
    final container = ProviderContainer(
      overrides: [
        requestLocalDataSourceProvider.overrideWith((ref) {
          ref.watch(featureSessionProvider);
          return DemoRequestLocalDataSource();
        }),
      ],
    );
    addTearDown(container.dispose);
    final context = container.read(requestContextProvider.notifier);
    context.state = _account('A');
    container.read(requestControllerProvider);
    await container.read(requestControllerProvider.notifier).submit('Only A');
    expect(container.read(requestControllerProvider).first.type, 'Only A');

    context.state = null;
    context.state = _account('B');
    expect(
      container.read(requestControllerProvider).map((item) => item.type),
      isNot(contains('Only A')),
    );
  });

  test(
    'late request submission writes only to the abandoned A repository',
    () async {
      final accountA = _Requests();
      final accountB = _Requests();
      final container = ProviderContainer(
        overrides: [
          requestRepositoryProvider.overrideWith((ref) {
            final session = ref.watch(featureSessionProvider);
            return session.context?.userId == 'A' ? accountA : accountB;
          }),
        ],
      );
      addTearDown(container.dispose);
      final context = container.read(requestContextProvider.notifier);
      context.state = _account('A');
      final pending = container
          .read(requestControllerProvider.notifier)
          .submit('private A');
      context.state = _account('B');
      expect(container.read(requestControllerProvider), isEmpty);
      accountA.release.complete();
      await pending;
      expect(accountA.current, hasLength(1));
      expect(accountB.current, isEmpty);
      expect(container.read(requestControllerProvider), isEmpty);
    },
  );

  for (final transition in ['account', 'company', 'invalidation']) {
    test('late feature responses are ignored on $transition change', () async {
      final dashboardA = _Dashboard('A');
      final profileA = _Profile('A');
      final calendarA = _Calendar('A');
      final attendanceA = _Attendance('A');
      final dashboardB = _Dashboard('B');
      final profileB = _Profile('B');
      final calendarB = _Calendar('B');
      final attendanceB = _Attendance('B');
      var firstScope = true;
      final container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWith((ref) {
            ref.watch(featureSessionProvider);
            return firstScope ? dashboardA : dashboardB;
          }),
          profileRepositoryProvider.overrideWith((ref) {
            ref.watch(featureSessionProvider);
            return firstScope ? profileA : profileB;
          }),
          calendarRepositoryProvider.overrideWith((ref) {
            ref.watch(featureSessionProvider);
            return firstScope ? calendarA : calendarB;
          }),
          attendanceRepositoryProvider.overrideWith((ref) {
            ref.watch(featureSessionProvider);
            return firstScope ? attendanceA : attendanceB;
          }),
        ],
      );
      addTearDown(container.dispose);
      currentAttendance() =>
          attendanceControllerProvider(container.read(featureSessionProvider));
      final context = container.read(requestContextProvider.notifier);
      context.state = const RequestContext(
        userId: 'A',
        employeeId: 'A',
        activeCompanyId: 'one',
        companyScope: ['one', 'two'],
      );
      container.read(dashboardControllerProvider);
      container.read(profileControllerProvider);
      final oldMonth = container
          .read(calendarControllerProvider.notifier)
          .loadMonth(2026, 1);
      final subscriptionA = container.listen(currentAttendance(), (_, _) {});
      addTearDown(subscriptionA.close);
      await container.read(currentAttendance().future);
      final oldToggle = container
          .read(currentAttendance().notifier)
          .toggleAttendance();
      await Future<void>.delayed(Duration.zero);
      final oldScope = container.read(featureSessionProvider);

      firstScope = false;
      switch (transition) {
        case 'account':
          context.state = null;
          context.state = _account('B');
        case 'company':
          context.state = context.state!.selectCompany('two');
        case 'invalidation':
          container.read(sessionLifecycleProvider).advance();
          context.state = null;
      }
      expect(oldScope.isCurrent, isFalse);
      expect(container.read(dashboardControllerProvider).employee.name, 'B');
      expect(container.read(profileControllerProvider).name, 'B');
      expect(
        container.read(calendarControllerProvider).eventsByDay[1]!.first.label,
        'B',
      );
      // No AsyncData from A is exposed while B's attendance loads.
      final subscriptionB = container.listen(currentAttendance(), (_, _) {});
      addTearDown(subscriptionB.close);
      expect(container.read(currentAttendance()).valueOrNull, isNull);
      expect((await container.read(currentAttendance().future)).userId, 'B');
      dashboardB.pending.complete(dashboardB.current);
      profileB.pending.complete(profileB.currentEmployee);
      dashboardA.pending.complete(dashboardA.current);
      profileA.pending.complete(profileA.currentEmployee);
      calendarA.pending.complete(calendarA.current);
      attendanceA.pending.complete(Success(attendanceA.current));
      await Future.wait([oldMonth, oldToggle]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(dashboardControllerProvider).employee.name, 'B');
      expect(container.read(profileControllerProvider).name, 'B');
      expect(
        container.read(calendarControllerProvider).eventsByDay[1]!.first.label,
        'B',
      );
      expect(container.read(currentAttendance()).requireValue.userId, 'B');
    });
  }

  test(
    'company switch and same-account relogin discard mutable request cache',
    () async {
      final container = ProviderContainer(
        overrides: [
          requestLocalDataSourceProvider.overrideWith((ref) {
            ref.watch(featureSessionProvider);
            return DemoRequestLocalDataSource();
          }),
        ],
      );
      addTearDown(container.dispose);
      final context = container.read(requestContextProvider.notifier);
      context.state = const RequestContext(
        userId: 'A',
        employeeId: 'A',
        activeCompanyId: 'one',
        companyScope: ['one', 'two'],
      );
      await container
          .read(requestControllerProvider.notifier)
          .submit('company one');
      context.state = context.state!.selectCompany('two');
      expect(
        container.read(requestControllerProvider).map((e) => e.type),
        isNot(contains('company one')),
      );
      await container
          .read(requestControllerProvider.notifier)
          .submit('old login');
      container.read(sessionLifecycleProvider).advance();
      expect(
        container.read(requestControllerProvider).map((e) => e.type),
        isNot(contains('old login')),
      );
    },
  );

  test(
    'clearing waits for an in-flight write and drops queued stale writes',
    () async {
      final lifecycle = SessionLifecycle();
      addTearDown(lifecycle.dispose);
      final started = Completer<void>();
      final release = Completer<void>();
      String? stored;
      final old = lifecycle.protect(0, () async {
        started.complete();
        await release.future;
        stored = 'A';
      });
      await started.future;
      final stale = lifecycle.protect(0, () async {
        stored = 'late A';
      });
      final revision = lifecycle.advance();
      final clear = lifecycle.protect(revision, () async {
        stored = null;
      });
      release.complete();
      await Future.wait([old, stale, clear]);
      expect(stored, isNull);
      await lifecycle.protect(revision, () async {
        stored = 'B';
      });
      await lifecycle.protect(0, () async {
        stored = 'A';
      });
      expect(stored, 'B');
    },
  );
}

RequestContext _account(String id) => RequestContext(
  userId: id,
  employeeId: 'employee-$id',
  activeCompanyId: 'company-$id',
  companyScope: ['company-$id'],
);

class _Requests extends RequestRepository {
  final release = Completer<void>();
  @override
  final List<EmployeeRequest> current = [];
  @override
  Future<List<EmployeeRequest>> refresh() async => current;
  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) async {
    await release.future;
    final item = EmployeeRequest(
      id: 'A',
      type: command.type,
      dateRange: '',
      submittedOn: '',
      status: RequestStatus.pending,
    );
    current.add(item);
    return item;
  }
}

class _Dashboard implements DashboardRepository {
  _Dashboard(this.name);
  final String name;
  final pending = Completer<DashboardSnapshot>();
  @override
  DashboardSnapshot get current => DashboardSnapshot(
    employee: DashboardEmployee(
      name: name,
      initials: name,
      avatarColorIndex: 0,
    ),
    leaveBalances: const [],
    announcements: const [],
  );
  @override
  Future<DashboardSnapshot> refresh() => pending.future;
}

class _Profile implements ProfileRepository {
  _Profile(this.name);
  final String name;
  final pending = Completer<Employee>();
  @override
  Employee get currentEmployee => Employee(
    id: name,
    name: name,
    role: '',
    department: '',
    email: '',
    phone: '',
    location: '',
    joinDate: '',
    salary: 0,
    initials: name,
    avatarColorIndex: 0,
  );
  @override
  Future<Employee> refresh() => pending.future;
}

class _Calendar implements CalendarRepository {
  _Calendar(this.name);
  final String name;
  final pending = Completer<CalendarData>();
  @override
  CalendarData get current => CalendarData(
    focusedDate: DateTime(2026),
    eventsByDay: {
      1: [CalendarEvent(name, CalendarEventTone.primary)],
    },
  );
  @override
  Future<CalendarData> loadMonth(int year, int month) => pending.future;
}

class _Attendance extends AttendanceRepository {
  _Attendance(this.name);
  final String name;
  final pending = Completer<Result<AttendanceEntity>>();
  AttendanceEntity get current => AttendanceEntity(
    id: name,
    userId: name,
    checkedInAt: DateTime(2026),
    status: AttendanceStatus.onTime,
    latitude: 0,
    longitude: 0,
  );
  @override
  Future<Result<AttendanceEntity>> getToday() async => Success(current);
  @override
  Future<Result<AttendanceContext>> getContext() async => Success(
    AttendanceContext(
      employeeId: name,
      companyId: name,
      allowedMethods: const {AttendanceCaptureMethod.mobileGps},
      requiresLocation: true,
      requiresSelfie: false,
      isWorkingDay: true,
      allowHolidayAttendance: false,
      allowWeekendAttendance: false,
      warnings: const [],
    ),
  );
  @override
  Future<Result<AttendanceEntity>> clockIn(AttendanceCommand command) =>
      pending.future;
  @override
  Future<Result<AttendanceEntity>> clockOut(AttendanceCommand command) =>
      pending.future;
}
