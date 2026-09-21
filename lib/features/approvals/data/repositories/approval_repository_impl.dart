import 'package:hrm_app/features/approvals/data/datasources/approval_remote_datasource.dart';
import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';
import 'package:hrm_app/features/approvals/domain/repositories/approval_repository.dart';

class ApprovalRepositoryImpl implements ApprovalRepository {
  const ApprovalRepositoryImpl(this._remote);

  final ApprovalRemoteDataSource _remote;

  @override
  Future<WorkflowApprovalPage> getQueue({required int page, int limit = 20}) =>
      _remote.getQueue(page: page, limit: limit);

  @override
  Future<void> applyAction({
    required String instanceId,
    required WorkflowApprovalAction action,
    String? comment,
  }) => _remote.applyAction(
    instanceId: instanceId,
    action: action,
    comment: comment,
  );

  @override
  Future<WorkflowBulkResult> applyBulkAction({
    required List<String> instanceIds,
    required WorkflowApprovalAction action,
    String? comment,
  }) => _remote.applyBulkAction(
    instanceIds: instanceIds,
    action: action,
    comment: comment,
  );

  @override
  Future<List<ApprovalDelegation>> getDelegations() => _remote.getDelegations();

  @override
  Future<ApprovalDelegation> createDelegation(
    CreateApprovalDelegation command,
  ) => _remote.createDelegation(command);

  @override
  Future<ApprovalDelegation> revokeDelegation(String id) =>
      _remote.revokeDelegation(id);
}
