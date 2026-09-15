import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/services/selfie_gateway.dart';
import 'package:hrm_app/core/services/temporary_file_cleanup.dart';
import 'package:image_picker/image_picker.dart';

final class ImagePickerSelfieService implements SelfieGateway {
  ImagePickerSelfieService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const _maximumBytes = 5 * 1024 * 1024;

  final ImagePicker _picker;

  @override
  Future<CapturedSelfie?> capture() async {
    XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 72,
        maxWidth: 1280,
        maxHeight: 1280,
        requestFullMetadata: false,
      );
      if (image == null) return null;
      final bytes = await image.readAsBytes();
      if (bytes.length > _maximumBytes) {
        throw const SelfieException(
          SelfieIssueKind.tooLarge,
          'Ukuran selfie melebihi 5 MB. Ambil foto ulang dengan pencahayaan yang cukup.',
        );
      }
      return CapturedSelfie(
        bytes: bytes,
        mimeType: image.mimeType ?? 'image/jpeg',
        capturedAt: DateTime.now().toUtc(),
      );
    } on PlatformException catch (error) {
      if (error.code == 'camera_access_denied') {
        throw const SelfieException(
          SelfieIssueKind.permissionDenied,
          'Izin kamera ditolak. Izinkan kamera untuk mengambil selfie absensi.',
        );
      }
      if (error.code == 'camera_access_restricted') {
        throw const SelfieException(
          SelfieIssueKind.restricted,
          'Kamera dibatasi oleh perangkat atau kebijakan organisasi.',
        );
      }
      throw const SelfieException(
        SelfieIssueKind.unavailable,
        'Kamera tidak dapat dibuka. Periksa perangkat lalu coba lagi.',
      );
    } finally {
      final path = image?.path;
      if (path != null) await deleteTemporaryCapture(path);
    }
  }
}

final selfieServiceProvider = Provider<SelfieGateway>(
  (ref) => ImagePickerSelfieService(),
);
