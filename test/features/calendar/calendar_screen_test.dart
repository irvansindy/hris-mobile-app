import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/services/clock.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/calendar/calendar_dependencies.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:hrm_app/features/calendar/presentation/screens/calendar_screen.dart';

void main() {
  testWidgets('calendar month controls support Tab focus and Enter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(repo.periods.last, (year: 2026, month: 11));
  });
  for (final dark in [false, true]) {
    testWidgets(
      'calendar selection, year transition and Today work at 320dp 200%, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repo();
        await tester.pumpWidget(_app(repo, dark: dark, scale: 2));
        await tester.pumpAndSettle();
        expect(repo.periods, [(year: 2026, month: 12)]);
        await tester.tap(find.byKey(const ValueKey('calendar-day-1')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Fixture shift 2026/12'));
        expect(find.text('Fixture shift 2026/12'), findsOneWidget);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 500),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Bulan berikutnya'));
        await tester.tap(find.byTooltip('Bulan berikutnya'));
        await tester.pumpAndSettle();
        expect(find.text('Januari 2027'), findsOneWidget);
        expect(repo.periods.last, (year: 2027, month: 1));
        await tester.ensureVisible(find.text('Hari ini (perangkat)'));
        await tester.tap(find.text('Hari ini (perangkat)'));
        await tester.pumpAndSettle();
        expect(find.text('Desember 2026'), findsOneWidget);
        expect(find.text('Agenda 14 Desember'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'calendar error retries, and late month cannot replace selected month',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo()..fail = true;
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      expect(find.text('Kalender gagal dimuat'), findsOneWidget);
      repo.fail = false;
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Kalender gagal dimuat'), findsNothing);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      repo.january = Completer<CalendarData>();
      await tester.tap(find.byTooltip('Bulan berikutnya'));
      await tester.pump();
      expect(find.text('Memuat kalender'), findsOneWidget);
      await tester.tap(find.byTooltip('Bulan berikutnya'));
      await tester.pumpAndSettle();
      expect(find.text('Februari 2027'), findsOneWidget);
      repo.january!.complete(repo.data(2027, 1));
      await tester.pumpAndSettle();
      expect(find.text('Februari 2027'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('calendar-day-1')));
      await tester.pumpAndSettle();
      expect(find.text('Fixture shift 2027/2'), findsOneWidget);
      expect(find.text('Fixture shift 2027/1'), findsNothing);
    },
  );

  testWidgets('calendar shows next shift and honest empty shift swap state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Shift berikutnya'));
    expect(find.text('Shift malam'), findsOneWidget);
    await tester.ensureVisible(find.text('Belum ada pengajuan tukar shift'));
    expect(find.text('Belum ada pengajuan tukar shift'), findsOneWidget);
  });

  testWidgets('calendar loads holidays and retries all remote sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo()
      ..holidays = [
        WorkHoliday(
          id: 'holiday-1',
          date: DateTime(2026, 12, 14),
          name: 'Hari Fixture',
          type: 'NH',
        ),
      ]
      ..nextShiftError = const ApiException(
        'Tidak dapat terhubung ke server.',
        code: 'NETWORK_ERROR',
      );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(repo.holidayYears, [2026]);
    expect(find.text('Hari Fixture'), findsOneWidget);
    await tester.ensureVisible(find.text('Shift berikutnya gagal dimuat'));
    repo.nextShiftError = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Shift malam'), findsOneWidget);

    final calls = (
      month: repo.periods.length,
      next: repo.nextShiftCalls,
      holidays: repo.holidayYears.length,
      swaps: repo.shiftSwapCalls,
    );
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(repo.periods.length, greaterThan(calls.month));
    expect(repo.nextShiftCalls, greaterThan(calls.next));
    expect(repo.holidayYears.length, greaterThan(calls.holidays));
    expect(repo.shiftSwapCalls, greaterThan(calls.swaps));
  });

  testWidgets('shift swap error can be retried without sample data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo()
      ..swapError = const ApiException(
        'Tidak dapat terhubung ke server.',
        code: 'NETWORK_ERROR',
      );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Tukar shift gagal dimuat'));
    expect(find.text('Tukar shift gagal dimuat'), findsOneWidget);
    repo.swapError = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada pengajuan tukar shift'), findsOneWidget);
  });

  testWidgets('employee creates and cancels a shift swap from Calendar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo()
      ..candidates = const [
        ShiftSwapCandidate(
          employeeId: 'employee-2',
          employeeNumber: 'EMP002',
          fullName: 'Budi',
        ),
      ];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final create = find.byKey(const ValueKey('calendar-create-shift-swap'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('shift-swap-reason')),
      'Tukar jadwal keluarga',
    );
    await tester.tap(find.byKey(const ValueKey('shift-swap-submit')));
    await tester.pumpAndSettle();

    expect(repo.createdSwap?.targetEmployeeId, 'employee-2');
    expect(find.text('Tukar shift berhasil diajukan.'), findsOneWidget);
    final cancel = find.byKey(const ValueKey('cancel-shift-swap-request-1'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(repo.cancelledRequestId, 'request-1');
  });
}

