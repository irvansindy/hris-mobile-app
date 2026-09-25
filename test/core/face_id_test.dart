import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/face_id/face_quality.dart';
import 'package:hrm_app/core/face_id/face_template_store.dart';

class _MemorySecureStore implements FaceSecureStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  const evaluator = FaceQualityEvaluator(FaceDetectionConfig());
  const good = FaceObservation(
    centerX: 0.5,
    centerY: 0.5,
    widthFraction: 0.4,
    yaw: 0,
    pitch: 0,
    roll: 0,
  );

  test('quality rejects missing, multiple, off-center and invalid pose', () {
    expect(evaluator.evaluate([]), FaceCaptureState.noFace);
    expect(evaluator.evaluate([good, good]), FaceCaptureState.multipleFaces);
    expect(evaluator.evaluate([good]), FaceCaptureState.faceReady);
    expect(
      evaluator.evaluate([
        const FaceObservation(
          centerX: 0.9,
          centerY: 0.5,
          widthFraction: 0.4,
          yaw: 0,
          pitch: 0,
          roll: 0,
        ),
      ]),
      FaceCaptureState.notCentered,
    );
    expect(
      evaluator.evaluate([
        const FaceObservation(
          centerX: 0.5,
          centerY: 0.5,
          widthFraction: 0.1,
          yaw: 0,
          pitch: 0,
          roll: 0,
        ),
      ]),
      FaceCaptureState.tooFar,
    );
    expect(
      evaluator.evaluate([
        const FaceObservation(
          centerX: 0.5,
          centerY: 0.5,
          widthFraction: 0.4,
          yaw: 40,
          pitch: 0,
          roll: 0,
        ),
      ]),
      FaceCaptureState.poseInvalid,
    );
  });

  test('pose evaluator distinguishes center, left and right angles', () {
    const poses = FacePoseEvaluator(FacePoseConfig());
    FaceObservation atYaw(double yaw, {double pitch = 0, double roll = 0}) =>
        FaceObservation(
          centerX: 0.5,
          centerY: 0.5,
          widthFraction: 0.4,
          yaw: yaw,
          pitch: pitch,
          roll: roll,
        );

    expect(poses.matches(atYaw(0), FacePoseTarget.center), isTrue);
    expect(poses.matches(atYaw(18), FacePoseTarget.left), isTrue);
    expect(poses.matches(atYaw(-18), FacePoseTarget.right), isTrue);
    expect(poses.matches(atYaw(18), FacePoseTarget.right), isFalse);
    expect(poses.matches(atYaw(8), FacePoseTarget.center), isFalse);
    expect(poses.matches(atYaw(-40), FacePoseTarget.right), isFalse);
    expect(poses.matches(atYaw(18, pitch: 20), FacePoseTarget.left), isFalse);
  });

  test('automatic capture requires a stable center-left-right sequence', () {
    final sequence = FaceAutoCaptureSequence(
      targets: const [
        FacePoseTarget.center,
        FacePoseTarget.left,
        FacePoseTarget.right,
      ],
    );
    FaceObservation atYaw(double yaw) => FaceObservation(
      centerX: 0.5,
      centerY: 0.5,
      widthFraction: 0.4,
      yaw: yaw,
      pitch: 0,
      roll: 0,
    );

    final start = DateTime.utc(2026, 9, 25, 1);
    expect(sequence.observe(atYaw(0), start), isFalse);
    expect(sequence.progress(start.add(const Duration(milliseconds: 375))), .5);
    expect(
      sequence.observe(atYaw(0), start.add(const Duration(milliseconds: 750))),
      isTrue,
    );
    expect(sequence.completed, 1);
    expect(sequence.currentTarget, FacePoseTarget.left);

    final leftStart = start.add(const Duration(seconds: 1));
    expect(sequence.observe(atYaw(18), leftStart), isFalse);
    expect(
      sequence.observe(
        atYaw(0),
        leftStart.add(const Duration(milliseconds: 500)),
      ),
      isFalse,
    );
    expect(
      sequence.observe(
        atYaw(18),
        leftStart.add(const Duration(milliseconds: 750)),
      ),
      isFalse,
    );
    expect(
      sequence.observe(
        atYaw(18),
        leftStart.add(const Duration(milliseconds: 1500)),
      ),
      isTrue,
    );
    expect(sequence.currentTarget, FacePoseTarget.right);

    final rightStart = leftStart.add(const Duration(seconds: 2));
    expect(sequence.observe(atYaw(-18), rightStart), isFalse);
    expect(
      sequence.observe(
        atYaw(-18),
        rightStart.add(const Duration(milliseconds: 750)),
      ),
      isTrue,
    );
    expect(sequence.completed, 3);
    expect(sequence.isComplete, isTrue);
    expect(sequence.currentTarget, isNull);
  });

  test(
    'verification needs calibrated threshold and matching model dimension',
    () {
      const unavailable = FaceVerificationConfig(
        modelVersion: 'model-v1',
        embeddingDimension: 3,
        calibratedThreshold: null,
      );
      expect(
        () => verifyFace(
          live: [1, 0, 0],
          templates: const [
            [1, 0, 0],
            [1, 0, 0],
            [1, 0, 0],
          ],
          templateModelVersion: 'model-v1',
          config: unavailable,
        ),
        throwsStateError,
      );
      expect(() => cosineSimilarity([0, 0], [1, 0]), throwsFormatException);
      expect(() => cosineSimilarity([1, 0], [1]), throwsFormatException);
      const calibrated = FaceVerificationConfig(
        modelVersion: 'model-v1',
        embeddingDimension: 3,
        calibratedThreshold: 0.9,
      );
      final result = verifyFace(
        live: [1, 0, 0],
        templates: const [
          [1, 0, 0],
          [0.9, 0.1, 0],
          [1, 0, 0],
        ],
        templateModelVersion: 'model-v1',
        config: calibrated,
        now: () => DateTime.utc(2026, 9, 24),
      );
      expect(result.matched, isTrue);
      expect(result.similarity, closeTo(1, 0.0001));
      expect(result.modelVersion, 'model-v1');
      expect(
        () => verifyFace(
          live: [1, 0, 0],
          templates: const [
            [1, 0, 0],
            [1, 0, 0],
            [1, 0, 0],
          ],
          templateModelVersion: 'model-v2',
          config: calibrated,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'secure template is scoped to employee and company without raw photo',
    () async {
      final memory = _MemorySecureStore();
      final store = FaceTemplateStore(memory);
      final deviceId = await store.deviceId();
      final template = FaceTemplate(
        employeeId: 'employee-a',
        companyId: 'company-a',
        deviceId: deviceId,
        modelVersion: 'model-v1',
        templateVersion: 1,
        createdAt: DateTime.utc(2026, 9, 24),
        embeddings: const [
          [1, 0, 0],
          [0.9, 0.1, 0],
          [0.9, 0, 0.1],
        ],
      );
      await store.save(template);
      expect(
        (await store.read(
          employeeId: 'employee-a',
          companyId: 'company-a',
        ))?.embeddings.length,
        3,
      );
      expect(
        await store.read(employeeId: 'employee-b', companyId: 'company-a'),
        isNull,
      );
      expect(
        await store.read(employeeId: 'employee-a', companyId: 'company-b'),
        isNull,
      );
      expect(memory.values.values.join(), isNot(contains('selfieImage')));
      await store.delete(employeeId: 'employee-a', companyId: 'company-a');
      expect(
        await store.read(employeeId: 'employee-a', companyId: 'company-a'),
        isNull,
      );
    },
  );

  test(
    'demo enrollment persists three metadata samples without an image',
    () async {
      final memory = _MemorySecureStore();
      final store = DemoFaceEnrollmentStore(memory);
      final deviceId = await store.deviceId();
      final enrollment = DemoFaceEnrollment(
        employeeId: 'employee-a',
        companyId: 'company-a',
        deviceId: deviceId,
        createdAt: DateTime.utc(2026, 9, 24),
        samples: const [good, good, good],
      );

      await store.save(enrollment);
      final restored = await store.read(
        employeeId: 'employee-a',
        companyId: 'company-a',
      );

      expect(restored?.samples, hasLength(3));
      expect(restored?.createdAt, DateTime.utc(2026, 9, 24));
      expect(
        await store.read(employeeId: 'employee-b', companyId: 'company-a'),
        isNull,
      );
      final serialized = memory.values.values.join();
      expect(serialized, contains('"usableForMatching":false'));
      expect(serialized, isNot(contains('selfie')));
      expect(serialized, isNot(contains('image')));

      await store.delete(employeeId: 'employee-a', companyId: 'company-a');
      expect(
        await store.read(employeeId: 'employee-a', companyId: 'company-a'),
        isNull,
      );
    },
  );
}
