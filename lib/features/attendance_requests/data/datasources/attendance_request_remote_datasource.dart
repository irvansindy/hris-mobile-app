import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/attendance_requests/domain/entities/attendance_request.dart';

abstract interface class AttendanceRequestRemoteDataSource {
  Future<List<AttendanceCorrectionRequest>> getCorrections({String? status});
  Future<AttendanceCorrectionRequest> getCorrection(String id);
  Future<AttendanceCorrectionRequest> createCorrection(
    CreateAttendanceCorrection command,
  );
  Future<List<OvertimeRequest>> getOvertimes({String? status});
  Future<OvertimeRequest> createOvertime(CreateOvertimeRequest command);
  Future<OvertimePayEstimate> getOvertimePay(OvertimeRequest request);
}

class DioAttendanceRequestRemoteDataSource
    implements AttendanceRequestRemoteDataSource {
  const DioAttendanceRequestRemoteDataSource(this._dio, this._context);

  final Dio _dio;
  final RequestContext? Function() _context;

  @override
  Future<List<AttendanceCorrectionRequest>> getCorrections({
    String? status,
  }) async {
    final context = _requireContext();
    final normalizedStatus = _statusFilter(status);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance-corrections/my',
        queryParameters: {'status': ?normalizedStatus},
      );
      return _objectList(
        response.data,
        'Attendance correction list',
      ).map((item) => _correction(item, context)).toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<AttendanceCorrectionRequest> getCorrection(String id) async {
    final context = _requireContext();
    _requireSafeId(id);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance-corrections/my/$id',
      );
      final result = _correction(
        ApiEnvelope.fromJson(response.data ?? const {}).requireObjectData(),
        context,
      );
      if (result.id != id) {
        throw const FormatException('Attendance correction ID is invalid');
      }
      return result;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<AttendanceCorrectionRequest> createCorrection(
    CreateAttendanceCorrection command,
  ) async {
    final context = _requireContext();
    final reason = _requiredCommandText(
      command.reason,
      field: 'Alasan koreksi',
      minLength: 3,
      maxLength: 2000,
    );
    if (command.attendanceId case final id?) _requireSafeId(id);
    if (command.requestedCheckIn == null && command.requestedCheckOut == null) {
      throw const ApiException(
        'Isi minimal satu waktu check-in atau check-out.',
      );
    }
    if (command.requestedCheckIn case final checkIn?) {
      if (!_sameDate(command.date, checkIn)) {
        throw const ApiException(
          'Waktu check-in harus berada pada tanggal koreksi.',
        );
      }
    }
    if (command.requestedCheckOut case final checkOut?) {
      if (!_sameDate(command.date, checkOut)) {
        throw const ApiException(
          'Waktu check-out harus berada pada tanggal koreksi.',
        );
      }
    }
    if (command.requestedCheckIn case final checkIn?) {
      if (command.requestedCheckOut case final checkOut?) {
        if (!checkOut.isAfter(checkIn)) {
          throw const ApiException('Waktu check-out harus setelah check-in.');
        }
      }
    }
    _requireIdempotencyKey(command.idempotencyKey);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/attendance-corrections',
        data: {
          'attendanceId': ?command.attendanceId,
          'date': _dateOnly(command.date),
          if (command.requestedCheckIn case final value?)
            'requestedCheckIn': value.toUtc().toIso8601String(),
          if (command.requestedCheckOut case final value?)
            'requestedCheckOut': value.toUtc().toIso8601String(),
          'reason': reason,
        },
        options: Options(headers: {'Idempotency-Key': command.idempotencyKey}),
      );
      final result = _correction(
        ApiEnvelope.fromJson(response.data ?? const {}).requireObjectData(),
        context,
      );
      if (result.status != AttendanceRequestStatus.pending) {
        throw const FormatException(
          'Created attendance correction status is invalid',
        );
      }
      return result;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<List<OvertimeRequest>> getOvertimes({String? status}) async {
    final context = _requirePermission('attendance:read');
    final normalizedStatus = _statusFilter(status);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/overtime',
        queryParameters: {
          'companyId': context.activeCompanyId,
          'employeeId': context.employeeId,
          'status': ?normalizedStatus,
        },
      );
      return _objectList(
        response.data,
        'Overtime request list',
      ).map((item) => _overtime(item, context)).toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<OvertimeRequest> createOvertime(CreateOvertimeRequest command) async {
    final context = _requirePermission('attendance:create');
    final reason = _requiredCommandText(
      command.reason,
      field: 'Alasan lembur',
      maxLength: 2000,
    );
    if (!command.endTime.isAfter(command.startTime)) {
      throw const ApiException('Waktu selesai harus setelah waktu mulai.');
    }
    final minutes = command.endTime.difference(command.startTime).inMinutes;
    if (minutes < 1) {
      throw const ApiException('Durasi lembur minimal satu menit.');
    }
    _requireIdempotencyKey(command.idempotencyKey);
    final durationHours = double.parse((minutes / 60).toStringAsFixed(2));
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/attendance/overtime',
        data: {
          'date': _dateOnly(command.startTime),
          'startTime': command.startTime.toUtc().toIso8601String(),
          'endTime': command.endTime.toUtc().toIso8601String(),
          'durationHours': durationHours,
          'reason': reason,
        },
        options: Options(headers: {'Idempotency-Key': command.idempotencyKey}),
      );
      final result = _overtime(
        ApiEnvelope.fromJson(response.data ?? const {}).requireObjectData(),
        context,
      );
      if (result.status != AttendanceRequestStatus.pending ||
          result.startTime.toUtc() != command.startTime.toUtc() ||
          result.endTime.toUtc() != command.endTime.toUtc()) {
        throw const FormatException('Created overtime response is invalid');
      }
      return result;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<OvertimePayEstimate> getOvertimePay(OvertimeRequest request) async {
    final context = _requirePermission('attendance:read');
    _requireSafeId(request.id);
    if (request.employeeId != context.employeeId ||
        request.companyId != context.activeCompanyId) {
      throw const ApiException('Pengajuan lembur tidak sesuai sesi aktif.');
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/overtime/${request.id}/pay',
      );
      final data = ApiEnvelope.fromJson(
        response.data ?? const {},
      ).requireObjectData();
      final overtimeId = _requiredText(data, 'overtimeId');
      if (overtimeId != request.id) {
        throw const FormatException('Overtime pay ID is invalid');
      }
      final rawBreakdown = data['breakdown'];
      if (rawBreakdown is! List ||
          rawBreakdown.any((item) => item is! Map<String, dynamic>)) {
        throw const FormatException('Overtime pay breakdown is invalid');
      }
      final result = OvertimePayEstimate(
        overtimeId: overtimeId,
        durationHours: _requiredNumber(data, 'durationHours'),
        dayType: _requiredText(data, 'dayType'),
        hourlyRate: _requiredNumber(data, 'hourlyRate'),
        weightedHours: _requiredNumber(data, 'weightedHours'),
        amount: _requiredNumber(data, 'amount'),
        breakdown: rawBreakdown
            .cast<Map<String, dynamic>>()
            .map(
              (item) => OvertimePayBand(
                hours: _requiredNumber(item, 'hours'),
                rate: _requiredNumber(item, 'rate'),
                subtotal: _requiredNumber(item, 'subtotal'),
              ),
            )
            .toList(growable: false),
      );
      if (result.amount < 0 || result.durationHours <= 0) {
        throw const FormatException('Overtime pay response is invalid');
      }
      return result;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  RequestContext _requireContext() {
    final context = _context();
    if (context?.userId == null ||
        context?.employeeId == null ||
        context?.activeCompanyId == null) {
      throw const ApiException('Sesi employee/company belum tersedia.');
    }
    return context!;
  }

  RequestContext _requirePermission(String permission) {
    final context = _requireContext();
    if (!context.permissions.contains(permission)) {
      throw ApiException(
        'Akun tidak memiliki izin $permission.',
        statusCode: 403,
        code: 'FORBIDDEN',
      );
    }
    return context;
  }

  AttendanceCorrectionRequest _correction(
    Map<String, dynamic> json,
    RequestContext context,
  ) {
    final employeeId = _requiredText(json, 'employeeId');
    final companyId = _requiredText(json, 'companyId');
    if (employeeId != context.employeeId ||
        companyId != context.activeCompanyId) {
      throw const FormatException(
        'Attendance correction does not match active session',
      );
    }
    return AttendanceCorrectionRequest(
      id: _requiredText(json, 'id'),
      employeeId: employeeId,
      companyId: companyId,
      attendanceId: _optionalText(json['attendanceId']),
      date: _requiredDate(json, 'date'),
      requestedCheckIn: _optionalDate(json['requestedCheckIn']),
      requestedCheckOut: _optionalDate(json['requestedCheckOut']),
      reason: _requiredText(json, 'reason'),
      status: _requestStatus(_requiredText(json, 'status')),
      createdAt: _requiredDate(json, 'createdAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
      approvedAt: _optionalDate(json['approvedAt']),
      rejectionReason: _optionalText(json['rejectionReason']),
      employeeName: _employeeName(json['employee']),
    );
  }

  OvertimeRequest _overtime(Map<String, dynamic> json, RequestContext context) {
    final employeeId = _requiredText(json, 'employeeId');
    final companyId = _requiredText(json, 'companyId');
    if (employeeId != context.employeeId ||
        companyId != context.activeCompanyId) {
      throw const FormatException(
        'Overtime request does not match active session',
      );
    }
    final start = _requiredDate(json, 'startTime');
    final end = _requiredDate(json, 'endTime');
    if (!end.isAfter(start)) {
      throw const FormatException('Overtime request times are invalid');
    }
    return OvertimeRequest(
      id: _requiredText(json, 'id'),
      employeeId: employeeId,
      companyId: companyId,
      date: _requiredDate(json, 'date'),
      startTime: start,
      endTime: end,
      durationHours: _requiredNumber(json, 'durationHours'),
      reason: _requiredText(json, 'reason'),
      status: _requestStatus(_requiredText(json, 'status')),
      createdAt: _requiredDate(json, 'createdAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
      approvedAt: _optionalDate(json['approvedAt']),
      employeeName: _employeeName(json['employee']),
    );
  }
}

List<Map<String, dynamic>> _objectList(
  Map<String, dynamic>? json,
  String label,
) {
  final envelope = ApiEnvelope.fromJson(json ?? const {});
  final data = envelope.data;
  if (!envelope.success ||
      data is! List ||
      data.any((item) => item is! Map<String, dynamic>)) {
    throw FormatException('$label response is invalid');
  }
  return data.cast<Map<String, dynamic>>();
}

AttendanceRequestStatus _requestStatus(String value) => switch (value) {
  'PENDING' => AttendanceRequestStatus.pending,
  'APPROVED' => AttendanceRequestStatus.approved,
  'REJECTED' => AttendanceRequestStatus.rejected,
  'CANCELLED' => AttendanceRequestStatus.cancelled,
  _ => throw FormatException('Unknown attendance request status: $value'),
};

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $key');
  }
  return value.trim();
}

String? _optionalText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _optionalDate(json[key]);
  if (value == null) throw FormatException('Missing $key');
  return value;
}

DateTime? _optionalDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

double _requiredNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value)
      : null;
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('Missing $key');
  }
  return parsed;
}

String? _employeeName(Object? value) =>
    value is Map<String, dynamic> ? _optionalText(value['fullName']) : null;

String? _statusFilter(String? value) {
  if (value == null) return null;
  const allowed = {'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'};
  if (!allowed.contains(value)) {
    throw const ApiException('Filter status pengajuan tidak valid.');
  }
  return value;
}

String _requiredCommandText(
  String value, {
  required String field,
  int minLength = 1,
  required int maxLength,
}) {
  final normalized = value.trim();
  if (normalized.length < minLength || normalized.length > maxLength) {
    throw ApiException('$field harus $minLength sampai $maxLength karakter.');
  }
  return normalized;
}

void _requireSafeId(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
    throw const ApiException('ID pengajuan tidak valid.');
  }
}

void _requireIdempotencyKey(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(value)) {
    throw const ApiException('Kunci pengajuan tidak valid.');
  }
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day).toIso8601String();
