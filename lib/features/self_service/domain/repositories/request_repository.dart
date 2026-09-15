import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/domain/entities/request_command.dart';

abstract class RequestRepository {
  List<EmployeeRequest> get current;
  Future<List<EmployeeRequest>> refresh();
  Future<EmployeeRequestPage> getPage({
    required RequestKind kind,
    int page = 1,
    int limit = 20,
  }) async {
    final items = (await refresh()).where((item) => item.kind == kind).toList();
    return EmployeeRequestPage(
      items: items,
      page: 1,
      totalPages: 1,
      total: items.length,
    );
  }

  Future<List<LeaveTypeOption>> getLeaveTypes() async => const [];
  Future<EmployeeRequest> getLeaveDetail(String id) async =>
      (await refresh()).firstWhere((item) => item.id == id);
  Future<EmployeeRequest> cancel(RequestKind kind, String id) =>
      throw UnsupportedError('Request cancellation is not implemented.');
  Future<EmployeeRequest> submit(SubmitRequestCommand command);
}
