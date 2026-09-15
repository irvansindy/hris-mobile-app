import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/widgets/app_navigation.dart';

class QuickActionCapability {
  const QuickActionCapability({
    required this.label,
    required this.icon,
    required this.endpointAvailable,
    required this.route,
    this.requiredPermission,
  });

  final String label;
  final IconData icon;
  final bool endpointAvailable;
  final String? route;
  final String? requiredPermission;
}

final quickActionCapabilitiesProvider = Provider<List<QuickActionCapability>>((
  ref,
) {
  return const [
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
      endpointAvailable: false,
      route: null,
    ),
    QuickActionCapability(
      label: 'Reimbursement',
      icon: Icons.receipt_long_outlined,
      endpointAvailable: false,
      route: null,
    ),
    QuickActionCapability(
      label: 'Slip gaji',
      icon: Icons.lock_outline_rounded,
      endpointAvailable: false,
      route: null,
      requiredPermission: 'payroll:read',
    ),
  ];
});

List<AppQuickActionItem> buildAvailableQuickActions({
  required BuildContext context,
  required RequestContext? requestContext,
  required List<QuickActionCapability> capabilities,
}) {
  if (requestContext == null) return const [];
  return capabilities
      .where((capability) {
        final permission = capability.requiredPermission;
        return capability.endpointAvailable &&
            capability.route != null &&
            (permission == null ||
                requestContext.permissions.contains(permission));
      })
      .map(
        (capability) => AppQuickActionItem(
          label: capability.label,
          icon: capability.icon,
          onPressed: () => context.push(capability.route!),
        ),
      )
      .toList(growable: false);
}
