import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/services/location_gateway.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_history.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:hrm_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/domain/entities/request_command.dart';
import 'package:hrm_app/features/self_service/domain/repositories/request_repository.dart';

class DemoAuth implements AuthRepository {
  DemoAuth(this.store);
  final DemoStore store;
  static const session = AuthSession(
    accessToken: 'local-demo-only',
    userId: 'demo-user',
    employeeId: 'DEMO001',
    companyId: 'demo-company',
    companyScope: ['demo-company'],
    userName: 'Karyawan Demo',
    email: 'demo@example.test',
    roles: ['EMPLOYEE'],
    permissions: [
      'leave:create',
      'attendance:create',
      'employee:read',
      'employee-loan:create',
      'ewa:create',
      'ewa:update',
      'daily-activity:create',
      'travel-expense:create',
    ],
  );
  @override
  Future<bool> hasSession() async =>
      store.preferences.getBool('hris.demo.loggedOut') != true;
  @override
  Future<Result<AuthSession?>> restoreSession() async =>
      Success(await hasSession() ? session : null);
  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) async {
    if (email != 'demo@example.test' || password != 'Demo123!') {
      return const FailureResult(
        AuthenticationFailure(
          'Mode demo: gunakan demo@example.test / Demo123!',
        ),
      );
    }
    await store.preferences.setBool('hris.demo.loggedOut', false);
    return const Success(session);
  }

  @override
  Future<void> logout() async {
    await store.preferences.setBool('hris.demo.loggedOut', true);
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => const FailureResult(
    ValidationFailure('Perubahan kata sandi tidak disimulasikan.'),
  );
}

class DemoAttendance extends AttendanceRepository {
  DemoAttendance(this.store);
  final DemoStore store;
  AttendanceEntity map(DemoRecord? row) => AttendanceEntity(
    id: row?['id'] as String? ?? '',
    userId: 'DEMO001',
    checkedInAt: row == null ? null : DateTime.parse(row['in'] as String),
    checkedOutAt: row?['out'] == null
        ? null
        : DateTime.parse(row!['out'] as String),
    status: row == null
        ? AttendanceStatus.notStarted
        : row['status'] == 'Telat'
        ? AttendanceStatus.late
        : AttendanceStatus.onTime,
    latitude: 0,
    longitude: 0,
    workDate: row == null ? null : DateTime.parse(row['date'] as String),
    branchName: 'Demo lokal',
  );
  @override
  Future<Result<AttendanceEntity>> getToday() async =>
      Success(map(store.today));
  @override
  Future<Result<AttendanceContext>> getContext() async => const Success(
    AttendanceContext(
      employeeId: 'DEMO001',
      companyId: 'demo-company',
      allowedMethods: {AttendanceCaptureMethod.mobileGps},
      requiresLocation: false,
      requiresSelfie: false,
      isWorkingDay: true,
      allowHolidayAttendance: true,
      allowWeekendAttendance: true,
      warnings: ['Simulasi lokal; GPS dan wajah tidak diverifikasi.'],
      branchName: 'Demo lokal',
      workStart: '08:00',
      workEnd: '17:00',
    ),
  );
  @override
  Future<Result<AttendanceHistoryPage>> getHistory({
    required String month,
    int page = 1,
    int limit = 20,
  }) async {
    final items = store.attendance
        .where((r) => (r['date'] as String).startsWith(month))
        .map(map)
        .toList();
    return Success(
      AttendanceHistoryPage(
        items: items.skip((page - 1) * limit).take(limit).toList(),
        page: page,
        totalPages: items.isEmpty ? 1 : (items.length / limit).ceil(),
        total: items.length,
      ),
    );
  }

  Future<Result<AttendanceEntity>> _save(Future<void> Function() action) async {
    try {
      await action();
      return Success(map(store.today));
    } catch (error) {
      return FailureResult(
        ValidationFailure(
          error is StateError ? error.message : 'Penyimpanan demo gagal.',
        ),
      );
    }
  }

