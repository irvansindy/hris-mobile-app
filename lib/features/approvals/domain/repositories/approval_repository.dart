import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';

abstract interface class ApprovalRepository {
  Future<WorkflowApprovalPage> getQueue({required int page, int limit = 20});

  Future<void> applyAction({
    required String instanceId,
    required WorkflowApprovalAction action,
    String? comment,
  });

  Future<WorkflowBulkResult> applyBulkAction({
    required List<String> instanceIds,
    required WorkflowApprovalAction action,
    String? comment,
  });

  Future<List<ApprovalDelegation>> getDelegations();

  Future<ApprovalDelegation> createDelegation(CreateApprovalDelegation command);

  Future<ApprovalDelegation> revokeDelegation(String id);
}
