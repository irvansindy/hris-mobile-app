import 'package:hrm_app/features/calendar/data/datasources/calendar_local_datasource.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:hrm_app/features/calendar/data/datasources/calendar_remote_datasource.dart';

class CalendarRepositoryImpl extends CalendarRepository {
  CalendarRepositoryImpl(this._local, {this.remote});
  final CalendarLocalDataSource _local;
  final DioCalendarRemoteDataSource? remote;

  @override
  CalendarData get current => _local.read();

  @override
  Future<CalendarData> loadMonth(int year, int month) async =>
      remote == null ? _local.read() : remote!.loadMonth(year, month);

  @override
  Future<NextShiftResult> loadNextShift(DateTime from) => remote == null
      ? Future.value(_emptyNextShift(from))
      : remote!.loadNextShift(from);

  @override
  Future<List<WorkHoliday>> loadHolidays(int year) =>
      remote == null ? Future.value(const []) : remote!.loadHolidays(year);

  @override
  Future<List<ShiftSwapCandidate>> loadShiftSwapCandidates(
    DateTime shiftDate,
  ) => remote == null
      ? Future.value(const [])
      : remote!.loadShiftSwapCandidates(shiftDate);

  @override
  Future<List<ShiftSwapRequest>> loadMyShiftSwaps() =>
      remote == null ? Future.value(const []) : remote!.loadMyShiftSwaps();

  @override
  Future<List<ShiftSwapRequest>> loadMyShiftSwapApprovals() => remote == null
      ? Future.value(const [])
      : remote!.loadMyShiftSwapApprovals();

  @override
  Future<ShiftSwapRequest> createShiftSwap(CreateShiftSwapCommand command) {
    final value = remote;
    if (value == null) {
      return Future.error(
        StateError('Tukar shift tidak tersedia tanpa sesi production.'),
      );
    }
    return value.createShiftSwap(command);
  }

  @override
  Future<void> cancelShiftSwap(String requestId) {
    final value = remote;
    if (value == null) {
      return Future.error(
        StateError('Tukar shift tidak tersedia tanpa sesi production.'),
      );
    }
    return value.cancelShiftSwap(requestId);
  }
}

NextShiftResult _emptyNextShift(DateTime from) => NextShiftResult(
  timezone: 'local',
  serverDate: DateTime(from.year, from.month, from.day),
  fromDate: DateTime(from.year, from.month, from.day),
  throughDate: DateTime(from.year, from.month, from.day),
  shift: null,
);
