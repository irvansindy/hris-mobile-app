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
    _requireContext();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        kind == RequestKind.leave ? '/leave' : '/permission-requests/my',
        queryParameters: {'page': page, 'limit': limit},
      );
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success) throw FormatException(envelope.message);
      final raw = envelope.data;
      final items = raw is List
          ? raw
          : raw is Map<String, dynamic>
          ? (raw['items'] ?? raw['requests'] ?? raw['leaves']) as List? ??
                const []
          : const [];
      final meta =
          envelope.meta ??
          (raw is Map<String, dynamic>
              ? raw['meta'] as Map<String, dynamic>?
              : null) ??
          const {};
      return EmployeeRequestPage(
        items: items
            .whereType<Map<String, dynamic>>()
            .map((item) => _request(item, kind))
            .toList(growable: false),
        page: _integer(meta['page'], page),
        totalPages: _integer(meta['totalPages'], page),
        total: _integer(meta['total'], items.length),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<List<LeaveTypeOption>> getLeaveTypes() async {
    _requireContext();
    try {
      final response = await _dio.get<Map<String, dynamic>>('/leave/types');
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success) throw FormatException(envelope.message);
      final raw = envelope.data;
      final items = raw is List
          ? raw
          : raw is Map<String, dynamic>
          ? (raw['items'] ?? raw['types']) as List? ?? const []
          : const [];
      return items
          .whereType<Map<String, dynamic>>()
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
    _requireContext();
    try {
      final response = await _dio.get<Map<String, dynamic>>('/leave/$id');
      return _request(_object(response), RequestKind.leave);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) async {
    _requireContext();
    if (command.startDate == null ||
        command.endDate == null ||
        command.reason?.trim().isEmpty != false) {
      throw const ApiException('Lengkapi tanggal dan alasan pengajuan.');
    }
    final isLeave = command.kind == RequestKind.leave;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        isLeave ? '/leave' : '/permission-requests',
        data: {
          if (isLeave) 'leaveTypeId': command.type else 'type': command.type,
          'startDate': _date(command.startDate!),
          'endDate': _date(command.endDate!),
          'reason': command.reason!.trim(),
          if (isLeave && command.attachment != null)
            'attachment': command.attachment,
        },
        options: command.idempotencyKey == null
            ? null
            : Options(headers: {'Idempotency-Key': command.idempotencyKey}),
      );
      return _request(_object(response), command.kind);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<EmployeeRequest> cancel(RequestKind kind, String id) async {
    _requireContext();
    try {
      final path = kind == RequestKind.leave
          ? '/leave/$id/cancel'
          : '/permission-requests/$id/cancel';
      final response = await _dio.patch<Map<String, dynamic>>(path);
      return _request(_object(response), kind);
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

  Map<String, dynamic> _object(Response<Map<String, dynamic>> response) {
    final data = ApiEnvelope.fromJson(
      response.data ?? const {},
    ).requireObjectData();
    for (final key in const ['request', 'leave', 'permissionRequest']) {
      if (data[key] case final Map<String, dynamic> nested) return nested;
    }
    return data;
  }

  EmployeeRequest _request(Map<String, dynamic> json, RequestKind kind) {
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

int _integer(Object? value, int fallback) => switch (value) {
  int number => number,
  num number => number.round(),
  String text => int.tryParse(text) ?? fallback,
  _ => fallback,
};
