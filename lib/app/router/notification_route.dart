import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hrm_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';
import 'package:hrm_app/features/notifications/presentation/widgets/push_status_panel.dart';

Future<String> resolvePushLocation(
  PushEvent event,
  NotificationRepository repository,
  bool Function() isCurrent,
) async {
  final id = event.notificationId;
  if (!isCurrent() || !validPushHint(id)) return '/notifications';
  try {
    final page = await repository.load(page: 1, limit: 50);
    if (!isCurrent()) return '/notifications';
    for (final item in page.items) {
      if (item.id == id) {
        return notificationResourceLocation(item) ?? '/notifications';
      }
    }
  } on Object {
    // Inbox remains the fallback; payloads cannot supply a destination.
  }
  return '/notifications';
}

bool validPushHint(String? value) =>
    value != null && RegExp(r'^[a-zA-Z0-9_-]{1,200}$').hasMatch(value);

String? notificationResourceLocation(NotificationItem item) {
  final resource = item.resource?.toLowerCase().replaceAll('-', '_');
  final id = item.referenceId;
  return switch (resource) {
    'attendance' => '/attendance',
    'leave' || 'leave_request' =>
      id != null && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)
          ? '/requests/leave/${Uri.encodeComponent(id)}'
          : '/requests',
    'permission_request' => '/requests',
    'work_calendar' => '/calendar',
    _ => null,
  };
}

class NotificationRoute extends ConsumerWidget {
  const NotificationRoute({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(featureSessionProvider);
    return NotificationsScreen(
      pushStatusPanel: const PushStatusPanel(),
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      onOpenResource: (item) {
        if (!session.isCurrent) return;
        final location = notificationResourceLocation(item);
        if (location == null) {
          showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            sheetAnimationStyle: AppMotion.sheetStyleOf(context),
            isScrollControlled: true,
            builder: (context) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (item.message != null) ...[
                      const SizedBox(height: 12),
                      Text(item.message!),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Detail terkait belum tersedia di aplikasi mobile.',
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (location.startsWith('/requests')) {
          context.push(location);
        } else {
          context.go(location);
        }
      },
    );
  }
}
