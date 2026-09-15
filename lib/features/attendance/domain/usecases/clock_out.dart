import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/services/location_gateway.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';

import 'package:uuid/uuid.dart';

class ClockOut {
  ClockOut(
    this._repository,
    this._locationService, {
    String Function()? idempotencyKey,
  }) : _idempotencyKey = idempotencyKey ?? const Uuid().v4;
  final AttendanceRepository _repository;
  final LocationGateway _locationService;
  final String Function() _idempotencyKey;

  Future<Result<AttendanceEntity>> call() async {
    final position = await _locationService.currentPosition();
    if (position.isMocked) {
      throw const LocationException(
        LocationIssueKind.mocked,
        'Lokasi tiruan terdeteksi. Matikan aplikasi fake GPS lalu coba lagi.',
      );
    }
    if (position.accuracyMeters > 100) {
      throw LocationException(
        LocationIssueKind.inaccurate,
        'Akurasi lokasi ${position.accuracyMeters.round()} meter belum memenuhi batas 100 meter. Pindah ke area terbuka lalu coba lagi.',
      );
    }
    return _repository.clockOut(
      AttendanceCommand(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracyMeters,
        capturedAt: position.capturedAt,
        isMocked: position.isMocked,
        method: AttendanceCaptureMethod.mobileGps,
        idempotencyKey: _idempotencyKey(),
      ),
    );
  }
}
