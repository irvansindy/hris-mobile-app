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
    permissions: ['leave:read', 'leave:create'],
  );

  test('leave list uses self context without invented pagination', () async {
    final adapter = _RequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioRequestRemoteDataSource(dio, () => context);

    final page = await remote.getPage(
      kind: RequestKind.leave,
      page: 1,
      limit: 20,
    );

    final request = adapter.requests.single;
    expect(request.path, '/leave');
    expect(request.queryParameters, isEmpty);
    expect(request.queryParameters, isNot(contains('employeeId')));
    expect(page.page, 1);
    expect(page.totalPages, 1);
    expect(page.hasNextPage, isFalse);
    expect(page.total, 1);
    expect(page.items.single.id, 'leave-1');
    expect(page.items.single.status, RequestStatus.pending);
  });

  test('empty request list reports zero pages', () async {
    final adapter = _RequestAdapter(defect: 'empty-list');
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);

    final page = await DioRequestRemoteDataSource(
      dio,
      () => context,
    ).getPage(kind: RequestKind.leave, page: 1, limit: 20);

    expect(page.items, isEmpty);
    expect(page.total, 0);
    expect(page.totalPages, 0);
    expect(page.hasNextPage, isFalse);
  });

  test('leave types and detail use documented read endpoints', () async {
    final adapter = _RequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioRequestRemoteDataSource(dio, () => context);

    final types = await remote.getLeaveTypes();
    final detail = await remote.getLeaveDetail('leave-1');

    expect(types.single.id, 'annual-1');
    expect(types.single.requiresAttachment, isTrue);
    expect(detail.id, 'leave-1');
    expect(
      adapter.requests.map((request) => '${request.method} ${request.path}'),
      ['GET /leave/types', 'GET /leave/leave-1'],
    );
  });

  test('permission history uses the self endpoint', () async {
    final adapter = _RequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioRequestRemoteDataSource(dio, () => context);

    final page = await remote.getPage(
      kind: RequestKind.permission,
      page: 1,
      limit: 20,
    );

    expect(adapter.requests.single.path, '/permission-requests/my');
    expect(adapter.requests.single.queryParameters, isEmpty);
    expect(page.items.single.kind, RequestKind.permission);
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
        attachment: RequestAttachment(
          fileName: 'surat.jpg',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        idempotencyKey: 'leave-attempt-1',
      ),
    );

    expect(adapter.requests, hasLength(2));
    final upload = adapter.requests.first;
    expect(upload.path, '/leave/attachments');
    expect(upload.method, 'POST');
    expect(upload.data, isA<FormData>());
    final uploadData = upload.data as FormData;
    expect(uploadData.files.single.key, 'attachment');
    expect(uploadData.files.single.value.filename, 'surat.jpg');

    final request = adapter.requests.last;
    expect(request.path, '/leave');
    expect(request.method, 'POST');
    expect(request.headers['Idempotency-Key'], 'leave-attempt-1');
    expect(request.data, {
      'leaveTypeId': 'annual-1',
      'employeeId': 'employee-1',
      'companyId': 'company-1',
      'startDate': '2026-09-21T00:00:00.000Z',
      'endDate': '2026-09-22T00:00:00.000Z',
      'reason': 'Keperluan keluarga',
      'attachment':
          'https://api.example.test/private-files/leave-attachments/file-1',
    });
    expect(result.id, 'leave-created');
  });

  test('leave create permission is checked before attachment upload', () async {
    final adapter = _RequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioRequestRemoteDataSource(
      dio,
      () => const RequestContext(
        userId: 'user-1',
        employeeId: 'employee-1',
        activeCompanyId: 'company-1',
        companyScope: ['company-1'],
        permissions: ['leave:read'],
      ),
    );

    await expectLater(
      remote.submit(
        SubmitRequestCommand(
          kind: RequestKind.leave,
          type: 'annual-1',
          startDate: DateTime(2026, 9, 21),
          endDate: DateTime(2026, 9, 22),
          reason: 'Keperluan keluarga',
          attachment: RequestAttachment(
            fileName: 'surat.jpg',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ),
      ),
      throwsA(isA<Exception>()),
    );

    expect(adapter.requests, isEmpty);
  });

  test('leave wildcard permits read and create operations', () async {
    final adapter = _RequestAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioRequestRemoteDataSource(
      dio,
      () => const RequestContext(
        userId: 'user-1',
        employeeId: 'employee-1',
        activeCompanyId: 'company-1',
        companyScope: ['company-1'],
        permissions: ['leave:*'],
      ),
    );

    await remote.getLeaveTypes();
    await remote.submit(
      SubmitRequestCommand(
        kind: RequestKind.leave,
        type: 'annual-1',
        startDate: DateTime(2026, 9, 21),
        endDate: DateTime(2026, 9, 22),
        reason: 'Keperluan keluarga',
      ),
    );

    expect(adapter.requests.map((request) => request.path), [
      '/leave/types',
      '/leave',
    ]);
  });

  test(
    'permission submit is blocked while duration contract is ambiguous',
    () async {
      final adapter = _RequestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioRequestRemoteDataSource(dio, () => context);

      await expectLater(
        remote.submit(
          SubmitRequestCommand(
            kind: RequestKind.permission,
            type: 'WORK_FROM_HOME',
            startDate: DateTime(2026, 9, 23),
            endDate: DateTime(2026, 9, 23),
            reason: 'Menunggu teknisi',
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('durasi'),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );

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

  test(
    'permission cancellation uses the matching self-service route',
    () async {
      final adapter = _RequestAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioRequestRemoteDataSource(dio, () => context);

      await remote.cancel(RequestKind.permission, 'permission-1');

      expect(adapter.requests.single.method, 'PATCH');
      expect(
        adapter.requests.single.path,
        '/permission-requests/permission-1/cancel',
      );
    },
  );

  test('rejects malformed list, foreign ownership, and unsafe IDs', () async {
    final malformedDio = Dio()
      ..httpClientAdapter = _RequestAdapter(defect: 'malformed-list');
    addTearDown(malformedDio.close);
    await expectLater(
      DioRequestRemoteDataSource(
        malformedDio,
        () => context,
      ).getPage(kind: RequestKind.leave, page: 1, limit: 20),
      throwsFormatException,
    );

    final foreignDio = Dio()
      ..httpClientAdapter = _RequestAdapter(defect: 'foreign-owner');
    addTearDown(foreignDio.close);
    await expectLater(
      DioRequestRemoteDataSource(
        foreignDio,
        () => context,
      ).getLeaveDetail('leave-1'),
      throwsFormatException,
    );

    final safeIdDio = Dio();
    addTearDown(safeIdDio.close);
    final remote = DioRequestRemoteDataSource(safeIdDio, () => context);
    await expectLater(
      remote.getLeaveDetail('../another-employee'),
      throwsFormatException,
    );
  });
}

class _RequestAdapter implements HttpClientAdapter {
  _RequestAdapter({this.defect});

  final String? defect;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final isPermission = options.path.startsWith('/permission-requests');
    final request = {
      'id': options.method == 'POST'
          ? isPermission
                ? 'permission-created'
                : 'leave-created'
          : isPermission
          ? 'permission-1'
          : 'leave-1',
      'employeeId': defect == 'foreign-owner' ? 'employee-2' : 'employee-1',
      'companyId': 'company-1',
      'type': isPermission ? 'WORK_FROM_HOME' : 'Annual Leave',
      'startDate': '2026-09-21',
      'endDate': '2026-09-22',
      'reason': 'Keperluan keluarga',
      'status': options.path.endsWith('/cancel') ? 'CANCELLED' : 'PENDING',
      'createdAt': '2026-09-14T01:00:00.000Z',
    };
    final Object data = switch ((options.method, options.path)) {
      ('GET', '/leave/types') => [
        {
          'id': 'annual-1',
          'name': 'Cuti tahunan',
          'code': 'ANNUAL',
          'requiresAttachment': true,
          'maxDays': 12,
        },
      ],
      ('GET', '/leave') || ('GET', '/permission-requests/my') =>
        defect == 'malformed-list'
            ? {'items': 'invalid'}
            : defect == 'empty-list'
            ? <Object>[]
            : [request],
      ('POST', '/leave/attachments') => {
        'url':
            'https://api.example.test/private-files/leave-attachments/file-1',
      },
      _ => request,
    };
    final body = {'success': true, 'data': data};
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
