import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/config/demo_mode.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/self_service_providers.dart';
import 'package:hrm_app/features/self_service/self_service_dependencies.dart';

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  RequestKind _kind = RequestKind.leave;
  bool _active = true;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final demoBuilder = ref.watch(demoRequestsBuilderProvider);
    if (demoBuilder != null) return demoBuilder(context);
    final session = ref.watch(featureSessionProvider);
    final query = RequestPageQuery(session: session, kind: _kind, page: _page);
    final state = ref.watch(requestPageProvider(query));
    final demo = ref.watch(demoModeProvider);
    final canCreateLeave =
        ref
            .watch(requestContextProvider)
            ?.permissions
            .contains('leave:create') ==
        true;
    final canCreateOvertime =
        ref
            .watch(requestContextProvider)
            ?.permissions
            .contains('attendance:create') ==
        true;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(requestPageProvider(query).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              16,
              AppSpacing.screenHorizontal,
              100,
            ),
            children: [
              AppPageHeader(
                title: 'Pengajuan',
                subtitle: demo
                    ? 'Data pengajuan lokal'
                    : 'Riwayat pengajuan Anda',
              ),
              const SizedBox(height: 18),
              state.when(
                loading: () => const AppStateView.loading(
                  title: 'Memuat pengajuan',
                  message: 'Mengambil status terbaru dari server.',
                ),
                error: (error, _) => AppStateView(
                  kind: AppViewStateKind.error,
                  title: 'Pengajuan gagal dimuat',
                  message: 'Periksa koneksi dan coba lagi.',
                  actionLabel: 'Coba lagi',
                  onAction: () => ref.invalidate(requestPageProvider(query)),
                ),
                data: (page) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RequestSummaryActions(
                      canCreateLeave: canCreateLeave,
                      pendingCount: page.items
                          .where((item) => item.status == RequestStatus.pending)
                          .length,
                      onCreate: () =>
                          _showCreateMenu(canCreateLeave, canCreateOvertime),
                    ),
                    const SizedBox(height: 10),
                    _RequestActionCard(
                      icon: Icons.apps_rounded,
                      title: 'Layanan Employee',
                      subtitle:
                          'Pinjaman, EWA, aktivitas, perjalanan, dan klaim',
                      onTap: () => context.push('/ess'),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 6,
                      runSpacing: 0,
                      children: [
                        _RequestFilterPill(
                          label: 'Cuti',
                          selected: _kind == RequestKind.leave,
                          onTap: () => setState(() {
                            _kind = RequestKind.leave;
                            _page = 1;
                          }),
                        ),
                        _RequestFilterPill(
                          label: 'Izin',
                          selected: _kind == RequestKind.permission,
                          onTap: () => setState(() {
                            _kind = RequestKind.permission;
                            _page = 1;
                          }),
                        ),
                        _RequestFilterPill(
                          label: 'Aktif',
                          selected: _active,
                          onTap: () => setState(() => _active = true),
                        ),
                        _RequestFilterPill(
                          label: 'Selesai',
                          selected: !_active,
                          onTap: () => setState(() => _active = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Riwayat',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _RequestList(
                      page: page,
                      active: _active,
                      onOpen: (item) {
                        if (item.kind == RequestKind.leave) {
                          context.push(
                            '/requests/leave/${item.id}',
                            extra: item,
                          );
                        } else {
                          _showPermissionDetail(item);
                        }
                      },
                      onPrevious: page.page > 1
                          ? () => setState(() => _page--)
                          : null,
                      onNext: page.hasNextPage
                          ? () => setState(() => _page++)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPermissionDetail(EmployeeRequest item) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        sheetAnimationStyle: AppMotion.sheetStyleOf(context),
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          minimum: const EdgeInsets.all(AppSpacing.lg),
          child: _RequestDetailSheet(item: item, closeOnSuccess: true),
        ),
      );

  Future<void> _showCreateMenu(bool canCreateLeave, bool canCreateOvertime) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        sheetAnimationStyle: AppMotion.sheetStyleOf(context),
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pilih jenis pengajuan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (canCreateLeave)
                ListTile(
                  leading: const AppIconTile(icon: Icons.beach_access_outlined),
                  title: const Text('Cuti'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/requests/leave/new');
                  },
                ),
              ListTile(
                leading: const AppIconTile(icon: Icons.description_outlined),
                title: const Text('Izin'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/requests/permission/new');
                },
              ),
              ListTile(
                leading: const AppIconTile(icon: Icons.edit_calendar_outlined),
                title: const Text('Koreksi absensi'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/attendance/requests?compose=true');
                },
              ),
              if (canCreateOvertime)
                ListTile(
                  leading: const AppIconTile(icon: Icons.more_time_rounded),
                  title: const Text('Lembur'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(
                      '/attendance/requests?tab=overtime&compose=true',
                    );
                  },
                ),
            ],
          ),
        ),
      );
}

