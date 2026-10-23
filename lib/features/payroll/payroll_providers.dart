import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/domain/payslip_unlock_vault.dart';
import 'package:hrm_app/features/payroll/payroll_dependencies.dart';
import 'package:hrm_app/features/payroll/presentation/controllers/payroll_controller.dart';
import 'package:hrm_app/features/payroll/presentation/controllers/payroll_lifecycle_lock.dart';

final payslipUnlockVaultProvider = Provider<PayslipUnlockVault>((ref) {
  ref.watch(featureSessionProvider);
  final vault = PayslipUnlockVault();
  ref.onDispose(vault.clear);
  return vault;
});

final payrollControllerProvider =
    StateNotifierProvider<PayrollController, PayrollState>((ref) {
      final session = ref.watch(featureSessionProvider);
      if (session.context == null) {
        throw const ApiException('Sesi akun belum tersedia.');
      }
      final controller = PayrollController(
        repository: ref.watch(payrollRepositoryProvider),
        vault: ref.watch(payslipUnlockVaultProvider),
        context: () => session.context,
        isCurrent: () => session.isCurrent,
      );
      final lifecycle = PayrollLifecycleLock(controller.lock)..start();
      ref.onDispose(lifecycle.stop);
      return controller;
    });

final payslipListProvider = Provider<List<PayslipSummary>>(
  (ref) => ref.watch(payrollControllerProvider).summaries,
);

final payslipPinStatusProvider = Provider<PayslipPinStatus?>(
  (ref) => ref.watch(payrollControllerProvider).pinStatus,
);
