import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/dashboard/dashboard_providers.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';

class HomeAttendanceData {
  const HomeAttendanceData({
    required this.clockIn,
    required this.clockOut,
    required this.isActive,
    this.available = true,
  });

  final DateTime? clockIn;
  final DateTime? clockOut;
  final bool isActive;
  final bool available;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.attendance = const AsyncData(
      HomeAttendanceData(
        clockIn: null,
        clockOut: null,
        isActive: false,
        available: false,
      ),
    ),
    required this.onOpenAttendance,
    this.onOpenRequests,
    this.onOpenCalendar,
    this.onOpenNotifications,
    this.notificationUnreadCount,
    this.onRefreshNotifications,
  });

  final AsyncValue<HomeAttendanceData> attendance;
  final VoidCallback onOpenAttendance;
  final VoidCallback? onOpenRequests;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenNotifications;
  final int? notificationUnreadCount;
  final VoidCallback? onRefreshNotifications;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedBalance = 0;

  void _showUnavailable(String title, String message) {
    showDialog<void>(
      context: context,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardControllerProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          widget.onRefreshNotifications?.call();
          await ref.read(dashboardControllerProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 68,
              titleSpacing: AppSpacing.screenHorizontal,
              title: Row(
                children: [
                  AppInitialAvatar(name: dashboard.employee.name, size: 42),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      dashboard.employee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppBadgeIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Buka chat',
                    boxed: true,
                    onPressed: () => _showUnavailable(
                      'Chat belum tersedia',
                      'Layanan chat belum tersedia dari server.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppBadgeIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Buka notifikasi',
                    boxed: true,
                    onPressed:
                        widget.onOpenNotifications ??
                        () => _showUnavailable(
                          'Notifikasi belum tersedia',
                          'Inbox notifikasi belum terhubung pada layar ini.',
                        ),
                    badgeCount: widget.notificationUnreadCount,
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                12,
                AppSpacing.screenHorizontal,
                AppSpacing.scrollBottom,
              ),
              sliver: SliverList.list(
                children: [
                  Text(
                    'Kerja Lebih Baik,\nTumbuh Bersama',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 18),
                  _AttendanceSummary(
                    state: widget.attendance,
                    onOpen: widget.onOpenAttendance,
                  ),
                  if (widget.onOpenRequests != null ||
                      widget.onOpenCalendar != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (widget.onOpenRequests != null)
                          Expanded(
                            child: _ShortcutCard(
                              label: 'Pengajuan',
                              icon: Icons.description_outlined,
                              onTap: widget.onOpenRequests!,
                            ),
                          ),
                        if (widget.onOpenRequests != null &&
                            widget.onOpenCalendar != null)
                          const SizedBox(width: 10),
                        if (widget.onOpenCalendar != null)
                          Expanded(
                            child: _ShortcutCard(
                              label: 'Kalender',
                              icon: Icons.calendar_month_outlined,
                              onTap: widget.onOpenCalendar!,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (dashboard.announcementsAvailable ||
                      dashboard.announcementsError != null) ...[
                    const SizedBox(height: 12),
                    _Announcements(
                      dashboard: dashboard,
                      onRetry: ref
                          .read(dashboardControllerProvider.notifier)
                          .refresh,
                    ),
                  ],
                  if (dashboard.leaveBalancesAvailable ||
                      dashboard.leaveBalancesError != null) ...[
                    const SizedBox(height: 12),
                    _LeaveBalanceCard(
                      dashboard: dashboard,
                      selected: _selectedBalance,
                      onSelected: (value) =>
                          setState(() => _selectedBalance = value),
                      onRetry: ref
                          .read(dashboardControllerProvider.notifier)
                          .refresh,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({required this.state, required this.onOpen});
  final AsyncValue<HomeAttendanceData> state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => state.when(
    loading: () => const AppStateView.loading(
      title: 'Memuat absensi hari ini',
      message: 'Menyelaraskan catatan terbaru dengan server.',
    ),
    error: (_, _) => AppStateView(
      kind: AppViewStateKind.error,
      title: 'Absensi belum tersedia',
      message: 'Buka layar Absensi untuk mencoba lagi.',
      actionLabel: 'Buka Absensi',
      onAction: onOpen,
    ),
    data: (record) {
      final duration = record.clockIn == null
          ? null
          : (record.clockOut ?? DateTime.now()).difference(record.clockIn!);
      final values = [
        (label: 'Masuk', value: _time(record.clockIn), primary: false),
        (label: 'Pulang', value: _time(record.clockOut), primary: false),
        (
          label: 'Jam Kerja',
          value: duration == null
              ? '--'
              : '${duration.inHours}j ${duration.inMinutes.remainder(60)}m',
          primary: true,
        ),
      ];
      return Semantics(
        button: true,
        label: 'Buka Absensi',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scaled = MediaQuery.textScalerOf(context).scale(1) > 1.45;
            if (scaled || constraints.maxWidth < 330) {
              return Column(
                children: values
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MetricCard(item: item, onTap: onOpen),
                      ),
                    )
                    .toList(growable: false),
              );
            }
            return Row(
              children: values.indexed
                  .map((entry) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: entry.$1 == 0 ? 0 : 10),
                        child: _MetricCard(item: entry.$2, onTap: onOpen),
                      ),
                    );
                  })
                  .toList(growable: false),
            );
          },
        ),
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item, required this.onTap});
  final ({String label, String value, bool primary}) item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: item.primary
        ? AppColors.primary
        : Theme.of(context).colorScheme.surface,
    elevation: 1,
    shadowColor: Colors.black.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(AppRadius.smallCard),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.smallCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: item.primary
                    ? Colors.white.withValues(alpha: 0.85)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                item.value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: item.primary ? Colors.white : null,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    semanticLabel: 'Buka $label',
    child: Row(
      children: [
        AppIconTile(icon: icon, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
      ],
    ),
  );
}

class _Announcements extends StatelessWidget {
  const _Announcements({required this.dashboard, required this.onRetry});
  final DashboardSnapshot dashboard;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (dashboard.announcementsError != null) {
      return AppStateView(
        kind: AppViewStateKind.error,
        title: 'Pengumuman gagal dimuat',
        message: dashboard.announcementsError!,
        actionLabel: 'Coba lagi',
        onAction: onRetry,
      );
    }
    if (dashboard.announcements.isEmpty) {
      return const AppStateView(
        kind: AppViewStateKind.empty,
        title: 'Belum ada pengumuman',
        message: 'Tidak ada pengumuman baru dari server.',
      );
    }
    return AppSurfaceCard(
      child: Column(
        children: dashboard.announcements.indexed
            .map((entry) {
              final item = entry.$2;
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppIconTile(icon: Icons.campaign_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.body,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (item.time.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.time,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (entry.$1 < dashboard.announcements.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _LeaveBalanceCard extends StatelessWidget {
  const _LeaveBalanceCard({
    required this.dashboard,
    required this.selected,
    required this.onSelected,
    required this.onRetry,
  });
  final DashboardSnapshot dashboard;
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (dashboard.leaveBalancesError != null) {
      return AppStateView(
        kind: AppViewStateKind.error,
        title: 'Saldo cuti gagal dimuat',
        message: dashboard.leaveBalancesError!,
        actionLabel: 'Coba lagi',
        onAction: onRetry,
      );
    }
    if (dashboard.leaveBalances.isEmpty) {
      return const AppStateView(
        kind: AppViewStateKind.empty,
        title: 'Belum ada saldo cuti',
        message: 'Server tidak mengembalikan saldo untuk akun ini.',
      );
    }
    final index = selected.clamp(0, dashboard.leaveBalances.length - 1);
    final active = dashboard.leaveBalances[index];
    final remaining = (active.total - active.used).clamp(0, active.total);
    final progress = active.total == 0 ? 0.0 : remaining / active.total;
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saldo Cuti', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 320 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.35;
              final chart = Semantics(
                label:
                    '$remaining dari ${active.total} hari ${active.type} tersisa',
                child: SizedBox.square(
                  dimension: 124,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 14,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                      ),
                      ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$remaining',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            Text(
                              'hari',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
              final legend = Column(
                children: dashboard.leaveBalances.indexed
                    .map((entry) {
                      final value = (entry.$2.total - entry.$2.used).clamp(
                        0,
                        entry.$2.total,
                      );
                      return _BalanceRow(
                        label: entry.$2.type,
                        value: '$value h',
                        selected: entry.$1 == index,
                        onTap: () => onSelected(entry.$1),
                      );
                    })
                    .toList(growable: false),
              );
              return compact
                  ? Column(
                      children: [chart, const SizedBox(height: 14), legend],
                    )
                  : Row(
                      children: [
                        chart,
                        const SizedBox(width: 18),
                        Expanded(child: legend),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.surfaceContainer
        : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(value, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    ),
  );
}

String _time(DateTime? value) {
  if (value == null) return '-- : --';
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')} : ${local.minute.toString().padLeft(2, '0')}';
}
