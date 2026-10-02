import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_app/core/network/request_context.dart';
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

enum _RequestCategory { all, leave }

enum _RequestStatusFilter { all, pending, completed }

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  _RequestCategory _category = _RequestCategory.all;
  _RequestStatusFilter _status = _RequestStatusFilter.all;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(featureSessionProvider);
    final leaveQuery = RequestPageQuery(
      session: session,
      kind: RequestKind.leave,
      page: _page,
    );
    final permissionQuery = RequestPageQuery(
      session: session,
      kind: RequestKind.permission,
      page: _page,
    );
    final leaveState = ref.watch(requestPageProvider(leaveQuery));
    final permissionState = ref.watch(requestPageProvider(permissionQuery));
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
          onRefresh: () async {
            await Future.wait([
              ref.refresh(requestPageProvider(leaveQuery).future),
              ref.refresh(requestPageProvider(permissionQuery).future),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              16,
              AppSpacing.screenHorizontal,
              100,
            ),
            children: [
              _buildOverview(
                leaveState: leaveState,
                permissionState: permissionState,
                leaveQuery: leaveQuery,
                permissionQuery: permissionQuery,
                canCreateLeave: canCreateLeave,
                canCreateOvertime: canCreateOvertime,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverview({
    required AsyncValue<EmployeeRequestPage> leaveState,
    required AsyncValue<EmployeeRequestPage> permissionState,
    required RequestPageQuery leaveQuery,
    required RequestPageQuery permissionQuery,
    required bool canCreateLeave,
    required bool canCreateOvertime,
  }) {
    if (leaveState.hasError ||
        (_category == _RequestCategory.all && permissionState.hasError)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppPageHeader(
            title: 'Pengajuan',
            subtitle: 'Status pengajuan terbaru',
          ),
          const SizedBox(height: 18),
          AppStateView(
            kind: AppViewStateKind.error,
            title: 'Pengajuan gagal dimuat',
            message: 'Periksa koneksi dan coba lagi.',
            actionLabel: 'Coba lagi',
            onAction: () {
              ref.invalidate(requestPageProvider(leaveQuery));
              ref.invalidate(requestPageProvider(permissionQuery));
            },
          ),
        ],
      );
    }
    if (leaveState.isLoading ||
        (_category == _RequestCategory.all && permissionState.isLoading)) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: 'Pengajuan',
            subtitle: 'Status pengajuan terbaru',
          ),
          SizedBox(height: 18),
          AppStateView.loading(
            title: 'Memuat pengajuan',
            message: 'Mengambil status pengajuan terbaru.',
          ),
        ],
      );
    }

    final leave = leaveState.requireValue;
    final permission = permissionState.valueOrNull;
    final page = _category == _RequestCategory.leave
        ? leave
        : EmployeeRequestPage(
            items: [...leave.items, ...?permission?.items],
            page: _page,
            totalPages: leave.totalPages > (permission?.totalPages ?? 0)
                ? leave.totalPages
                : permission?.totalPages ?? leave.totalPages,
            total: leave.total + (permission?.total ?? 0),
          );
    final pending = page.items
        .where((item) => item.status == RequestStatus.pending)
        .length;
    final completed = page.items.length - pending;
    final completePage = page.totalPages <= 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          key: const ValueKey('requests-header'),
          title: 'Pengajuan',
          subtitle: completePage
              ? '$pending aktif · $completed selesai'
              : '${page.total} pengajuan · halaman ${page.page} dari ${page.totalPages}',
        ),
        const SizedBox(height: 18),
        _RequestSummaryActions(
          key: const ValueKey('requests-summary-actions'),
          canCreateLeave: canCreateLeave,
          pendingLabel: completePage
              ? '$pending perlu approval'
              : '$pending menunggu di halaman ini',
          onCreate: () => _showCreateMenu(canCreateLeave, canCreateOvertime),
          onPending: () =>
              setState(() => _status = _RequestStatusFilter.pending),
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: const ValueKey('requests-category-filters'),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _RequestFilterPill(
                  label: 'Semua',
                  selected: _category == _RequestCategory.all,
                  onTap: () => setState(() {
                    _category = _RequestCategory.all;
                    _page = 1;
                  }),
                ),
                const SizedBox(width: 7),
                _RequestFilterPill(
                  label: 'Cuti',
                  selected: _category == _RequestCategory.leave,
                  onTap: () => setState(() {
                    _category = _RequestCategory.leave;
                    _page = 1;
                  }),
                ),
                const SizedBox(width: 7),
                _RequestFilterPill(
                  label: 'Lembur',
                  selected: false,
                  onTap: () =>
                      context.push('/attendance/requests?tab=overtime'),
                ),
                const SizedBox(width: 7),
                _RequestFilterPill(
                  label: 'Reimburse',
                  selected: false,
                  onTap: () => context.push('/ess?area=travel'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          key: const ValueKey('requests-history-header'),
          children: [
            Expanded(
              child: Text(
                'Riwayat',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            PopupMenuButton<_RequestStatusFilter>(
              tooltip: 'Filter status pengajuan',
              onSelected: (value) => setState(() => _status = value),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _RequestStatusFilter.all,
                  child: Text('Semua'),
                ),
                PopupMenuItem(
                  value: _RequestStatusFilter.pending,
                  child: Text('Menunggu'),
                ),
                PopupMenuItem(
                  value: _RequestStatusFilter.completed,
                  child: Text('Selesai'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Text(
                  switch (_status) {
                    _RequestStatusFilter.all => 'Semua',
                    _RequestStatusFilter.pending => 'Menunggu',
                    _RequestStatusFilter.completed => 'Selesai',
                  },
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        KeyedSubtree(
          key: const ValueKey('requests-history-content'),
          child: _RequestList(
            page: page,
            status: _status,
            onOpen: (item) {
              if (item.kind == RequestKind.leave) {
                context.push('/requests/leave/${item.id}', extra: item);
              } else {
                _showPermissionDetail(item);
              }
            },
            onPrevious: page.page > 1 ? () => setState(() => _page--) : null,
            onNext: page.hasNextPage ? () => setState(() => _page++) : null,
          ),
        ),
      ],
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
      child: SizedBox(
        height: 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Align(
              widthFactor: 1,
              child: Container(
                key: ValueKey('request-filter-$label'),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
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
    super.key,
    required this.canCreateLeave,
    required this.pendingLabel,
    required this.onCreate,
    required this.onPending,
  });

  final bool canCreateLeave;
  final String pendingLabel;
  final VoidCallback onCreate;
  final VoidCallback onPending;

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
      subtitle: pendingLabel,
      onTap: onPending,
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
    required this.status,
    required this.onOpen,
    required this.onPrevious,
    required this.onNext,
  });

  final EmployeeRequestPage page;
  final _RequestStatusFilter status;
  final ValueChanged<EmployeeRequest> onOpen;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final items = page.items
        .where((item) {
          final isActive = item.status == RequestStatus.pending;
          return switch (status) {
            _RequestStatusFilter.all => true,
            _RequestStatusFilter.pending => isActive,
            _RequestStatusFilter.completed => !isActive,
          };
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
            title: status == _RequestStatusFilter.pending
                ? 'Tidak ada pengajuan aktif'
                : 'Belum ada pengajuan pada filter ini',
            message: 'Coba filter lain atau halaman berikutnya.',
          )
        else
          for (final item in items) ...[
            _RequestCard(item: item, onTap: () => onOpen(item)),
            const SizedBox(height: AppSpacing.sm),
          ],
        if (onPrevious != null || onNext != null)
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(
            children: [
              const AppIconTile(
                icon: Icons.insert_drive_file_outlined,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.totalDays == null
                          ? item.type
                          : '${item.type} · ${item.totalDays} hari',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      'Diajukan ${item.submittedOn}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );
          final statusChip = AppStatusChip(label: status.$1, tone: status.$2);
          if (constraints.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: statusChip),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 6),
              statusChip,
            ],
          );
        },
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
              subtitle: 'Status pengajuan terbaru',
            ),
            const SizedBox(height: AppSpacing.lg),
            state.when(
              loading: () => initial == null
                  ? const AppStateView.loading(
                      title: 'Memuat detail',
                      message: 'Mengambil status pengajuan terbaru.',
                    )
                  : _RequestDetailSheet(item: initial!),
              error: (_, _) => AppStateView(
                kind: AppViewStateKind.error,
                title: 'Detail gagal dimuat',
                message:
                    'Data awal tetap aman. Coba muat ulang status terbaru.',
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
          'Sistem akan memeriksa apakah pengajuan ini masih dapat dibatalkan.',
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
          content: Text('Pengajuan ${widget.item.id} berhasil dibatalkan.'),
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
              if (item.totalDays case final days?) Text('$days hari kerja'),
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
                    ? 'Status pengajuan terbaru'
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
