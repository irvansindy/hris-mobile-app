import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';

class AttendanceToday {
  const AttendanceToday({
    required this.record,
    required this.context,
    required this.serverTime,
    required this.serverDate,
    required this.timezone,
    required this.canCheckIn,
    required this.canCheckOut,
  });

  factory AttendanceToday.derived({
    required AttendanceEntity record,
    required AttendanceContext context,
  }) {
    final now = DateTime.now();
    return AttendanceToday(
      record: record,
      context: context,
      serverTime: now.toUtc(),
      serverDate:
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}',
      timezone: now.timeZoneName,
      canCheckIn: !record.isActive && record.checkedOutAt == null,
      canCheckOut: record.isActive,
    );
  }

  final AttendanceEntity record;
  final AttendanceContext context;
  final DateTime serverTime;
  final String serverDate;
  final String timezone;
  final bool canCheckIn;
  final bool canCheckOut;

  String get userId => record.userId;

  AttendanceToday copyWith({
    AttendanceEntity? record,
    bool? canCheckIn,
    bool? canCheckOut,
  }) => AttendanceToday(
    record: record ?? this.record,
    context: context,
    serverTime: serverTime,
    serverDate: serverDate,
    timezone: timezone,
    canCheckIn: canCheckIn ?? this.canCheckIn,
    canCheckOut: canCheckOut ?? this.canCheckOut,
  );
}
