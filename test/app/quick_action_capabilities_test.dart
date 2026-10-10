import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/app/shell/quick_action_capabilities.dart';
import 'package:hrm_app/core/network/request_context.dart';

void main() {
  testWidgets('quick actions require an endpoint, route, and permission', (
    tester,
  ) async {
    late int visibleCount;
    const context = RequestContext(
      userId: 'user-1',
      employeeId: 'employee-1',
      activeCompanyId: 'company-1',
      companyScope: ['company-1'],
      permissions: ['leave:create'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            visibleCount = buildAvailableQuickActions(
              context: buildContext,
              requestContext: context,
              capabilities: const [
                QuickActionCapability(
                  label: 'Tanpa endpoint',
                  icon: Icons.close,
                  endpointAvailable: false,
                  route: '/requests',
                ),
                QuickActionCapability(
                  label: 'Tanpa route',
                  icon: Icons.close,
                  endpointAvailable: true,
                  route: null,
                ),
                QuickActionCapability(
                  label: 'Tanpa izin',
                  icon: Icons.close,
                  endpointAvailable: true,
                  route: '/requests',
                  requiredPermission: 'payroll:read',
                ),
                QuickActionCapability(
                  label: 'Ajukan cuti',
                  icon: Icons.beach_access_outlined,
                  endpointAvailable: true,
                  route: '/requests?type=leave',
                  requiredPermission: 'leave:create',
                ),
              ],
            ).length;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(visibleCount, 1);
  });

  testWidgets('quick actions accept wildcard and legacy permissions', (
    tester,
  ) async {
    late List<String> labels;
    const context = RequestContext(
      userId: 'user-1',
      employeeId: 'employee-1',
      activeCompanyId: 'company-1',
      companyScope: ['company-1'],
      permissions: ['leave:*', 'att:create'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            labels = buildAvailableQuickActions(
              context: buildContext,
              requestContext: context,
              capabilities: const [
                QuickActionCapability(
                  label: 'Ajukan cuti',
                  icon: Icons.beach_access_outlined,
                  endpointAvailable: true,
                  route: '/requests/leave/new',
                  requiredPermission: 'leave:create',
                ),
                QuickActionCapability(
                  label: 'Klaim lembur',
                  icon: Icons.more_time_rounded,
                  endpointAvailable: true,
                  route: '/attendance/requests',
                  requiredPermission: 'attendance:create',
                ),
              ],
            ).map((item) => item.label).toList();
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(labels, ['Ajukan cuti', 'Klaim lembur']);
  });

  testWidgets('payroll quick action is available only with payroll read', (
    tester,
  ) async {
    late List<String> labels;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quickActionCapabilitiesProvider.overrideWithValue(const [
            QuickActionCapability(
              label: 'Slip gaji',
              icon: Icons.lock_outline_rounded,
              endpointAvailable: true,
              route: '/payroll',
              requiredPermission: 'payroll:read',
            ),
          ]),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              labels = buildAvailableQuickActions(
                context: context,
                requestContext: const RequestContext(
                  userId: 'user-1',
                  employeeId: 'employee-1',
                  activeCompanyId: 'company-1',
                  companyScope: ['company-1'],
                  permissions: ['payroll:*'],
                ),
                capabilities: ref.watch(quickActionCapabilitiesProvider),
              ).map((item) => item.label).toList();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(labels, ['Slip gaji']);
  });
}
