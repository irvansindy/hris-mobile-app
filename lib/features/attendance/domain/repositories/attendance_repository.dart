import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_history.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_today.dart';

abstract class AttendanceRepository {
  Future<Result<AttendanceEntity>> getToday();
  Future<Result<AttendanceContext>> getContext();
  Future<Result<AttendanceToday>> getTodayState() async {
    final record = await getToday();
    if (record case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final context = await getContext();
    if (context case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    return Success(
      AttendanceToday(
        record: (record as Success<AttendanceEntity>).value,
        context: (context as Success<AttendanceContext>).value,
      ),
    );
  }

  Future<Result<AttendanceHistoryPage>> getHistory({
    required String month,
    int page = 1,
    int limit = 20,
  }) async =>
      const FailureResult(ServerFailure('Riwayat absensi belum tersedia.'));
  Future<Result<AttendanceEntity>> clockIn(AttendanceCommand command);
  Future<Result<AttendanceEntity>> clockOut(AttendanceCommand command);
}
