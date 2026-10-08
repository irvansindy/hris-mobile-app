import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/domain/payroll_repository.dart';
import 'package:hrm_app/features/payroll/domain/payslip_unlock_vault.dart';
import 'package:hrm_app/features/payroll/presentation/controllers/payroll_controller.dart';
import 'package:hrm_app/features/payroll/presentation/controllers/payroll_lifecycle_lock.dart';

void main() {
  const context = RequestContext(
    userId: 'user-1',
    employeeId: 'employee-1',
    activeCompanyId: 'company-1',
    companyScope: ['company-1'],
    permissions: ['payroll:read'],
  );
  final now = DateTime.utc(2026, 10, 8, 10);

  test('loads, sets PIN, unlocks, reads detail and PDF, then locks', () async {
    final repo = _Payroll();
    final vault = PayslipUnlockVault();
    final controller = PayrollController(
      repository: repo,
      vault: vault,
      context: () => context,
      isCurrent: () => true,
      now: () => now,
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.state.summaries, hasLength(1));
    await controller.setPin(currentPassword: 'secret', pin: '135791');
    expect(repo.setPinCalls, 1);
    expect(await controller.unlock('135791'), isTrue);
    expect(await controller.loadDetail('payslip-1'), isTrue);
    expect(await controller.loadPdf('payslip-1'), isTrue);
    expect(controller.state.detail?.netPay, 5000000);
    expect(controller.state.pdf?.sourceName, 'payslip-1.pdf');

    controller.lock();

    expect(vault.isEmpty, isTrue);
    expect(controller.state.detail, isNull);
    expect(controller.state.pdf, isNull);
  });

  test(
    'keeps lockout as a recoverable feature error without a grant',
    () async {
      final repo = _Payroll(
        unlockError: const ApiException(
          'Coba lagi dalam 15 menit.',
          statusCode: 429,
          code: 'PAYSLIP_PIN_LOCKED',
        ),
      );
      final vault = PayslipUnlockVault();
      final controller = PayrollController(
        repository: repo,
        vault: vault,
        context: () => context,
        isCurrent: () => true,
        now: () => now,
      );
      addTearDown(controller.dispose);

      expect(await controller.unlock('135791'), isFalse);
      expect(
        (controller.state.error as ApiException).code,
        'PAYSLIP_PIN_LOCKED',
      );
      expect(vault.isEmpty, isTrue);
    },
  );

  test('rejects an already expired unlock grant', () async {
    final repo = _Payroll(
      grant: PayslipUnlockGrant(
        token: 'expired',
        expiresAt: now.subtract(const Duration(seconds: 1)),
      ),
    );
    final vault = PayslipUnlockVault();
    final controller = PayrollController(
      repository: repo,
      vault: vault,
      context: () => context,
      isCurrent: () => true,
      now: () => now,
    );
    addTearDown(controller.dispose);

    expect(await controller.unlock('135791'), isFalse);
    expect(vault.isEmpty, isTrue);
  });

  test('invalid unlock response clears sensitive state', () async {
    final repo = _Payroll(
      detailError: const ApiException(
        'Unlock expired',
        statusCode: 403,
        code: 'PAYSLIP_UNLOCK_INVALID',
      ),
    );
    final vault = PayslipUnlockVault();
    final controller = PayrollController(
      repository: repo,
      vault: vault,
      context: () => context,
      isCurrent: () => true,
      now: () => now,
    );
    addTearDown(controller.dispose);
    await controller.unlock('135791');

    expect(await controller.loadDetail('payslip-1'), isFalse);
    expect(vault.isEmpty, isTrue);
    expect(controller.state.detail, isNull);
  });

  test('background transition clears grant, detail, and PDF', () async {
    final vault = PayslipUnlockVault();
    final controller = PayrollController(
      repository: _Payroll(),
      vault: vault,
      context: () => context,
      isCurrent: () => true,
      now: () => now,
    );
    addTearDown(controller.dispose);
    await controller.unlock('135791');
    await controller.loadDetail('payslip-1');
    await controller.loadPdf('payslip-1');
    final lifecycle = PayrollLifecycleLock(controller.lock);

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(vault.isEmpty, isTrue);
    expect(controller.state.detail, isNull);
    expect(controller.state.pdf, isNull);
  });

  test('late detail response is ignored after identity changes', () async {
    var current = true;
    final repo = _Payroll(delayDetail: true);
    final controller = PayrollController(
      repository: repo,
      vault: PayslipUnlockVault(),
      context: () => context,
      isCurrent: () => current,
      now: () => now,
    );
    addTearDown(controller.dispose);
    await controller.unlock('135791');
    final pending = controller.loadDetail('payslip-1');
    current = false;
    repo.detailCompleter.complete(repo.detail);

    expect(await pending, isFalse);
    expect(controller.state.detail, isNull);
  });
}

class _Payroll implements PayrollRepository {
  _Payroll({
    this.unlockError,
    this.detailError,
    this.delayDetail = false,
    PayslipUnlockGrant? grant,
  }) : grant =
           grant ??
           PayslipUnlockGrant(
             token: 'token-1',
             expiresAt: DateTime.utc(2026, 10, 8, 10, 15),
           );

  final Object? unlockError;
  final Object? detailError;
  final bool delayDetail;
  final PayslipUnlockGrant grant;
  final detailCompleter = Completer<PayslipDetail>();
  var setPinCalls = 0;

  final detail = PayslipDetail(
    id: 'payslip-1',
    status: 'APPROVED',
    baseSalary: 5000000,
    totalEarnings: 5500000,
    totalDeductions: 500000,
    netPay: 5000000,
    components: const [],
  );

  @override
  Future<List<PayslipSummary>> getPayslips() async => [
    PayslipSummary(
      id: 'payslip-1',
      status: 'APPROVED',
      createdAt: DateTime.utc(2026, 10, 1),
      locked: true,
    ),
  ];

  @override
  Future<PayslipPinStatus> getPinStatus() async =>
      const PayslipPinStatus(pinSet: true);

  @override
  Future<void> setPin({
    required String currentPassword,
    required String pin,
  }) async {
    setPinCalls++;
  }

  @override
  Future<PayslipUnlockGrant> unlock(String pin) async {
    if (unlockError case final error?) throw error;
    return grant;
  }

  @override
  Future<PayslipDetail> getDetail({
    required String id,
    required String unlockToken,
  }) async {
    if (detailError case final error?) throw error;
    return delayDetail ? detailCompleter.future : detail;
  }

  @override
  Future<PayslipPdf> getPdf({
    required String id,
    required String unlockToken,
  }) async => PayslipPdf(
    bytes: Uint8List.fromList('%PDF-1.7 fixture'.codeUnits),
    sourceName: 'payslip-1.pdf',
  );
}
