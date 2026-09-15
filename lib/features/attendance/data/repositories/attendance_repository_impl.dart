import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:hrm_app/features/attendance/data/dto/attendance_dto.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_history.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_today.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  const AttendanceRepositoryImpl(this._remote);
  final AttendanceRemoteDataSource _remote;

  @override
  Future<Result<AttendanceEntity>> getToday() => _guard(_remote.getToday);

  @override
  Future<Result<AttendanceContext>> getContext() async {
    try {
      return Success(await _remote.getContext());
    } on ApiException catch (error) {
      return FailureResult(mapApiException(error));
    } catch (_) {
      return const FailureResult(
        ServerFailure('Unexpected attendance context error'),
      );
    }
  }

  @override
  Future<Result<AttendanceToday>> getTodayState() =>
      _guardValue(_remote.getTodayState, 'Unexpected attendance context error');

  @override
  Future<Result<AttendanceHistoryPage>> getHistory({
    required String month,
    int page = 1,
    int limit = 20,
  }) => _guardValue(
    () => _remote.getHistory(month: month, page: page, limit: limit),
    'Unexpected attendance history error',
  );

  @override
  Future<Result<AttendanceEntity>> clockIn(AttendanceCommand command) =>
      _guard(() => _remote.clockIn(command));

  @override
  Future<Result<AttendanceEntity>> clockOut(AttendanceCommand command) =>
      _guard(() => _remote.clockOut(command));

  Future<Result<AttendanceEntity>> _guard(
    Future<AttendanceDto> Function() operation,
  ) async {
    try {
      final dto = await operation();
      return Success(dto.toEntity());
    } on ApiException catch (error) {
      return FailureResult(mapApiException(error));
    } catch (_) {
      return const FailureResult(ServerFailure('Unexpected attendance error'));
    }
  }

  Future<Result<T>> _guardValue<T>(
    Future<T> Function() operation,
    String fallbackMessage,
  ) async {
    try {
      return Success(await operation());
    } on ApiException catch (error) {
      return FailureResult(mapApiException(error));
    } catch (_) {
      return FailureResult(ServerFailure(fallbackMessage));
    }
  }
}
