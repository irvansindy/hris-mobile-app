import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/face_id/face_id_providers.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/services/location_gateway.dart';
import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/core/services/selfie_gateway.dart';
import 'package:hrm_app/core/services/selfie_service.dart';
import 'package:hrm_app/features/attendance/attendance_dependencies.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_history.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_today.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/attendance/presentation/screens/attendance_screen.dart';

void main() {
  testWidgets('attendance confirmation can be cancelled without a request', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, repository: repository);

    await tester.tap(find.text('Catat masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi catat masuk'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(repository.clockInCalls, 0);
    expect(find.text('Konfirmasi catat masuk'), findsNothing);
  });

  testWidgets('GPS clock in shows success only after server result', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, repository: repository);

    await tester.tap(find.text('Catat masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    expect(repository.clockInCalls, 1);
    expect(repository.command?.latitude, -6.2088);
    expect(repository.command?.method, AttendanceCaptureMethod.mobileGps);
    expect(find.text('Sedang bekerja'), findsOneWidget);
    expect(find.text('Waktu masuk tercatat di server.'), findsOneWidget);
  });

  testWidgets('server rejection stays failed and never shows success', (
    tester,
  ) async {
    final repository = _Repository(failure: 'Di luar radius kantor.');
    await _pump(tester, repository: repository);

    await tester.tap(find.text('Catat masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    expect(repository.clockInCalls, 1);
    expect(find.text('Absensi belum tercatat'), findsOneWidget);
    expect(find.text('Di luar radius kantor.'), findsOneWidget);
    expect(find.text('Waktu masuk tercatat di server.'), findsNothing);
    expect(find.text('Sedang bekerja'), findsNothing);
  });

  testWidgets('required selfie is captured before face attendance submission', (
    tester,
  ) async {
    final repository = _Repository(requiresSelfie: true);
    await _pump(
      tester,
      repository: repository,
      selfie: _Selfie(
        CapturedSelfie(
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
          mimeType: 'image/png',
          capturedAt: DateTime.utc(2026, 9, 12),
        ),
      ),
    );

    expect(repository.clockInCalls, 0);
    await tester.ensureVisible(find.text('Ambil selfie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ambil selfie'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    final submitButton = find.text('Catat masuk');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    expect(repository.clockInCalls, 1);
    expect(repository.command?.method, AttendanceCaptureMethod.faceRecognition);
    expect(repository.command?.selfie?.mimeType, 'image/png');
  });

  testWidgets('permanent location denial offers app settings recovery', (
    tester,
  ) async {
    final repository = _Repository();
    final location = _DeniedLocation();
    await _pump(tester, repository: repository, location: location);

    await tester.tap(find.text('Catat masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    expect(find.text('Absensi belum tercatat'), findsOneWidget);
    expect(find.text('Buka pengaturan'), findsOneWidget);
    await tester.ensureVisible(find.text('Buka pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka pengaturan'));
    expect(location.openedAppSettings, isTrue);
    expect(repository.clockInCalls, 0);
  });

  testWidgets('demo attendance submits only after camera validation succeeds', (
    tester,
  ) async {
    final repository = _Repository();
    var verificationCalls = 0;
    await _pump(
      tester,
      repository: repository,
      faceVerificationLauncher:
          ({required context, required employeeId, required companyId}) async {
            verificationCalls++;
            expect(employeeId, 'employee-1');
            expect(companyId, 'company-1');
            return true;
          },
    );

    await tester.tap(find.text('Catat masuk'));
    await tester.pumpAndSettle();

    expect(verificationCalls, 1);
    expect(repository.clockInCalls, 1);
    expect(find.text('Konfirmasi catat masuk'), findsNothing);
    expect(
      find.text('Absensi demo tersimpan setelah validasi kamera.'),
      findsOneWidget,
    );
  });

  testWidgets('demo attendance stays blocked when Face ID is not enrolled', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(
      tester,
      repository: repository,
      faceVerificationLauncher:
          ({required context, required employeeId, required companyId}) async =>
              throw const FaceEnrollmentRequiredException(),
    );

    await tester.tap(find.text('Catat masuk'));
    await tester.pumpAndSettle();

    expect(repository.clockInCalls, 0);
    expect(
      find.text(
        'Face ID demo belum disiapkan. Buka Profil, lalu simpan setup Face ID sebelum absensi.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('closing face camera never submits demo attendance', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(
      tester,
      repository: repository,
      faceVerificationLauncher:
          ({required context, required employeeId, required companyId}) async =>
              false,
    );

    await tester.tap(find.text('Catat masuk'));
    await tester.pumpAndSettle();

    expect(repository.clockInCalls, 0);
    expect(find.text('Konfirmasi catat masuk'), findsNothing);
  });

  testWidgets('completed attendance cannot be submitted again', (tester) async {
    final repository = _Repository(completed: true);
    await _pump(
      tester,
      repository: repository,
      faceVerificationLauncher:
          ({required context, required employeeId, required companyId}) async =>
              true,
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Catat masuk'),
    );
    expect(button.onPressed, isNull);
    expect(repository.clockInCalls, 0);
  });

  testWidgets('completed server attendance cannot be submitted again', (
    tester,
  ) async {
    final repository = _Repository(completed: true);
    await _pump(tester, repository: repository);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Catat masuk'),
    );
    expect(button.onPressed, isNull);
    expect(repository.clockInCalls, 0);
  });

  testWidgets('server eligibility disables check in even without a record', (
    tester,
  ) async {
    final repository = _Repository(canCheckIn: false);
    await _pump(tester, repository: repository);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Catat masuk'),
    );
    expect(button.onPressed, isNull);
    expect(repository.clockInCalls, 0);
  });

  testWidgets('missing open checkout directs the employee to correction', (
    tester,
  ) async {
    final repository = _Repository(
      active: true,
      canCheckIn: false,
      canCheckOut: true,
      failure: 'No open attendance record found for checkout',
      failureStatusCode: 404,
      failureCode: 'NOT_FOUND',
    );
    await _pump(tester, repository: repository);

    await tester.tap(find.text('Catat pulang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    expect(repository.clockOutCalls, 1);
    expect(find.text('Ajukan koreksi'), findsOneWidget);
    expect(find.text('Coba lagi'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('attendance-submit-action')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('generic today not found remains retryable', (tester) async {
    final repository = _Repository(initialNotFound: true);
    await _pump(tester, repository: repository);

    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.text('Ajukan koreksi'), findsNothing);
  });

  testWidgets('successful punch with failed refresh reports both facts', (
    tester,
  ) async {
    final repository = _Repository(refreshFailsAfterPunch: true);
    await _pump(tester, repository: repository);

    await tester.tap(find.text('Catat masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    expect(repository.clockInCalls, 1);
    expect(find.text('Waktu masuk tercatat di server.'), findsOneWidget);
    expect(
      find.text('Absensi tercatat, status belum diperbarui'),
      findsOneWidget,
    );
    expect(find.text('Absensi belum tercatat'), findsNothing);
  });

  testWidgets('server hasNextPage false disables the next history button', (
    tester,
  ) async {
    final repository = _Repository(
      history: const AttendanceHistoryPage(
        items: [
          AttendanceEntity(
            id: 'attendance-history-1',
            userId: 'employee-1',
            checkedInAt: null,
            status: AttendanceStatus.onTime,
            latitude: -6.2,
            longitude: 106.8,
          ),
        ],
        page: 1,
        totalPages: 3,
        total: 41,
        hasNextPage: false,
      ),
    );
    await _pump(tester, repository: repository);

    await tester.scrollUntilVisible(find.text('Berikutnya'), 300);
    final next = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Berikutnya'),
    );
    expect(next.onPressed, isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _Repository repository,
  SelfieGateway? selfie,
  LocationGateway location = const _Location(),
  AttendanceFaceVerificationLauncher? faceVerificationLauncher,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requestContextProvider.overrideWith(
          (ref) => const RequestContext(
            userId: 'user-1',
            employeeId: 'employee-1',
            activeCompanyId: 'company-1',
            companyScope: ['company-1'],
          ),
        ),
        attendanceRepositoryProvider.overrideWithValue(repository),
        locationServiceProvider.overrideWithValue(location),
        if (faceVerificationLauncher != null)
          attendanceFaceVerificationLauncherProvider.overrideWithValue(
            faceVerificationLauncher,
          ),
        if (selfie != null) selfieServiceProvider.overrideWithValue(selfie),
      ],
      child: const MaterialApp(home: AttendanceScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _Location implements LocationGateway {
  const _Location();

  @override
  Future<GeoCoordinate> currentPosition() async => GeoCoordinate(
    -6.2088,
    106.8456,
    accuracyMeters: 8,
    capturedAt: DateTime.utc(2026, 9, 12, 1),
  );

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _Selfie implements SelfieGateway {
  const _Selfie(this.value);

  final CapturedSelfie value;

  @override
  Future<CapturedSelfie?> capture() async => value;
}

class _DeniedLocation implements LocationGateway {
  bool openedAppSettings = false;

  @override
  Future<GeoCoordinate> currentPosition() => throw const LocationException(
    LocationIssueKind.permissionDeniedForever,
    'Izin lokasi diblokir.',
  );

  @override
  Future<bool> openAppSettings() async {
    openedAppSettings = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async => true;
}

class _Repository extends AttendanceRepository {
  _Repository({
    this.failure,
    this.requiresSelfie = false,
    this.completed = false,
    this.active = false,
    this.canCheckIn,
    this.canCheckOut,
    this.failureStatusCode = 400,
    this.failureCode,
    this.initialNotFound = false,
    this.refreshFailsAfterPunch = false,
    this.history,
  });

  final String? failure;
  final bool requiresSelfie;
  final bool completed;
  final bool active;
  final bool? canCheckIn;
  final bool? canCheckOut;
  final int failureStatusCode;
  final String? failureCode;
  final bool initialNotFound;
  final bool refreshFailsAfterPunch;
  final AttendanceHistoryPage? history;
  int clockInCalls = 0;
  int clockOutCalls = 0;
  AttendanceCommand? command;
  AttendanceEntity? _currentRecord;

  AttendanceEntity get _record =>
      _currentRecord ??
      (completed
          ? AttendanceEntity(
              id: 'attendance-1',
              userId: 'employee-1',
              checkedInAt: DateTime.utc(2026, 9, 12, 1),
              checkedOutAt: DateTime.utc(2026, 9, 12, 9),
              status: AttendanceStatus.completed,
              latitude: -6.2,
              longitude: 106.8,
            )
          : active
          ? AttendanceEntity(
              id: 'attendance-1',
              userId: 'employee-1',
              checkedInAt: DateTime.utc(2026, 9, 12, 1),
              status: AttendanceStatus.onTime,
              latitude: -6.2,
              longitude: 106.8,
            )
          : const AttendanceEntity(
              id: '',
              userId: 'employee-1',
              checkedInAt: null,
              status: AttendanceStatus.notStarted,
              latitude: 0,
              longitude: 0,
            ));

  @override
  Future<Result<AttendanceContext>> getContext() async => Success(
    AttendanceContext(
      employeeId: 'employee-1',
      companyId: 'company-1',
      branchName: 'Kantor Pusat',
      allowedMethods: {
        requiresSelfie
            ? AttendanceCaptureMethod.faceRecognition
            : AttendanceCaptureMethod.mobileGps,
      },
      requiresLocation: true,
      requiresSelfie: requiresSelfie,
      isWorkingDay: true,
      allowHolidayAttendance: false,
      allowWeekendAttendance: false,
      warnings: const [],
    ),
  );

  @override
  Future<Result<AttendanceEntity>> getToday() async => Success(_record);

  @override
  Future<Result<AttendanceHistoryPage>> getHistory({
    required String month,
    int page = 1,
    int limit = 20,
  }) async => history == null
      ? const FailureResult(ServerFailure('Riwayat absensi belum tersedia.'))
      : Success(history!);

  @override
  Future<Result<AttendanceToday>> getTodayState() async {
    if (initialNotFound && _currentRecord == null) {
      return const FailureResult(
        ServerFailure('Resource not found', statusCode: 404, code: 'NOT_FOUND'),
      );
    }
    if (refreshFailsAfterPunch && _currentRecord != null) {
      return const FailureResult(NetworkFailure('Koneksi terputus.'));
    }
    final context = (await getContext() as Success<AttendanceContext>).value;
    final record = _record;
    return Success(
      AttendanceToday(
        record: record,
        context: context,
        serverTime: DateTime.utc(2026, 9, 12, 1),
        serverDate: '2026-09-12',
        timezone: 'Asia/Jakarta',
        canCheckIn:
            canCheckIn ?? (!record.isActive && record.checkedOutAt == null),
        canCheckOut: canCheckOut ?? record.isActive,
      ),
    );
  }

  @override
  Future<Result<AttendanceEntity>> clockIn(AttendanceCommand value) async {
    clockInCalls++;
    command = value;
    if (failure case final message?) {
      return FailureResult(
        ServerFailure(
          message,
          statusCode: failureStatusCode,
          code: failureCode,
        ),
      );
    }
    final record = AttendanceEntity(
      id: 'attendance-1',
      userId: 'employee-1',
      checkedInAt: value.capturedAt,
      status: AttendanceStatus.onTime,
      latitude: value.latitude,
      longitude: value.longitude,
    );
    _currentRecord = record;
    return Success(record);
  }

  @override
  Future<Result<AttendanceEntity>> clockOut(AttendanceCommand value) async {
    clockOutCalls++;
    command = value;
    if (failure case final message?) {
      return FailureResult(
        ServerFailure(
          message,
          statusCode: failureStatusCode,
          code: failureCode,
        ),
      );
    }
    final record = AttendanceEntity(
      id: 'attendance-1',
      userId: 'employee-1',
      checkedInAt: _record.checkedInAt,
      checkedOutAt: value.capturedAt,
      status: AttendanceStatus.completed,
      latitude: value.latitude,
      longitude: value.longitude,
    );
    _currentRecord = record;
    return Success(record);
  }
}
