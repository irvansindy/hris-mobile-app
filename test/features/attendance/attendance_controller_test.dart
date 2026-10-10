import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/services/location_gateway.dart';
import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/features/attendance/attendance_dependencies.dart';
import 'package:hrm_app/features/attendance/attendance_providers.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_today.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';

void main() {
  test('parallel attendance submission is accepted only once', () async {
    final repository = _DelayedRepository();
    final container = ProviderContainer(
      overrides: [
        requestContextProvider.overrideWith(
          (ref) => const RequestContext(
            userId: 'user-1',
            employeeId: 'employee-1',
            activeCompanyId: 'company-1',
            companyScope: ['company-1'],
          ),
        ),
        attendanceRepositoryProvider.overrideWithValue(repository),
        locationServiceProvider.overrideWithValue(const _Location()),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(featureSessionProvider);
    final provider = attendanceControllerProvider(session);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);

    final first = container.read(provider.notifier).toggleAttendance();
    final duplicate = container.read(provider.notifier).toggleAttendance();

    expect(await duplicate, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(repository.clockInCalls, 1);
    repository.pending.complete(Success(repository.activeRecord));
    expect(await first, isTrue);
    expect(repository.clockInCalls, 1);
    expect(repository.todayCalls, 3);
    final confirmed = container.read(provider).requireValue;
    expect(confirmed.serverTime, DateTime.utc(2026, 10, 6, 3));
    expect(confirmed.canCheckIn, isFalse);
    expect(confirmed.canCheckOut, isTrue);
  });
}

class _Location implements LocationGateway {
  const _Location();

  @override
  Future<GeoCoordinate> currentPosition() async => GeoCoordinate(
    -6.2,
    106.8,
    accuracyMeters: 8,
    capturedAt: DateTime.utc(2026, 10, 6, 1),
  );

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _DelayedRepository extends AttendanceRepository {
  final pending = Completer<Result<AttendanceEntity>>();
  int clockInCalls = 0;
  int todayCalls = 0;
  AttendanceEntity? _currentRecord;

  AttendanceEntity get emptyRecord => const AttendanceEntity(
    id: '',
    userId: 'employee-1',
    checkedInAt: null,
    status: AttendanceStatus.notStarted,
    latitude: 0,
    longitude: 0,
  );

  AttendanceEntity get activeRecord => AttendanceEntity(
    id: 'attendance-1',
    userId: 'employee-1',
    checkedInAt: DateTime.utc(2026, 10, 6, 1),
    status: AttendanceStatus.onTime,
    latitude: -6.2,
    longitude: 106.8,
  );

  @override
  Future<Result<AttendanceEntity>> getToday() async => Success(emptyRecord);

  @override
  Future<Result<AttendanceToday>> getTodayState() async {
    todayCalls++;
    final record = _currentRecord ?? emptyRecord;
    final context = (await getContext() as Success<AttendanceContext>).value;
    return Success(
      AttendanceToday(
        record: record,
        context: context,
        serverTime: DateTime.utc(2026, 10, 6, todayCalls),
        serverDate: '2026-10-06',
        timezone: 'Asia/Jakarta',
        canCheckIn: !record.isActive,
        canCheckOut: record.isActive,
      ),
    );
  }

  @override
  Future<Result<AttendanceContext>> getContext() async => const Success(
    AttendanceContext(
      employeeId: 'employee-1',
      companyId: 'company-1',
      allowedMethods: {AttendanceCaptureMethod.mobileGps},
      requiresLocation: true,
      requiresSelfie: false,
      isWorkingDay: true,
      allowHolidayAttendance: false,
      allowWeekendAttendance: false,
      warnings: [],
    ),
  );

  @override
  Future<Result<AttendanceEntity>> clockIn(AttendanceCommand command) {
    clockInCalls++;
    return pending.future.then((result) {
      if (result case Success(:final value)) _currentRecord = value;
      return result;
    });
  }

  @override
  Future<Result<AttendanceEntity>> clockOut(AttendanceCommand command) =>
      throw UnimplementedError();
}
