import 'package:hrm_app/features/attendance_requests/domain/entities/attendance_request.dart';

abstract interface class AttendanceRequestRepository {
  Future<List<AttendanceCorrectionRequest>> getCorrections({String? status});

  Future<AttendanceCorrectionRequest> getCorrection(String id);

  Future<AttendanceCorrectionRequest> createCorrection(
    CreateAttendanceCorrection command,
  );

  Future<List<OvertimeRequest>> getOvertimes({String? status});

  Future<OvertimeRequest> createOvertime(CreateOvertimeRequest command);

  Future<OvertimePayEstimate> getOvertimePay(OvertimeRequest request);
}
