import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:hrm_app/core/face_id/face_quality.dart';
import 'package:hrm_app/core/face_id/face_template_store.dart';
import 'package:hrm_app/core/theme/app_theme.dart';

enum FaceCaptureMode { enrollment, attendanceDemo }

class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({
    super.key,
    required this.enrollmentStore,
    required this.employeeId,
    required this.companyId,
    this.mode = FaceCaptureMode.enrollment,
  });

  final DemoFaceEnrollmentStore enrollmentStore;
  final String employeeId;
  final String companyId;
  final FaceCaptureMode mode;

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen>
    with WidgetsBindingObserver {
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  final _quality = const FaceQualityEvaluator(
    FaceDetectionConfig(maximumYawDegrees: 35),
  );
  final _samples = <FaceObservation>[];
  late final FaceAutoCaptureSequence _captureSequence;
  CameraController? _controller;
  CameraDescription? _frontCamera;
  DemoFaceEnrollment? _existingEnrollment;
  FaceCaptureState _state = FaceCaptureState.initializing;
  String? _cameraError;
  String? _storageError;
  DateTime? _lastFrame;
  double _holdProgress = 0;
  bool _processing = false;
  bool _saving = false;
  bool _saved = false;
  int _generation = 0;

  bool get _isAttendance => widget.mode == FaceCaptureMode.attendanceDemo;
  int get _requiredSamples => _isAttendance ? 1 : 3;
  int get _visibleStep => _captureSequence.isComplete
      ? _requiredSamples
      : _captureSequence.completed + 1;

  @override
  void initState() {
    super.initState();
    _captureSequence = FaceAutoCaptureSequence(
      targets: _isAttendance
          ? const [FacePoseTarget.center]
          : const [
              FacePoseTarget.center,
              FacePoseTarget.left,
              FacePoseTarget.right,
            ],
    );
    WidgetsBinding.instance.addObserver(this);
    _loadEnrollment();
    _start();
  }

  Future<void> _loadEnrollment() async {
    try {
      final value = await widget.enrollmentStore.read(
        employeeId: widget.employeeId,
        companyId: widget.companyId,
      );
      if (mounted) {
        setState(() {
          _existingEnrollment = value;
          if (_isAttendance && value == null) {
            _storageError =
                'Face ID demo belum disiapkan untuk akun dan perangkat ini.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _storageError = 'Data setup lama tidak dapat dibaca.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _generation++;
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _start();
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _state = FaceCaptureState.initializing;
        _cameraError = null;
      });
    }
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      final front = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      if (front.isEmpty) throw StateError('Kamera depan tidak tersedia.');
      _frontCamera = front.first;
      controller = CameraController(
        front.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() => _state = FaceCaptureState.cameraReady);
      await controller.startImageStream(_processFrame);
    } on CameraException catch (error) {
      await controller?.dispose();
      if (mounted && generation == _generation) {
        setState(() {
          _state = FaceCaptureState.error;
          _cameraError = switch (error.code) {
            'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
              'Izin kamera ditolak. Izinkan kamera di pengaturan perangkat.',
            'CameraAccessRestricted' => 'Kamera dibatasi oleh perangkat.',
            _ => 'Kamera tidak dapat dibuka. Coba lagi.',
          };
        });
      }
    } catch (_) {
      await controller?.dispose();
      if (mounted && generation == _generation) {
        setState(() {
          _state = FaceCaptureState.error;
          _cameraError = 'Kamera depan atau deteksi wajah tidak tersedia.';
        });
      }
    }
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    } catch (_) {
      // Platform may close the controller while the app is backgrounded.
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    final now = DateTime.now();
    if (_processing ||
        (_lastFrame != null &&
            now.difference(_lastFrame!) < const Duration(milliseconds: 250))) {
      return;
    }
    _lastFrame = now;
    final generation = _generation;
    final controller = _controller;
    final camera = _frontCamera;
    if (controller == null || camera == null) return;
    final input = _inputImage(image, controller, camera);
    if (input == null) {
      if (mounted) {
        setState(() {
          _state = FaceCaptureState.error;
          _cameraError = 'Format frame kamera tidak didukung perangkat ini.';
        });
      }
      return;
    }
    _processing = true;
    try {
      final faces = await _detector.processImage(input);
      if (!mounted || generation != _generation) return;
      final rotated =
          input.metadata!.rotation == InputImageRotation.rotation90deg ||
          input.metadata!.rotation == InputImageRotation.rotation270deg;
      final width = rotated ? image.height.toDouble() : image.width.toDouble();
      final height = rotated ? image.width.toDouble() : image.height.toDouble();
      final observations = faces
          .map(
            (face) => FaceObservation(
              centerX: face.boundingBox.center.dx / width,
              centerY: face.boundingBox.center.dy / height,
              widthFraction: face.boundingBox.width / width,
              yaw: face.headEulerAngleY,
              pitch: face.headEulerAngleX,
              roll: face.headEulerAngleZ,
              leftEyeOpen: face.leftEyeOpenProbability,
              rightEyeOpen: face.rightEyeOpenProbability,
              smiling: face.smilingProbability,
              hasEyeLandmarks: face.landmarks.isNotEmpty,
            ),
          )
          .toList(growable: false);
      final quality = _quality.evaluate(observations);
      final observedAt = DateTime.now();
      final target = _captureSequence.currentTarget;
      FaceObservation? validObservation;
      var captureState = quality;
      if (quality == FaceCaptureState.faceReady &&
          target != null &&
          (!_isAttendance || _existingEnrollment != null)) {
        final observation = observations.single;
        if (_captureSequence.poseEvaluator.matches(observation, target)) {
          validObservation = observation;
        } else {
          captureState = FaceCaptureState.poseInvalid;
        }
      }
      final captured =
          !_saving &&
          !_saved &&
          _captureSequence.observe(validObservation, observedAt);
      setState(() {
        _state = captureState;
        _holdProgress = _captureSequence.progress(observedAt);
        if (captured && validObservation != null) {
          _samples.add(validObservation);
          _storageError = null;
          if (_isAttendance) _saved = true;
        }
        _cameraError = null;
      });
      if (captured) {
        HapticFeedback.mediumImpact();
        if (_isAttendance) {
          HapticFeedback.lightImpact();
        } else if (_captureSequence.isComplete) {
          unawaited(_save());
        }
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _state = FaceCaptureState.error;
          _cameraError = 'Deteksi wajah gagal. Tutup kamera lalu coba lagi.';
        });
      }
    } finally {
      _processing = false;
    }
  }

  InputImage? _inputImage(
    CameraImage image,
    CameraController controller,
    CameraDescription camera,
  ) {
    const orientation = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final deviceRotation = orientation[controller.value.deviceOrientation];
    if (deviceRotation == null) return null;
    final degrees = Platform.isIOS
        ? camera.sensorOrientation
        : (camera.sensorOrientation + deviceRotation) % 360;
    final rotation = InputImageRotationValue.fromRawValue(degrees);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null ||
        format == null ||
        image.planes.length != 1 ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _save() async {
    if (_samples.length != 3 || _saving) return;
    setState(() {
      _saving = true;
      _storageError = null;
    });
    try {
      final enrollment = DemoFaceEnrollment(
        employeeId: widget.employeeId,
        companyId: widget.companyId,
        deviceId: await widget.enrollmentStore.deviceId(),
        createdAt: DateTime.now().toUtc(),
        samples: List.unmodifiable(_samples),
      );
      await widget.enrollmentStore.save(enrollment);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _existingEnrollment = enrollment;
        _saved = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _storageError = 'Data demo gagal disimpan. Coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retryCamera() async {
    _generation++;
    _captureSequence.resetCurrentHold();
    if (mounted) setState(() => _holdProgress = 0);
    await _stopCamera();
    if (mounted) _start();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _detector.close();
    super.dispose();
  }

  String get _poseInstruction => switch (_captureSequence.currentTarget) {
    FacePoseTarget.center => 'Hadapkan wajah lurus ke kamera.',
    FacePoseTarget.left => 'Putar kepala perlahan ke kiri.',
    FacePoseTarget.right => 'Putar kepala perlahan ke kanan.',
    null => 'Pemindaian sudut selesai.',
  };

  String get _message {
    if (_cameraError != null) return _cameraError!;
    if (_saving) return 'Pemindaian selesai. Menyimpan data...';
    if (_captureSequence.isComplete && !_saved) {
      return 'Pemindaian sudut selesai.';
    }
    return switch (_state) {
      FaceCaptureState.initializing => 'Menyiapkan kamera depan...',
      FaceCaptureState.cameraReady => 'Arahkan wajah ke dalam bingkai.',
      FaceCaptureState.noFace => 'Wajah belum terlihat.',
      FaceCaptureState.multipleFaces => 'Pastikan hanya satu wajah terlihat.',
      FaceCaptureState.tooFar => 'Dekatkan wajah ke kamera.',
      FaceCaptureState.tooClose => 'Jauhkan wajah sedikit dari kamera.',
      FaceCaptureState.notCentered => 'Posisikan wajah di tengah.',
      FaceCaptureState.poseInvalid => _poseInstruction,
      FaceCaptureState.faceReady =>
        'Tahan posisi. Pemindaian berjalan otomatis.',
      FaceCaptureState.error => 'Kamera atau deteksi wajah gagal.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    final statusColor = _state == FaceCaptureState.faceReady
        ? const Color(0xFF4ADE80)
        : Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              _FullScreenPreview(controller: controller!)
            else
              const ColoredBox(color: Colors.black),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB3000000),
                    Color(0x10000000),
                    Color(0x20000000),
                    Color(0xD9000000),
                  ],
                  stops: [0, 0.24, 0.55, 1],
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final frameWidth = (constraints.maxWidth * 0.68).clamp(
                  210.0,
                  300.0,
                );
                final frameHeight = (constraints.maxHeight * 0.43).clamp(
                  270.0,
                  390.0,
                );
                return Center(
                  child: Semantics(
                    label: 'Bingkai posisi wajah',
                    child: AnimatedContainer(
                      duration: AppMotion.durationOf(
                        context,
                        AppMotion.control,
                      ),
                      width: frameWidth,
                      height: frameHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: statusColor, width: 3),
                        borderRadius: BorderRadius.circular(frameWidth / 2),
                      ),
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Row(
                  children: [
                    _OverlayIconButton(
                      tooltip: 'Kembali',
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.pop(
                        context,
                        _isAttendance ? false : _saved,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isAttendance
                            ? 'Validasi wajah absensi'
                            : 'Setup Face ID demo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_existingEnrollment != null && !_isAttendance)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE615803D),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Tersimpan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xD90F172A),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0x4DFFFFFF)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _isAttendance && _saved
                                  ? 'Validasi demo selesai.'
                                  : _saved
                                  ? 'Data setup demo tersimpan.'
                                  : _message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isAttendance && _saved
                                ? 'Sampel wajah valid. Lanjutkan untuk menyimpan absensi demo.'
                                : _isAttendance
                                ? 'Enrollment lokal ditemukan. Wajah lurus dipindai otomatis tanpa menyimpan foto mentah.'
                                : _saved
                                ? 'Tiga sampel metadata deteksi tersimpan lokal. Data ini belum dapat mencocokkan identitas.'
                                : 'Tahap $_visibleStep dari $_requiredSamples. Tengah, kiri, dan kanan dipindai otomatis. Foto mentah tidak disimpan.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              height: 1.35,
                            ),
                          ),
                          if (_storageError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _storageError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (!_saved && _state != FaceCaptureState.error) ...[
                            const SizedBox(height: 14),
                            _CaptureProgress(
                              completed: _captureSequence.completed,
                              total: _requiredSamples,
                              activeProgress: _holdProgress,
                            ),
                          ],
                          if (_saving) ...[
                            const SizedBox(height: 14),
                            Semantics(
                              label: 'Menyimpan data Face ID demo',
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ],
                          if (_saved ||
                              _state == FaceCaptureState.error ||
                              (_captureSequence.isComplete &&
                                  !_saving &&
                                  _storageError != null)) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton(
                                onPressed: _saved
                                    ? () => Navigator.pop(context, true)
                                    : _state == FaceCaptureState.error
                                    ? _retryCamera
                                    : _save,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  _saved
                                      ? _isAttendance
                                            ? 'Lanjutkan absensi'
                                            : 'Selesai'
                                      : _state == FaceCaptureState.error
                                      ? 'Coba kamera lagi'
                                      : 'Coba simpan lagi',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!ready && _state != FaceCaptureState.error)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaptureProgress extends StatelessWidget {
  const _CaptureProgress({
    required this.completed,
    required this.total,
    required this.activeProgress,
  });

  final int completed;
  final int total;
  final double activeProgress;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Progres pemindaian wajah, $completed dari $total tahap selesai',
    value: '${((completed + activeProgress) / total * 100).round()} persen',
    child: Row(
      children: [
        for (var index = 0; index < total; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 7,
                child: ColoredBox(
                  color: const Color(0xFF475569),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: index < completed
                          ? 1
                          : index == completed
                          ? activeProgress
                          : 0,
                      child: const ColoredBox(color: Color(0xFF4ADE80)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _FullScreenPreview extends StatelessWidget {
  const _FullScreenPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final preview = controller.value.previewSize;
    if (preview == null) return const ColoredBox(color: Colors.black);
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: preview.height,
            height: preview.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x99000000),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: Colors.white,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    ),
  );
}
