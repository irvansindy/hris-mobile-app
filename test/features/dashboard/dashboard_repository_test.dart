import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/demo/demo_repositories.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:hrm_app/features/dashboard/data/datasources/dashboard_local_datasource.dart';
import 'package:hrm_app/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:hrm_app/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'exposes the dashboard projection without presentation dependencies',
    () {
      final repository = DashboardRepositoryImpl(
        DemoDashboardLocalDataSource(),
      );

      expect(repository.current.employee.name, 'Siti Rahayu');
      expect(repository.current.leaveBalances, hasLength(4));
      expect(repository.current.announcements, hasLength(3));
    },
  );

  test('uses authenticated identity and refreshes API projection', () async {
    const context = RequestContext(
      userId: 'user-1',
      employeeId: 'employee-1',
      activeCompanyId: 'company-1',
      companyScope: ['company-1'],
      displayName: 'Budi Santoso',
      email: 'budi@example.com',
    );
    final repository = DashboardRepositoryImpl(
      DemoDashboardLocalDataSource(),
      _DashboardRemote(),
      () => context,
    );

    expect(repository.current.employee.name, 'Budi Santoso');
    expect(repository.current.leaveBalances, isEmpty);
    final refreshed = await repository.refresh();
    expect(refreshed.leaveBalances.single.total, 12);
  });

  test('defaults optional home sections to unavailable', () {
    const snapshot = DashboardSnapshot(
      employee: DashboardEmployee(
        name: 'Budi Santoso',
        initials: 'BS',
        avatarColorIndex: 0,
      ),
      leaveBalances: [],
      announcements: [],
    );

    expect(snapshot.teamSummary.available, isFalse);
    expect(snapshot.nextShift.available, isFalse);
    expect(snapshot.attendancePattern.available, isFalse);
  });

  test('demo dashboard exposes shared home section domain data', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DemoStore(await SharedPreferences.getInstance());
    await store.load();

    final snapshot = DemoDashboard(store).current;

    expect(snapshot.teamSummary.available, isTrue);
    expect(snapshot.teamSummary.presentCount, 6);
    expect(snapshot.teamSummary.leaveCount, 2);
    expect(snapshot.teamSummary.division, 'Divisi Marketing');
    expect(snapshot.teamSummary.members, hasLength(4));
    expect(snapshot.nextShift.available, isTrue);
    expect(snapshot.nextShift.timeRange, '08.00 – 17.00');
    expect(snapshot.attendancePattern.available, isTrue);
    expect(snapshot.attendancePattern.periodDays, 90);
    expect(snapshot.attendancePattern.rows, hasLength(5));
    expect(snapshot.attendancePattern.rows.first.levels, hasLength(11));
    expect(
      snapshot.attendancePattern.rows
          .expand((row) => row.levels)
          .every((level) => level >= 0 && level <= 3),
      isTrue,
    );
    expect(snapshot.attendancePattern.onsitePercent, 75);
    expect(snapshot.attendancePattern.remotePercent, 15);
    expect(snapshot.attendancePattern.leavePercent, 10);
  });
}

class _DashboardRemote implements DashboardRemoteDataSource {
  @override
  Future<DashboardSnapshot> fetch(
    RequestContext context,
    DashboardSnapshot fallback,
  ) async => DashboardSnapshot(
    employee: fallback.employee,
    leaveBalances: const [
      LeaveBalance(type: 'Annual Leave', total: 12, used: 2, colorIndex: 0),
    ],
    announcements: const [],
  );
}
