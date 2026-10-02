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
import 'package:hrm_app/features/self_service/presentation/screens/request_form_screen.dart';
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
    expect(find.text('0 aktif · 2 selesai'), findsOneWidget);
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

  testWidgets('paginated data labels current-page counts honestly', (
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
            _PaginatedRequestRepository(),
          ),
        ],
        child: const MaterialApp(home: RequestsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('50 pengajuan · halaman 1 dari 3'), findsOneWidget);
    expect(find.text('1 menunggu di halaman ini'), findsOneWidget);
    expect(find.text('1 aktif · 1 selesai'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('request form uses persistence-neutral workflow copy', (
    tester,
  ) async {
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
            ),
          ),
          ...demoOverrides(store),
        ],
        child: const MaterialApp(
          home: RequestFormScreen(kind: RequestKind.permission),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('server'), findsNothing);
    expect(find.textContaining('sistem'), findsWidgets);
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

class _PaginatedRequestRepository extends RequestRepository {
  @override
  List<EmployeeRequest> get current => const [];

  @override
  Future<List<EmployeeRequest>> refresh() async => const [];

  @override
  Future<EmployeeRequestPage> getPage({
    required RequestKind kind,
    int page = 1,
    int limit = 20,
  }) async => kind == RequestKind.leave
      ? const EmployeeRequestPage(
          items: [
            EmployeeRequest(
              id: 'leave-1',
              type: 'Cuti tahunan',
              dateRange: '2026-10-01',
              submittedOn: '2026-09-30',
              status: RequestStatus.pending,
            ),
          ],
          page: 1,
          totalPages: 3,
          total: 30,
        )
      : const EmployeeRequestPage(
          items: [
            EmployeeRequest(
              id: 'permission-1',
              kind: RequestKind.permission,
              type: 'Izin',
              dateRange: '2026-09-29',
              submittedOn: '2026-09-28',
              status: RequestStatus.approved,
            ),
          ],
          page: 1,
          totalPages: 2,
          total: 20,
        );

  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) =>
      throw UnimplementedError();
}
