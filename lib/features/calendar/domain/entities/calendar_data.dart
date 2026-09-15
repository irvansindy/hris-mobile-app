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
