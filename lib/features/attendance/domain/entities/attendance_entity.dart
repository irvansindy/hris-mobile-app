class AttendanceEntity {
  const AttendanceEntity({
    required this.id,
    required this.userId,
    required this.checkedInAt,
    this.checkedOutAt,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.workDate,
    this.branchName,
    this.officeTimezone,
    this.isWithinRadius,
    this.requiresReview = false,
  });

  final String id;
  final String userId;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final AttendanceStatus status;
  final double latitude;
  final double longitude;
  final DateTime? workDate;
  final String? branchName;
  final String? officeTimezone;
  final bool? isWithinRadius;
  final bool requiresReview;

  bool get isActive => id.isNotEmpty && checkedOutAt == null;
}

enum AttendanceStatus { notStarted, onTime, late, completed, absent, excused }
