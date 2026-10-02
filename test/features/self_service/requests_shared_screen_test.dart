import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/demo/demo_overrides.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/domain/entities/request_command.dart';
import 'package:hrm_app/features/self_service/domain/repositories/request_repository.dart';
import 'package:hrm_app/features/self_service/presentation/screens/requests_screen.dart';
import 'package:hrm_app/features/self_service/self_service_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const sectionKeys = [
    'requests-header',
    'requests-summary-actions',
    'requests-category-filters',
    'requests-history-header',
    'requests-history-content',
  ];

  testWidgets('demo renders repository data through the shared sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = DemoStore(preferences);
    await store.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          requestContextProvider.overrideWith(
            (_) => const RequestContext(
              userId: 'demo-user',
              employeeId: 'DEMO001',
              activeCompanyId: 'demo-company',
              companyScope: ['demo-company'],
              permissions: ['leave:create', 'attendance:create'],
            ),
          ),
          ...demoOverrides(store),
        ],
        child: const MaterialApp(home: RequestsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _sectionOffsets(tester, sectionKeys).keys,
      orderedEquals(sectionKeys),
    );
    expect(find.textContaining('Cuti tahunan demo'), findsOneWidget);
    expect(find.text('Izin · 1 hari'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production empty data keeps the same shared sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requestContextProvider.overrideWith(
            (_) => const RequestContext(
              userId: 'user-1',
              employeeId: 'employee-1',
              activeCompanyId: 'company-1',
              companyScope: ['company-1'],
              permissions: ['leave:create'],
            ),
          ),
          requestRepositoryProvider.overrideWithValue(
            _EmptyRequestRepository(),
          ),
        ],
        child: const MaterialApp(home: RequestsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _sectionOffsets(tester, sectionKeys).keys,
      orderedEquals(sectionKeys),
    );
    expect(find.text('Belum ada pengajuan'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
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

class _EmptyRequestRepository extends RequestRepository {
  @override
  List<EmployeeRequest> get current => const [];

  @override
  Future<List<EmployeeRequest>> refresh() async => const [];

  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) =>
      throw UnimplementedError();
}
