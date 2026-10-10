import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:hrm_app/features/profile/domain/entities/employee.dart';
import 'package:hrm_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:hrm_app/features/profile/domain/entities/employee_support.dart';
import 'package:hrm_app/features/profile/domain/repositories/employee_support_repository.dart';

class DemoEmployeeSupport implements EmployeeSupportRepository {
  @override
  Future<EmployeeSupportSnapshot> load() async => const EmployeeSupportSnapshot(
    reportingLine: ReportingLine(
      source: 'POSITION_REPORTS_TO',
      alternateSupervisors: [],
    ),
    attachments: [],
    canReadAttachments: true,
  );
}

class DemoDesignProfile implements ProfileRepository {
  @override
  Employee get currentEmployee => const Employee(
    id: 'DEMO001',
    name: 'Karyawan Demo',
    role: 'Marketing Staff · Demo',
    department: 'Marketing',
    email: 'demo@example.test',
    phone: 'Tidak diisi (demo)',
    location: 'Head Office Jakarta',
    joinDate: '15 Jan 2024 · contoh',
    salary: 0,
    initials: 'KD',
    avatarColorIndex: 0,
  );
  @override
  Future<Employee> refresh() async => currentEmployee;
}

class DemoDesignCalendar extends CalendarRepository {
  @override
  CalendarData get current => _month(DateTime.now().year, DateTime.now().month);
  @override
  Future<CalendarData> loadMonth(int year, int month) async =>
      _month(year, month);
  CalendarData _month(int year, int month) {
    final now = DateTime.now();
    final day = year == now.year && month == now.month ? now.day : 1;
    return CalendarData(
      focusedDate: DateTime(year, month, day),
      eventsByDay: {
        day: const [
          CalendarEvent(
            'Daily stand-up',
            CalendarEventTone.primary,
            detail: 'Contoh agenda · Divisi Marketing',
            time: '09:00',
          ),
          CalendarEvent(
            'Review campaign',
            CalendarEventTone.info,
            detail: 'Contoh agenda · Ruang meeting',
            time: '13:00',
          ),
          CalendarEvent(
            'Dina · Cuti tahunan',
            CalendarEventTone.purple,
            detail: 'Contoh cuti tim',
            time: 'Seharian',
          ),
        ],
        if (day != 17)
          17: const [
            CalendarEvent(
              'Libur · contoh desain',
              CalendarEventTone.danger,
              detail: 'Bukan kalender libur resmi',
            ),
          ],
      },
    );
  }
}
