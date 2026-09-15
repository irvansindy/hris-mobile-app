import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/self_service/data/datasources/request_remote_datasource.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/domain/entities/request_command.dart';

void main() {
  const context = RequestContext(
    userId: 'user-1',
    employeeId: 'employee-1',
    activeCompanyId: 'company-1',
    companyScope: ['company-1'],
  );

  test('leave list uses self context and pagination envelope', () async {
    final adapter = _RequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioRequestRemoteDataSource(dio, () => context);

    final page = await remote.getPage(
      kind: RequestKind.leave,
      page: 2,
      limit: 20,
    );

    final request = adapter.requests.single;
    expect(request.path, '/leave');
    expect(request.queryParameters, {'page': 2, 'limit': 20});
    expect(request.queryParameters, isNot(contains('employeeId')));
    expect(page.page, 2);
    expect(page.total, 21);
    expect(page.items.single.id, 'leave-1');
    expect(page.items.single.status, RequestStatus.pending);
  });

  test('leave submit sends documented fields and idempotency key', () async {
    final adapter = _RequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioRequestRemoteDataSource(dio, () => context);

    final result = await remote.submit(
      SubmitRequestCommand(
        kind: RequestKind.leave,
        type: 'annual-1',
        startDate: DateTime(2026, 9, 21),
        endDate: DateTime(2026, 9, 22),
        reason: 'Keperluan keluarga',
        attachment: 'data:image/jpeg;base64,AQID',
        idempotencyKey: 'leave-attempt-1',
      ),
    );

    final request = adapter.requests.single;
    expect(request.path, '/leave');
    expect(request.method, 'POST');
    expect(request.headers['Idempotency-Key'], 'leave-attempt-1');
    expect(request.data, {
      'leaveTypeId': 'annual-1',
      'startDate': '2026-09-21',
      'endDate': '2026-09-22',
      'reason': 'Keperluan keluarga',
      'attachment': 'data:image/jpeg;base64,AQID',
    });
    expect(result.id, 'leave-created');
  });

  test('permission submit uses employee self-service endpoint', () async {
    final adapter = _RequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioRequestRemoteDataSource(dio, () => context);

    await remote.submit(
      SubmitRequestCommand(
        kind: RequestKind.permission,
        type: 'WORK_FROM_HOME',
        startDate: DateTime(2026, 9, 23),
        endDate: DateTime(2026, 9, 23),
        reason: 'Menunggu teknisi',
      ),
    );

    final request = adapter.requests.single;
    expect(request.path, '/permission-requests');
    expect(request.data, {
      'type': 'WORK_FROM_HOME',
      'startDate': '2026-09-23',
      'endDate': '2026-09-23',
      'reason': 'Menunggu teknisi',
    });
  });

  test(
    'pending request cancellation uses the matching self-service route',
    () async {
      final adapter = _RequestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioRequestRemoteDataSource(dio, () => context);

      await remote.cancel(RequestKind.leave, 'leave-1');

      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.path, '/leave/leave-1/cancel');
    },
  );
}

class _RequestAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final request = {
      'id': options.path == '/permission-requests'
          ? 'permission-created'
          : options.method == 'POST'
          ? 'leave-created'
          : 'leave-1',
      'type': options.path == '/permission-requests'
          ? 'WORK_FROM_HOME'
          : 'Annual Leave',
      'startDate': '2026-09-21',
      'endDate': '2026-09-22',
      'reason': 'Keperluan keluarga',
      'status': options.path.endsWith('/cancel') ? 'CANCELLED' : 'PENDING',
      'createdAt': '2026-09-14T01:00:00.000Z',
    };
    final body = options.method == 'GET' && options.path == '/leave'
        ? {
            'success': true,
            'data': [request],
            'meta': {'page': 2, 'limit': 20, 'total': 21, 'totalPages': 2},
          }
        : {'success': true, 'data': request};
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
