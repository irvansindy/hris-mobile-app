enum RequestStatus { approved, pending, rejected, cancelled, unknown }

enum RequestKind { leave, permission }

class EmployeeRequest {
  const EmployeeRequest({
    required this.id,
    required this.type,
    required this.dateRange,
    required this.submittedOn,
    required this.status,
    this.kind = RequestKind.leave,
    this.startDate,
    this.endDate,
    this.reason,
    this.totalDays,
    this.approvedAt,
    this.rejectionReason,
    this.attachment,
  });

  final String id;
  final String type;
  final String dateRange;
  final String submittedOn;
  final RequestStatus status;
  final RequestKind kind;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? reason;
  final num? totalDays;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? attachment;
}

class EmployeeRequestPage {
  const EmployeeRequestPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<EmployeeRequest> items;
  final int page;
  final int totalPages;
  final int total;
  bool get hasNextPage => page < totalPages;
}

class LeaveTypeOption {
  const LeaveTypeOption({
    required this.id,
    required this.name,
    this.code,
    this.requiresAttachment = false,
    this.maxDays,
  });

  final String id;
  final String name;
  final String? code;
  final bool requiresAttachment;
  final num? maxDays;
}
