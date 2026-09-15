import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/presentation/controllers/request_controller.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/self_service/self_service_dependencies.dart';

final requestControllerProvider =
    NotifierProvider<RequestController, List<EmployeeRequest>>(
      RequestController.new,
    );

class RequestPageQuery {
  const RequestPageQuery({
    required this.session,
    required this.kind,
    this.page = 1,
  });

  final FeatureSession session;
  final RequestKind kind;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is RequestPageQuery &&
      other.session == session &&
      other.kind == kind &&
      other.page == page;

  @override
  int get hashCode => Object.hash(session, kind, page);
}

final requestPageProvider = FutureProvider.autoDispose
    .family<EmployeeRequestPage, RequestPageQuery>((ref, query) async {
      final page = await ref
          .watch(requestRepositoryProvider)
          .getPage(kind: query.kind, page: query.page);
      if (!query.session.isCurrent) {
        throw StateError('Sesi telah berubah. Muat ulang pengajuan.');
      }
      return page;
    });

final leaveTypesProvider = FutureProvider.autoDispose
    .family<List<LeaveTypeOption>, FeatureSession>((ref, session) async {
      final values = await ref.watch(requestRepositoryProvider).getLeaveTypes();
      if (!session.isCurrent) {
        throw StateError('Sesi telah berubah. Muat ulang jenis cuti.');
      }
      return values;
    });

final leaveRequestDetailProvider = FutureProvider.autoDispose
    .family<EmployeeRequest, ({FeatureSession session, String id})>((
      ref,
      query,
    ) async {
      final value = await ref
          .watch(requestRepositoryProvider)
          .getLeaveDetail(query.id);
      if (!query.session.isCurrent) {
        throw StateError('Sesi telah berubah. Muat ulang detail pengajuan.');
      }
      return value;
    });
