import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/attendance_requests/data/datasources/attendance_request_remote_datasource.dart';
import 'package:hrm_app/features/attendance_requests/data/repositories/attendance_request_repository_impl.dart';
import 'package:hrm_app/features/attendance_requests/domain/repositories/attendance_request_repository.dart';

final attendanceRequestRepositoryProvider =
    Provider<AttendanceRequestRepository>((ref) {
      final session = ref.watch(featureSessionProvider);
      return AttendanceRequestRepositoryImpl(
        DioAttendanceRequestRemoteDataSource(
          ref.watch(featureDioProvider),
          () => session.context,
        ),
      );
    });
