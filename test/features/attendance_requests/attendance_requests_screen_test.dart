import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/attendance_requests/attendance_request_dependencies.dart';
import 'package:hrm_app/features/attendance_requests/attendance_request_providers.dart';
import 'package:hrm_app/features/attendance_requests/domain/entities/attendance_request.dart';
import 'package:hrm_app/features/attendance_requests/domain/repositories/attendance_request_repository.dart';
import 'package:hrm_app/features/attendance_requests/presentation/screens/attendance_requests_screen.dart';

void main() {
  testWidgets('correction covers loading, error retry, and empty states', (
    tester,
  ) async {
    final gate = Completer<List<AttendanceCorrectionRequest>>();
    final repository = _Repository()..correctionsGate = gate;
    await tester.pumpWidget(_app(repository));
    await tester.pump();
    expect(find.text('Memuat koreksi absensi'), findsOneWidget);

    gate.completeError(
      const ApiException('Jaringan terputus.', code: 'NETWORK_ERROR'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Koreksi absensi gagal dimuat'), findsOneWidget);

    repository.correctionsGate = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('correction-empty')), findsOneWidget);
  });

  testWidgets('correction validates locally and waits for server success', (
    tester,
  ) async {
    final gate = Completer<AttendanceCorrectionRequest>();
    final repository = _Repository()..createCorrectionGate = gate;
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-correction')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('correction-reason')),
      'Mesin kantor tidak merekam waktu masuk',
    );
    await tester.tap(find.byKey(const ValueKey('correction-submit')));
    await tester.pump();
    expect(
      find.text('Pilih minimal satu waktu yang dikoreksi.'),
      findsOneWidget,
    );
    expect(repository.createdCorrection, isNull);

    await tester.tap(find.text('Koreksi waktu masuk'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('correction-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.createdCorrection, isNotNull);
    expect(
      find.text('Koreksi berhasil dikirim dan menunggu persetujuan.'),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('create-correction')))
          .onPressed,
      isNull,
    );

    gate.complete(_correction(id: 'correction-created'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('create-correction')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('correction detail refreshes the selected item from server', (
    tester,
  ) async {
    final repository = _Repository()..corrections = [_correction()];
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('correction-correction-1')));
    await tester.pumpAndSettle();

    expect(repository.correctionDetailId, 'correction-1');
    expect(find.text('Detail koreksi'), findsOneWidget);
    expect(find.text('Status server'), findsOneWidget);
  });

  testWidgets('overtime form rejects incomplete time without a mutation', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      _app(
        repository,
        home: const AttendanceRequestsScreen(
          initialTab: AttendanceRequestTab.overtime,
          openComposer: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('overtime-reason')),
      'Penyelesaian tutup buku bulanan',
    );
    await tester.tap(find.byKey(const ValueKey('overtime-submit')));
    await tester.pump();

    expect(find.text('Lengkapi waktu mulai dan selesai.'), findsOneWidget);
    expect(repository.createdOvertime, isNull);
  });

  testWidgets('overtime pay displays only the amount returned by server', (
    tester,
  ) async {
    final repository = _Repository()
      ..overtimes = [_overtime()]
      ..pay = const OvertimePayEstimate(
        overtimeId: 'overtime-1',
        durationHours: 3,
        dayType: 'WORKDAY',
        hourlyRate: 50000,
        weightedHours: 6.5,
        amount: 325000,
        breakdown: [
          OvertimePayBand(hours: 1, rate: 1.5, subtotal: 75000),
          OvertimePayBand(hours: 2, rate: 2.5, subtotal: 250000),
        ],
      );
    await tester.pumpWidget(
      _app(
        repository,
        home: const AttendanceRequestsScreen(
          initialTab: AttendanceRequestTab.overtime,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('overtime-overtime-1')));
    await tester.pumpAndSettle();

    expect(repository.payRequest?.id, 'overtime-1');
    expect(find.textContaining('325.000'), findsOneWidget);
    expect(find.text('Estimasi bayaran server'), findsOneWidget);
  });

  testWidgets('overtime permission hides create and reports read denial', (
    tester,
  ) async {
    final repository = _Repository()
      ..overtimesError = const ApiException(
        'Forbidden',
        statusCode: 403,
        code: 'FORBIDDEN',
      );
    await tester.pumpWidget(
      _app(
        repository,
        home: const AttendanceRequestsScreen(
          initialTab: AttendanceRequestTab.overtime,
        ),
        permissions: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('create-overtime')), findsNothing);
    expect(find.text('Riwayat lembur tidak tersedia'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    for (final tab in AttendanceRequestTab.values) {
      testWidgets('${tab.name} fits 320dp at 200% text, dark=$dark', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final repository = _Repository()
          ..corrections = [_correction()]
          ..overtimes = [_overtime()];
        await tester.pumpWidget(
          _app(
            repository,
            home: AttendanceRequestsScreen(initialTab: tab),
            dark: dark,
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Koreksi & lembur'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('late correction response is rejected after account switch', () async {
    final gate = Completer<List<AttendanceCorrectionRequest>>();
    final repository = _Repository()..correctionsGate = gate;
    final container = ProviderContainer(
      overrides: [
        attendanceRequestRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.read(requestContextProvider.notifier).state = _context();
    final session = container.read(featureSessionProvider);
    final future = container.read(
      attendanceCorrectionsProvider(
        AttendanceRequestQuery(session: session),
      ).future,
    );

    container.read(requestContextProvider.notifier).state = _context(
      companyId: 'company-2',
    );
    gate.complete([_correction()]);

    await expectLater(future, throwsA(isA<StateError>()));
  });
}

Widget _app(
  AttendanceRequestRepository repository, {
  Widget home = const AttendanceRequestsScreen(),
  bool dark = false,
  double textScale = 1,
  List<String> permissions = const ['attendance:read', 'attendance:create'],
}) => ProviderScope(
  overrides: [
    requestContextProvider.overrideWith(
      (ref) => _context(permissions: permissions),
    ),
    attendanceRequestRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    theme: dark ? AppTheme.dark : AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 30, bottom: 16),
        disableAnimations: true,
      ),
      child: child!,
    ),
    home: home,
  ),
);

RequestContext _context({
  String companyId = 'company-1',
  List<String> permissions = const ['attendance:read', 'attendance:create'],
}) => RequestContext(
  userId: 'user-1',
  employeeId: 'employee-1',
  activeCompanyId: companyId,
  companyScope: [companyId],
  permissions: permissions,
);

AttendanceCorrectionRequest _correction({String id = 'correction-1'}) =>
    AttendanceCorrectionRequest(
      id: id,
      employeeId: 'employee-1',
      companyId: 'company-1',
      attendanceId: 'attendance-1',
      date: DateTime(2026, 9, 18),
      requestedCheckIn: DateTime(2026, 9, 18, 8, 15),
      reason: 'Mesin kantor tidak merekam waktu masuk',
      status: AttendanceRequestStatus.pending,
      createdAt: DateTime(2026, 9, 18, 9),
      updatedAt: DateTime(2026, 9, 18, 9),
    );

OvertimeRequest _overtime() => OvertimeRequest(
  id: 'overtime-1',
  employeeId: 'employee-1',
  companyId: 'company-1',
  date: DateTime(2026, 9, 18),
  startTime: DateTime(2026, 9, 18, 20),
  endTime: DateTime(2026, 9, 18, 23),
  durationHours: 3,
  reason: 'Penyelesaian tutup buku bulanan',
  status: AttendanceRequestStatus.approved,
  createdAt: DateTime(2026, 9, 18, 18),
  updatedAt: DateTime(2026, 9, 18, 19),
  approvedAt: DateTime(2026, 9, 18, 19),
);

class _Repository implements AttendanceRequestRepository {
  List<AttendanceCorrectionRequest> corrections = const [];
  List<OvertimeRequest> overtimes = const [];
  Completer<List<AttendanceCorrectionRequest>>? correctionsGate;
  Completer<AttendanceCorrectionRequest>? createCorrectionGate;
  Object? overtimesError;
  OvertimePayEstimate pay = const OvertimePayEstimate(
    overtimeId: 'overtime-1',
    durationHours: 3,
    dayType: 'WORKDAY',
    hourlyRate: 0,
    weightedHours: 0,
    amount: 0,
    breakdown: [],
  );
  CreateAttendanceCorrection? createdCorrection;
  CreateOvertimeRequest? createdOvertime;
  OvertimeRequest? payRequest;
  String? correctionDetailId;

  @override
  Future<List<AttendanceCorrectionRequest>> getCorrections({String? status}) =>
      correctionsGate?.future ?? Future.value(corrections);

  @override
  Future<AttendanceCorrectionRequest> getCorrection(String id) async {
    correctionDetailId = id;
    return corrections.singleWhere((value) => value.id == id);
  }

  @override
  Future<AttendanceCorrectionRequest> createCorrection(
    CreateAttendanceCorrection command,
  ) {
    createdCorrection = command;
    return createCorrectionGate?.future ??
        Future.value(_correction(id: 'correction-created'));
  }

  @override
  Future<List<OvertimeRequest>> getOvertimes({String? status}) {
    if (overtimesError case final error?) return Future.error(error);
    return Future.value(overtimes);
  }

  @override
  Future<OvertimeRequest> createOvertime(CreateOvertimeRequest command) async {
    createdOvertime = command;
    return _overtime();
  }

  @override
  Future<OvertimePayEstimate> getOvertimePay(OvertimeRequest request) async {
    payRequest = request;
    return pay;
  }
}
