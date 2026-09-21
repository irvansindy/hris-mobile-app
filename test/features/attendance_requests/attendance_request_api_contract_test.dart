import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/attendance_requests/data/datasources/attendance_request_remote_datasource.dart';
import 'package:hrm_app/features/attendance_requests/domain/entities/attendance_request.dart';

void main() {
  const context = RequestContext(
    userId: 'user-1',
    employeeId: 'employee-1',
    activeCompanyId: 'company-1',
    companyScope: ['company-1'],
    permissions: ['attendance:read', 'attendance:create'],
  );

  test('correction list and detail use employee-scoped routes', () async {
    final adapter = _AttendanceRequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioAttendanceRequestRemoteDataSource(dio, () => context);

    final list = await remote.getCorrections(status: 'PENDING');
    final detail = await remote.getCorrection('correction-1');

    expect(list.single.id, 'correction-1');
    expect(detail.id, 'correction-1');
    expect(adapter.requests[0].path, '/attendance-corrections/my');
    expect(adapter.requests[0].queryParameters, {'status': 'PENDING'});
    expect(adapter.requests[0].queryParameters, isNot(contains('employeeId')));
    expect(adapter.requests[1].path, '/attendance-corrections/my/correction-1');
  });

  test(
    'correction create sends no client identity and has retry key',
    () async {
      final adapter = _AttendanceRequestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioAttendanceRequestRemoteDataSource(dio, () => context);

      final value = await remote.createCorrection(
        CreateAttendanceCorrection(
          attendanceId: 'attendance-1',
          date: DateTime(2026, 9, 18),
          requestedCheckIn: DateTime(2026, 9, 18, 8, 15),
          requestedCheckOut: DateTime(2026, 9, 18, 17, 10),
          reason: '  Perangkat tidak dapat digunakan  ',
          idempotencyKey: 'correction-attempt-1',
        ),
      );

      final request = adapter.requests.single;
      expect(request.path, '/attendance-corrections');
      expect(request.headers['Idempotency-Key'], 'correction-attempt-1');
      expect(request.data, isNot(contains('employeeId')));
      expect(request.data, isNot(contains('companyId')));
      expect(request.data['reason'], 'Perangkat tidak dapat digunakan');
      expect(value.status, AttendanceRequestStatus.pending);
    },
  );

  test('correction validation runs before any request', () async {
    final adapter = _AttendanceRequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioAttendanceRequestRemoteDataSource(dio, () => context);

    await expectLater(
      remote.createCorrection(
        CreateAttendanceCorrection(
          date: DateTime(2026, 9, 18),
          reason: 'Alasan valid',
          idempotencyKey: 'correction-attempt-1',
        ),
      ),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      remote.createCorrection(
        CreateAttendanceCorrection(
          date: DateTime(2026, 9, 18),
          requestedCheckIn: DateTime(2026, 9, 19, 8),
          reason: 'Alasan valid',
          idempotencyKey: 'correction-attempt-1',
        ),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('overtime list identity comes only from active session', () async {
    final adapter = _AttendanceRequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioAttendanceRequestRemoteDataSource(dio, () => context);

    final values = await remote.getOvertimes(status: 'PENDING');

    final request = adapter.requests.single;
    expect(request.path, '/attendance/overtime');
    expect(request.queryParameters, {
      'companyId': 'company-1',
      'employeeId': 'employee-1',
      'status': 'PENDING',
    });
    expect(values.single.employeeId, 'employee-1');
  });

  test('cross-day overtime derives duration and omits identity', () async {
    final adapter = _AttendanceRequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioAttendanceRequestRemoteDataSource(dio, () => context);

    await remote.createOvertime(
      CreateOvertimeRequest(
        startTime: DateTime.utc(2026, 9, 18, 23),
        endTime: DateTime.utc(2026, 9, 19, 1, 30),
        reason: '  Penutupan bulanan  ',
        idempotencyKey: 'overtime-attempt-1',
      ),
    );

    final request = adapter.requests.single;
    expect(request.path, '/attendance/overtime');
    expect(request.headers['Idempotency-Key'], 'overtime-attempt-1');
    expect(request.data['durationHours'], 2.5);
    expect(request.data['reason'], 'Penutupan bulanan');
    expect(request.data, isNot(contains('employeeId')));
    expect(request.data, isNot(contains('companyId')));
    expect(request.data, isNot(contains('multiplier')));
  });

  test('overtime permission failure is local and non-mutating', () async {
    final adapter = _AttendanceRequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioAttendanceRequestRemoteDataSource(
      dio,
      () => const RequestContext(
        userId: 'user-1',
        employeeId: 'employee-1',
        activeCompanyId: 'company-1',
        companyScope: ['company-1'],
      ),
    );

    await expectLater(
      remote.getOvertimes(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
    await expectLater(
      remote.createOvertime(
        CreateOvertimeRequest(
          startTime: DateTime.utc(2026, 9, 18, 18),
          endTime: DateTime.utc(2026, 9, 18, 20),
          reason: 'Penutupan bulanan',
          idempotencyKey: 'overtime-attempt-1',
        ),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test(
    'pay estimate accepts only server amount for the selected request',
    () async {
      final adapter = _AttendanceRequestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioAttendanceRequestRemoteDataSource(dio, () => context);
      final request = (await remote.getOvertimes()).single;

      final estimate = await remote.getOvertimePay(request);

      expect(adapter.requests.last.path, '/attendance/overtime/overtime-1/pay');
      expect(estimate.amount, 250000);
      expect(estimate.breakdown.single.subtotal, 250000);
    },
  );

  test('foreign and malformed response data is rejected', () async {
    for (final defect in ['foreign-company', 'foreign-employee', 'bad-list']) {
      final adapter = _AttendanceRequestAdapter(defect: defect);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioAttendanceRequestRemoteDataSource(dio, () => context);

      await expectLater(remote.getCorrections(), throwsFormatException);
    }
  });
}

class _AttendanceRequestAdapter implements HttpClientAdapter {
  _AttendanceRequestAdapter({this.defect});

  final String? defect;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Object? data;
    if (options.path == '/attendance-corrections/my') {
      data = defect == 'bad-list' ? {'items': []} : [_correction()];
    } else if (options.path == '/attendance-corrections/my/correction-1' ||
        options.path == '/attendance-corrections') {
      data = _correction();
    } else if (options.path == '/attendance/overtime') {
      data = options.method == 'GET' ? [_overtime()] : _overtime();
    } else if (options.path == '/attendance/overtime/overtime-1/pay') {
      data = {
        'overtimeId': 'overtime-1',
        'durationHours': 2.5,
        'dayType': 'WORKDAY',
        'hourlyRate': 100000,
        'weightedHours': 2.5,
        'amount': 250000,
        'breakdown': [
          {'hours': 2.5, 'rate': 1, 'subtotal': 250000},
        ],
      };
    }
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, Object?> _correction() => {
    'id': 'correction-1',
    'employeeId': defect == 'foreign-employee' ? 'employee-2' : 'employee-1',
    'companyId': defect == 'foreign-company' ? 'company-2' : 'company-1',
    'attendanceId': 'attendance-1',
    'date': '2026-09-18T00:00:00.000Z',
    'requestedCheckIn': '2026-09-18T01:15:00.000Z',
    'requestedCheckOut': '2026-09-18T10:10:00.000Z',
    'reason': 'Perangkat tidak dapat digunakan',
    'status': 'PENDING',
    'createdAt': '2026-09-18T11:00:00.000Z',
    'updatedAt': '2026-09-18T11:00:00.000Z',
  };

  Map<String, Object?> _overtime() => {
    'id': 'overtime-1',
    'employeeId': 'employee-1',
    'companyId': 'company-1',
    'date': '2026-09-18T00:00:00.000Z',
    'startTime': '2026-09-18T23:00:00.000Z',
    'endTime': '2026-09-19T01:30:00.000Z',
    'durationHours': '2.50',
    'reason': 'Penutupan bulanan',
    'status': 'PENDING',
    'createdAt': '2026-09-18T12:00:00.000Z',
    'updatedAt': '2026-09-18T12:00:00.000Z',
  };

  @override
  void close({bool force = false}) {}
}
