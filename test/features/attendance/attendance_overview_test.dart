import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_history.dart';
import 'package:hrm_app/features/attendance/presentation/widgets/attendance_overview.dart';

void main() {
  testWidgets('renders real attendance summary, location, metrics, and state', (
    tester,
  ) async {
    await _pumpOverview(tester, history: AsyncData(_completeHistory));

    expect(find.byKey(const ValueKey('attendance-summary-section')), findsOne);
    expect(find.byKey(const ValueKey('attendance-location-section')), findsOne);
    expect(find.byKey(const ValueKey('attendance-metrics-section')), findsOne);
    expect(find.byKey(const ValueKey('attendance-state-section')), findsOne);
    expect(find.text('Hadir 1'), findsOne);
    expect(find.text('Cuti 1'), findsOne);
    expect(find.text('Telat 1'), findsOne);
    expect(find.text('08:30'), findsOne);
    expect(find.text('Di dalam area kantor'), findsOne);
    expect(find.text('Sedang bekerja'), findsOne);
  });

  testWidgets('does not calculate totals from incomplete history', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      history: const AsyncData(
        AttendanceHistoryPage(
          items: [_onTime],
          page: 1,
          totalPages: 2,
          total: 21,
        ),
      ),
    );

    expect(
      find.text('Ringkasan bulanan belum tersedia dari server.'),
      findsOne,
    );
    expect(find.text('Hadir 1'), findsNothing);
    expect(find.text('--:--'), findsOne);
  });

  testWidgets('reflows long content at 320dp and 200 percent text', (
    tester,
  ) async {
    await _pumpOverview(
      tester,
      history: AsyncData(_completeHistory),
      width: 320,
      textScale: 2,
      contextValue: _longContext,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('attendance-state-section')),
      220,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('attendance-summary-section')), findsOne);
    expect(find.byKey(const ValueKey('attendance-location-section')), findsOne);
    expect(find.byKey(const ValueKey('attendance-metrics-section')), findsOne);
    expect(find.byKey(const ValueKey('attendance-state-section')), findsOne);
    expect(tester.takeException(), isNull);
  });
}

const _context = AttendanceContext(
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
);

const _longContext = AttendanceContext(
  employeeId: 'employee-1',
  companyId: 'company-1',
  branchName: 'Kantor Pusat dengan nama lokasi yang sangat panjang',
  branchCode: 'HEAD-OFFICE-JAKARTA',
  allowedMethods: {AttendanceCaptureMethod.mobileGps},
  requiresLocation: true,
  requiresSelfie: false,
  isWorkingDay: true,
  allowHolidayAttendance: false,
  allowWeekendAttendance: false,
  warnings: [
    'Pastikan akurasi lokasi memenuhi kebijakan perusahaan sebelum mengirim absensi.',
  ],
);

final _record = AttendanceEntity(
  id: 'attendance-today',
  userId: 'employee-1',
  checkedInAt: DateTime.utc(2026, 10, 2, 8),
  status: AttendanceStatus.onTime,
  latitude: -6.2,
  longitude: 106.8,
  isWithinRadius: true,
);

const _onTime = AttendanceEntity(
  id: 'attendance-1',
  userId: 'employee-1',
  checkedInAt: null,
  status: AttendanceStatus.onTime,
  latitude: -6.2,
  longitude: 106.8,
);

final _completeHistory = AttendanceHistoryPage(
  items: [
    AttendanceEntity(
      id: 'attendance-1',
      userId: 'employee-1',
      checkedInAt: DateTime(2026, 10, 1, 8),
      status: AttendanceStatus.onTime,
      latitude: -6.2,
      longitude: 106.8,
    ),
    const AttendanceEntity(
      id: 'attendance-2',
      userId: 'employee-1',
      checkedInAt: null,
      status: AttendanceStatus.excused,
      latitude: 0,
      longitude: 0,
    ),
    AttendanceEntity(
      id: 'attendance-3',
      userId: 'employee-1',
      checkedInAt: DateTime(2026, 10, 3, 9),
      status: AttendanceStatus.late,
      latitude: -6.2,
      longitude: 106.8,
    ),
  ],
  page: 1,
  totalPages: 1,
  total: 3,
);

Future<void> _pumpOverview(
  WidgetTester tester, {
  required AsyncValue<AttendanceHistoryPage> history,
  AttendanceContext contextValue = _context,
  double width = 400,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: AttendanceOverview(
            contextValue: contextValue,
            record: _record,
            history: history,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
