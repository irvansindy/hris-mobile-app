import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/domain/payroll_repository.dart';
import 'package:hrm_app/features/payroll/payroll_dependencies.dart';
import 'package:hrm_app/features/payroll/presentation/screens/payroll_screen.dart';
import 'package:hrm_app/features/payroll/presentation/screens/payslip_pdf_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader(AppTypography.fontFamily)..addFont(
          rootBundle.load('assets/fonts/PlusJakartaSans-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final dark in [false, true]) {
    for (final scenario in [
      'list',
      'setup',
      'unlock',
      'lockout',
      'detail',
      'pdf_error',
    ]) {
      testWidgets('$scenario payroll golden dark=$dark', (tester) async {
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scale = ValueNotifier(1.0);
        addTearDown(scale.dispose);

        final repository = _GoldenPayroll(
          pinSet: scenario != 'setup',
          lockout: scenario == 'lockout',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              requestContextProvider.overrideWith(
                (_) => const RequestContext(
                  userId: 'golden-user',
                  employeeId: 'golden-employee',
                  activeCompanyId: 'golden-company',
                  companyScope: ['golden-company'],
                  permissions: ['payroll:read'],
                ),
              ),
              payrollRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('payroll-golden'),
                child: ValueListenableBuilder<double>(
                  valueListenable: scale,
                  builder: (context, value, _) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(value),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                ),
              ),
              home: scenario == 'pdf_error'
                  ? PayslipPdfScreen(
                      bytes: Uint8List.fromList('invalid'.codeUnits),
                      sourceName: 'invalid.pdf',
                    )
                  : const PayrollScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        if (scenario != 'list' && scenario != 'pdf_error') {
          await tester.tap(find.text('September 2026'));
          await tester.pumpAndSettle();
        }
        if (scenario == 'lockout' || scenario == 'detail') {
          await tester.enterText(
            find.byKey(const ValueKey('payslip-pin')),
            scenario == 'lockout' ? '000000' : '135791',
          );
          await tester.tap(find.widgetWithText(FilledButton, 'Buka slip gaji'));
          await tester.pumpAndSettle();
        }

        scale.value = 2;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scenario == 'detail') {
          expect(
            tester.getSize(find.text('Rincian slip gaji')).width,
            greaterThan(160),
          );
          expect(
            tester.getSize(find.text('Gaji pokok')).width,
            greaterThan(90),
          );
        }
        await expectLater(
          find.byKey(const ValueKey('payroll-golden')),
          matchesGoldenFile(
            'goldens/payroll/${scenario}_${dark ? 'dark' : 'light'}_320_text200.png',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        debugDisableShadows = previousShadows;
      });
    }
  }
}

class _GoldenPayroll implements PayrollRepository {
  _GoldenPayroll({required this.pinSet, required this.lockout});

  bool pinSet;
  final bool lockout;

  @override
  Future<List<PayslipSummary>> getPayslips() async => [
    PayslipSummary(
      id: 'golden-payslip',
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
      token: 'golden-token',
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
    employeeName: 'Karyawan Fixture',
    employeeNumber: 'EMP-001',
    periodName: 'September 2026',
    baseSalary: 5000000,
    totalEarnings: 5500000,
    totalDeductions: 500000,
    netPay: 5000000,
    components: const [
      PayslipComponent(
        code: 'UNKNOWN',
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
    bytes: Uint8List.fromList('%PDF-1.4 fixture'.codeUnits),
    sourceName: 'fixture.pdf',
  );
}
