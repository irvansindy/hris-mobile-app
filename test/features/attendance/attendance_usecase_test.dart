import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/services/location_gateway.dart';
import 'package:hrm_app/core/services/selfie_gateway.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/attendance/domain/usecases/clock_in.dart';
import 'package:hrm_app/features/attendance/domain/usecases/clock_out.dart';

void main() {
  final capturedAt = DateTime.utc(2026, 9, 11, 1, 15);

  test(
    'clock in forwards measured GPS, selfie, and stable request key',
    () async {
      final repository = _Repository();
      final location = _Location(
        GeoCoordinate(
          -6.2088,
          106.8456,
          accuracyMeters: 8,
          capturedAt: capturedAt,
          altitudeMeters: 14,
          headingDegrees: 45,
        ),
      );
      final selfie = CapturedSelfie(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/jpeg',
        capturedAt: capturedAt,
      );

      final result = await ClockIn(
        repository,
        location,
        idempotencyKey: () => 'request-1',
      )(selfie: selfie);

      expect(result, isA<Success<AttendanceEntity>>());
      expect(repository.clockInCalls, 1);
      expect(repository.command?.latitude, -6.2088);
      expect(repository.command?.accuracyMeters, 8);
      expect(repository.command?.capturedAt, capturedAt);
      expect(
        repository.command?.method,
        AttendanceCaptureMethod.faceRecognition,
      );
      expect(repository.command?.idempotencyKey, 'request-1');
      expect(repository.command?.selfie, same(selfie));
    },
  );

  test('mock location is rejected before any attendance request', () async {
    final repository = _Repository();
    final location = _Location(
      GeoCoordinate(
        -6.2,
        106.8,
        accuracyMeters: 5,
        capturedAt: capturedAt,
        isMocked: true,
      ),
    );

    await expectLater(
      ClockIn(repository, location)(),
      throwsA(
        isA<LocationException>().having(
          (error) => error.kind,
          'kind',
          LocationIssueKind.mocked,
        ),
      ),
    );
    expect(repository.clockInCalls, 0);
  });

  test('GPS accuracy above 100 meters is rejected before checkout', () async {
    final repository = _Repository();
    final location = _Location(
      GeoCoordinate(-6.2, 106.8, accuracyMeters: 101, capturedAt: capturedAt),
    );

    await expectLater(
      ClockOut(repository, location)(),
      throwsA(
        isA<LocationException>().having(
          (error) => error.kind,
          'kind',
          LocationIssueKind.inaccurate,
        ),
      ),
    );
    expect(repository.clockOutCalls, 0);
  });
}

class _Location implements LocationGateway {
  const _Location(this.coordinate);

  final GeoCoordinate coordinate;

  @override
  Future<GeoCoordinate> currentPosition() async => coordinate;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _Repository extends AttendanceRepository {
  AttendanceCommand? command;
  int clockInCalls = 0;
  int clockOutCalls = 0;

  @override
  Future<Result<AttendanceEntity>> clockIn(AttendanceCommand value) async {
    clockInCalls++;
    command = value;
    return Success(
      AttendanceEntity(
        id: 'attendance-1',
        userId: 'employee-1',
        checkedInAt: value.capturedAt,
        status: AttendanceStatus.onTime,
        latitude: value.latitude,
        longitude: value.longitude,
      ),
    );
  }

  @override
  Future<Result<AttendanceEntity>> clockOut(AttendanceCommand value) async {
    clockOutCalls++;
    command = value;
    return Success(
      AttendanceEntity(
        id: 'attendance-1',
        userId: 'employee-1',
        checkedInAt: value.capturedAt.subtract(const Duration(hours: 8)),
        checkedOutAt: value.capturedAt,
        status: AttendanceStatus.completed,
        latitude: value.latitude,
        longitude: value.longitude,
      ),
    );
  }

  @override
  Future<Result<AttendanceContext>> getContext() => throw UnimplementedError();

  @override
  Future<Result<AttendanceEntity>> getToday() => throw UnimplementedError();
}
