import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';

class AttendanceHistoryPage {
  const AttendanceHistoryPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<AttendanceEntity> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasNextPage => page < totalPages;
}
