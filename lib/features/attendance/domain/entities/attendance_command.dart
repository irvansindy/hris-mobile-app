import 'package:hrm_app/core/services/selfie_gateway.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';

class AttendanceCommand {
  const AttendanceCommand({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    required this.isMocked,
    required this.method,
    required this.idempotencyKey,
    this.selfie,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final bool isMocked;
  final AttendanceCaptureMethod method;
  final String idempotencyKey;
  final CapturedSelfie? selfie;
}
