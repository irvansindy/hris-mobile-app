import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';

class AttendanceContextDto {
  const AttendanceContextDto({required this.value});

  factory AttendanceContextDto.fromJson(
    Map<String, dynamic> json, {
    String? employeeId,
    String? companyId,
  }) {
    final policy = _map(json['policy'] ?? json['attendancePolicy']);
    final schedule = _map(json['schedule']);
    final branch = _map(json['branch']);
    final methods =
        ((json['allowedMethods'] ?? policy['allowedMethods']) as List? ??
                const [])
            .whereType<String>()
            .map(_method)
            .whereType<AttendanceCaptureMethod>()
            .toSet();
    final resolvedEmployeeId = json['employeeId'] as String? ?? employeeId;
    final resolvedCompanyId = json['companyId'] as String? ?? companyId;
    if (resolvedEmployeeId == null ||
        resolvedCompanyId == null ||
        methods.isEmpty) {
      throw const FormatException('Attendance context is incomplete');
    }
    return AttendanceContextDto(
      value: AttendanceContext(
        employeeId: resolvedEmployeeId,
        companyId: resolvedCompanyId,
        branchName: branch['name'] as String?,
        branchCode: branch['code'] as String?,
        allowedMethods: methods,
        requiresLocation:
            (json['requiresLocation'] ?? policy['requiresLocation']) as bool? ??
            false,
        requiresSelfie:
            (json['requiresSelfie'] ?? policy['requiresSelfie']) as bool? ??
            false,
        gpsRadiusMeters: (policy['gpsRadiusMeters'] as num?)?.toDouble(),
        isWorkingDay: schedule['isWorkingDay'] as bool? ?? false,
        allowHolidayAttendance:
            policy['allowHolidayAttendance'] as bool? ?? false,
        allowWeekendAttendance:
            policy['allowWeekendAttendance'] as bool? ?? false,
        dayType: schedule['dayType'] as String?,
        workStart: schedule['workStart'] as String?,
        workEnd: schedule['workEnd'] as String?,
        warnings: (json['warnings'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      ),
    );
  }

  final AttendanceContext value;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

AttendanceCaptureMethod? _method(String value) {
  for (final method in AttendanceCaptureMethod.values) {
    if (method.apiValue == value) return method;
  }
  return null;
}
