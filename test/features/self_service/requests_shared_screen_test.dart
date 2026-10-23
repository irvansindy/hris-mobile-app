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

  testWidgets(
    'production request form explains unavailable permission create',
    (tester) async {
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
              _BlockedPermissionRepository(),
            ),
          ],
          child: const MaterialApp(
            home: RequestFormScreen(kind: RequestKind.permission),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pengajuan izin belum tersedia'), findsOneWidget);
      expect(find.textContaining('durasi'), findsOneWidget);
      expect(find.text('Tinjau dan kirim'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leave wildcard permits the production leave form', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requestContextProvider.overrideWith(
            (_) => const RequestContext(
              userId: 'user-1',
              employeeId: 'employee-1',
              activeCompanyId: 'company-1',
              companyScope: ['company-1'],
              permissions: ['leave:*'],
            ),
          ),
          requestRepositoryProvider.overrideWithValue(
            _EmptyRequestRepository(),
          ),
        ],
        child: const MaterialApp(
          home: RequestFormScreen(kind: RequestKind.leave),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Akses pengajuan tidak tersedia'), findsNothing);
    expect(find.text('Detail cuti'), findsOneWidget);
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

class _BlockedPermissionRepository extends RequestRepository {
  @override
  List<EmployeeRequest> get current => const [];

  @override
  Future<List<EmployeeRequest>> refresh() async => const [];

  @override
  String? submissionBlocker(RequestKind kind) => kind == RequestKind.permission
      ? 'Kontrak durasi dan upload lampiran izin belum dipastikan backend.'
      : null;

  @override
  Future<EmployeeRequest> submit(SubmitRequestCommand command) =>
      throw UnimplementedError();
}
