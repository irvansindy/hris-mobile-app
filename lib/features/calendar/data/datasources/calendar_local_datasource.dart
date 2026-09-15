import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';

abstract interface class CalendarLocalDataSource {
  CalendarData read();
}

class UnavailableCalendarLocalDataSource implements CalendarLocalDataSource {
  @override
  CalendarData read() => CalendarData(
    focusedDate: DateTime.now(),
    eventsByDay: const {},
    available: false,
  );
}

class DemoCalendarLocalDataSource implements CalendarLocalDataSource {
  @override
  CalendarData read() => CalendarData(
    focusedDate: DateTime(2025, 6, 20),
    eventsByDay: const {
      5: [
        CalendarEvent('Public Holiday: Eid Al-Adha', CalendarEventTone.danger),
      ],
      10: [CalendarEvent('Dewi: Annual Leave', CalendarEventTone.primary)],
      11: [CalendarEvent('Dewi: Annual Leave', CalendarEventTone.primary)],
      15: [
        CalendarEvent('Team Offsite (Engineering)', CalendarEventTone.purple),
      ],
      20: [
        CalendarEvent('All-Hands Meeting 10:00', CalendarEventTone.success),
        CalendarEvent('Putri: Annual Leave', CalendarEventTone.primary),
      ],
      21: [CalendarEvent('Putri: Annual Leave', CalendarEventTone.primary)],
      22: [CalendarEvent('Putri: Annual Leave', CalendarEventTone.primary)],
      25: [CalendarEvent('Payroll Disbursement', CalendarEventTone.success)],
      27: [CalendarEvent('Q2 Performance Review', CalendarEventTone.warning)],
      30: [CalendarEvent('Month-End HR Reports Due', CalendarEventTone.info)],
    },
  );
}
