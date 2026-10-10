import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/profile/data/repositories/employee_support_repository_impl.dart';

void main() {
  const context = RequestContext(
    userId: 'user-1',
    employeeId: 'employee-1',
    activeCompanyId: 'company-1',
    companyScope: ['company-1'],
    permissions: ['employee:*'],
  );

  test('loads reporting line and private attachment metadata', () async {
    final adapter = _SupportAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);

    final snapshot = await DioEmployeeSupportRepository(
      dio,
      () => context,
    ).load();

    expect(adapter.requests.map((request) => request.path), [
      '/employees/me/reporting-line',
      '/employees/employee-1/attachments',
    ]);
    expect(snapshot.reportingLine.primarySupervisor?.name, 'Atasan Satu');
    expect(snapshot.attachments.single.name, 'kontrak.pdf');
    expect(snapshot.attachments.single.id, 'attachment-1');
  });

  test(
    'without employee read only calls self-service reporting line',
    () async {
      final adapter = _SupportAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);

      final snapshot = await DioEmployeeSupportRepository(
        dio,
        () => const RequestContext(
          userId: 'user-1',
          employeeId: 'employee-1',
          activeCompanyId: 'company-1',
          companyScope: ['company-1'],
        ),
      ).load();

      expect(adapter.requests.single.path, '/employees/me/reporting-line');
      expect(snapshot.canReadAttachments, isFalse);
      expect(snapshot.attachments, isEmpty);
    },
  );

  test('rejects attachment metadata from another company', () async {
    final dio = Dio()
      ..httpClientAdapter = _SupportAdapter(foreignCompany: true);
    addTearDown(dio.close);

    await expectLater(
      DioEmployeeSupportRepository(dio, () => context).load(),
      throwsFormatException,
    );
  });
}

class _SupportAdapter implements HttpClientAdapter {
  _SupportAdapter({this.foreignCompany = false});

  final bool foreignCompany;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data = switch (options.path) {
      '/employees/me/reporting-line' => {
        'source': 'POSITION_REPORTS_TO',
        'primarySupervisor': {
          'id': 'employee-2',
          'employeeNumber': 'EMP002',
          'fullName': 'Atasan Satu',
          'position': {'name': 'Manager'},
        },
        'alternateSupervisors': <Object?>[],
      },
      '/employees/employee-1/attachments' => [
        {
          'id': 'attachment-1',
          'employeeId': 'employee-1',
          'companyId': foreignCompany ? 'company-2' : 'company-1',
          'originalName': 'kontrak.pdf',
          'mimeType': 'application/pdf',
          'size': 2048,
          'documentType': 'CONTRACT',
          'filePath': 'private/secret.pdf',
          'url': 'https://invalid.example/uploads/private/secret.pdf',
        },
      ],
      _ => null,
    };
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
