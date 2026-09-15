import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/services/selfie_gateway.dart';
import 'package:hrm_app/features/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';

void main() {
  const context = RequestContext(
    userId: '00000000-0000-4000-8000-000000000001',
    employeeId: '00000000-0000-4000-8000-000000000002',
    activeCompanyId: '00000000-0000-4000-8000-000000000003',
    companyScope: ['00000000-0000-4000-8000-000000000003'],
  );

  test(
    'loads self-service attendance policy without client identity parameters',
    () async {
      final adapter = _AttendanceAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioAttendanceRemoteDataSource(dio, () => context);

      final result = await remote.getContext();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/attendance/me/today');
      expect(request.queryParameters, isEmpty);
      expect(result.branchName, 'Kantor Pusat');
      expect(result.requiresLocation, isTrue);
      expect(result.requiresSelfie, isTrue);
      expect(result.supportsFaceRecognition, isTrue);
      expect(result.gpsRadiusMeters, 150);
    },
  );

  test('loads today record and policy from one server response', () async {
    final adapter = _AttendanceAdapter(activeRecord: true);
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioAttendanceRemoteDataSource(dio, () => context);

    final result = await remote.getTodayState();

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/attendance/me/today');
    expect(result.record.id, 'attendance-1');
    expect(result.context.branchName, 'Kantor Pusat');
  });

  test('history sends month and maps pagination metadata', () async {
    final adapter = _AttendanceAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioAttendanceRemoteDataSource(dio, () => context);

    final result = await remote.getHistory(
      month: '2026-09',
      page: 2,
      limit: 20,
    );

    final request = adapter.requests.single;
    expect(request.path, '/attendance/me');
    expect(request.queryParameters, {
      'month': '2026-09',
      'page': 2,
      'limit': 20,
    });
    expect(result.page, 2);
    expect(result.totalPages, 3);
    expect(result.total, 41);
    expect(result.items.single.status, AttendanceStatus.late);
  });

  test(
    'clock in sends measured GPS and captured selfie to the server',
    () async {
      final adapter = _AttendanceAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioAttendanceRemoteDataSource(dio, () => context);
      final capturedAt = DateTime.parse('2026-09-11T08:15:30+07:00');

      await remote.clockIn(
        AttendanceCommand(
          latitude: -6.2088,
          longitude: 106.8456,
          accuracyMeters: 7.5,
          capturedAt: capturedAt,
          isMocked: false,
          method: AttendanceCaptureMethod.faceRecognition,
          idempotencyKey: 'request-123',
          selfie: CapturedSelfie(
            bytes: Uint8List.fromList([1, 2, 3]),
            mimeType: 'image/jpeg',
            capturedAt: capturedAt.toUtc(),
          ),
        ),
      );

      final request = adapter.requests.single;
      final body = Map<String, dynamic>.from(request.data as Map);
      expect(request.method, 'POST');
      expect(request.path, '/attendance/me/check-in');
      expect(request.headers['Idempotency-Key'], 'request-123');
      expect(body, isNot(contains('employeeId')));
      expect(body, isNot(contains('companyId')));
      expect(body, isNot(contains('date')));
      expect(body, isNot(contains('checkIn')));
      expect(body['method'], 'FACE_RECOGNITION');
      expect(body, isNot(contains('source')));
      expect(body['checkInLatitude'], -6.2088);
      expect(body['checkInLongitude'], 106.8456);
      expect(body, isNot(contains('status')));
      expect(body['deviceGps'], {
        'isMockLocation': false,
        'accuracyMeters': 7.5,
      });
      expect(body['faceRecognition'], {
        'selfieImage': 'data:image/jpeg;base64,AQID',
      });
      expect(body['liveness'], {
        'isLiveCapture': true,
        'clientSource': 'camera',
      });
    },
  );

  test(
    'clock out uses the self endpoint and lets the server assign time',
    () async {
      final adapter = _AttendanceAdapter(activeRecord: true);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioAttendanceRemoteDataSource(dio, () => context);
      final capturedAt = DateTime.utc(2026, 9, 11, 10, 30);

      final result = await remote.clockOut(
        AttendanceCommand(
          latitude: -6.21,
          longitude: 106.84,
          accuracyMeters: 9,
          capturedAt: capturedAt,
          isMocked: false,
          method: AttendanceCaptureMethod.mobileGps,
          idempotencyKey: 'request-out',
        ),
      );

      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/attendance/me/check-out');
      expect(request.headers['Idempotency-Key'], 'request-out');
      expect(request.data, {
        'method': 'MOBILE_GPS',
        'checkOutLatitude': -6.21,
        'checkOutLongitude': 106.84,
        'deviceGps': {'isMockLocation': false, 'accuracyMeters': 9.0},
      });
      expect(result.checkedOutAt, isNotNull);
    },
  );
}

class _AttendanceAdapter implements HttpClientAdapter {
  _AttendanceAdapter({this.activeRecord = false});

  final bool activeRecord;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}T01:15:30.000Z';
    final body = switch ((options.method, options.path)) {
      ('GET', '/attendance/me/today') => {
        'success': true,
        'data': {
          if (activeRecord)
            'attendance': {
              'id': 'attendance-1',
              'employeeId': '00000000-0000-4000-8000-000000000002',
              'date': today,
              'checkIn': today,
              'status': 'PRESENT',
            },
          'branch': {'name': 'Kantor Pusat', 'code': 'HQ'},
          'schedule': {
            'isWorkingDay': true,
            'dayType': 'WORKING_DAY',
            'workStart': '08:00',
            'workEnd': '17:00',
          },
          'policy': {
            'requiresLocation': true,
            'requiresSelfie': true,
            'gpsRadiusMeters': 150,
            'allowHolidayAttendance': false,
            'allowWeekendAttendance': false,
          },
          'allowedMethods': ['FACE_RECOGNITION'],
          'warnings': <String>[],
        },
      },
      ('GET', '/attendance/me') => {
        'success': true,
        'data': [
          {
            'id': 'attendance-history-1',
            'employeeId': '00000000-0000-4000-8000-000000000002',
            'date': '2026-09-10',
            'checkIn': '2026-09-10T01:25:00.000Z',
            'checkOut': '2026-09-10T10:00:00.000Z',
            'status': 'LATE',
            'officeTimezone': 'Asia/Jakarta',
          },
        ],
        'meta': {'page': 2, 'limit': 20, 'total': 41, 'totalPages': 3},
      },
      ('POST', '/attendance/me/check-in') => {
        'success': true,
        'data': {
          'attendance': {
            'id': 'attendance-1',
            'employeeId': '00000000-0000-4000-8000-000000000002',
            'checkIn': today,
            'status': 'PRESENT',
          },
        },
      },
      ('PATCH', '/attendance/me/check-out') => {
        'success': true,
        'data': {
          'attendance': {
            'id': 'attendance-1',
            'employeeId': '00000000-0000-4000-8000-000000000002',
            'checkIn': today,
            'checkOut': '2026-09-11T10:30:00.000Z',
            'status': 'PRESENT',
          },
        },
      },
      _ => {'success': false, 'message': 'Unexpected request'},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
