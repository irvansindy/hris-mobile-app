import 'package:hrm_app/features/payroll/domain/payroll_models.dart';

abstract interface class PayrollRepository {
  Future<List<PayslipSummary>> getPayslips();

  Future<PayslipPinStatus> getPinStatus();

  Future<void> setPin({required String currentPassword, required String pin});

  Future<PayslipUnlockGrant> unlock(String pin);

  Future<PayslipDetail> getDetail({
    required String id,
    required String unlockToken,
  });

  Future<PayslipPdf> getPdf({required String id, required String unlockToken});
}
