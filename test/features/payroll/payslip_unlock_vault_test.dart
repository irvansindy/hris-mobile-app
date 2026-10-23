import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/domain/payslip_unlock_vault.dart';

void main() {
  const context = RequestContext(
    userId: 'user-1',
    employeeId: 'employee-1',
    activeCompanyId: 'company-1',
    companyScope: ['company-1'],
  );
  final now = DateTime.utc(2026, 10, 8, 10);

  test('stores and reads an unexpired grant for the same identity', () {
    final vault = PayslipUnlockVault();
    final grant = PayslipUnlockGrant(
      token: 'unlock-token',
      expiresAt: now.add(const Duration(minutes: 15)),
    );

    expect(vault.store(context, grant, now), isTrue);

    expect(vault.read(context, now.add(const Duration(minutes: 1))), grant);
  });

  test('clears an expired grant before returning it', () {
    final vault = PayslipUnlockVault();
    final grant = PayslipUnlockGrant(
      token: 'unlock-token',
      expiresAt: now.add(const Duration(minutes: 1)),
    );
    vault.store(context, grant, now);

    expect(vault.read(context, now.add(const Duration(minutes: 1))), isNull);
    expect(vault.isEmpty, isTrue);
  });

  test('clears a grant when the complete identity changes', () {
    final vault = PayslipUnlockVault();
    final grant = PayslipUnlockGrant(
      token: 'unlock-token',
      expiresAt: now.add(const Duration(minutes: 15)),
    );
    vault.store(context, grant, now);
    const foreignCompany = RequestContext(
      userId: 'user-1',
      employeeId: 'employee-1',
      activeCompanyId: 'company-2',
      companyScope: ['company-1', 'company-2'],
    );

    expect(vault.read(foreignCompany, now), isNull);
    expect(vault.isEmpty, isTrue);
  });

  test('rejects empty tokens and non-future expiry timestamps', () {
    final vault = PayslipUnlockVault();

    expect(
      vault.store(
        context,
        PayslipUnlockGrant(token: ' ', expiresAt: now.add(const Duration())),
        now,
      ),
      isFalse,
    );
    expect(vault.isEmpty, isTrue);
  });

  test('clear survives a rapid inactive and resumed transition', () {
    final vault = PayslipUnlockVault();
    final grant = PayslipUnlockGrant(
      token: 'unlock-token',
      expiresAt: now.add(const Duration(minutes: 15)),
    );
    vault.store(context, grant, now);

    vault.clear();

    expect(
      vault.read(context, now.add(const Duration(milliseconds: 1))),
      isNull,
    );
  });
}
