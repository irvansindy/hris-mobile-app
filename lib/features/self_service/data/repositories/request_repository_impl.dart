import 'package:hrm_app/features/self_service/data/datasources/request_local_datasource.dart';
import 'package:hrm_app/features/self_service/data/datasources/request_remote_datasource.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/domain/entities/request_command.dart';
import 'package:hrm_app/features/self_service/domain/repositories/request_repository.dart';

class RequestRepositoryImpl implements RequestRepository {
  RequestRepositoryImpl(this._local, [this._remote]);
  final RequestLocalDataSource _local;
  final RequestRemoteDataSource? _remote;

  @override
  List<EmployeeRequest> get current => _local.readAll();

  @override
  Future<List<EmployeeRequest>> refresh() async {
    final remote = _remote;
    if (remote == null) return _local.readAll();
    return (await remote.getPage(
      kind: RequestKind.leave,
      page: 1,
      limit: 20,
    )).items;
  }

  @override
  Future<EmployeeRequestPage> getPage({
    required RequestKind kind,
    int page = 1,
    int limit = 20,
  }) async {
    final remote = _remote;
    if (remote != null) {
      return remote.getPage(kind: kind, page: page, limit: limit);
    }
    final items = _local.readAll().where((item) => item.kind == kind).toList();
    return EmployeeRequestPage(
      items: items,
      page: 1,
      totalPages: 1,
      total: items.length,
    );
  }

  @override
  Future<List<LeaveTypeOption>> getLeaveTypes() async {
    final remote = _remote;
    return remote == null ? const [] : remote.getLeaveTypes();
  }

  @override
  Future<EmployeeRequest> getLeaveDetail(String id) async {
    final remote = _remote;
    if (remote != null) return remote.getLeaveDetail(id);
    return _local.readAll().firstWhere((item) => item.id == id);
  }

  @override
  Future<EmployeeRequest> cancel(RequestKind kind, String id) async {
    final remote = _remote;
    if (remote == null) {
      throw UnsupportedError('Pembatalan pengajuan belum terhubung ke server.');
    }
    return remote.cancel(kind, id);
  }

  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) =>
      _remote?.submit(command) ?? _local.insert(command);
}
