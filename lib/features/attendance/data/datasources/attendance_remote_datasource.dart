import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/attendance/data/dto/attendance_dto.dart';
import 'package:hrm_app/features/attendance/data/dto/attendance_context_dto.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_history.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_today.dart';

abstract class AttendanceRemoteDataSource {
  Future<AttendanceDto> getToday();
  Future<AttendanceContext> getContext();
  Future<AttendanceToday> getTodayState() async => AttendanceToday(
    record: (await getToday()).toEntity(),
    context: await getContext(),
  );
  Future<AttendanceHistoryPage> getHistory({
    required String month,
    required int page,
    required int limit,
  }) => throw UnsupportedError('Attendance history is not implemented.');
  Future<AttendanceDto> clockIn(AttendanceCommand command);
  Future<AttendanceDto> clockOut(AttendanceCommand command);
}

class DioAttendanceRemoteDataSource implements AttendanceRemoteDataSource {
  const DioAttendanceRemoteDataSource(this._dio, this._context);

  final Dio _dio;
  final RequestContext? Function() _context;

  @override
  Future<AttendanceToday> getTodayState() async {
    final context = _requireContext();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/me/today',
      );
      final data = ApiEnvelope.fromJson(
        response.data ?? const {},
      ).requireObjectData();
      final nestedContext = data['context'];
      final policy = AttendanceContextDto.fromJson(
        nestedContext is Map<String, dynamic> ? nestedContext : data,
        employeeId: context.employeeId!,
        companyId: context.activeCompanyId!,
      ).value;
      final today = _todayAttendance(data);
      final record = today == null
          ? AttendanceDto(
              id: '',
              employeeId: context.employeeId!,
              checkedInAt: null,
              status: 'notStarted',
              latitude: 0,
              longitude: 0,
            ).toEntity()
          : AttendanceDto.fromJson(today).toEntity();
      return AttendanceToday(record: record, context: policy);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<AttendanceHistoryPage> getHistory({
    required String month,
    required int page,
    required int limit,
  }) async {
    _requireContext();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/me',
        queryParameters: {'month': month, 'page': page, 'limit': limit},
      );
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success) throw FormatException(envelope.message);
      final raw = envelope.data;
      final items = raw is List
          ? raw
          : raw is Map<String, dynamic>
          ? (raw['items'] ?? raw['records'] ?? raw['attendances']) as List? ??
                const []
          : const [];
      final meta =
          envelope.meta ??
          (raw is Map<String, dynamic>
              ? raw['meta'] as Map<String, dynamic>?
              : null) ??
          const {};
      return AttendanceHistoryPage(
        items: items
            .whereType<Map<String, dynamic>>()
            .map(AttendanceDto.fromJson)
            .map((item) => item.toEntity())
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
  Future<AttendanceContext> getContext() async {
    final context = _requireContext();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/me/today',
      );
      final data = ApiEnvelope.fromJson(
        response.data ?? const {},
      ).requireObjectData();
      final nested = data['context'];
      return AttendanceContextDto.fromJson(
        nested is Map<String, dynamic> ? nested : data,
        employeeId: context.employeeId!,
        companyId: context.activeCompanyId!,
      ).value;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<AttendanceDto> getToday() async {
    final context = _requireContext();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/me/today',
      );
      final data = ApiEnvelope.fromJson(
        response.data ?? const {},
      ).requireObjectData();
      final today = _todayAttendance(data);
      if (today != null) return AttendanceDto.fromJson(today);
      return AttendanceDto(
        id: '',
        employeeId: context.employeeId!,
        checkedInAt: null,
        status: 'notStarted',
        latitude: 0,
        longitude: 0,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<AttendanceDto> clockIn(AttendanceCommand command) async {
    _requireContext();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/attendance/me/check-in',
        data: {
          'method': command.method.apiValue,
          'checkInLatitude': command.latitude,
          'checkInLongitude': command.longitude,
          'deviceGps': _deviceGps(command),
          if (command.selfie case final selfie?)
            'faceRecognition': {
              'selfieImage':
                  'data:${selfie.mimeType};base64,${base64Encode(selfie.bytes)}',
            },
          if (command.selfie != null)
            'liveness': {'isLiveCapture': true, 'clientSource': 'camera'},
        },
        options: Options(headers: {'Idempotency-Key': command.idempotencyKey}),
      );
      return AttendanceDto.fromJson(
        _attendanceObject(
          ApiEnvelope.fromJson(response.data ?? const {}).requireObjectData(),
        ),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<AttendanceDto> clockOut(AttendanceCommand command) async {
    _requireContext();
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/attendance/me/check-out',
        data: {
          'method': command.method.apiValue,
          'checkOutLatitude': command.latitude,
          'checkOutLongitude': command.longitude,
          'deviceGps': _deviceGps(command),
        },
        options: Options(headers: {'Idempotency-Key': command.idempotencyKey}),
      );
      return AttendanceDto.fromJson(
        _attendanceObject(
          ApiEnvelope.fromJson(response.data ?? const {}).requireObjectData(),
        ),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  RequestContext _requireContext() {
    final value = _context();
    if (value?.employeeId == null || value?.activeCompanyId == null) {
      throw const ApiException('Session employee/company belum tersedia.');
    }
    return value!;
  }

  Map<String, dynamic>? _todayAttendance(Map<String, dynamic> data) {
    for (final key in const ['attendance', 'record', 'today']) {
      final value = data[key];
      if (value is Map<String, dynamic>) return value;
    }
    if (data.containsKey('id') ||
        data.containsKey('checkIn') ||
        data.containsKey('checkedInAt')) {
      return data;
    }
    return null;
  }

  Map<String, dynamic> _attendanceObject(Map<String, dynamic> data) {
    final nested = data['attendance'];
    return nested is Map<String, dynamic> ? nested : data;
  }

  Map<String, dynamic> _deviceGps(AttendanceCommand command) => {
    'isMockLocation': command.isMocked,
    'accuracyMeters': command.accuracyMeters,
  };

  int _integer(Object? value, int fallback) => switch (value) {
    int number => number,
    num number => number.round(),
    String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };
}
