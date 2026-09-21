import 'package:hrm_app/features/attendance_requests/data/datasources/attendance_request_remote_datasource.dart';
import 'package:hrm_app/features/attendance_requests/domain/entities/attendance_request.dart';
import 'package:hrm_app/features/attendance_requests/domain/repositories/attendance_request_repository.dart';

class AttendanceRequestRepositoryImpl implements AttendanceRequestRepository {
  const AttendanceRequestRepositoryImpl(this._remote);

  final AttendanceRequestRemoteDataSource _remote;

  @override
  Future<List<AttendanceCorrectionRequest>> getCorrections({String? status}) =>
      _remote.getCorrections(status: status);

  @override
  Future<AttendanceCorrectionRequest> getCorrection(String id) =>
      _remote.getCorrection(id);

  @override
  Future<AttendanceCorrectionRequest> createCorrection(
    CreateAttendanceCorrection command,
  ) => _remote.createCorrection(command);

  @override
  Future<List<OvertimeRequest>> getOvertimes({String? status}) =>
      _remote.getOvertimes(status: status);

  @override
  Future<OvertimeRequest> createOvertime(CreateOvertimeRequest command) =>
      _remote.createOvertime(command);

  @override
  Future<OvertimePayEstimate> getOvertimePay(OvertimeRequest request) =>
      _remote.getOvertimePay(request);
}
