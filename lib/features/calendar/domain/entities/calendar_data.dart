enum CalendarEventTone { danger, primary, purple, success, warning, info }

class CalendarEvent {
  const CalendarEvent(this.label, this.tone, {this.detail, this.time});
  final String label;
  final CalendarEventTone tone;
  final String? detail;
  final String? time;
}

class CalendarData {
  const CalendarData({
    required this.focusedDate,
    required this.eventsByDay,
    this.available = true,
  });

  final DateTime focusedDate;
  final Map<int, List<CalendarEvent>> eventsByDay;
  final bool available;
}

class CalendarShift {
  const CalendarShift({
    required this.date,
    required this.label,
    required this.dayType,
    required this.workStart,
    required this.workEnd,
    required this.crossesMidnight,
  });

  final DateTime date;
  final String label;
  final String dayType;
  final String? workStart;
  final String? workEnd;
  final bool crossesMidnight;
}

class NextShiftResult {
  const NextShiftResult({
    required this.timezone,
    required this.serverDate,
    required this.fromDate,
    required this.throughDate,
    required this.shift,
  });

  final String timezone;
  final DateTime serverDate;
  final DateTime fromDate;
  final DateTime throughDate;
  final CalendarShift? shift;
}

class WorkHoliday {
  const WorkHoliday({
    required this.id,
    required this.date,
    required this.name,
    required this.type,
  });

  final String id;
  final DateTime date;
  final String name;
  final String type;
}

class ShiftSwapCandidate {
  const ShiftSwapCandidate({
    required this.employeeId,
    required this.employeeNumber,
    required this.fullName,
  });

  final String employeeId;
  final String employeeNumber;
  final String fullName;
}

enum ShiftSwapStatus { pending, approved, rejected, cancelled }

class ShiftSwapRequest {
  const ShiftSwapRequest({
    required this.id,
    required this.companyId,
    required this.requesterEmployeeId,
    required this.targetEmployeeId,
    required this.approverEmployeeId,
    required this.shiftDate,
    required this.reason,
    required this.status,
    required this.counterpartName,
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final String requesterEmployeeId;
  final String targetEmployeeId;
  final String approverEmployeeId;
  final DateTime shiftDate;
  final String reason;
  final ShiftSwapStatus status;
  final String counterpartName;
  final DateTime createdAt;
}

class CreateShiftSwapCommand {
  const CreateShiftSwapCommand({
    required this.targetEmployeeId,
    required this.shiftDate,
    required this.reason,
  });

  final String targetEmployeeId;
  final DateTime shiftDate;
  final String reason;
}
