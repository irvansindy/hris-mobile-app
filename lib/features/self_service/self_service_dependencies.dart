import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/features/self_service/data/datasources/request_local_datasource.dart';
import 'package:hrm_app/features/self_service/data/repositories/request_repository_impl.dart';
import 'package:hrm_app/features/self_service/data/datasources/request_remote_datasource.dart';
import 'package:hrm_app/features/self_service/domain/repositories/request_repository.dart';
import 'package:hrm_app/features/self_service/domain/usecases/submit_request.dart';

final requestLocalDataSourceProvider = Provider<RequestLocalDataSource>((ref) {
  ref.watch(featureSessionProvider);
  return UnavailableRequestLocalDataSource();
});

final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  final session = ref.watch(featureSessionProvider);
  final local = ref.watch(requestLocalDataSourceProvider);
  return RequestRepositoryImpl(
    local,
    local is UnavailableRequestLocalDataSource
        ? DioRequestRemoteDataSource(
            ref.watch(featureDioProvider),
            () => session.context,
          )
        : null,
  );
});

final submitRequestProvider = Provider<SubmitRequest>(
  (ref) => SubmitRequest(ref.watch(requestRepositoryProvider)),
);
