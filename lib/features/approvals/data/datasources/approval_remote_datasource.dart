import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';

abstract interface class ApprovalRemoteDataSource {
  Future<WorkflowApprovalPage> getQueue({
    required int page,
    required int limit,
  });
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

class DioApprovalRemoteDataSource implements ApprovalRemoteDataSource {
  const DioApprovalRemoteDataSource(this._dio, this._context);

  final Dio _dio;
  final RequestContext? Function() _context;

  @override
  Future<WorkflowApprovalPage> getQueue({
    required int page,
    required int limit,
  }) async {
    final context = _requireApprover();
    if (page < 1 || limit < 1 || limit > 100) {
      throw const ApiException('Pagination approval tidak valid.');
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/workflow-engine/instances/my-approvals',
        queryParameters: {'page': page, 'limit': limit},
      );
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success || envelope.data is! List) {
        throw const FormatException('Approval queue response is invalid');
      }
      final rawItems = envelope.data! as List;
      if (rawItems.any((item) => item is! Map<String, dynamic>)) {
        throw const FormatException('Approval queue response is invalid');
      }
      final meta = envelope.meta ?? const <String, dynamic>{};
      final items = rawItems
          .cast<Map<String, dynamic>>()
          .map((item) => _approval(item, context))
          .toList(growable: false);
      return WorkflowApprovalPage(
        items: items,
        page: _integer(meta['page'], page),
        totalPages: _integer(meta['totalPages'], page),
        total: _integer(meta['total'], items.length),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<void> applyAction({
    required String instanceId,
    required WorkflowApprovalAction action,
    String? comment,
  }) async {
    _requireApprover();
    _requireSafeId(instanceId);
    final normalizedComment = _actionComment(action, comment);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/workflow-engine/instances/$instanceId/actions',
        data: {'action': action.apiValue, 'comment': ?normalizedComment},
      );
      _requireSuccess(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<WorkflowBulkResult> applyBulkAction({
    required List<String> instanceIds,
    required WorkflowApprovalAction action,
    String? comment,
  }) async {
    _requireApprover();
    if (instanceIds.isEmpty || instanceIds.length > 100) {
      throw const ApiException('Pilih 1 sampai 100 approval.');
    }
    final uniqueIds = instanceIds.toSet();
    if (uniqueIds.length != instanceIds.length) {
      throw const ApiException('Daftar approval mengandung ID duplikat.');
    }
    for (final id in instanceIds) {
      _requireSafeId(id);
    }
    final normalizedComment = _actionComment(action, comment);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/workflow-engine/instances/bulk-approve',
        data: {
          'instanceIds': instanceIds,
          'action': action.apiValue,
          'comment': ?normalizedComment,
        },
      );
      final data = ApiEnvelope.fromJson(
        response.data ?? const {},
      ).requireObjectData();
      return _bulkResult(data, uniqueIds);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<List<ApprovalDelegation>> getDelegations() async {
    final context = _requireContext();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/workflow-engine/delegations',
        queryParameters: const {'mine': true},
      );
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success || envelope.data is! List) {
        throw const FormatException('Delegation list response is invalid');
      }
      final values = envelope.data! as List;
      if (values.any((item) => item is! Map<String, dynamic>)) {
        throw const FormatException('Delegation list response is invalid');
      }
      return values
          .cast<Map<String, dynamic>>()
          .map((item) => _delegation(item, context))
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<ApprovalDelegation> createDelegation(
    CreateApprovalDelegation command,
  ) async {
    final context = _requireContext();
    _requireSafeId(command.delegateId);
    if (command.delegateId == context.userId) {
      throw const ApiException(
        'Approval tidak dapat didelegasikan ke diri sendiri.',
      );
    }
    if (!command.endDate.isAfter(command.startDate)) {
      throw const ApiException('Tanggal akhir harus setelah tanggal mulai.');
    }
    final reason = _optionalText(command.reason, maxLength: 1000);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/workflow-engine/delegations',
        data: {
          'delegateId': command.delegateId,
          'startDate': command.startDate.toUtc().toIso8601String(),
          'endDate': command.endDate.toUtc().toIso8601String(),
          'reason': ?reason,
        },
      );
      return _delegation(
        ApiEnvelope.fromJson(response.data ?? const {}).requireObjectData(),
        context,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<ApprovalDelegation> revokeDelegation(String id) async {
    final context = _requireContext();
    _requireSafeId(id);
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/workflow-engine/delegations/$id/revoke',
      );
      final result = _delegation(
        ApiEnvelope.fromJson(response.data ?? const {}).requireObjectData(),
        context,
      );
      if (result.id != id || result.isActive) {
        throw const FormatException('Revoked delegation response is invalid');
      }
      return result;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  RequestContext _requireContext() {
    final context = _context();
    if (context?.userId == null || context?.activeCompanyId == null) {
      throw const ApiException('Sesi akun belum tersedia.');
    }
    return context!;
  }

  RequestContext _requireApprover() {
    final context = _requireContext();
    if (!context.permissions.contains('workflow:approve')) {
      throw const ApiException(
        'Akun tidak memiliki izin Approval Center.',
        statusCode: 403,
        code: 'FORBIDDEN',
      );
    }
    return context;
  }

  WorkflowApproval _approval(
    Map<String, dynamic> json,
    RequestContext context,
  ) {
    final instance = json['instance'];
    if (instance is! Map<String, dynamic> ||
        json['isCurrent'] != true ||
        json['status'] != 'PENDING') {
      throw const FormatException('Approval queue item is invalid');
    }
    final companyId = _requiredText(instance, const ['companyId']);
    if (companyId != context.activeCompanyId) {
      throw const FormatException('Approval does not match active company');
    }
    final template = instance['template'];
    final templateMap = template is Map<String, dynamic>
        ? template
        : const <String, dynamic>{};
    final approvalType = _requiredText(instance, const ['approvalType']);
    final title = _text(templateMap, const ['name']) ?? approvalType;
    final payload = instance['payload'];
    final payloadMap = payload is Map<String, dynamic>
        ? payload
        : const <String, dynamic>{};
    return WorkflowApproval(
      stepId: _requiredText(json, const ['id']),
      instanceId: _requiredText(instance, const ['id']),
      companyId: companyId,
      referenceType: _requiredText(instance, const ['referenceType']),
      referenceId: _requiredText(instance, const ['referenceId']),
      approvalType: approvalType,
      title: title,
      stepName: _requiredText(json, const ['name']),
      level: _requiredInteger(json['level']),
      status: 'PENDING',
      submittedAt: _requiredDate(instance['createdAt']),
      requesterLabel: _text(payloadMap, const [
        'requesterName',
        'employeeName',
        'subjectName',
      ]),
    );
  }

  WorkflowBulkResult _bulkResult(
    Map<String, dynamic> data,
    Set<String> requestedIds,
  ) {
    final total = _requiredInteger(data['total']);
    final successful = _requiredInteger(data['successful']);
    final failed = _requiredInteger(data['failed']);
    final rawResults = data['results'];
    if (rawResults is! List ||
        rawResults.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Bulk approval result is invalid');
    }
    final seen = <String>{};
    final results = rawResults
        .cast<Map<String, dynamic>>()
        .map((item) {
          final id = _requiredText(item, const ['instanceId']);
          final success = item['success'];
          if (!requestedIds.contains(id) || !seen.add(id) || success is! bool) {
            throw const FormatException('Bulk approval result is invalid');
          }
          return WorkflowBulkItemResult(
            instanceId: id,
            success: success,
            error: _text(item, const ['error']),
          );
        })
        .toList(growable: false);
    if (total != requestedIds.length ||
        results.length != total ||
        successful + failed != total ||
        results.where((item) => item.success).length != successful) {
      throw const FormatException('Bulk approval totals are inconsistent');
    }
    return WorkflowBulkResult(
      total: total,
      successful: successful,
      failed: failed,
      results: results,
    );
  }

  ApprovalDelegation _delegation(
    Map<String, dynamic> json,
    RequestContext context,
  ) {
    final companyId = _requiredText(json, const ['companyId']);
    final delegatorId = _requiredText(json, const ['delegatorId']);
    if (companyId != context.activeCompanyId || delegatorId != context.userId) {
      throw const FormatException('Delegation does not match active session');
    }
    final delegate = json['delegate'];
    return ApprovalDelegation(
      id: _requiredText(json, const ['id']),
      companyId: companyId,
      delegatorId: delegatorId,
      delegateId: _requiredText(json, const ['delegateId']),
      delegateLabel: delegate is Map<String, dynamic>
          ? _text(delegate, const ['email', 'name'])
          : null,
      startDate: _requiredDate(json['startDate']),
      endDate: _requiredDate(json['endDate']),
      isActive: json['isActive'] is bool
          ? json['isActive'] as bool
          : throw const FormatException('Delegation status is missing'),
      reason: _text(json, const ['reason']),
    );
  }

  String? _actionComment(WorkflowApprovalAction action, String? value) {
    final comment = _optionalText(value, maxLength: 2000);
    if (action == WorkflowApprovalAction.reject && comment == null) {
      throw const ApiException('Alasan penolakan wajib diisi.');
    }
    return comment;
  }

  void _requireSuccess(Map<String, dynamic>? data) {
    final envelope = ApiEnvelope.fromJson(data ?? const {});
    if (!envelope.success) {
      throw FormatException(
        envelope.message.isEmpty
            ? 'Workflow response is invalid'
            : envelope.message,
      );
    }
  }

  void _requireSafeId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Workflow ID is invalid');
    }
  }
}

String? _text(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _requiredText(Map<dynamic, dynamic> json, List<String> keys) {
  final value = _text(json, keys);
  if (value == null) throw const FormatException('Workflow data is incomplete');
  return value;
}

String? _optionalText(String? value, {required int maxLength}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > maxLength) {
    throw const ApiException('Teks melebihi batas yang diizinkan.');
  }
  return normalized;
}

int _integer(Object? value, int fallback) => switch (value) {
  int number => number,
  num number => number.round(),
  String text => int.tryParse(text) ?? fallback,
  _ => fallback,
};

int _requiredInteger(Object? value) => switch (value) {
  int number => number,
  num number => number.round(),
  String text when int.tryParse(text) != null => int.parse(text),
  _ => throw const FormatException('Workflow number is missing'),
};

DateTime _requiredDate(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value)?.toLocal() : null;
  if (parsed == null) throw const FormatException('Workflow date is invalid');
  return parsed;
}
