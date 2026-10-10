import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/services/clock.dart';
import 'package:hrm_app/features/calendar/calendar_dependencies.dart';

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarData>(CalendarController.new);

final calendarMonthProvider = FutureProvider.autoDispose
    .family<CalendarData, ({int year, int month})>((ref, period) {
      ref.watch(featureSessionProvider);
      return ref
          .watch(calendarRepositoryProvider)
          .loadMonth(period.year, period.month);
    });

final calendarNextShiftProvider = FutureProvider.autoDispose<NextShiftResult>((
  ref,
) {
  ref.watch(featureSessionProvider);
  return ref
      .watch(calendarRepositoryProvider)
      .loadNextShift(ref.watch(clockProvider)());
});

final calendarHolidaysProvider = FutureProvider.autoDispose
    .family<List<WorkHoliday>, int>((ref, year) {
      ref.watch(featureSessionProvider);
      return ref.watch(calendarRepositoryProvider).loadHolidays(year);
    });

typedef ShiftSwapOverview = ({
  List<ShiftSwapRequest> requests,
  List<ShiftSwapRequest> approvals,
});

final calendarShiftSwapOverviewProvider =
    FutureProvider.autoDispose<ShiftSwapOverview>((ref) async {
      ref.watch(featureSessionProvider);
      final repository = ref.watch(calendarRepositoryProvider);
      final values = await Future.wait([
        repository.loadMyShiftSwaps(),
        repository.loadMyShiftSwapApprovals(),
      ]);
      return (requests: values[0], approvals: values[1]);
    });

final calendarShiftSwapCandidatesProvider = FutureProvider.autoDispose
    .family<List<ShiftSwapCandidate>, DateTime>((ref, shiftDate) {
      ref.watch(featureSessionProvider);
      return ref
          .watch(calendarRepositoryProvider)
          .loadShiftSwapCandidates(shiftDate);
    });
