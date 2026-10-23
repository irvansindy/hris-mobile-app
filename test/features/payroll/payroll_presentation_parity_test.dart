import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/demo/demo_payroll_repository.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/domain/payroll_repository.dart';
import 'package:hrm_app/features/payroll/payroll_dependencies.dart';
import 'package:hrm_app/features/payroll/presentation/screens/payroll_screen.dart';

void main() {
  const keys = ['payroll-header', 'payroll-security-note', 'payroll-list'];

  testWidgets('demo and production use the same payroll composition', (
    tester,
  ) async {
    final demo = await _positions(tester, DemoPayrollRepository(), keys);
    final production = await _positions(tester, _ProductionPayroll(), keys);

    expect(demo.keys, orderedEquals(keys));
    expect(production.keys, orderedEquals(keys));
    expect(_increasing(demo.values), isTrue);
    expect(_increasing(production.values), isTrue);
  });
}

Future<Map<String, double>> _positions(
  WidgetTester tester,
  PayrollRepository repository,
  List<String> keys,
) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        requestContextProvider.overrideWith(
          (_) => const RequestContext(
            userId: 'user-1',
            employeeId: 'employee-1',
            activeCompanyId: 'company-1',
            companyScope: ['company-1'],
            permissions: ['payroll:read'],
          ),
        ),
        payrollRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: PayrollScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return {
    for (final key in keys)
      key: tester.getTopLeft(find.byKey(ValueKey(key))).dy,
  };
}

bool _increasing(Iterable<double> values) {
  final items = values.toList(growable: false);
  for (var index = 1; index < items.length; index++) {
    if (items[index] <= items[index - 1]) return false;
  }
  return true;
}

class _ProductionPayroll implements PayrollRepository {
  @override
  Future<List<PayslipSummary>> getPayslips() async => [
    PayslipSummary(
      id: 'payslip-1',
      status: 'APPROVED',
      createdAt: DateTime(2026, 10, 1),
      locked: true,
      periodName: 'September 2026',
    ),
  ];
  @override
  Future<PayslipPinStatus> getPinStatus() async =>
      const PayslipPinStatus(pinSet: true);
  @override
  Future<void> setPin({required String currentPassword, required String pin}) =>
      throw UnimplementedError();
  @override
  Future<PayslipUnlockGrant> unlock(String pin) => throw UnimplementedError();
  @override
  Future<PayslipDetail> getDetail({
    required String id,
    required String unlockToken,
  }) => throw UnimplementedError();
  @override
  Future<PayslipPdf> getPdf({
    required String id,
    required String unlockToken,
  }) async => PayslipPdf(bytes: Uint8List(0), sourceName: 'unused.pdf');
}
