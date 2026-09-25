import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/config/demo_mode.dart';
import 'package:hrm_app/core/face_id/face_id_providers.dart';
import 'package:hrm_app/core/face_id/face_template_store.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/demo/demo_app.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:hrm_app/demo/demo_design_sections.dart';
import 'package:hrm_app/demo/demo_design_repositories.dart';
import 'package:hrm_app/demo/demo_requests_screen.dart';
import 'package:hrm_app/features/calendar/calendar_dependencies.dart';
import 'package:hrm_app/demo/demo_repositories.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/attendance/attendance_dependencies.dart';
import 'package:hrm_app/features/attendance/attendance_providers.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';
import 'package:hrm_app/features/dashboard/dashboard_providers.dart';
import 'package:hrm_app/features/self_service/self_service_dependencies.dart';
import 'package:hrm_app/features/self_service/self_service_providers.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';

List<Override> demoOverrides(
  DemoStore store, {
  DemoFaceStorage? faceStorage,
  DemoFaceEnrollmentStore? enrollmentStore,
  DemoFaceVerificationLauncher? faceVerificationLauncher,
}) {
  final resolvedEnrollmentStore =
      enrollmentStore ??
      const DemoFaceEnrollmentStore(PlatformFaceSecureStore());
  return [
    demoModeProvider.overrideWithValue(true),
    demoFaceEnrollmentStoreProvider.overrideWithValue(resolvedEnrollmentStore),
    if (faceVerificationLauncher != null)
      demoFaceVerificationLauncherProvider.overrideWithValue(
        faceVerificationLauncher,
      ),
    demoRequestsBuilderProvider.overrideWithValue(
      (_) => DemoRequestsScreen(store: store),
    ),
    demoHomeSectionsBuilderProvider.overrideWithValue(
      (_) => const DemoHomeSections(),
    ),
    demoAttendanceSummaryBuilderProvider.overrideWithValue(
      (_) => DemoAttendanceSummary(store: store),
    ),
    authRepositoryProvider.overrideWithValue(DemoAuth(store)),
    attendanceRepositoryProvider.overrideWithValue(DemoAttendance(store)),
    requestRepositoryProvider.overrideWithValue(DemoRequests(store)),
    dashboardRepositoryProvider.overrideWith((ref) {
      void changed() => ref.invalidateSelf();
      store.addListener(changed);
      ref.onDispose(() => store.removeListener(changed));
      return DemoDashboard(store);
    }),
    locationServiceProvider.overrideWithValue(DemoLocation()),
    profileRepositoryProvider.overrideWithValue(DemoDesignProfile()),
    calendarRepositoryProvider.overrideWithValue(DemoDesignCalendar()),
    dioProvider.overrideWith((ref) => _offlineDio(ref)),
    featureDioProvider.overrideWith((ref) => _offlineDio(ref)),
    demoToolsBuilderProvider.overrideWith(
      (ref) =>
          (_) => DemoToolsScreen(
            store: store,
            faceStorage: faceStorage ?? SecureDemoFaceStorage(),
            enrollmentStore: ref.watch(demoFaceEnrollmentStoreProvider),
            onChanged: () {
              ref.invalidate(attendanceControllerProvider);
              ref.invalidate(attendanceHistoryProvider);
              ref.invalidate(requestPageProvider);
              ref.invalidate(leaveRequestDetailProvider);
              ref.invalidate(dashboardControllerProvider);
            },
          ),
    ),
  ];
}

Dio _offlineDio(Ref ref) {
  final dio = Dio(BaseOptions(baseUrl: 'https://demo.invalid/api/v1'))
    ..httpClientAdapter = DemoOfflineAdapter();
  ref.onDispose(() => dio.close(force: true));
  return dio;
}

class DemoOfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"success":false,"code":"DEMO_UNAVAILABLE","message":"Fitur ini belum disimulasikan dalam demo lokal."}',
    503,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}
