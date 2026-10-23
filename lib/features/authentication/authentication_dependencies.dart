import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/face_id/face_id_providers.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/security/token_storage.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:hrm_app/features/authentication/data/dto/auth_session_dto.dart';
import 'package:hrm_app/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/authentication/domain/usecases/login.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => DioAuthRemoteDataSource(
    ref.watch(dioProvider),
    lifecycle: ref.read(sessionLifecycleProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(tokenStorageProvider),
    lifecycle: ref.read(sessionLifecycleProvider),
    cookieStore: ref.watch(sessionCookieStoreProvider),
  ),
);

final loginUseCaseProvider = Provider<Login>(
  (ref) => Login(ref.watch(authRepositoryProvider)),
);

final refreshedAuthSessionProvider = Provider<AuthSession?>((ref) {
  final stored = ref.watch(refreshedSessionProvider);
  return stored == null
      ? null
      : AuthSessionDto.fromStoredJson(stored).toEntity();
});

typedef SessionArtifactCleaner = Future<void> Function(AuthSession session);

final sessionArtifactCleanerProvider = Provider<SessionArtifactCleaner>((ref) {
  final demoEnrollment = ref.watch(demoFaceEnrollmentStoreProvider);
  final faceTemplate = ref.watch(faceTemplateStoreProvider);
  return (session) async {
    final employeeId = session.employeeId;
    final companyId = session.companyId;
    if (employeeId != null && companyId != null) {
      await Future.wait([
        _bestEffort(
          demoEnrollment.delete(employeeId: employeeId, companyId: companyId),
        ),
        _bestEffort(
          faceTemplate.delete(employeeId: employeeId, companyId: companyId),
        ),
      ]);
    }
  };
});

Future<void> _bestEffort(Future<void> operation) async {
  try {
    await operation;
  } on Object {
    // Local session invalidation must not depend on a platform plugin.
  }
}
