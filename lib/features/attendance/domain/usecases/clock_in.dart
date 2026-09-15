import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/services/location_gateway.dart';
import 'package:hrm_app/core/services/selfie_gateway.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';

import 'package:uuid/uuid.dart';

class ClockIn {
  ClockIn(
    this._repository,
    this._locationService, {
    String Function()? idempotencyKey,
  }) : _idempotencyKey = idempotencyKey ?? const Uuid().v4;
  final AttendanceRepository _repository;
  final LocationGateway _locationService;
  final String Function() _idempotencyKey;

  Future<Result<AttendanceEntity>> call({CapturedSelfie? selfie}) async {
    final position = await _locationService.currentPosition();
    _validate(position);
    return _repository.clockIn(
      AttendanceCommand(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracyMeters,
        capturedAt: position.capturedAt,
        isMocked: position.isMocked,
        method: selfie == null
            ? AttendanceCaptureMethod.mobileGps
            : AttendanceCaptureMethod.faceRecognition,
        idempotencyKey: _idempotencyKey(),
        selfie: selfie,
      ),
    );
  }

  void _validate(GeoCoordinate position) {
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
  }
}
