import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
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
