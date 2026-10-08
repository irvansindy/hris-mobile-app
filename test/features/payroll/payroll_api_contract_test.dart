import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/payroll/data/dio_payroll_repository.dart';

void main() {
  const context = RequestContext(
    userId: 'user-1',
    employeeId: 'employee-1',
    activeCompanyId: 'company-1',
    companyScope: ['company-1'],
    permissions: ['payroll:read'],
  );

  test('uses all employee endpoints and scopes unlock header', () async {
    final adapter = _PayrollAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final repository = DioPayrollRepository(dio, () => context);

    final summaries = await repository.getPayslips();
    final status = await repository.getPinStatus();
    await repository.setPin(currentPassword: 'secret', pin: '135791');
    final grant = await repository.unlock('135791');
    final detail = await repository.getDetail(
      id: 'payslip-1',
      unlockToken: grant.token,
    );
    final pdf = await repository.getPdf(
      id: 'payslip-1',
      unlockToken: grant.token,
    );

    expect(summaries.single.locked, isTrue);
    expect(summaries.single.periodName, 'September 2026');
    expect(status.pinSet, isTrue);
    expect(detail.baseSalary, 5000000);
    expect(detail.totalEarnings, 5500000.5);
    expect(detail.components.single.code, 'NEW_COMPONENT');
    expect(detail.components.single.name, 'Komponen Baru');
    expect(pdf.bytes.take(5), <int>[0x25, 0x50, 0x44, 0x46, 0x2D]);

    expect(
      adapter.requests.map((request) => '${request.method} ${request.path}'),
      [
        'GET /payroll/payslips',
        'GET /payroll/payslips/pin/status',
        'PUT /payroll/payslips/pin',
        'POST /payroll/payslips/my/unlock',
        'GET /payroll/payslips/my/payslip-1',
        'GET /payroll/payslips/my/payslip-1/pdf',
      ],
    );
    expect(adapter.requests[2].data, {
      'currentPassword': 'secret',
      'pin': '135791',
    });
    expect(adapter.requests[3].data, {'pin': '135791'});
    for (var index = 0; index < 4; index++) {
      expect(
        adapter.requests[index].headers,
        isNot(contains('X-Payslip-Unlock')),
      );
      expect(
        adapter.requests[index].headers,
        isNot(contains('X-Payroll-Unlock-Token')),
      );
    }
    for (var index = 4; index < 6; index++) {
      expect(adapter.requests[index].headers['X-Payslip-Unlock'], 'token-1');
      expect(
        adapter.requests[index].headers,
        isNot(contains('X-Payroll-Unlock-Token')),
      );
    }
  });

  test('rejects nominal fields in a locked summary', () async {
    final dio = Dio()
      ..httpClientAdapter = _PayrollAdapter(defect: 'summary-nominal');
    addTearDown(dio.close);

    await expectLater(
      DioPayrollRepository(dio, () => context).getPayslips(),
      throwsFormatException,
    );
  });

  test('rejects a response completed after session identity changes', () async {
    var current = context;
    final adapter = _PayrollAdapter(
      onFetch: () => current = const RequestContext(
        userId: 'user-2',
        employeeId: 'employee-2',
        activeCompanyId: 'company-2',
        companyScope: ['company-2'],
        permissions: ['payroll:read'],
      ),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);

    await expectLater(
      DioPayrollRepository(dio, () => current).getPayslips(),
      throwsA(isA<ApiException>()),
    );
  });

  for (final defect in [
    'pdf-empty',
    'pdf-magic',
    'pdf-content-type',
    'pdf-too-large',
  ]) {
    test('rejects unsafe PDF response: $defect', () async {
      final dio = Dio()..httpClientAdapter = _PayrollAdapter(defect: defect);
      addTearDown(dio.close);

      await expectLater(
        DioPayrollRepository(
          dio,
          () => context,
        ).getPdf(id: 'payslip-1', unlockToken: 'token-1'),
        throwsFormatException,
      );
    });
  }
}

class _PayrollAdapter implements HttpClientAdapter {
  _PayrollAdapter({this.defect, this.onFetch});

  final String? defect;
  final void Function()? onFetch;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    onFetch?.call();
    if (options.path.endsWith('/pdf')) return _pdf();
    final data = switch (options.path) {
      '/payroll/payslips' => [
        {
          'id': 'payslip-1',
          'status': 'APPROVED',
          'createdAt': '2026-10-01T00:00:00.000Z',
          'locked': true,
          if (defect == 'summary-nominal') 'netPay': 5000000,
          'payrollRun': {
            'period': {
              'name': 'September 2026',
              'startDate': '2026-09-01T00:00:00.000Z',
              'endDate': '2026-09-30T00:00:00.000Z',
              'payDate': '2026-10-01T00:00:00.000Z',
            },
          },
        },
      ],
      '/payroll/payslips/pin/status' => {'pinSet': true},
      '/payroll/payslips/pin' => null,
      '/payroll/payslips/my/unlock' => {
        'unlockToken': 'token-1',
        'expiresAt': '2026-10-08T10:15:00.000Z',
      },
      '/payroll/payslips/my/payslip-1' => {
        'id': 'payslip-1',
        'status': 'APPROVED',
        'baseSalary': '5000000.00',
        'totalEarnings': 5500000.5,
        'totalDeductions': '500000',
        'netPay': 5000000.5,
        'employee': {'fullName': 'Karyawan Satu', 'employeeNumber': 'EMP001'},
        'payrollRun': {
          'period': {
            'name': 'September 2026',
            'payDate': '2026-10-01T00:00:00.000Z',
          },
        },
        'components': [
          {
            'amount': '500000.50',
            'salaryComponent': {
              'code': 'NEW_COMPONENT',
              'name': 'Komponen Baru',
              'type': 'EARNING',
            },
          },
        ],
      },
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'Success', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  ResponseBody _pdf() {
    var bytes = Uint8List.fromList('%PDF-1.7\nfixture'.codeUnits);
    var contentType = 'application/pdf';
    if (defect == 'pdf-empty') bytes = Uint8List(0);
    if (defect == 'pdf-magic') bytes = Uint8List.fromList('not-pdf'.codeUnits);
    if (defect == 'pdf-content-type') contentType = 'text/plain';
    if (defect == 'pdf-too-large') bytes = Uint8List(5 * 1024 * 1024 + 1);
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: [contentType],
        'content-disposition': ['attachment; filename="payslip-1.pdf"'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
