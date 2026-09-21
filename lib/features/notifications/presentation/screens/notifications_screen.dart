import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/services/clock.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.onOpenResource});
  final ValueChanged<NotificationItem>? onOpenResource;
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _filter = 0;
  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(notificationInboxProvider);
    final count = ref.watch(notificationUnreadCountProvider).asData?.value;
    final data = inbox.asData?.value;
    final items =
        data?.items
            .where(
              (item) => switch (_filter) {
                1 => !item.isRead,
                2 => item.isApproval,
                _ => true,
              },
            )
            .toList(growable: false) ??
        const <NotificationItem>[];
    final controller = ref.read(notificationInboxProvider.notifier);
    final stackedHeader =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final readAllButton = TextButton(
      onPressed:
          data == null ||
              data.busy ||
              ((count ?? 0) == 0 && !data.items.any((item) => !item.isRead))
          ? null
          : () => controller.markRead(),
      child: const Text('Tandai dibaca'),
    );
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notifikasi',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  if (!stackedHeader) readAllButton,
                ],
              ),
              if (stackedHeader)
                Align(alignment: Alignment.centerRight, child: readAllButton),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in [
                    'Semua',
                    count == null ? 'Belum dibaca' : 'Belum dibaca $count',
                    'Approval',
                  ].indexed)
                    ChoiceChip(
                      showCheckmark: false,
                      side: BorderSide.none,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        color: _filter == entry.$1
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      label: Text(entry.$2),
                      selected: _filter == entry.$1,
                      onSelected: (_) => setState(() => _filter = entry.$1),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (inbox.isLoading)
                const AppStateView.loading(
                  title: 'Memuat notifikasi',
                  message: 'Mengambil inbox akun Anda.',
                )
              else if (inbox.hasError)
                AppStateView(
                  kind:
                      inbox.error is ApiException &&
                          (inbox.error as ApiException).statusCode == 403
                      ? AppViewStateKind.permission
                      : inbox.error is ApiException &&
                            (inbox.error as ApiException).code ==
                                'NETWORK_ERROR'
                      ? AppViewStateKind.offline
                      : AppViewStateKind.error,
                  title: 'Notifikasi gagal dimuat',
                  message: inbox.error is ApiException
                      ? (inbox.error as ApiException).message
                      : 'Respons notifikasi tidak valid. Silakan coba lagi.',
                  actionLabel: 'Coba lagi',
                  onAction: controller.refresh,
                )
              else ...[
                if (data?.busy == true)
                  const AppLoadingIndicator(
                    linear: true,
                    semanticLabel: 'Memperbarui notifikasi',
                  ),
                if (data?.actionError != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      data!.actionError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (items.isEmpty)
                  const AppStateView(
                    kind: AppViewStateKind.empty,
                    title: 'Belum ada notifikasi',
                    message:
                        'Tidak ada notifikasi dalam daftar yang dimuat untuk filter ini.',
                  ),
                for (final item in items) ...[
                  _NotificationCard(
                    item: item,
                    today: ref.read(clockProvider)(),
                    onDelete: data?.busy == true
                        ? null
                        : () => _confirmDelete(context, controller, item),
                    onTap: data?.busy == true
                        ? null
                        : () async {
                            final session = ref.read(featureSessionProvider);
                            final saved =
                                item.isRead ||
                                await controller.markRead(id: item.id);
                            if (!mounted || !session.isCurrent || !saved) {
                              return;
                            }
                            widget.onOpenResource?.call(item);
                          },
                  ),
                  const SizedBox(height: 10),
                ],
                if (data?.canLoadMore == true)
                  OutlinedButton(
                    onPressed: data!.busy
                        ? null
                        : () => controller.refresh(loadMore: true),
                    child: const Text('Muat lebih banyak'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    NotificationInboxController controller,
    NotificationItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus notifikasi?'),
        content: Text(
          'Notifikasi "${item.title}" akan dihapus dari akun Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    final deleted = await controller.delete(item.id);
    if (!context.mounted || !deleted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Notifikasi dihapus.')));
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.today,
  });
  final NotificationItem item;
  final DateTime today;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (tone, background) = switch (item.type.toUpperCase()) {
      'SUCCESS' => (
        dark ? AppColors.darkSuccess : AppColors.success,
        dark ? AppColors.darkSuccessBackground : AppColors.successBackground,
      ),
      'WARNING' => (
        dark ? AppColors.darkWarning : AppColors.warning,
        dark ? AppColors.darkWarningBackground : AppColors.warningBackground,
      ),
      'ERROR' => (colors.error, colors.errorContainer),
      _ => (colors.primary, colors.primaryContainer),
    };
    final icon = item.isApproval
        ? Icons.task_alt_rounded
        : switch (item.type.toUpperCase()) {
            'SUCCESS' => Icons.check_circle_outline,
            'WARNING' => Icons.warning_amber_rounded,
            'ERROR' => Icons.error_outline,
            _ => Icons.notifications_none_rounded,
          };
    return Semantics(
      button: true,
      label: '${item.title}, ${item.isRead ? 'sudah dibaca' : 'belum dibaca'}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 18, color: tone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: item.isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (!item.isRead) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.circle, size: 7, color: colors.primary),
                          ],
                          if (item.createdAt != null) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(item.createdAt!),
                              child: Text(
                                DateFormat(
                                  item.createdAt!.year == today.year &&
                                          item.createdAt!.month ==
                                              today.month &&
                                          item.createdAt!.day == today.day
                                      ? 'HH:mm'
                                      : 'dd/MM',
                                ).format(item.createdAt!),
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 10),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: onDelete,
                            tooltip: 'Hapus notifikasi',
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      if (item.message != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.message!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
