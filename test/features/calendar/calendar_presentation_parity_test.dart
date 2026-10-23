import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/services/clock.dart';
import 'package:hrm_app/demo/demo_design_repositories.dart';
import 'package:hrm_app/features/calendar/calendar_dependencies.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:hrm_app/features/calendar/presentation/screens/calendar_screen.dart';

void main() {
  const sectionKeys = [
    'calendar-header',
    'calendar-month-grid',
    'calendar-today-action',
    'calendar-legend',
    'calendar-agenda-header',
    'calendar-agenda-content',
  ];

  testWidgets('demo and production keep the same Calendar composition', (
    tester,
  ) async {
    final demoOrder = await _pumpAndReadSectionOrder(
      tester,
      repository: DemoDesignCalendar(),
      sectionKeys: sectionKeys,
    );
    final productionOrder = await _pumpAndReadSectionOrder(
      tester,
      repository: const _ProductionCalendarRepository(),
      sectionKeys: sectionKeys,
    );

    expect(demoOrder, orderedEquals(sectionKeys));
    expect(productionOrder, orderedEquals(sectionKeys));
    expect(productionOrder, orderedEquals(demoOrder));
    expect(find.text('Shift kantor'), findsOneWidget);
    expect(find.textContaining('Contoh agenda'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<List<String>> _pumpAndReadSectionOrder(
  WidgetTester tester, {
  required CalendarRepository repository,
  required List<String> sectionKeys,
}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 3)),
      ],
      child: const MaterialApp(home: CalendarScreen()),
    ),
  );
  await tester.pumpAndSettle();

  final positions = {
    for (final key in sectionKeys)
      key: tester.getTopLeft(find.byKey(ValueKey(key))).dy,
  };
  final ordered = positions.entries.toList()
    ..sort((left, right) => left.value.compareTo(right.value));
  return ordered.map((entry) => entry.key).toList(growable: false);
}

class _ProductionCalendarRepository extends CalendarRepository {
  const _ProductionCalendarRepository();

  CalendarData _month(int year, int month) => CalendarData(
    focusedDate: DateTime(year, month, 3),
    eventsByDay: const {
      3: [
        CalendarEvent(
          'Shift kantor',
          CalendarEventTone.primary,
          detail: 'Head Office Jakarta',
          time: '08:00 - 17:00',
        ),
      ],
    },
  );

  @override
  CalendarData get current => _month(2026, 10);

  @override
  Future<CalendarData> loadMonth(int year, int month) async =>
      _month(year, month);
}
