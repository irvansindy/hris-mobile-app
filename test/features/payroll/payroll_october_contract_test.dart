import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/payroll/data/dio_payroll_repository.dart';
import 'package:hrm_app/features/payroll/payroll_dependencies.dart';
import 'package:hrm_app/features/payroll/presentation/screens/payroll_screen.dart';

const _context = RequestContext(
  userId: 'user-1',
  employeeId: 'employee-1',
  activeCompanyId: 'company-1',
  companyScope: ['company-1'],
  permissions: ['payroll:read'],
);

void main() {
  testWidgets(
    'same-period payslips show run labels and open the selected payslip ID',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('hris_mobile/sensitive_screen'),
            (_) async => null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('hris_mobile/sensitive_screen'),
              null,
            ),
      );
      final adapter = _Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requestContextProvider.overrideWith((_) => _context),
            payrollRepositoryProvider.overrideWithValue(
              DioPayrollRepository(dio, () => _context),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PayrollScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Oktober 2026'), findsNWidgets(2));
      expect(find.text('Payroll Reguler · RUN-001'), findsOneWidget);
      expect(find.text('Payroll Tambahan · RUN-002'), findsOneWidget);
      expect(find.textContaining('Rp'), findsNothing);
      await tester.tap(find.text('Payroll Tambahan · RUN-002'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('payslip-pin')),
        '135791',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Buka slip gaji'));
      await tester.pumpAndSettle();
      expect(adapter.paths, contains('/payroll/payslips/my/payslip-2'));
      expect(adapter.paths, isNot(contains('/payroll/payslips/my/payslip-1')));
      expect(find.text('Rincian slip gaji'), findsOneWidget);
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final Object? data;
    if (options.path == '/payroll/payslips') {
      data = [
        for (final index in [1, 2])
          {
            'id': 'payslip-$index',
            'status': 'FUTURE_STATUS',
            'locked': true,
            'createdAt': '2026-10-18T00:00:00Z',
            'newField': 'ignored',
            'payrollRun': {
              'name': index == 1 ? 'Payroll Reguler' : 'Payroll Tambahan',
              'runNumber': 'RUN-00$index',
              'period': {'code': '2026-10', 'name': 'Oktober 2026'},
            },
          },
      ];
    } else if (options.path.endsWith('/pin/status')) {
      data = {'pinSet': true};
    } else if (options.path.endsWith('/unlock')) {
      data = {
        'unlockToken': 'fixture-token',
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      };
    } else if (options.path == '/payroll/payslips/my/payslip-2') {
      data = {
        'id': 'payslip-2',
        'status': 'APPROVED',
        'baseSalary': 1,
        'totalEarnings': 1,
        'totalDeductions': 0,
        'netPay': 1,
        'components': [],
      };
    } else {
      throw StateError('Unexpected endpoint: ${options.path}');
    }
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
