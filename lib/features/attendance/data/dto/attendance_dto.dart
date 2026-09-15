import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';

class AttendanceDto {
  const AttendanceDto({
    required this.id,
    required this.employeeId,
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

  factory AttendanceDto.fromJson(Map<String, dynamic> json) => AttendanceDto(
    id: json['id'] as String? ?? '',
    employeeId: (json['employeeId'] ?? json['employee_id']) as String? ?? '',
    checkedInAt: _date(
      json['checkIn'] ?? json['checkedInAt'] ?? json['checked_in_at'],
    ),
    checkedOutAt:
        (json['checkOut'] ?? json['checkedOutAt'] ?? json['checked_out_at']) ==
            null
        ? null
        : DateTime.parse(
            (json['checkOut'] ?? json['checkedOutAt'] ?? json['checked_out_at'])
                as String,
          ),
    status: json['status'] as String? ?? 'PRESENT',
    latitude: _number(json['checkInLatitude'] ?? json['latitude']),
    longitude: _number(json['checkInLongitude'] ?? json['longitude']),
    workDate: _date(json['date'] ?? json['attendanceDate']),
    branchName:
        _text(json['branchName']) ?? _text(_map(json['branch'])['name']),
    officeTimezone: _text(json['timezone'] ?? json['officeTimezone']),
    isWithinRadius: _boolean(json['isWithinRadius'] ?? json['withinRadius']),
    requiresReview: _boolean(json['requiresReview']) ?? false,
  );

  final String id;
  final String employeeId;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final String status;
  final double latitude;
  final double longitude;
  final DateTime? workDate;
  final String? branchName;
  final String? officeTimezone;
  final bool? isWithinRadius;
  final bool requiresReview;

  AttendanceEntity toEntity() => AttendanceEntity(
    id: id,
    userId: employeeId,
    checkedInAt: checkedInAt,
    checkedOutAt: checkedOutAt,
    status: _parseStatus(status),
    latitude: latitude,
    longitude: longitude,
    workDate: workDate,
    branchName: branchName,
    officeTimezone: officeTimezone,
    isWithinRadius: isWithinRadius,
    requiresReview: requiresReview,
  );
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

double _number(Object? value) => value is num ? value.toDouble() : 0;

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

bool? _boolean(Object? value) => value is bool ? value : null;

AttendanceStatus _parseStatus(String value) {
  final normalized = value.replaceAll('_', '').toLowerCase();
  if (normalized == 'present' || normalized == 'ontime') {
    return AttendanceStatus.onTime;
  }
  if (normalized == 'completed') return AttendanceStatus.completed;
  if (normalized == 'late') return AttendanceStatus.late;
  if (normalized == 'absent') return AttendanceStatus.absent;
  if (normalized == 'excused') return AttendanceStatus.excused;
  for (final status in AttendanceStatus.values) {
    if (status.name.toLowerCase() == normalized) return status;
  }
  throw FormatException('Unknown attendance status: $value');
}