class _RequestFilterPill extends StatelessWidget {
  const _RequestFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: IntrinsicWidth(
        child: SizedBox(
          height: 44,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Center(
                child: Container(
                  key: ValueKey('request-filter-$label'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? colors.primary : colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? colors.onPrimary : colors.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestActionCard extends StatelessWidget {
  const _RequestActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.primary = false,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: primary ? AppColors.primary : Theme.of(context).colorScheme.surface,
    elevation: primary ? 4 : 1,
    shadowColor: primary
        ? AppColors.primary.withValues(alpha: 0.45)
        : Colors.black12,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 21,
                color: primary
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: primary ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: primary ? Colors.white.withValues(alpha: 0.82) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RequestSummaryActions extends StatelessWidget {
  const _RequestSummaryActions({
    required this.canCreateLeave,
    required this.pendingCount,
    required this.onCreate,
  });

  final bool canCreateLeave;
  final int pendingCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final create = _RequestActionCard(
      primary: true,
      icon: Icons.add_rounded,
      title: 'Buat Pengajuan',
      subtitle: canCreateLeave ? 'Cuti atau izin' : 'Izin',
      onTap: onCreate,
    );
    final pending = _RequestActionCard(
      icon: Icons.schedule_rounded,
      title: 'Menunggu',
      subtitle: '$pendingCount di halaman ini',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.35;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [create, const SizedBox(height: 10), pending],
          );
        }
        return Row(
          children: [
            Expanded(child: create),
            const SizedBox(width: 10),
            Expanded(child: pending),
          ],
        );
      },
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.page,
    required this.active,
    required this.onOpen,
    required this.onPrevious,
    required this.onNext,
  });

  final EmployeeRequestPage page;
  final bool active;
  final ValueChanged<EmployeeRequest> onOpen;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final items = page.items
        .where((item) {
          final isActive = item.status == RequestStatus.pending;
          return active == isActive;
        })
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (page.items.isEmpty)
          const AppStateView(
            kind: AppViewStateKind.empty,
            title: 'Belum ada pengajuan',
            message: 'Pengajuan yang dikirim akan muncul di sini.',
          )
        else if (items.isEmpty)
          AppStateView(
            kind: AppViewStateKind.empty,
            title: active
                ? 'Tidak ada pengajuan aktif'
                : 'Belum ada yang selesai',
            message: 'Coba filter lain atau halaman berikutnya.',
          )
        else
          for (final item in items) ...[
            _RequestCard(item: item, onTap: () => onOpen(item)),
            const SizedBox(height: AppSpacing.sm),
          ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onPrevious,
                child: const Text('Sebelumnya'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: onNext,
                child: const Text('Berikutnya'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item, required this.onTap});
  final EmployeeRequest item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _status(item.status);
    return AppSurfaceCard(
      onTap: onTap,
      semanticLabel: '${item.type}, ${status.$1}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.type, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(item.dateRange),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Dikirim ${item.submittedOn}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          AppStatusChip(label: status.$1, tone: status.$2),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.id, this.initial});
  final String id;
  final EmployeeRequest? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(featureSessionProvider);
    final state = ref.watch(
      leaveRequestDetailProvider((session: session, id: id)),
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.md,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          children: [
            const AppDetailHeader(
              title: 'Detail pengajuan',
              subtitle: 'Status terbaru dari server',
            ),
            const SizedBox(height: AppSpacing.lg),
            state.when(
              loading: () => initial == null
                  ? const AppStateView.loading(
                      title: 'Memuat detail',
                      message: 'Mengambil status terbaru dari server.',
                    )
                  : _RequestDetailSheet(item: initial!),
              error: (_, _) => AppStateView(
                kind: AppViewStateKind.error,
                title: 'Detail gagal dimuat',
                message: 'Data awal tetap aman. Coba muat ulang status server.',
                actionLabel: 'Coba lagi',
                onAction: () => ref.invalidate(
                  leaveRequestDetailProvider((session: session, id: id)),
                ),
              ),
              data: (item) => _RequestDetailSheet(item: item),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestDetailSheet extends ConsumerStatefulWidget {
  const _RequestDetailSheet({required this.item, this.closeOnSuccess = false});

  final EmployeeRequest item;
  final bool closeOnSuccess;

  @override
  ConsumerState<_RequestDetailSheet> createState() =>
      _RequestDetailSheetState();
}

class _RequestDetailSheetState extends ConsumerState<_RequestDetailSheet> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _RequestDetailContent(item: widget.item),
      if (widget.item.status == RequestStatus.pending) ...[
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _cancelling ? null : _cancel,
          icon: _cancelling
              ? const SizedBox.square(
                  dimension: 18,
                  child: AppLoadingIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cancel_outlined),
          label: Text(_cancelling ? 'Membatalkan...' : 'Batalkan pengajuan'),
        ),
      ],
    ],
  );

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pengajuan?'),
        content: const Text(
          'Server akan menentukan apakah pengajuan ini masih dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || _cancelling) return;
    setState(() => _cancelling = true);
    try {
      await ref
          .read(requestRepositoryProvider)
          .cancel(widget.item.kind, widget.item.id);
      ref.invalidate(requestPageProvider);
      ref.invalidate(leaveRequestDetailProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pengajuan ${widget.item.id} dibatalkan di server.'),
        ),
      );
      if (widget.closeOnSuccess) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan belum dapat dibatalkan. Coba lagi.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

class _RequestDetailContent extends StatelessWidget {
  const _RequestDetailContent({required this.item});
  final EmployeeRequest item;

  @override
  Widget build(BuildContext context) {
    final status = _status(item.status);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.type,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  AppStatusChip(label: status.$1, tone: status.$2),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(item.dateRange),
              if (item.totalDays case final days?)
                Text('$days hari menurut server'),
              if (item.reason case final reason?) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Alasan', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(reason),
              ],
              if (item.rejectionReason case final reason?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Catatan keputusan',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(reason),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Linimasa', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _TimelineRow(
                label: 'Dikirim',
                detail: item.submittedOn,
                complete: true,
              ),
              _TimelineRow(
                label: status.$1,
                detail: item.approvedAt == null
                    ? 'Status terbaru dari server'
                    : _date(item.approvedAt!),
                complete: item.status != RequestStatus.pending,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.detail,
    required this.complete,
  });
  final String label;
  final String detail;
  final bool complete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Icon(
          complete
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 20,
          color: complete
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text('$label\n$detail')),
      ],
    ),
  );
}

(String, AppStatusTone) _status(RequestStatus status) => switch (status) {
  RequestStatus.pending => ('Menunggu', AppStatusTone.warning),
  RequestStatus.approved => ('Disetujui', AppStatusTone.success),
  RequestStatus.rejected => ('Ditolak', AppStatusTone.danger),
  RequestStatus.cancelled => ('Dibatalkan', AppStatusTone.neutral),
  RequestStatus.unknown => ('Status lain', AppStatusTone.neutral),
};

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
