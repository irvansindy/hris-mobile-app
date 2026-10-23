import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/profile/domain/entities/employee_support.dart';
import 'package:hrm_app/features/profile/domain/repositories/employee_support_repository.dart';

class DioEmployeeSupportRepository implements EmployeeSupportRepository {
  const DioEmployeeSupportRepository(this._dio, this._context);

  final Dio _dio;
  final RequestContext? Function() _context;

  @override
  Future<EmployeeSupportSnapshot> load() async {
    final context = _context();
    if (context?.employeeId == null || context?.activeCompanyId == null) {
      throw const ApiException('Sesi employee/company belum tersedia.');
    }
    try {
      final reportingResponse = await _dio.get<Map<String, dynamic>>(
        '/employees/me/reporting-line',
      );
      final reporting = _reportingLine(
        ApiEnvelope.fromJson(
          reportingResponse.data ?? const {},
        ).requireObjectData(),
      );
      if (!context!.hasPermission('employee:read')) {
        return EmployeeSupportSnapshot(
          reportingLine: reporting,
          attachments: const [],
          canReadAttachments: false,
        );
      }
      final attachmentResponse = await _dio.get<Map<String, dynamic>>(
        '/employees/${context.employeeId}/attachments',
      );
      final values = ApiEnvelope.fromJson(
        attachmentResponse.data ?? const {},
      ).requireListData();
      if (values.any((value) => value is! Map)) {
        throw const FormatException('Metadata dokumen tidak valid.');
      }
      return EmployeeSupportSnapshot(
        reportingLine: reporting,
        attachments: values
            .cast<Map>()
            .map(
              (value) => _attachment(Map<String, dynamic>.from(value), context),
            )
            .toList(growable: false),
        canReadAttachments: true,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  ReportingLine _reportingLine(Map<String, dynamic> json) {
    final primary = json['primarySupervisor'];
    final alternates = json['alternateSupervisors'];
    if (alternates is! List || alternates.any((value) => value is! Map)) {
      throw const FormatException('Garis pelaporan tidak valid.');
    }
    return ReportingLine(
      source: _text(json, 'source') ?? 'POSITION_REPORTS_TO',
      primarySupervisor: primary == null
          ? null
          : primary is Map
          ? _supervisor(Map<String, dynamic>.from(primary))
          : throw const FormatException('Atasan utama tidak valid.'),
      alternateSupervisors: alternates
          .cast<Map>()
          .map((value) => _supervisor(Map<String, dynamic>.from(value)))
          .toList(growable: false),
    );
  }

  ReportingSupervisor _supervisor(Map<String, dynamic> json) {
    final employee = json['employee'];
    final source = employee is Map ? Map<String, dynamic>.from(employee) : json;
    final position = source['position'];
    return ReportingSupervisor(
      id: _requiredText(source, 'id'),
      name:
          _text(source, 'fullName') ??
          _text(source, 'name') ??
          _requiredText(source, 'employeeNumber'),
      employeeNumber: _text(source, 'employeeNumber'),
      position: position is Map
          ? _text(Map<String, dynamic>.from(position), 'name')
          : _text(source, 'positionName'),
    );
  }

  EmployeeAttachmentMetadata _attachment(
    Map<String, dynamic> json,
    RequestContext context,
  ) {
    final employeeId = _text(json, 'employeeId');
    final companyId = _text(json, 'companyId');
    if ((employeeId != null && employeeId != context.employeeId) ||
        (companyId != null && companyId != context.activeCompanyId)) {
      throw const FormatException('Dokumen tidak sesuai sesi aktif.');
    }
    return EmployeeAttachmentMetadata(
      id: _requiredText(json, 'id'),
      name:
          _text(json, 'originalName') ??
          _text(json, 'fileName') ??
          _requiredText(json, 'name'),
      mimeType: _text(json, 'mimeType'),
      sizeBytes: _integer(json['size']),
      documentType:
          _text(json, 'documentType') ?? _text(json, 'attachmentType'),
      createdAt: DateTime.tryParse(_text(json, 'createdAt') ?? '')?.toLocal(),
    );
  }
}

String? _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

String _requiredText(Map<String, dynamic> json, String key) =>
    _text(json, key) ?? (throw FormatException('Field $key tidak tersedia.'));

int? _integer(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text),
  _ => null,
};
