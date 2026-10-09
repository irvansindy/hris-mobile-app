import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/domain/payroll_repository.dart';
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
  testWidgets('permission denial does not expose payroll controls', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: _Payroll(),
      context: const RequestContext(
        userId: 'user-1',
        employeeId: 'employee-1',
        activeCompanyId: 'company-1',
        companyScope: ['company-1'],
      ),
    );

    expect(find.text('Akses slip gaji terbatas'), findsOneWidget);
    expect(find.text('September 2026'), findsNothing);
  });

  testWidgets('unlocks a safe summary and opens detail without bottom nav', (
    tester,
  ) async {
    await _pump(tester, repository: _Payroll());

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.textContaining('Rp5.000.000'), findsNothing);
    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan PIN slip gaji'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('payslip-pin')), '135791');
    await tester.tap(find.widgetWithText(FilledButton, 'Buka slip gaji'));
    await tester.pumpAndSettle();

    expect(find.text('Rincian slip gaji'), findsOneWidget);
    expect(find.text('Komponen Baru'), findsOneWidget);
    expect(find.textContaining('Rp5.000.000'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('setup PIN requires matching six digits', (tester) async {
    final repository = _Payroll(pinSet: false);
    await _pump(tester, repository: repository);

    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Atur PIN slip gaji'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('payslip-current-password')),
      'secret',
    );
    await tester.enterText(
      find.byKey(const ValueKey('payslip-new-pin')),
      '123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('payslip-confirm-pin')),
      '456',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan PIN'));
    await tester.pump();

    expect(
      find.text('PIN harus sama dan terdiri dari 6 digit.'),
      findsOneWidget,
    );
    expect(repository.setPinCalls, 0);
  });

  testWidgets('opens payslip PDF from the unlocked in-memory response', (
    tester,
  ) async {
    await _pump(tester, repository: _Payroll());

    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('payslip-pin')), '135791');
    await tester.tap(find.widgetWithText(FilledButton, 'Buka slip gaji'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lihat PDF'));
    await tester.pump();
    await tester.pump();

    expect(find.text('PDF slip gaji'), findsOneWidget);
    expect(find.text('Bagikan'), findsNothing);
    expect(find.text('Unduh'), findsNothing);
  });

  testWidgets('lockout remains visible after a rejected PIN', (tester) async {
    await _pump(tester, repository: _Payroll(lockout: true));
    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('payslip-pin')), '000000');
    await tester.tap(find.widgetWithText(FilledButton, 'Buka slip gaji'));
    await tester.pumpAndSettle();

    expect(find.textContaining('15 menit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payroll list fits 320dp at 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      repository: _Payroll(),
      textScaler: const TextScaler.linear(2),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payroll-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required PayrollRepository repository,
  RequestContext context = _context,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requestContextProvider.overrideWith((_) => context),
        payrollRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const PayrollScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Payroll implements PayrollRepository {
  _Payroll({this.pinSet = true, this.lockout = false});

  bool pinSet;
  final bool lockout;
  var setPinCalls = 0;

  @override
  Future<List<PayslipSummary>> getPayslips() async => [
    PayslipSummary(
      id: 'payslip-1',
      status: 'APPROVED',
      createdAt: DateTime(2026, 10, 1),
      locked: true,
      periodName: 'September 2026',
      payDate: DateTime(2026, 10, 1),
    ),
  ];

  @override
  Future<PayslipPinStatus> getPinStatus() async =>
      PayslipPinStatus(pinSet: pinSet);

  @override
  Future<void> setPin({
    required String currentPassword,
    required String pin,
  }) async {
    setPinCalls++;
    pinSet = true;
  }

  @override
  Future<PayslipUnlockGrant> unlock(String pin) async {
    if (lockout) {
      throw const ApiException(
        'Terlalu banyak percobaan. Coba lagi dalam 15 menit.',
        statusCode: 429,
        code: 'PAYSLIP_PIN_LOCKED',
      );
    }
    return PayslipUnlockGrant(
      token: 'token-1',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<PayslipDetail> getDetail({
    required String id,
    required String unlockToken,
  }) async => PayslipDetail(
    id: id,
    status: 'APPROVED',
    baseSalary: 5000000,
    totalEarnings: 5500000,
    totalDeductions: 500000,
    netPay: 5000000,
    employeeName: 'Karyawan Satu',
    periodName: 'September 2026',
    components: const [
      PayslipComponent(
        code: 'NEW_COMPONENT',
        name: 'Komponen Baru',
        type: 'EARNING',
        amount: 500000,
      ),
    ],
  );

  @override
  Future<PayslipPdf> getPdf({
    required String id,
    required String unlockToken,
  }) async => PayslipPdf(
    bytes: Uint8List.fromList('%PDF-1.7 fixture'.codeUnits),
    sourceName: '$id.pdf',
  );
}
