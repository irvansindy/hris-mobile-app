import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:hrm_app/features/dashboard/presentation/widgets/home_support_sections.dart';

void main() {
  testWidgets('renders available home support data and team details', (
    tester,
  ) async {
    await _pumpSections(tester, data: _availableData);

    expect(find.byKey(const ValueKey('home-team-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-shift-section')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-attendance-pattern-section')),
      findsOneWidget,
    );
    expect(find.text('6 hadir · 2 cuti'), findsOneWidget);
    expect(find.text('Shift berikutnya · Senin'), findsOneWidget);
    expect(find.text('Kantor'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);

    await tester.tap(find.text('Lihat semua'));
    await tester.pumpAndSettle();

    expect(find.text('Tim Hari Ini · Divisi Marketing'), findsOneWidget);
    expect(find.text('Dina'), findsOneWidget);
    expect(find.text('Cuti tahunan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps section structure without fabricating unavailable data', (
    tester,
  ) async {
    await _pumpSections(tester, data: _unavailableData);

    expect(find.byKey(const ValueKey('home-team-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-shift-section')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-attendance-pattern-section')),
      findsOneWidget,
    );
    expect(find.text('Tim hari ini belum tersedia'), findsOneWidget);
    expect(find.text('Shift berikutnya belum tersedia'), findsOneWidget);
    expect(find.text('Kehadiran belum tersedia'), findsOneWidget);
    expect(find.text('Dina'), findsNothing);
    expect(find.text('75%'), findsNothing);
  });

  testWidgets('distinguishes available empty data from unavailable sections', (
    tester,
  ) async {
    await _pumpSections(
      tester,
      data: const (
        team: DashboardTeamSummary(available: true),
        shift: DashboardShiftSummary(available: true),
        pattern: DashboardAttendancePattern(available: true),
      ),
    );

    expect(find.text('Belum ada status tim hari ini'), findsOneWidget);
    expect(find.text('Detail shift belum tersedia'), findsOneWidget);
    expect(find.text('Riwayat kehadiran belum tersedia'), findsOneWidget);
  });

  testWidgets('reflows all support sections at 320dp and 200 percent text', (
    tester,
  ) async {
    await _pumpSections(tester, data: _availableData, width: 320, textScale: 2);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-attendance-pattern-section')),
      220,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-attendance-pattern-section')),
      findsOneWidget,
    );
    expect(find.text('Kehadiran'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

typedef _SectionsData = ({
  DashboardTeamSummary team,
  DashboardShiftSummary shift,
  DashboardAttendancePattern pattern,
});

const _unavailableData = (
  team: DashboardTeamSummary(),
  shift: DashboardShiftSummary(),
  pattern: DashboardAttendancePattern(),
);

const _availableData = (
  team: DashboardTeamSummary(
    available: true,
    presentCount: 6,
    leaveCount: 2,
    division: 'Divisi Marketing',
    members: [
      DashboardTeamMember(
        initials: 'DA',
        label: 'Dina',
        detail: 'Cuti tahunan',
      ),
      DashboardTeamMember(initials: 'YP', label: 'Yoga', detail: 'WFH'),
    ],
  ),
  shift: DashboardShiftSummary(
    available: true,
    dayLabel: 'Senin',
    timeRange: '08.00 – 17.00',
    location: 'Head Office Jakarta dengan nama lokasi panjang',
    typeLabel: 'Reguler',
  ),
  pattern: DashboardAttendancePattern(
    available: true,
    rows: [
      DashboardAttendancePatternRow(
        label: 'Sen',
        levels: [3, 2, 1, 3, 0, 3, 2, 1, 3, 2, 3],
      ),
      DashboardAttendancePatternRow(
        label: 'Sel',
        levels: [1, 3, 2, 0, 3, 2, 1, 3, 2, 3, 1],
      ),
    ],
    onsitePercent: 75,
    remotePercent: 15,
    leavePercent: 10,
  ),
);

Future<void> _pumpSections(
  WidgetTester tester, {
  required _SectionsData data,
  double width = 400,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 700);
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
          child: HomeSupportSections(
            team: data.team,
            shift: data.shift,
            attendancePattern: data.pattern,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