  @override
  Future<Result<AttendanceEntity>> clockIn(AttendanceCommand command) =>
      _save(() => store.checkIn());
  @override
  Future<Result<AttendanceEntity>> clockOut(AttendanceCommand command) =>
      _save(store.checkOut);
}

class DemoLocation implements LocationGateway {
  @override
  Future<GeoCoordinate> currentPosition() async =>
      GeoCoordinate(0, 0, accuracyMeters: 0, capturedAt: DateTime.now());
  @override
  Future<bool> openAppSettings() async => false;
  @override
  Future<bool> openLocationSettings() async => false;
}

class DemoRequests extends RequestRepository {
  DemoRequests(this.store);
  final DemoStore store;
  EmployeeRequest map(DemoRecord row) => EmployeeRequest(
    id: row['id'] as String,
    type: row['kind'] == 'Cuti' ? 'Cuti tahunan demo' : 'Izin',
    kind: row['kind'] == 'Cuti' ? RequestKind.leave : RequestKind.permission,
    dateRange: '${row['start']} – ${row['end']}',
    submittedOn: 'Demo lokal',
    status: switch (row['status']) {
      'Disetujui' => RequestStatus.approved,
      'Dibatalkan' => RequestStatus.cancelled,
      _ => RequestStatus.pending,
    },
    startDate: DateTime.parse(row['start'] as String),
    endDate: DateTime.parse(row['end'] as String),
    reason: row['reason'] as String,
    totalDays: row['days'] as int,
  );
  @override
  List<EmployeeRequest> get current => store.requests.map(map).toList();
  @override
  Future<List<EmployeeRequest>> refresh() async => current;
  @override
  Future<List<LeaveTypeOption>> getLeaveTypes() async => const [
    LeaveTypeOption(id: 'demo-annual', name: 'Cuti tahunan demo'),
  ];
  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) async {
    await store.submit(
      command.kind == RequestKind.leave ? 'Cuti' : 'Izin',
      command.startDate!,
      command.endDate!,
      command.reason ?? '',
    );
    return current.first;
  }

  @override
  Future<EmployeeRequest> cancel(RequestKind kind, String id) async {
    await store.decide(id, approve: false);
    return current.firstWhere((r) => r.id == id);
  }
}

class DemoDashboard implements DashboardRepository {
  DemoDashboard(this.store);
  final DemoStore store;
  @override
  DashboardSnapshot get current => DashboardSnapshot(
    employee: const DashboardEmployee(
      name: 'Karyawan Demo',
      initials: 'KD',
      avatarColorIndex: 0,
      role: 'Marketing Staff · Demo',
    ),
    leaveBalances: [
      LeaveBalance(
        type: 'Cuti tahunan',
        total: 12,
        used: 12 - store.balance,
        colorIndex: 0,
        shortLabel: 'Tahunan',
      ),
      const LeaveBalance(
        type: 'Cuti sakit',
        total: 3,
        used: 0,
        colorIndex: 1,
        shortLabel: 'Sakit',
        note: 'contoh desain',
      ),
      const LeaveBalance(
        type: 'Izin',
        total: 1,
        used: 0,
        colorIndex: 2,
        shortLabel: 'Izin',
        note: 'contoh desain',
      ),
    ],
    announcements: const [
      Announcement(
        title: 'Pengumuman',
        body:
            'Simulasi pengumuman perusahaan. Pengajuan cuti H-3 ditutup Jumat pukul 17.00.',
        time: 'Contoh lokal',
        category: 'Demo',
      ),
    ],
    leaveBalancesAvailable: true,
    attendanceAvailable: true,
    announcementsAvailable: true,
    attendance: DashboardAttendance(
      isClockedIn: store.today != null && store.today!['out'] == null,
      clockInTime: store.today == null
          ? null
          : DateTime.parse(store.today!['in'] as String),
    ),
  );
  @override
  Future<DashboardSnapshot> refresh() async => current;
}
