import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/approvals/data/datasources/approval_remote_datasource.dart';
import 'package:hrm_app/features/approvals/data/repositories/approval_repository_impl.dart';
import 'package:hrm_app/features/approvals/domain/repositories/approval_repository.dart';

final approvalRepositoryProvider = Provider<ApprovalRepository>((ref) {
  final session = ref.watch(featureSessionProvider);
  if (session.context == null) {
    throw const ApiException('Sesi akun belum tersedia.');
  }
  return ApprovalRepositoryImpl(
    DioApprovalRemoteDataSource(
      ref.watch(featureDioProvider),
      () => session.context,
    ),
  );
});
