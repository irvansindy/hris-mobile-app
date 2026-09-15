import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';

void main() {
  test(
    'dashboard leaves attendance loading to the shared attendance state',
    () async {
      final adapter = _DashboardAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioDashboardRemoteDataSource(dio);
      const context = RequestContext(
        userId: 'user-1',
        employeeId: 'employee-1',
        activeCompanyId: 'company-1',
        companyScope: ['company-1'],
        displayName: 'Employee One',
      );

      final result = await remote.fetch(
        context,
        const DashboardSnapshot(
          employee: DashboardEmployee(
            name: 'Employee',
            initials: 'E',
            avatarColorIndex: 0,
          ),
          leaveBalances: [],
          announcements: [],
        ),
      );

      expect(
        adapter.requests.map((request) => request.path),
        isNot(contains('/attendance/me/today')),
      );
      expect(
        adapter.requests.map((request) => request.path),
        isNot(contains('/attendance')),
      );
      expect(result.attendanceAvailable, isFalse);
      expect(result.monthlySummaryAvailable, isFalse);
    },
  );
}

class _DashboardAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data = switch (options.path) {
      '/leave/balances/employee' => <Object>[],
      '/notifications' => <Object>[],
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
