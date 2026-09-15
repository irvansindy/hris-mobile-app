import 'package:flutter/material.dart';
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
}
