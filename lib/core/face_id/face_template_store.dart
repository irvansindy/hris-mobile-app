import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hrm_app/core/face_id/face_quality.dart';
import 'package:uuid/uuid.dart';

abstract interface class FaceSecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformFaceSecureStore implements FaceSecureStore {
  const PlatformFaceSecureStore();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'hris_face_id'),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class FaceTemplate {
  const FaceTemplate({
    required this.employeeId,
    required this.companyId,
    required this.deviceId,
    required this.modelVersion,
    required this.templateVersion,
    required this.createdAt,
    required this.embeddings,
  });

  final String employeeId;
  final String companyId;
  final String deviceId;
  final String modelVersion;
  final int templateVersion;
  final DateTime createdAt;
  final List<List<double>> embeddings;

  Map<String, Object> toJson() => {
    'employeeId': employeeId,
    'companyId': companyId,
    'deviceId': deviceId,
    'modelVersion': modelVersion,
    'templateVersion': templateVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'embeddings': embeddings,
  };

  factory FaceTemplate.fromJson(Map<String, dynamic> json) {
    final samples = (json['embeddings'] as List?)
        ?.map(
          (row) =>
              (row as List).map((value) => (value as num).toDouble()).toList(),
        )
        .toList();
    if (samples == null ||
        samples.length < 3 ||
        samples.any(
          (row) =>
              row.isEmpty ||
              row.length != samples.first.length ||
              row.any((value) => !value.isFinite),
        )) {
      throw const FormatException('Template wajah tidak valid.');
    }
    return FaceTemplate(
      employeeId: json['employeeId'] as String,
      companyId: json['companyId'] as String,
      deviceId: json['deviceId'] as String,
      modelVersion: json['modelVersion'] as String,
      templateVersion: json['templateVersion'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      embeddings: samples,
    );
  }
}

class FaceTemplateStore {
  const FaceTemplateStore(this.secureStore);

  final FaceSecureStore secureStore;
  static const _deviceKey = 'face_id.device.v1';

  String _key(String employeeId, String companyId) =>
      'face_id.template.v1.${base64Url.encode(utf8.encode(companyId))}.${base64Url.encode(utf8.encode(employeeId))}';

  Future<String> deviceId() async {
    final existing = await secureStore.read(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await secureStore.write(_deviceKey, generated);
    return generated;
  }

  Future<FaceTemplate?> read({
    required String employeeId,
    required String companyId,
  }) async {
    final raw = await secureStore.read(_key(employeeId, companyId));
    if (raw == null) return null;
    final template = FaceTemplate.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (template.employeeId != employeeId ||
        template.companyId != companyId ||
        template.deviceId != await deviceId()) {
      throw const FormatException(
        'Template bukan milik employee, company, atau perangkat ini.',
      );
    }
    return template;
  }

  Future<void> save(FaceTemplate template) async {
    if (template.employeeId.isEmpty ||
        template.companyId.isEmpty ||
        template.modelVersion.isEmpty ||
        template.templateVersion < 1 ||
        template.deviceId != await deviceId()) {
      throw const FormatException('Metadata template wajah tidak valid.');
    }
    FaceTemplate.fromJson(template.toJson());
    await secureStore.write(
      _key(template.employeeId, template.companyId),
      jsonEncode(template.toJson()),
    );
  }

  Future<void> delete({
    required String employeeId,
    required String companyId,
  }) => secureStore.delete(_key(employeeId, companyId));
}

class DemoFaceEnrollment {
  const DemoFaceEnrollment({
    required this.employeeId,
    required this.companyId,
    required this.deviceId,
    required this.createdAt,
    required this.samples,
  });

  static const format = 'mlkit-detection-metadata-v1';
  final String employeeId;
  final String companyId;
  final String deviceId;
  final DateTime createdAt;
  final List<FaceObservation> samples;

  Map<String, Object> toJson() => {
    'format': format,
    'employeeId': employeeId,
    'companyId': companyId,
    'deviceId': deviceId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'usableForMatching': false,
    'samples': samples
        .map(
          (sample) => {
            'centerX': sample.centerX,
            'centerY': sample.centerY,
            'widthFraction': sample.widthFraction,
            'yaw': sample.yaw,
            'pitch': sample.pitch,
            'roll': sample.roll,
            'leftEyeOpen': sample.leftEyeOpen,
            'rightEyeOpen': sample.rightEyeOpen,
            'smiling': sample.smiling,
            'hasEyeLandmarks': sample.hasEyeLandmarks,
          },
        )
        .toList(growable: false),
  };

  factory DemoFaceEnrollment.fromJson(Map<String, dynamic> json) {
    final rows = json['samples'];
    if (json['format'] != format ||
        json['usableForMatching'] != false ||
        rows is! List ||
        rows.length != 3) {
      throw const FormatException('Data enrollment demo tidak valid.');
    }
    final samples = rows
        .map((value) {
          final row = value as Map<String, dynamic>;
          double requiredNumber(String key) {
            final number = row[key];
            if (number is! num || !number.toDouble().isFinite) {
              throw const FormatException('Metadata sampel wajah tidak valid.');
            }
            return number.toDouble();
          }

          double? optionalNumber(String key) {
            final number = row[key];
            if (number == null) return null;
            if (number is! num || !number.toDouble().isFinite) {
              throw const FormatException('Metadata sampel wajah tidak valid.');
            }
            return number.toDouble();
          }

          return FaceObservation(
            centerX: requiredNumber('centerX'),
            centerY: requiredNumber('centerY'),
            widthFraction: requiredNumber('widthFraction'),
            yaw: optionalNumber('yaw'),
            pitch: optionalNumber('pitch'),
            roll: optionalNumber('roll'),
            leftEyeOpen: optionalNumber('leftEyeOpen'),
            rightEyeOpen: optionalNumber('rightEyeOpen'),
            smiling: optionalNumber('smiling'),
            hasEyeLandmarks: row['hasEyeLandmarks'] == true,
          );
        })
        .toList(growable: false);
    return DemoFaceEnrollment(
      employeeId: json['employeeId'] as String,
      companyId: json['companyId'] as String,
      deviceId: json['deviceId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      samples: samples,
    );
  }
}

class DemoFaceEnrollmentStore {
  const DemoFaceEnrollmentStore(this.secureStore);

  final FaceSecureStore secureStore;
  static const _deviceKey = 'face_id.device.v1';

  String _key(String employeeId, String companyId) =>
      'face_id.demo_enrollment.v1.${base64Url.encode(utf8.encode(companyId))}.${base64Url.encode(utf8.encode(employeeId))}';

  Future<String> deviceId() async {
    final existing = await secureStore.read(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await secureStore.write(_deviceKey, generated);
    return generated;
  }

  Future<DemoFaceEnrollment?> read({
    required String employeeId,
    required String companyId,
  }) async {
    final raw = await secureStore.read(_key(employeeId, companyId));
    if (raw == null) return null;
    final enrollment = DemoFaceEnrollment.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (enrollment.employeeId != employeeId ||
        enrollment.companyId != companyId ||
        enrollment.deviceId != await deviceId()) {
      throw const FormatException(
        'Enrollment bukan milik employee, company, atau perangkat ini.',
      );
    }
    return enrollment;
  }

  Future<void> save(DemoFaceEnrollment enrollment) async {
    if (enrollment.employeeId.isEmpty ||
        enrollment.companyId.isEmpty ||
        enrollment.deviceId != await deviceId()) {
      throw const FormatException('Metadata enrollment demo tidak valid.');
    }
    DemoFaceEnrollment.fromJson(enrollment.toJson());
    await secureStore.write(
      _key(enrollment.employeeId, enrollment.companyId),
      jsonEncode(enrollment.toJson()),
    );
  }

  Future<void> delete({
    required String employeeId,
    required String companyId,
  }) => secureStore.delete(_key(employeeId, companyId));
}
