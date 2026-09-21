import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/approvals/data/datasources/approval_remote_datasource.dart';
import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';

void main() {
  const approverContext = RequestContext(
    userId: 'user-1',
    employeeId: 'employee-1',
    activeCompanyId: 'company-1',
    companyScope: ['company-1'],
    permissions: ['workflow:approve'],
  );

  test(
    'approval queue uses approver endpoint and strict tenant context',
    () async {
      final adapter = _ApprovalAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioApprovalRemoteDataSource(dio, () => approverContext);

      final page = await remote.getQueue(page: 2, limit: 20);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/workflow-engine/instances/my-approvals');
      expect(request.queryParameters, {'page': 2, 'limit': 20});
      expect(request.queryParameters, isNot(contains('companyId')));
      expect(page.page, 2);
      expect(page.totalPages, 3);
      expect(page.total, 41);
      expect(page.items.single.instanceId, 'instance-1');
      expect(page.items.single.requesterLabel, 'Karyawan Uji');
    },
  );

  test(
    'queue is blocked locally without workflow approve permission',
    () async {
      final adapter = _ApprovalAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioApprovalRemoteDataSource(
        dio,
        () => const RequestContext(
          userId: 'employee-user',
          employeeId: 'employee-2',
          activeCompanyId: 'company-1',
          companyScope: ['company-1'],
        ),
      );

      await expectLater(
        remote.getQueue(page: 1, limit: 20),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having((error) => error.code, 'code', 'FORBIDDEN'),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test('single action sends server enum and requires reject reason', () async {
    final adapter = _ApprovalAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioApprovalRemoteDataSource(dio, () => approverContext);

    await remote.applyAction(
      instanceId: 'instance-1',
      action: WorkflowApprovalAction.reject,
      comment: '  Dokumen belum lengkap  ',
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/workflow-engine/instances/instance-1/actions');
    expect(request.data, {
      'action': 'REJECT',
      'comment': 'Dokumen belum lengkap',
    });
    await expectLater(
      remote.applyAction(
        instanceId: 'instance-1',
        action: WorkflowApprovalAction.reject,
      ),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      remote.applyAction(
        instanceId: '../foreign',
        action: WorkflowApprovalAction.approve,
      ),
      throwsFormatException,
    );
  });

  test('bulk action preserves partial failure per instance', () async {
    final adapter = _ApprovalAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioApprovalRemoteDataSource(dio, () => approverContext);

    final result = await remote.applyBulkAction(
      instanceIds: const ['instance-1', 'instance-2'],
      action: WorkflowApprovalAction.approve,
      comment: 'Disetujui bersama',
    );

    expect(
      adapter.requests.single.path,
      '/workflow-engine/instances/bulk-approve',
    );
    expect(adapter.requests.single.data, {
      'instanceIds': ['instance-1', 'instance-2'],
      'action': 'APPROVE',
      'comment': 'Disetujui bersama',
    });
    expect(result.total, 2);
    expect(result.successful, 1);
    expect(result.failed, 1);
    expect(result.results.last.error, 'Workflow changed');
  });

  test(
    'bulk action rejects duplicate request and inconsistent result',
    () async {
      final duplicateDio = Dio()..httpClientAdapter = _ApprovalAdapter();
      addTearDown(duplicateDio.close);
      final remote = DioApprovalRemoteDataSource(
        duplicateDio,
        () => approverContext,
      );
      await expectLater(
        remote.applyBulkAction(
          instanceIds: const ['instance-1', 'instance-1'],
          action: WorkflowApprovalAction.approve,
        ),
        throwsA(isA<ApiException>()),
      );

      final malformedDio = Dio()
        ..httpClientAdapter = _ApprovalAdapter(defect: 'foreign-bulk-id');
      addTearDown(malformedDio.close);
      await expectLater(
        DioApprovalRemoteDataSource(
          malformedDio,
          () => approverContext,
        ).applyBulkAction(
          instanceIds: const ['instance-1', 'instance-2'],
          action: WorkflowApprovalAction.approve,
        ),
        throwsFormatException,
      );
    },
  );

  test('delegation list is scoped to the active user and company', () async {
    final adapter = _ApprovalAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioApprovalRemoteDataSource(dio, () => approverContext);

    final values = await remote.getDelegations();

    expect(adapter.requests.single.path, '/workflow-engine/delegations');
    expect(adapter.requests.single.queryParameters, {'mine': true});
    expect(values.single.delegateId, 'user-2');
    expect(values.single.delegateLabel, 'delegate@example.test');
  });

  test(
    'create delegation sends UTC dates and rejects self delegation',
    () async {
      final adapter = _ApprovalAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioApprovalRemoteDataSource(dio, () => approverContext);

      await remote.createDelegation(
        CreateApprovalDelegation(
          delegateId: 'user-2',
          startDate: DateTime.parse('2026-09-20T08:00:00+07:00'),
          endDate: DateTime.parse('2026-09-21T08:00:00+07:00'),
          reason: '  Dinas luar  ',
        ),
      );

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, {
        'delegateId': 'user-2',
        'startDate': '2026-09-20T01:00:00.000Z',
        'endDate': '2026-09-21T01:00:00.000Z',
        'reason': 'Dinas luar',
      });
      await expectLater(
        remote.createDelegation(
          CreateApprovalDelegation(
            delegateId: 'user-1',
            startDate: DateTime(2026, 9, 20),
            endDate: DateTime(2026, 9, 21),
          ),
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'revoke delegation validates returned identity and inactive state',
    () async {
      final adapter = _ApprovalAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioApprovalRemoteDataSource(dio, () => approverContext);

      final value = await remote.revokeDelegation('delegation-1');

      expect(
        adapter.requests.single.path,
        '/workflow-engine/delegations/delegation-1/revoke',
      );
      expect(value.isActive, isFalse);

      final foreignDio = Dio()
        ..httpClientAdapter = _ApprovalAdapter(defect: 'foreign-company');
      addTearDown(foreignDio.close);
      await expectLater(
        DioApprovalRemoteDataSource(
          foreignDio,
          () => approverContext,
        ).getDelegations(),
        throwsFormatException,
      );
    },
  );
}

class _ApprovalAdapter implements HttpClientAdapter {
  _ApprovalAdapter({this.defect});

  final String? defect;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final Object? data = switch ((options.method, options.path)) {
      ('GET', '/workflow-engine/instances/my-approvals') => [_approval()],
      ('POST', '/workflow-engine/instances/bulk-approve') => {
        'total': 2,
        'successful': 1,
        'failed': 1,
        'results': [
          {'instanceId': 'instance-1', 'success': true},
          {
            'instanceId': defect == 'foreign-bulk-id'
                ? 'instance-foreign'
                : 'instance-2',
            'success': false,
            'error': 'Workflow changed',
          },
        ],
      },
      ('GET', '/workflow-engine/delegations') => [_delegation()],
      ('POST', '/workflow-engine/delegations') => _delegation(),
      ('PATCH', '/workflow-engine/delegations/delegation-1/revoke') =>
        _delegation(active: false),
      _ => null,
    };
    final body = <String, Object?>{'success': true, 'data': data};
    if (options.path == '/workflow-engine/instances/my-approvals') {
      body['meta'] = {'page': 2, 'limit': 20, 'total': 41, 'totalPages': 3};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, Object?> _approval() => {
    'id': 'step-1',
    'instanceId': 'instance-1',
    'name': 'Persetujuan atasan',
    'level': 1,
    'status': 'PENDING',
    'isCurrent': true,
    'createdAt': '2026-09-18T08:00:00.000Z',
    'instance': {
      'id': 'instance-1',
      'companyId': defect == 'foreign-company' ? 'company-2' : 'company-1',
      'approvalType': 'LEAVE',
      'referenceType': 'LEAVE_REQUEST',
      'referenceId': 'leave-1',
      'requesterId': 'employee-user',
      'payload': {'employeeName': 'Karyawan Uji'},
      'status': 'PENDING',
      'currentLevel': 1,
      'createdAt': '2026-09-18T07:30:00.000Z',
      'template': {
        'id': 'template-1',
        'name': 'Persetujuan cuti',
        'approvalType': 'LEAVE',
      },
    },
  };

  Map<String, Object?> _delegation({bool active = true}) => {
    'id': 'delegation-1',
    'companyId': defect == 'foreign-company' ? 'company-2' : 'company-1',
    'delegatorId': 'user-1',
    'delegateId': 'user-2',
    'startDate': '2026-09-20T01:00:00.000Z',
    'endDate': '2026-09-21T01:00:00.000Z',
    'reason': 'Dinas luar',
    'isActive': active,
    'delegate': {'id': 'user-2', 'email': 'delegate@example.test'},
  };

  @override
  void close({bool force = false}) {}
}
