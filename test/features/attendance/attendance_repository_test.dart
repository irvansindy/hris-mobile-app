import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:hrm_app/features/attendance/data/dto/attendance_dto.dart';
import 'package:hrm_app/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';

void main() {
  test('clock out returns only the record confirmed by the server', () async {
    final now = DateTime.utc(2026, 8, 30, 17);
    final repository = AttendanceRepositoryImpl(_Remote(now));

    final result = await repository.clockOut(
      AttendanceCommand(
        latitude: -6.2,
        longitude: 106.8,
        accuracyMeters: 8,
        capturedAt: now,
        isMocked: false,
        method: AttendanceCaptureMethod.mobileGps,
        idempotencyKey: 'request-1',
      ),
    );

    expect(result, isA<Success>());
    final attendance = (result as Success).value;
    expect(attendance.isActive, isFalse);
    expect(attendance.checkedOutAt, now);
  });
}

class _Remote extends AttendanceRemoteDataSource {
  _Remote(this.now);

  final DateTime now;

  @override
  Future<AttendanceDto> getToday() async => AttendanceDto(
    id: 'attendance-1',
    employeeId: 'employee-1',
    checkedInAt: now.subtract(const Duration(hours: 8)),
    status: 'PRESENT',
    latitude: -6.2,
    longitude: 106.8,
  );

  @override
  Future<AttendanceContext> getContext() async => const AttendanceContext(
    employeeId: 'employee-1',
    companyId: 'company-1',
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
  Future<AttendanceDto> clockOut(AttendanceCommand command) async =>
      AttendanceDto(
        id: 'attendance-1',
        employeeId: 'employee-1',
        checkedInAt: now.subtract(const Duration(hours: 8)),
        checkedOutAt: now,
        status: 'PRESENT',
        latitude: command.latitude,
        longitude: command.longitude,
      );
}
