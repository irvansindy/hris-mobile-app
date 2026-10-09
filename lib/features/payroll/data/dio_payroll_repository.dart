import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/domain/payroll_repository.dart';

class DioPayrollRepository implements PayrollRepository {
  const DioPayrollRepository(this._dio, this._context);

  static const _maxPdfBytes = 5 * 1024 * 1024;
  final Dio _dio;
  final RequestContext? Function() _context;

  @override
  Future<List<PayslipSummary>> getPayslips() async {
    final context = _requireContext();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payroll/payslips',
      );
      _ensureCurrent(context);
      final items = _envelope(response).requireListData();
      if (items.any((item) => item is! Map)) {
        throw const FormatException('Daftar slip gaji tidak valid.');
      }
      return items
          .cast<Map>()
          .map((item) => _summary(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<PayslipPinStatus> getPinStatus() async {
    final context = _requireContext(requirePermission: false);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payroll/payslips/pin/status',
      );
      _ensureCurrent(context);
      final json = _envelope(response).requireObjectData();
      if (json['pinSet'] is! bool) {
        throw const FormatException('Status PIN slip gaji tidak valid.');
      }
      return PayslipPinStatus(
        pinSet: json['pinSet']! as bool,
        lockedUntil: json['lockedUntil'] == null
            ? null
            : _securityDate(json['lockedUntil']),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<void> setPin({
    required String currentPassword,
    required String pin,
  }) async {
    final context = _requireContext(requirePermission: false);
    if (currentPassword.isEmpty || currentPassword.length > 128) {
      throw const ApiException('Kata sandi akun tidak valid.');
    }
    _validatePin(pin);
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/payroll/payslips/pin',
        data: {'currentPassword': currentPassword, 'pin': pin},
      );
      _ensureCurrent(context);
      final envelope = _envelope(response);
      if (!envelope.success || envelope.data != null) {
        throw const FormatException('Konfirmasi PIN slip gaji tidak valid.');
      }
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<PayslipUnlockGrant> unlock(String pin) async {
    final context = _requireContext(requirePermission: false);
    _validatePin(pin);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/payroll/payslips/my/unlock',
        data: {'pin': pin},
      );
      _ensureCurrent(context);
      final json = _envelope(response).requireObjectData();
      return PayslipUnlockGrant(
        token: _requiredString(json, 'unlockToken'),
        expiresAt: _securityDate(json['expiresAt']),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<PayslipDetail> getDetail({
    required String id,
    required String unlockToken,
  }) async {
    final context = _requireContext(requirePermission: false);
    _validateId(id);
    final token = _validateToken(unlockToken);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/payroll/payslips/my/$id',
        options: Options(headers: {'X-Payslip-Unlock': token}),
      );
      _ensureCurrent(context);
      return _detail(_envelope(response).requireObjectData());
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<PayslipPdf> getPdf({
    required String id,
    required String unlockToken,
  }) async {
    final context = _requireContext(requirePermission: false);
    _validateId(id);
    final token = _validateToken(unlockToken);
    try {
      final response = await _dio.get<List<int>>(
        '/payroll/payslips/my/$id/pdf',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'X-Payslip-Unlock': token},
        ),
      );
      _ensureCurrent(context);
      final contentType = response.headers.value(Headers.contentTypeHeader);
      final raw = response.data;
      if (contentType == null ||
          contentType.split(';').first.trim().toLowerCase() !=
              'application/pdf' ||
          raw == null ||
          raw.isEmpty ||
          raw.length > _maxPdfBytes) {
        throw const FormatException('Dokumen slip gaji tidak valid.');
      }
      final bytes = Uint8List.fromList(raw);
      if (bytes.length < 5 ||
          bytes[0] != 0x25 ||
          bytes[1] != 0x50 ||
          bytes[2] != 0x44 ||
          bytes[3] != 0x46 ||
          bytes[4] != 0x2D) {
        throw const FormatException('Dokumen slip gaji tidak valid.');
      }
      return PayslipPdf(bytes: bytes, sourceName: 'payslip-$id.pdf');
    } on DioException catch (error) {
      final response = error.response;
      final raw = response?.data;
      if (raw is List<int> &&
          raw.length <= 64 * 1024 &&
          response?.headers
                  .value(Headers.contentTypeHeader)
                  ?.split(';')
                  .first
                  .trim()
                  .toLowerCase() ==
              'application/json') {
        try {
          response!.data = jsonDecode(utf8.decode(raw));
        } on FormatException {
          // Preserve the HTTP fallback when an error envelope is malformed.
        }
      }
      throw mapDioException(error);
    }
  }

  RequestContext _requireContext({bool requirePermission = true}) {
    final context = _context();
    if (context == null ||
        context.userId == null ||
        context.employeeId == null ||
        context.activeCompanyId == null) {
      throw const ApiException('Sesi karyawan belum tersedia.');
    }
    if (requirePermission && !context.hasPermission('payroll:read')) {
      throw const ApiException(
        'Anda tidak memiliki akses slip gaji.',
        statusCode: 403,
        code: 'FORBIDDEN',
      );
    }
    return context;
  }

  void _ensureCurrent(RequestContext captured) {
    final current = _context();
    if (current?.userId != captured.userId ||
        current?.employeeId != captured.employeeId ||
        current?.activeCompanyId != captured.activeCompanyId) {
      throw const ApiException(
        'Sesi berubah saat memuat slip gaji.',
        code: 'SESSION_CHANGED',
      );
    }
  }
}

ApiEnvelope _envelope(Response<Map<String, dynamic>> response) {
  final data = response.data;
  if (data == null) throw const FormatException('Respons server kosong.');
  return ApiEnvelope.fromJson(data);
}

PayslipSummary _summary(Map<String, dynamic> json) {
  const forbidden = {
    'baseSalary',
    'totalEarnings',
    'totalDeductions',
    'netPay',
    'components',
    'breakdown',
  };
  if (json.keys.any(forbidden.contains) || json['locked'] != true) {
    throw const FormatException('Daftar slip gaji membocorkan nominal.');
  }
  final payrollRun = _optionalMap(json['payrollRun']);
  final period = _optionalMap(payrollRun?['period']);
  return PayslipSummary(
    id: _requiredString(json, 'id'),
    status: _requiredString(json, 'status'),
    createdAt: _requiredDate(json, 'createdAt'),
    locked: true,
    periodName: _optionalString(period?['name']),
    periodStart: _optionalDate(period?['startDate']),
    periodEnd: _optionalDate(period?['endDate']),
    payDate: _optionalDate(period?['payDate']),
  );
}

PayslipDetail _detail(Map<String, dynamic> json) {
  final rawComponents = json['components'];
  if (rawComponents is! List || rawComponents.any((item) => item is! Map)) {
    throw const FormatException('Komponen slip gaji tidak valid.');
  }
  final employee = _optionalMap(json['employee']);
  final payrollRun = _optionalMap(json['payrollRun']);
  final period = _optionalMap(payrollRun?['period']);
  return PayslipDetail(
    id: _requiredString(json, 'id'),
    status: _requiredString(json, 'status'),
    baseSalary: _money(json, 'baseSalary'),
    totalEarnings: _money(json, 'totalEarnings'),
    totalDeductions: _money(json, 'totalDeductions'),
    netPay: _money(json, 'netPay'),
    employeeName: _optionalString(employee?['fullName']),
    employeeNumber: _optionalString(employee?['employeeNumber']),
    periodName: _optionalString(period?['name']),
    payDate: _optionalDate(period?['payDate']),
    components: rawComponents
        .cast<Map>()
        .map((raw) {
          final component = Map<String, dynamic>.from(raw);
          final definition = _optionalMap(component['salaryComponent']);
          final code = _optionalString(definition?['code']) ?? 'UNKNOWN';
          return PayslipComponent(
            code: code,
            name: _optionalString(definition?['name']) ?? code,
            type: _optionalString(definition?['type']) ?? 'UNKNOWN',
            amount: _money(component, 'amount'),
          );
        })
        .toList(growable: false),
  );
}

double _money(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed.isFinite) return parsed;
  }
  throw FormatException('Nilai $key tidak valid.');
}

