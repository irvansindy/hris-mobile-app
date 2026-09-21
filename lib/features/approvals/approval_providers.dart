import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/approvals/approval_dependencies.dart';
import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';

bool canAccessApprovalCenter(RequestContext? context) =>
    context?.permissions.contains('workflow:approve') == true;

class ApprovalQueueQuery {
  const ApprovalQueueQuery({
    required this.session,
    this.page = 1,
    this.limit = 20,
  });

  final FeatureSession session;
  final int page;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is ApprovalQueueQuery &&
      other.session == session &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(session, page, limit);
}

final approvalQueueProvider = FutureProvider.autoDispose
    .family<WorkflowApprovalPage, ApprovalQueueQuery>((ref, query) async {
      final page = await ref
          .watch(approvalRepositoryProvider)
          .getQueue(page: query.page, limit: query.limit);
      if (!query.session.isCurrent) {
        throw StateError('Sesi telah berubah. Muat ulang Approval Center.');
      }
      return page;
    });

final approvalDelegationsProvider = FutureProvider.autoDispose
    .family<List<ApprovalDelegation>, FeatureSession>((ref, session) async {
      final values = await ref
          .watch(approvalRepositoryProvider)
          .getDelegations();
      if (!session.isCurrent) {
        throw StateError('Sesi telah berubah. Muat ulang delegasi.');
      }
      return values;
    });
