class ReportingSupervisor {
  const ReportingSupervisor({
    required this.id,
    required this.name,
    this.employeeNumber,
    this.position,
  });

  final String id;
  final String name;
  final String? employeeNumber;
  final String? position;
}

class ReportingLine {
  const ReportingLine({
    required this.source,
    required this.alternateSupervisors,
    this.primarySupervisor,
  });

  final String source;
  final ReportingSupervisor? primarySupervisor;
  final List<ReportingSupervisor> alternateSupervisors;
}

class EmployeeAttachmentMetadata {
  const EmployeeAttachmentMetadata({
    required this.id,
    required this.name,
    this.mimeType,
    this.sizeBytes,
    this.documentType,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? mimeType;
  final int? sizeBytes;
  final String? documentType;
  final DateTime? createdAt;
}

class EmployeeSupportSnapshot {
  const EmployeeSupportSnapshot({
    required this.reportingLine,
    required this.attachments,
    required this.canReadAttachments,
  });

  final ReportingLine reportingLine;
  final List<EmployeeAttachmentMetadata> attachments;
  final bool canReadAttachments;
}