Map<String, dynamic>? _optionalMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null) throw FormatException('Field $key tidak valid.');
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _optionalDate(json[key]);
  if (value == null) throw FormatException('Tanggal $key tidak valid.');
  return value;
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Tanggal tidak valid.');
  final parsed = DateTime.tryParse(value)?.toUtc();
  if (parsed == null) throw const FormatException('Tanggal tidak valid.');
  return parsed;
}

DateTime _securityDate(Object? value) {
  if (value is! String) throw const FormatException('Timestamp tidak valid.');
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null) {
    throw const FormatException('Timestamp wajib memiliki zona waktu.');
  }
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final calendar = DateTime.utc(parts[0], parts[1], parts[2]);
  if (calendar.year != parts[0] ||
      calendar.month != parts[1] ||
      calendar.day != parts[2] ||
      parts[3] > 23 ||
      parts[4] > 59 ||
      parts[5] > 59) {
    throw const FormatException('Timestamp tidak valid.');
  }
  final zone = match.group(7)!;
  if (zone != 'Z' &&
      (int.parse(zone.substring(1, 3)) > 23 ||
          int.parse(zone.substring(4)) > 59)) {
    throw const FormatException('Zona waktu tidak valid.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException('Timestamp tidak valid.');
  return parsed.toUtc();
}

void _validatePin(String pin) {
  if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
    throw const ApiException('PIN harus terdiri dari 6 digit angka.');
  }
}

void _validateId(String id) {
  if (id.trim().isEmpty || id.contains('/')) {
    throw const ApiException('Identitas slip gaji tidak valid.');
  }
}

String _validateToken(String token) {
  final normalized = token.trim();
  if (normalized.isEmpty) {
    throw const ApiException('Slip gaji belum dibuka.');
  }
  return normalized;
}
