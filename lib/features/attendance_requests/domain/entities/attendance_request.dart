enum AttendanceRequestStatus { pending, approved, rejected, cancelled }

class AttendanceCorrectionRequest {
  const AttendanceCorrectionRequest({
    required this.id,
    required this.employeeId,
    required this.companyId,
    required this.date,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.attendanceId,
    this.requestedCheckIn,
    this.requestedCheckOut,
    this.approvedAt,
    this.rejectionReason,
    this.employeeName,
  });

  final String id;
  final String employeeId;
  final String companyId;
  final String? attendanceId;
  final DateTime date;
  final DateTime? requestedCheckIn;
  final DateTime? requestedCheckOut;
  final String reason;
  final AttendanceRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? employeeName;
}

class OvertimeRequest {
  const OvertimeRequest({
    required this.id,
    required this.employeeId,
    required this.companyId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.employeeName,
  });

  final String id;
  final String employeeId;
  final String companyId;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final String reason;
  final AttendanceRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final String? employeeName;
}

class OvertimePayEstimate {
  const OvertimePayEstimate({
    required this.overtimeId,
    required this.durationHours,
    required this.dayType,
    required this.hourlyRate,
    required this.weightedHours,
    required this.amount,
    required this.breakdown,
  });

  final String overtimeId;
  final double durationHours;
  final String dayType;
  final double hourlyRate;
  final double weightedHours;
  final double amount;
  final List<OvertimePayBand> breakdown;
}

class OvertimePayBand {
  const OvertimePayBand({
    required this.hours,
    required this.rate,
    required this.subtotal,
  });

  final double hours;
  final double rate;
  final double subtotal;
}

class CreateAttendanceCorrection {
  const CreateAttendanceCorrection({
    required this.date,
    required this.reason,
    required this.idempotencyKey,
    this.attendanceId,
    this.requestedCheckIn,
    this.requestedCheckOut,
  });

  final String? attendanceId;
  final DateTime date;
  final DateTime? requestedCheckIn;
  final DateTime? requestedCheckOut;
  final String reason;
  final String idempotencyKey;
}

class CreateOvertimeRequest {
  const CreateOvertimeRequest({
    required this.startTime,
    required this.endTime,
    required this.reason,
    required this.idempotencyKey,
  });

  final DateTime startTime;
  final DateTime endTime;
  final String reason;
  final String idempotencyKey;
}
