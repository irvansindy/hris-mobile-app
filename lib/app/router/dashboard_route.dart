import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/attendance/attendance_providers.dart';
import 'package:hrm_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';

class DashboardRoute extends ConsumerWidget {
  const DashboardRoute({
    super.key,
    required this.onOpenAttendance,
    required this.onOpenRequests,
    this.requestShortcutLabel = 'Pengajuan',
    required this.onOpenCalendar,
    this.onOpenNotifications,
  });

  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenRequests;
  final String requestShortcutLabel;
  final VoidCallback onOpenCalendar;
  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(featureSessionProvider);
    final attendanceState = ref.watch(attendanceControllerProvider(session));
    final AsyncValue<HomeAttendanceData> attendance = attendanceState.when(
      data: (value) => AsyncData<HomeAttendanceData>(
        HomeAttendanceData(
          clockIn: value.record.checkedInAt,
          clockOut: value.record.checkedOutAt,
          isActive: value.record.isActive,
        ),
      ),
      loading: () => const AsyncData<HomeAttendanceData>(
        HomeAttendanceData(
          clockIn: null,
          clockOut: null,
          isActive: false,
          available: false,
        ),
      ),
      error: (error, stackTrace) =>
          AsyncError<HomeAttendanceData>(error, stackTrace),
    );
    return HomeScreen(
      attendance: attendance,
      onOpenAttendance: onOpenAttendance,
      onOpenRequests: onOpenRequests,
      requestShortcutLabel: requestShortcutLabel,
      onOpenCalendar: onOpenCalendar,
      onOpenNotifications: onOpenNotifications,
      notificationUnreadCount: onOpenNotifications == null
          ? null
          : ref.watch(notificationUnreadCountProvider).asData?.value,
      onRefreshNotifications: onOpenNotifications == null
          ? null
          : () => ref.invalidate(notificationUnreadCountProvider),
    );
  }
}
