import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/demo/demo_overrides.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:hrm_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:hrm_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const sectionKeys = [
    'home-header',
    'home-attendance-summary',
    'home-shortcuts',
    'home-announcements',
    'home-team-section',
    'home-shift-section',
    'home-attendance-pattern-section',
    'home-leave-balance',
  ];

  testWidgets('demo and production use the same ordered Home structure', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = DemoStore(await SharedPreferences.getInstance());
    await store.load();

    await _pumpHome(tester, overrides: demoOverrides(store));
    final demoOffsets = _sectionOffsets(tester, sectionKeys);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pumpHome(
      tester,
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          const _DashboardRepository(_productionSnapshot),
        ),
      ],
    );
    final productionOffsets = _sectionOffsets(tester, sectionKeys);

    expect(demoOffsets.keys, orderedEquals(sectionKeys));
    expect(productionOffsets.keys, orderedEquals(sectionKeys));
    expect(_strictlyIncreasing(demoOffsets.values), isTrue);
    expect(_strictlyIncreasing(productionOffsets.values), isTrue);
    expect(find.text('Tim hari ini belum tersedia'), findsOneWidget);
    expect(find.text('Dina · Cuti tahunan'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _productionSnapshot = DashboardSnapshot(
  employee: DashboardEmployee(
    name: 'Maya Anggraini',
    initials: 'MA',
    avatarColorIndex: 0,
    role: 'Marketing Staff',
  ),
  leaveBalances: [],
  announcements: [],
);

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

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  tester.view.physicalSize = const Size(400, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          attendance: const AsyncData(
            HomeAttendanceData(clockIn: null, clockOut: null, isActive: false),
          ),
          onOpenAttendance: () {},
          onOpenRequests: () {},
          onOpenCalendar: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _DashboardRepository implements DashboardRepository {
  const _DashboardRepository(this.current);

  @override
  final DashboardSnapshot current;

  @override
  Future<DashboardSnapshot> refresh() async => current;
}
