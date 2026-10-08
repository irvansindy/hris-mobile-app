import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/payroll/data/dio_payroll_repository.dart';
import 'package:hrm_app/features/payroll/domain/payroll_repository.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  final session = ref.watch(featureSessionProvider);
  if (session.context == null) {
    throw const ApiException('Sesi akun belum tersedia.');
  }
  return DioPayrollRepository(
    ref.watch(featureDioProvider),
    () => session.context,
  );
});