Widget _app(_Repo repo, {bool dark = false, double scale = 1}) => ProviderScope(
  overrides: [
    calendarRepositoryProvider.overrideWithValue(repo),
    clockProvider.overrideWithValue(() => DateTime(2026, 12, 14)),
  ],
  child: MaterialApp(
    theme: dark ? AppTheme.dark : AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        padding: const EdgeInsets.only(top: 30),
      ),
      child: child!,
    ),
    home: const CalendarScreen(),
  ),
);

class _Repo extends CalendarRepository {
  final periods = <({int year, int month})>[];
  bool fail = false;
  Completer<CalendarData>? january;
  Object? swapError;
  Object? nextShiftError;
  List<ShiftSwapCandidate> candidates = const [];
  List<WorkHoliday> holidays = const [];
  final List<int> holidayYears = [];
  int nextShiftCalls = 0;
  int shiftSwapCalls = 0;
  final List<ShiftSwapRequest> swaps = [];
  CreateShiftSwapCommand? createdSwap;
  String? cancelledRequestId;
  CalendarData data(int year, int month) => CalendarData(
    focusedDate: DateTime(year, month),
    eventsByDay: {
      1: [
        CalendarEvent(
          'Fixture shift $year/$month',
          CalendarEventTone.primary,
          time: '08:00 - 17:00',
          detail: 'Fixture kalender, bukan data server',
        ),
      ],
    },
  );
  @override
  CalendarData get current => data(2026, 12);
  @override
  Future<CalendarData> loadMonth(int year, int month) async {
    periods.add((year: year, month: month));
    if (fail) {
      throw const ApiException(
        'Tidak dapat terhubung ke server.',
        code: 'NETWORK_ERROR',
      );
    }
    if (year == 2027 && month == 1 && january != null) return january!.future;
    return data(year, month);
  }

  @override
  Future<NextShiftResult> loadNextShift(DateTime from) async {
    nextShiftCalls += 1;
    if (nextShiftError case final error?) throw error;
    return NextShiftResult(
      timezone: 'Asia/Jakarta',
      serverDate: DateTime(2026, 12, 14),
      fromDate: DateTime(2026, 12, 14),
      throughDate: DateTime(2027, 3, 16),
      shift: CalendarShift(
        date: DateTime(2027, 1, 1),
        label: 'Shift malam',
        dayType: 'WD',
        workStart: '22:00',
        workEnd: '06:00',
        crossesMidnight: true,
      ),
    );
  }

  @override
  Future<List<WorkHoliday>> loadHolidays(int year) async {
    holidayYears.add(year);
    return holidays;
  }

  @override
  Future<List<ShiftSwapCandidate>> loadShiftSwapCandidates(
    DateTime shiftDate,
  ) async => candidates;

  @override
  Future<List<ShiftSwapRequest>> loadMyShiftSwaps() async {
    shiftSwapCalls += 1;
    if (swapError case final error?) throw error;
    return List.unmodifiable(swaps);
  }

  @override
  Future<List<ShiftSwapRequest>> loadMyShiftSwapApprovals() async {
    if (swapError case final error?) throw error;
    return const [];
  }

  @override
  Future<ShiftSwapRequest> createShiftSwap(
    CreateShiftSwapCommand command,
  ) async {
    createdSwap = command;
    final request = _shiftSwap();
    swaps.add(request);
    return request;
  }

  @override
  Future<void> cancelShiftSwap(String requestId) async {
    cancelledRequestId = requestId;
    swaps.removeWhere((item) => item.id == requestId);
  }
}

ShiftSwapRequest _shiftSwap() => ShiftSwapRequest(
  id: 'request-1',
  companyId: 'company-1',
  requesterEmployeeId: 'employee-1',
  targetEmployeeId: 'employee-2',
  approverEmployeeId: 'employee-3',
  shiftDate: DateTime(2026, 12, 14),
  reason: 'Tukar jadwal keluarga',
  status: ShiftSwapStatus.pending,
  counterpartName: 'Budi',
  createdAt: DateTime(2026, 12, 10),
);
