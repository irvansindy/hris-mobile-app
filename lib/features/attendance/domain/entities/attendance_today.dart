import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';

class AttendanceToday {
  const AttendanceToday({required this.record, required this.context});

  final AttendanceEntity record;
  final AttendanceContext context;

  String get userId => record.userId;

  AttendanceToday copyWith({AttendanceEntity? record}) =>
      AttendanceToday(record: record ?? this.record, context: context);
}
