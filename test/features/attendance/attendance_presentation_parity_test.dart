import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/demo/demo_repositories.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:hrm_app/features/attendance/attendance_dependencies.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_command.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_history.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const sectionKeys = [
    'attendance-header',
    'attendance-summary-section',
    'attendance-location-section',
    'attendance-metrics-section',
    'attendance-state-section',
    'attendance-submit-action',
    'attendance-history-picker',
    'attendance-history-filters',
    'attendance-history-content',
  ];

  testWidgets('demo and production use the same ordered attendance structure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final store = DemoStore(await SharedPreferences.getInstance());
    await store.load();
    await _pumpAttendance(
      tester,
      repository: DemoAttendance(store),
      context: const RequestContext(
        userId: 'demo-user',
        employeeId: 'DEMO001',
        activeCompanyId: 'demo-company',
        companyScope: ['demo-company'],
      ),
    );
    final demoOffsets = _sectionOffsets(tester, sectionKeys);
    expect(find.text('Demo lokal'), findsWidgets);
    expect(
      find.text(
        'Simulasi lokal; GPS tidak diverifikasi, wajah diverifikasi di perangkat.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Simulasi lokal; GPS dan wajah tidak diverifikasi.'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pumpAttendance(
      tester,
      repository: _ProductionRepository(),
      context: const RequestContext(
        userId: 'user-1',
        employeeId: 'employee-1',
        activeCompanyId: 'company-1',
        companyScope: ['company-1'],
      ),
    );
    final productionOffsets = _sectionOffsets(tester, sectionKeys);

    expect(demoOffsets.keys, orderedEquals(sectionKeys));
    expect(productionOffsets.keys, orderedEquals(sectionKeys));
    expect(_strictlyIncreasing(demoOffsets.values), isTrue);
    expect(_strictlyIncreasing(productionOffsets.values), isTrue);
    expect(find.text('Demo lokal'), findsNothing);
    expect(find.textContaining('simulasi'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Map<String, double> _sectionOffsets(
  WidgetTester tester,
  List<String> sectionKeys,
) => {
  for (final key in sectionKeys)
    key: tester.getTopLeft(find.byKey(ValueKey(key))).dy,
};

bool _strictlyIncreasing(Iterable<double> values) {
  final offsets = values.toList(growable: false);
  for (var index = 1; index < offsets.length; index++) {
    if (offsets[index] <= offsets[index - 1]) return false;
  }
  return true;
}

Future<void> _pumpAttendance(
  WidgetTester tester, {
  required AttendanceRepository repository,
  required RequestContext context,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requestContextProvider.overrideWith((_) => context),
        attendanceRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: AttendanceScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _ProductionRepository extends AttendanceRepository {
  @override
  Future<Result<AttendanceContext>> getContext() async => const Success(
    AttendanceContext(
      employeeId: 'employee-1',
      companyId: 'company-1',
      branchName: 'Kantor Pusat',
      branchCode: 'JKT',
      allowedMethods: {AttendanceCaptureMethod.mobileGps},
      requiresLocation: true,
      requiresSelfie: false,
      isWorkingDay: true,
      allowHolidayAttendance: false,
      allowWeekendAttendance: false,
      warnings: [],
    ),
  );

  @override
  Future<Result<AttendanceEntity>> getToday() async => const Success(
    AttendanceEntity(
      id: '',
      userId: 'employee-1',
      checkedInAt: null,
      status: AttendanceStatus.notStarted,
      latitude: 0,
      longitude: 0,
    ),
  );

  @override
  Future<Result<AttendanceHistoryPage>> getHistory({
    required String month,
    int page = 1,
    int limit = 20,
  }) async => const Success(
    AttendanceHistoryPage(items: [], page: 1, totalPages: 1, total: 0),
  );

  @override
  Future<Result<AttendanceEntity>> clockIn(AttendanceCommand command) =>
      throw UnimplementedError();

  @override
  Future<Result<AttendanceEntity>> clockOut(AttendanceCommand command) =>
      throw UnimplementedError();
}
