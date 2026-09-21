enum WorkflowApprovalAction {
  approve('APPROVE'),
  reject('REJECT'),
  escalate('ESCALATE');

  const WorkflowApprovalAction(this.apiValue);
  final String apiValue;
}

class WorkflowApproval {
  const WorkflowApproval({
    required this.stepId,
    required this.instanceId,
    required this.companyId,
    required this.referenceType,
    required this.referenceId,
    required this.approvalType,
    required this.title,
    required this.stepName,
    required this.level,
    required this.status,
    required this.submittedAt,
    this.requesterLabel,
  });

  final String stepId;
  final String instanceId;
  final String companyId;
  final String referenceType;
  final String referenceId;
  final String approvalType;
  final String title;
  final String stepName;
  final int level;
  final String status;
  final DateTime submittedAt;
  final String? requesterLabel;
}

class WorkflowApprovalPage {
  const WorkflowApprovalPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<WorkflowApproval> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;
}

class WorkflowBulkItemResult {
  const WorkflowBulkItemResult({
    required this.instanceId,
    required this.success,
    this.error,
  });

  final String instanceId;
  final bool success;
  final String? error;
}

class WorkflowBulkResult {
  const WorkflowBulkResult({
    required this.total,
    required this.successful,
    required this.failed,
    required this.results,
  });

  final int total;
  final int successful;
  final int failed;
  final List<WorkflowBulkItemResult> results;
}

class ApprovalDelegation {
  const ApprovalDelegation({
    required this.id,
    required this.companyId,
    required this.delegatorId,
    required this.delegateId,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.delegateLabel,
    this.reason,
  });

  final String id;
  final String companyId;
  final String delegatorId;
  final String delegateId;
  final String? delegateLabel;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? reason;
}

class CreateApprovalDelegation {
  const CreateApprovalDelegation({
    required this.delegateId,
    required this.startDate,
    required this.endDate,
    this.reason,
  });

  final String delegateId;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;
}
