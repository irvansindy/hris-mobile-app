import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/attendance_requests/attendance_request_dependencies.dart';
import 'package:hrm_app/features/attendance_requests/domain/entities/attendance_request.dart';
import 'package:hrm_app/features/attendance_requests/domain/repositories/attendance_request_repository.dart';
import 'package:hrm_app/features/attendance_requests/presentation/screens/attendance_requests_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(AppTypography.fontFamily)..addFont(
          rootBundle.load('assets/fonts/PlusJakartaSans-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final dark in [false, true]) {
    for (final tab in AttendanceRequestTab.values) {
      testWidgets('attendance requests ${tab.name}, dark=$dark', (
        tester,
      ) async {
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                requestContextProvider.overrideWith(
                  (ref) => const RequestContext(
                    userId: 'user-fixture',
                    employeeId: 'employee-fixture',
                    activeCompanyId: 'company-fixture',
                    companyScope: ['company-fixture'],
                    permissions: ['attendance:read', 'attendance:create'],
                  ),
                ),
                attendanceRequestRepositoryProvider.overrideWithValue(
                  const _GoldenAttendanceRequests(),
                ),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 30, bottom: 20),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: const ValueKey('attendance-stage3-fixture'),
                  child: AttendanceRequestsScreen(initialTab: tab),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const ValueKey('attendance-stage3-fixture')),
            matchesGoldenFile(
              'goldens/attendance_stage3/${tab.name}_${dark ? 'dark' : 'light'}.png',
            ),
          );
        } finally {
          debugDisableShadows = previousShadows;
        }
      });
    }
  }
}

class _GoldenAttendanceRequests implements AttendanceRequestRepository {
  const _GoldenAttendanceRequests();

  @override
  Future<List<AttendanceCorrectionRequest>> getCorrections({String? status}) {
    return Future.value([
      AttendanceCorrectionRequest(
        id: 'correction-pending',
        employeeId: 'employee-fixture',
        companyId: 'company-fixture',
        date: DateTime(2026, 9, 18),
        requestedCheckIn: DateTime(2026, 9, 18, 8, 15),
        reason: 'Mesin kantor tidak merekam waktu masuk',
        status: AttendanceRequestStatus.pending,
        createdAt: DateTime(2026, 9, 18, 9),
        updatedAt: DateTime(2026, 9, 18, 9),
      ),
      AttendanceCorrectionRequest(
        id: 'correction-approved',
        employeeId: 'employee-fixture',
        companyId: 'company-fixture',
        date: DateTime(2026, 9, 17),
        requestedCheckOut: DateTime(2026, 9, 17, 17, 35),
        reason: 'Perangkat mati saat pulang',
        status: AttendanceRequestStatus.approved,
        createdAt: DateTime(2026, 9, 17, 18),
        updatedAt: DateTime(2026, 9, 18, 8),
        approvedAt: DateTime(2026, 9, 18, 8),
      ),
    ]);
  }

  @override
  Future<List<OvertimeRequest>> getOvertimes({String? status}) {
    return Future.value([
      OvertimeRequest(
        id: 'overtime-approved',
        employeeId: 'employee-fixture',
        companyId: 'company-fixture',
        date: DateTime(2026, 9, 18),
        startTime: DateTime(2026, 9, 18, 20),
        endTime: DateTime(2026, 9, 18, 23),
        durationHours: 3,
        reason: 'Penyelesaian tutup buku bulanan',
        status: AttendanceRequestStatus.approved,
        createdAt: DateTime(2026, 9, 18, 18),
        updatedAt: DateTime(2026, 9, 18, 19),
        approvedAt: DateTime(2026, 9, 18, 19),
      ),
      OvertimeRequest(
        id: 'overtime-rejected',
        employeeId: 'employee-fixture',
        companyId: 'company-fixture',
        date: DateTime(2026, 9, 16),
        startTime: DateTime(2026, 9, 16, 18),
        endTime: DateTime(2026, 9, 16, 20),
        durationHours: 2,
        reason: 'Persiapan materi rapat',
        status: AttendanceRequestStatus.rejected,
        createdAt: DateTime(2026, 9, 16, 17),
        updatedAt: DateTime(2026, 9, 17, 8),
      ),
    ]);
  }

  @override
  Future<AttendanceCorrectionRequest> createCorrection(
    CreateAttendanceCorrection command,
  ) => throw UnimplementedError();

  @override
  Future<AttendanceCorrectionRequest> getCorrection(String id) =>
      throw UnimplementedError();

  @override
  Future<OvertimeRequest> createOvertime(CreateOvertimeRequest command) =>
      throw UnimplementedError();

  @override
  Future<OvertimePayEstimate> getOvertimePay(OvertimeRequest request) =>
      throw UnimplementedError();
}
