class AttendanceCorrectionSeed {
  const AttendanceCorrectionSeed({
    required this.attendanceId,
    required this.date,
    this.checkedInAt,
    this.checkedOutAt,
  });

  final String attendanceId;
  final DateTime date;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
}
