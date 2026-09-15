import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:hrm_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:hrm_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:hrm_app/features/profile/domain/repositories/profile_repository.dart';

final profileLocalDataSourceProvider = Provider<ProfileLocalDataSource>((ref) {
  ref.watch(featureSessionProvider);
  return EmptyProfileLocalDataSource();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final session = ref.watch(featureSessionProvider);
  return ProfileRepositoryImpl(
    ref.watch(profileLocalDataSourceProvider),
    session.context == null
        ? null
        : DioProfileRemoteDataSource(ref.watch(featureDioProvider)),
    () => session.context,
  );
});
