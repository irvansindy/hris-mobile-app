import 'dart:math' as math;

enum FaceCaptureState {
  initializing,
  cameraReady,
  noFace,
  multipleFaces,
  tooFar,
  tooClose,
  notCentered,
  poseInvalid,
  faceReady,
  error,
}

class FaceDetectionConfig {
  const FaceDetectionConfig({
    this.minimumWidthFraction = 0.22,
    this.maximumWidthFraction = 0.72,
    this.maximumCenterOffset = 0.16,
    this.maximumYawDegrees = 18,
    this.maximumPitchDegrees = 18,
    this.maximumRollDegrees = 18,
  });

  final double minimumWidthFraction;
  final double maximumWidthFraction;
  final double maximumCenterOffset;
  final double maximumYawDegrees;
  final double maximumPitchDegrees;
  final double maximumRollDegrees;
}

class FaceObservation {
  const FaceObservation({
    required this.centerX,
    required this.centerY,
    required this.widthFraction,
    required this.yaw,
    required this.pitch,
    required this.roll,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.smiling,
    this.hasEyeLandmarks = false,
  });

  final double centerX;
  final double centerY;
  final double widthFraction;
  final double? yaw;
  final double? pitch;
  final double? roll;
  final double? leftEyeOpen;
  final double? rightEyeOpen;
  final double? smiling;
  final bool hasEyeLandmarks;
}

class FaceQualityEvaluator {
  const FaceQualityEvaluator(this.config);

  final FaceDetectionConfig config;

  FaceCaptureState evaluate(List<FaceObservation> faces) {
    if (faces.isEmpty) return FaceCaptureState.noFace;
    if (faces.length > 1) return FaceCaptureState.multipleFaces;
    final face = faces.single;
    if (!_finite(face.centerX) ||
        !_finite(face.centerY) ||
        !_finite(face.widthFraction)) {
      return FaceCaptureState.error;
    }
    if (face.widthFraction < config.minimumWidthFraction) {
      return FaceCaptureState.tooFar;
    }
    if (face.widthFraction > config.maximumWidthFraction) {
      return FaceCaptureState.tooClose;
    }
    if ((face.centerX - 0.5).abs() > config.maximumCenterOffset ||
        (face.centerY - 0.5).abs() > config.maximumCenterOffset) {
      return FaceCaptureState.notCentered;
    }
    if (face.yaw == null ||
        face.pitch == null ||
        face.roll == null ||
        !_finite(face.yaw!) ||
        !_finite(face.pitch!) ||
        !_finite(face.roll!) ||
        face.yaw!.abs() > config.maximumYawDegrees ||
        face.pitch!.abs() > config.maximumPitchDegrees ||
        face.roll!.abs() > config.maximumRollDegrees) {
      return FaceCaptureState.poseInvalid;
    }
    return FaceCaptureState.faceReady;
  }

  bool _finite(double value) => value.isFinite && !value.isNaN;
}

enum FacePoseTarget { center, left, right }

class FacePoseConfig {
  const FacePoseConfig({
    this.maximumCenterYawDegrees = 7,
    this.minimumTurnYawDegrees = 12,
    this.maximumTurnYawDegrees = 32,
    this.maximumPitchDegrees = 15,
    this.maximumRollDegrees = 15,
  });

  final double maximumCenterYawDegrees;
  final double minimumTurnYawDegrees;
  final double maximumTurnYawDegrees;
  final double maximumPitchDegrees;
  final double maximumRollDegrees;
}

class FacePoseEvaluator {
  const FacePoseEvaluator(this.config);

  final FacePoseConfig config;

  bool matches(FaceObservation face, FacePoseTarget target) {
    final yaw = face.yaw;
    final pitch = face.pitch;
    final roll = face.roll;
    if (yaw == null ||
        pitch == null ||
        roll == null ||
        !yaw.isFinite ||
        !pitch.isFinite ||
        !roll.isFinite ||
        pitch.abs() > config.maximumPitchDegrees ||
        roll.abs() > config.maximumRollDegrees) {
      return false;
    }
    return switch (target) {
      FacePoseTarget.center => yaw.abs() <= config.maximumCenterYawDegrees,
      // ML Kit yaw is image-relative. The employee's left points toward the
      // right side of the processed image, so it produces a positive yaw.
      FacePoseTarget.left =>
        yaw >= config.minimumTurnYawDegrees &&
            yaw <= config.maximumTurnYawDegrees,
      FacePoseTarget.right =>
        yaw <= -config.minimumTurnYawDegrees &&
            yaw >= -config.maximumTurnYawDegrees,
    };
  }
}

