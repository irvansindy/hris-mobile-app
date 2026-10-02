import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/demo/demo_repositories.dart';
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

  testWidgets('demo and production keep the same Pengajuan composition', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = DemoStore(preferences);
    await store.load();

    final demoOrder = await _pumpAndReadSectionOrder(
      tester,
      repository: DemoRequests(store),
      context: const RequestContext(
        userId: 'demo-user',
        employeeId: 'DEMO001',
        activeCompanyId: 'demo-company',
        companyScope: ['demo-company'],
        permissions: ['leave:create'],
      ),
      sectionKeys: sectionKeys,
    );
    expect(find.textContaining('Cuti tahunan demo'), findsOneWidget);

    final productionOrder = await _pumpAndReadSectionOrder(
      tester,
      repository: _ProductionRequestRepository(),
      context: const RequestContext(
        userId: 'user-1',
        employeeId: 'employee-1',
        activeCompanyId: 'company-1',
        companyScope: ['company-1'],
        permissions: ['leave:create'],
      ),
      sectionKeys: sectionKeys,
    );

    expect(demoOrder, orderedEquals(sectionKeys));
    expect(productionOrder, orderedEquals(sectionKeys));
    expect(productionOrder, orderedEquals(demoOrder));
    expect(find.text('Cuti tahunan · 1 hari'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<List<String>> _pumpAndReadSectionOrder(
  WidgetTester tester, {
  required RequestRepository repository,
  required RequestContext context,
  required List<String> sectionKeys,
}) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requestContextProvider.overrideWith((_) => context),
        requestRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: RequestsScreen()),
    ),
  );
  await tester.pumpAndSettle();

  final positions = {
    for (final key in sectionKeys)
      key: tester.getTopLeft(find.byKey(ValueKey(key))).dy,
  };
  final ordered = positions.entries.toList()
    ..sort((left, right) => left.value.compareTo(right.value));
  return ordered.map((entry) => entry.key).toList();
}

class _ProductionRequestRepository extends RequestRepository {
  static const _items = [
    EmployeeRequest(
      id: 'leave-1',
      type: 'Cuti tahunan',
      dateRange: '1 Oktober 2026',
      submittedOn: '30 September 2026',
      status: RequestStatus.pending,
      totalDays: 1,
    ),
  ];

  @override
  List<EmployeeRequest> get current => _items;

  @override
  Future<List<EmployeeRequest>> refresh() async => _items;

  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) =>
      throw UnimplementedError();
}
