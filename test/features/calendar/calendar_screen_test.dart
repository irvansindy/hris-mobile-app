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

class _Repo implements CalendarRepository {
  final periods = <({int year, int month})>[];
  bool fail = false;
  Completer<CalendarData>? january;
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
}
