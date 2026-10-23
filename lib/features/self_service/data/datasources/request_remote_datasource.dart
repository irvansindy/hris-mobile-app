import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/domain/entities/request_command.dart';

abstract interface class RequestRemoteDataSource {
  Future<EmployeeRequestPage> getPage({
    required RequestKind kind,
    required int page,
    required int limit,
  });
  Future<List<LeaveTypeOption>> getLeaveTypes();
  Future<EmployeeRequest> getLeaveDetail(String id);
  Future<EmployeeRequest> submit(SubmitRequestCommand command);
  Future<EmployeeRequest> cancel(RequestKind kind, String id);
}

class DioRequestRemoteDataSource implements RequestRemoteDataSource {
  const DioRequestRemoteDataSource(this._dio, this._context);

  final Dio _dio;
  final RequestContext? Function() _context;

  @override
  Future<EmployeeRequestPage> getPage({
    required RequestKind kind,
    required int page,
    required int limit,
  }) async {
    final context = kind == RequestKind.leave
        ? _requirePermission('leave:read')
        : _requireContext();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        kind == RequestKind.leave ? '/leave' : '/permission-requests/my',
      );
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success) throw FormatException(envelope.message);
      final raw = envelope.data;
      final items = _listData(raw, const ['items', 'requests', 'leaves']);
      return EmployeeRequestPage(
        items: items
            .map((item) => _request(item, kind, context))
            .toList(growable: false),
        page: 1,
        totalPages: items.isEmpty ? 0 : 1,
        total: items.length,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<List<LeaveTypeOption>> getLeaveTypes() async {
    _requirePermission('leave:read');
    try {
      final response = await _dio.get<Map<String, dynamic>>('/leave/types');
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success) throw FormatException(envelope.message);
      final raw = envelope.data;
      final items = _listData(raw, const ['items', 'types']);
      return items
          .map((item) {
            return LeaveTypeOption(
              id: _requiredText(item, const ['id']),
              name: _requiredText(item, const ['name', 'label', 'code']),
              code: _text(item, const ['code']),
              requiresAttachment: item['requiresAttachment'] as bool? ?? false,
              maxDays: item['maxDays'] as num?,
            );
          })
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<EmployeeRequest> getLeaveDetail(String id) async {
    final context = _requirePermission('leave:read');
    _requireSafeId(id);
    try {
      final response = await _dio.get<Map<String, dynamic>>('/leave/$id');
      return _request(_object(response), RequestKind.leave, context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) async {
    if (command.kind == RequestKind.permission) {
      _requireContext();
      throw const ApiException(
        'Pengajuan izin production belum tersedia karena satuan durasi dan kontrak upload lampiran belum dipastikan backend.',
      );
    }
    final context = _requirePermission('leave:create');
    if (command.startDate == null ||
        command.endDate == null ||
        command.reason?.trim().isEmpty != false) {
      throw const ApiException('Lengkapi tanggal dan alasan pengajuan.');
    }
    try {
      final attachment = command.attachment == null
          ? null
          : await _uploadLeaveAttachment(command.attachment!);
      final response = await _dio.post<Map<String, dynamic>>(
        '/leave',
        data: {
          'employeeId': context.employeeId,
          'companyId': context.activeCompanyId,
          'leaveTypeId': command.type,
          'startDate': _isoDate(command.startDate!),
          'endDate': _isoDate(command.endDate!),
          'reason': command.reason!.trim(),
          'attachment': ?attachment,
        },
        options: command.idempotencyKey == null
            ? null
            : Options(headers: {'Idempotency-Key': command.idempotencyKey}),
      );
      return _request(_object(response), command.kind, context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> _uploadLeaveAttachment(RequestAttachment attachment) async {
    if (attachment.bytes.isEmpty || attachment.fileName.trim().isEmpty) {
      throw const ApiException('Lampiran cuti tidak valid.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/leave/attachments',
      data: FormData.fromMap({
        'attachment': MultipartFile.fromBytes(
          attachment.bytes,
          filename: attachment.fileName.trim(),
        ),
      }),
    );
    final data = ApiEnvelope.fromJson(
      response.data ?? const {},
    ).requireObjectData();
    return _requiredText(data, const ['url']);
  }

  @override
  Future<EmployeeRequest> cancel(RequestKind kind, String id) async {
    final context = _requireContext();
    _requireSafeId(id);
    try {
      final path = kind == RequestKind.leave
          ? '/leave/$id/cancel'
          : '/permission-requests/$id/cancel';
      final response = await _dio.patch<Map<String, dynamic>>(path);
      return _request(_object(response), kind, context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  RequestContext _requireContext() {
    final context = _context();
    if (context?.employeeId == null || context?.activeCompanyId == null) {
      throw const ApiException('Session employee/company belum tersedia.');
    }
    return context!;
  }

  RequestContext _requirePermission(String permission) {
    final context = _requireContext();
    if (!context.hasPermission(permission)) {
      throw ApiException(
        'Akun tidak memiliki izin $permission.',
        statusCode: 403,
        code: 'FORBIDDEN',
      );
    }
    return context;
  }

  Map<String, dynamic> _object(Response<Map<String, dynamic>> response) {
    final data = ApiEnvelope.fromJson(
      response.data ?? const {},
    ).requireObjectData();
    for (final key in const ['request', 'leave', 'permissionRequest']) {
      if (data[key] case final Map<String, dynamic> nested) return nested;
    }
    return data;
  }

  EmployeeRequest _request(
    Map<String, dynamic> json,
    RequestKind kind,
    RequestContext context,
  ) {
    final employeeId = _text(json, const ['employeeId', 'employee_id']);
    final companyId = _text(json, const ['companyId', 'company_id']);
    if ((employeeId != null && employeeId != context.employeeId) ||
        (companyId != null && companyId != context.activeCompanyId)) {
      throw const FormatException(
        'Request response does not match the active employee or company',
      );
    }
    final typeObject = json['leaveType'];
    final type = typeObject is Map<String, dynamic>
        ? _text(typeObject, const ['name', 'code'])
        : _text(json, const ['typeName', 'type', 'leaveTypeId']);
    final start = _parseDate(json['startDate']);
    final end = _parseDate(json['endDate']);
    final created = _parseDate(json['createdAt'] ?? json['submittedAt']);
    return EmployeeRequest(
      id: _requiredText(json, const ['id']),
      kind: kind,
      type: type ?? 'Tidak diketahui',
      dateRange: _range(start, end),
      submittedOn: created == null ? 'Tanggal tidak tersedia' : _date(created),
      status: _status(json['status']),
      startDate: start,
      endDate: end,
      reason: _text(json, const ['reason']),
      totalDays: json['totalDays'] as num?,
      approvedAt: _parseDate(json['approvedAt']),
      rejectionReason: _text(json, const ['rejectionReason', 'notes']),
      attachment: _text(json, const ['attachment']),
    );
  }

  List<Map<String, dynamic>> _listData(Object? data, List<String> keys) {
    Object? raw = data;
    if (raw is Map<String, dynamic>) {
      final map = raw;
      for (final key in keys) {
        if (map.containsKey(key)) {
          raw = map[key];
          break;
        }
      }
    }
    if (raw is! List || raw.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Request list response is invalid');
    }
    return raw.cast<Map<String, dynamic>>();
  }

  void _requireSafeId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Request ID is invalid');
    }
  }
}

RequestStatus _status(Object? value) => switch ('$value'.toUpperCase()) {
  'APPROVED' => RequestStatus.approved,
  'PENDING' || 'SUBMITTED' => RequestStatus.pending,
  'REJECTED' => RequestStatus.rejected,
  'CANCELLED' || 'CANCELED' => RequestStatus.cancelled,
  _ => RequestStatus.unknown,
};

String _range(DateTime? start, DateTime? end) {
  if (start == null) return 'Tanggal tidak tersedia';
  if (end == null || start == end) return _date(start);
  return '${_date(start)} sampai ${_date(end)}';
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _isoDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day).toIso8601String();

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

String? _text(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _requiredText(Map<dynamic, dynamic> json, List<String> keys) {
  final value = _text(json, keys);
  if (value == null) throw const FormatException('Request data is incomplete');
  return value;
}
