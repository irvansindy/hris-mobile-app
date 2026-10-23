import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';

abstract class CalendarRepository {
  const CalendarRepository();

  CalendarData get current;
  Future<CalendarData> loadMonth(int year, int month);
  Future<NextShiftResult> loadNextShift(DateTime from) async => NextShiftResult(
    timezone: 'local',
    serverDate: DateTime(from.year, from.month, from.day),
    fromDate: DateTime(from.year, from.month, from.day),
    throughDate: DateTime(from.year, from.month, from.day),
    shift: null,
  );
  Future<List<WorkHoliday>> loadHolidays(int year) async => const [];
  Future<List<ShiftSwapCandidate>> loadShiftSwapCandidates(
    DateTime shiftDate,
  ) async => const [];
  Future<List<ShiftSwapRequest>> loadMyShiftSwaps() async => const [];
  Future<List<ShiftSwapRequest>> loadMyShiftSwapApprovals() async => const [];
  Future<ShiftSwapRequest> createShiftSwap(CreateShiftSwapCommand command) =>
      Future.error(UnsupportedError('Tukar shift tidak tersedia.'));
  Future<void> cancelShiftSwap(String requestId) =>
      Future.error(UnsupportedError('Tukar shift tidak tersedia.'));
}
