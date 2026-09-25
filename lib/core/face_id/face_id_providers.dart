import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/face_id/face_detection_screen.dart';
import 'package:hrm_app/core/face_id/face_template_store.dart';

class FaceEnrollmentRequiredException implements Exception {
  const FaceEnrollmentRequiredException();
}

typedef DemoFaceVerificationLauncher =
    Future<bool> Function({
      required BuildContext context,
      required String employeeId,
      required String companyId,
    });

final demoFaceEnrollmentStoreProvider = Provider<DemoFaceEnrollmentStore>(
  (_) => const DemoFaceEnrollmentStore(PlatformFaceSecureStore()),
);

final demoFaceVerificationLauncherProvider =
    Provider<DemoFaceVerificationLauncher>((ref) {
      final store = ref.watch(demoFaceEnrollmentStoreProvider);
      return ({
        required BuildContext context,
        required String employeeId,
        required String companyId,
      }) async {
        final enrollment = await store.read(
          employeeId: employeeId,
          companyId: companyId,
        );
        if (enrollment == null) {
          throw const FaceEnrollmentRequiredException();
        }
        if (!context.mounted) return false;
        return await Navigator.of(context, rootNavigator: true).push<bool>(
              MaterialPageRoute<bool>(
                fullscreenDialog: true,
                builder: (_) => FaceDetectionScreen(
                  enrollmentStore: store,
                  employeeId: employeeId,
                  companyId: companyId,
                  mode: FaceCaptureMode.attendanceDemo,
                ),
              ),
            ) ??
            false;
      };
    });