class FaceAutoCaptureSequence {
  FaceAutoCaptureSequence({
    required List<FacePoseTarget> targets,
    this.holdDuration = const Duration(milliseconds: 750),
    this.poseEvaluator = const FacePoseEvaluator(FacePoseConfig()),
  }) : targets = List.unmodifiable(targets) {
    if (targets.isEmpty) {
      throw ArgumentError.value(targets, 'targets', 'Tidak boleh kosong.');
    }
  }

  final List<FacePoseTarget> targets;
  final Duration holdDuration;
  final FacePoseEvaluator poseEvaluator;
  int _completed = 0;
  DateTime? _stableSince;

  int get completed => _completed;
  bool get isComplete => _completed >= targets.length;
  FacePoseTarget? get currentTarget => isComplete ? null : targets[_completed];

  bool observe(FaceObservation? face, DateTime capturedAt) {
    final target = currentTarget;
    if (target == null) return false;
    if (face == null || !poseEvaluator.matches(face, target)) {
      _stableSince = null;
      return false;
    }
    _stableSince ??= capturedAt;
    if (capturedAt.difference(_stableSince!) < holdDuration) return false;
    _completed++;
    _stableSince = null;
    return true;
  }

  double progress(DateTime now) {
    if (isComplete) return 1;
    final since = _stableSince;
    if (since == null) return 0;
    final elapsed = now.difference(since).inMilliseconds;
    return (elapsed / holdDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  void resetCurrentHold() => _stableSince = null;
}

double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty ||
      a.length != b.length ||
      a.any((v) => !v.isFinite) ||
      b.any((v) => !v.isFinite)) {
    throw const FormatException('Embedding tidak valid atau dimensi berbeda.');
  }
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA <= 0 || normB <= 0) {
    throw const FormatException('Embedding bernorma nol.');
  }
  return (dot / (math.sqrt(normA) * math.sqrt(normB))).clamp(-1.0, 1.0);
}

class FaceVerificationConfig {
  const FaceVerificationConfig({
    required this.modelVersion,
    required this.embeddingDimension,
    required this.calibratedThreshold,
  });

  final String modelVersion;
  final int embeddingDimension;
  final double? calibratedThreshold;

  bool get isReady =>
      modelVersion.isNotEmpty &&
      embeddingDimension > 0 &&
      calibratedThreshold != null &&
      calibratedThreshold!.isFinite &&
      calibratedThreshold! >= -1 &&
      calibratedThreshold! <= 1;
}

class FaceVerificationResult {
  const FaceVerificationResult({
    required this.matched,
    required this.similarity,
    required this.modelVersion,
    required this.timestamp,
  });

  final bool matched;
  final double similarity;
  final String modelVersion;
  final DateTime timestamp;
}

FaceVerificationResult verifyFace({
  required List<double> live,
  required List<List<double>> templates,
  required String templateModelVersion,
  required FaceVerificationConfig config,
  DateTime Function()? now,
}) {
  if (!config.isReady) {
    throw StateError('Model dan threshold belum dikalibrasi.');
  }
  if (templateModelVersion != config.modelVersion) {
    throw const FormatException('Versi model template tidak cocok.');
  }
  if (templates.length < 3 ||
      live.length != config.embeddingDimension ||
      templates.any((sample) => sample.length != config.embeddingDimension)) {
    throw const FormatException('Template wajah tidak valid.');
  }
  final similarity = templates
      .map((sample) => cosineSimilarity(live, sample))
      .reduce(math.max);
  return FaceVerificationResult(
    matched: similarity >= config.calibratedThreshold!,
    similarity: similarity,
    modelVersion: config.modelVersion,
    timestamp: (now ?? DateTime.now)().toUtc(),
  );
}
