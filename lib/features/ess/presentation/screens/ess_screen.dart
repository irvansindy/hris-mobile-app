import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/ess/domain/ess_models.dart';
import 'package:hrm_app/features/ess/ess_providers.dart';
import 'package:hrm_app/features/ess/presentation/screens/ess_forms.dart';

enum EssArea { loan, ewa, activity, travel }

class EssScreen extends ConsumerStatefulWidget {
  const EssScreen({super.key, this.initialArea = EssArea.loan});

  final EssArea initialArea;

  @override
  ConsumerState<EssScreen> createState() => _EssScreenState();
}

class _EssScreenState extends ConsumerState<EssScreen> {
  late EssArea _area = widget.initialArea;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(featureSessionProvider);
    final permissions =
        ref.watch(requestContextProvider)?.permissions ?? const [];
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(session),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              16,
              AppSpacing.screenHorizontal,
              40,
            ),
            children: [
              const AppDetailHeader(
                title: 'Layanan Employee',
                subtitle: 'Status dan nominal langsung dari server',
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<EssArea>(
                key: const Key('ess-area-selector'),
                initialValue: _area,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pilih layanan',
                  prefixIcon: Icon(Icons.apps_rounded),
                ),
                items: EssArea.values
                    .map(
                      (area) => DropdownMenuItem(
                        value: area,
                        child: Text(_areaLabel(area)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _area = value);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              switch (_area) {
                EssArea.loan => _LoanPanel(
                  session: session,
                  canReadDetail: permissions.contains('employee-loan:read'),
                ),
                EssArea.ewa => _EwaPanel(
                  session: session,
                  canCreate: permissions.contains('ewa:create'),
                  canCancel: permissions.contains('ewa:update'),
                  canReadDetail: permissions.contains('ewa:read'),
                ),
                EssArea.activity => _ActivityPanel(
                  session: session,
                  canCreate: permissions.contains('daily-activity:create'),
                  canReadDetail: permissions.contains('daily-activity:read'),
                  canUpdate: permissions.contains('daily-activity:update'),
                  canDelete: permissions.contains('daily-activity:delete'),
                ),
                EssArea.travel => _TravelPanel(session: session),
              },
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(FeatureSession session) => switch (_area) {
    EssArea.loan => ref.refresh(loanSnapshotProvider(session).future),
    EssArea.ewa => ref.refresh(ewaSnapshotProvider(session).future),
    EssArea.activity => ref.refresh(activitySnapshotProvider(session).future),
    EssArea.travel => ref.refresh(travelSnapshotProvider(session).future),
  };
}

class _LoanPanel extends ConsumerWidget {
  const _LoanPanel({required this.session, required this.canReadDetail});
  final FeatureSession session;
  final bool canReadDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loanSnapshotProvider(session));
    return state.when(
      loading: () => const AppStateView.loading(
        title: 'Memuat pinjaman',
        message: 'Mengambil tipe dan riwayat pinjaman.',
      ),
      error: (_, _) => _ErrorState(
        title: 'Pinjaman gagal dimuat',
        onRetry: () => ref.invalidate(loanSnapshotProvider(session)),
      ),
      data: (snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: 'Pinjaman karyawan',
            description: 'Jadwal final dihitung oleh server.',
            actionLabel: snapshot.types.isEmpty ? null : 'Ajukan',
            onAction: snapshot.types.isEmpty
                ? null
                : () => showLoanForm(context, ref, snapshot.types),
          ),
          const SizedBox(height: AppSpacing.md),
          if (snapshot.types.isEmpty)
            const AppStateView(
              kind: AppViewStateKind.empty,
              title: 'Tipe pinjaman belum tersedia',
              message: 'Hubungi HR agar tipe pinjaman perusahaan diaktifkan.',
            )
          else if (snapshot.loans.isEmpty)
            const AppStateView(
              kind: AppViewStateKind.empty,
              title: 'Belum ada pinjaman',
              message: 'Pengajuan pinjaman Anda akan muncul di sini.',
            )
          else
            ...snapshot.loans.map(
              (loan) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RecordCard(
                  title: loan.loanTypeName,
                  amount: _money(loan.amount),
                  subtitle:
                      '${loan.totalInstallments} cicilan · ${_date(loan.createdAt)}',
                  status: loan.status,
                  actions: [
                    if (canReadDetail)
                      TextButton(
                        onPressed: () =>
                            _showLoanDetail(context, ref, session, loan),
                        child: const Text('Rincian'),
                      ),
                    if (loan.canCancel)
                      TextButton(
                        onPressed: () => _confirmMutation(
                          context,
                          ref,
                          title: 'Batalkan pinjaman?',
                          message:
                              'Pengajuan yang dibatalkan tidak dapat dipulihkan.',
                          action: () => ref
                              .read(essMutationProvider.notifier)
                              .cancelLoan(loan.id),
                        ),
                        child: const Text('Batalkan'),
                      ),
                  ],
                ),
              ),
            ),
          if (!canReadDetail && snapshot.loans.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            const _InfoNote(
              text: 'Jadwal cicilan membutuhkan izin employee-loan:read.',
            ),
          ],
        ],
      ),
    );
  }
}

class _EwaPanel extends ConsumerWidget {
  const _EwaPanel({
    required this.session,
    required this.canCreate,
    required this.canCancel,
    required this.canReadDetail,
  });
  final FeatureSession session;
  final bool canCreate;
  final bool canCancel;
  final bool canReadDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ewaSnapshotProvider(session));
    return state.when(
      loading: () => const AppStateView.loading(
        title: 'Memuat EWA',
        message: 'Menghitung limit dari payroll dan kehadiran server.',
      ),
      error: (_, _) => _ErrorState(
        title: 'EWA gagal dimuat',
        onRetry: () => ref.invalidate(ewaSnapshotProvider(session)),
      ),
      data: (snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: 'Earned Wage Access',
            description: 'Limit dihitung server dari pendapatan berjalan.',
            actionLabel: canCreate && snapshot.limit.remaining > 0
                ? 'Ajukan'
                : null,
            onAction: canCreate && snapshot.limit.remaining > 0
                ? () => showEwaForm(context, ref, snapshot.limit)
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sisa limit',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _money(snapshot.limit.remaining),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Maksimum ${_money(snapshot.limit.maximum)} · Dicadangkan ${_money(snapshot.limit.totalReserved)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!canCreate) ...[
            const SizedBox(height: AppSpacing.sm),
            const _InfoNote(
              text:
                  'Akun ini belum memiliki izin ewa:create. Riwayat dan limit tetap dapat dilihat.',
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Riwayat', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (snapshot.requests.isEmpty)
            const AppStateView(
              kind: AppViewStateKind.empty,
              title: 'Belum ada pengajuan EWA',
              message: 'Pengajuan yang dikirim akan muncul di sini.',
            )
          else
            ...snapshot.requests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RecordCard(
                  title: request.requestCode ?? 'Pengajuan EWA',
                  amount: _money(request.amount),
                  subtitle: _date(request.createdAt),
                  status: request.status,
                  actions: [
                    if (canReadDetail)
                      TextButton(
                        onPressed: () =>
                            _showEwaDetail(context, session, request.id),
                        child: const Text('Rincian'),
                      ),
                    if (canCancel && request.canCancel)
                      TextButton(
                        onPressed: () => _confirmMutation(
                          context,
                          ref,
                          title: 'Batalkan EWA?',
                          message:
                              'Pengajuan yang dibatalkan tidak dapat dipulihkan.',
                          action: () => ref
                              .read(essMutationProvider.notifier)
                              .cancelEwa(request.id),
                        ),
                        child: const Text('Batalkan'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends ConsumerWidget {
  const _ActivityPanel({
    required this.session,
    required this.canCreate,
    required this.canReadDetail,
    required this.canUpdate,
    required this.canDelete,
  });
  final FeatureSession session;
  final bool canCreate;
  final bool canReadDetail;
  final bool canUpdate;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activitySnapshotProvider(session));
    return state.when(
      loading: () => const AppStateView.loading(
        title: 'Memuat aktivitas',
        message: 'Mengambil aktivitas bulan berjalan.',
      ),
      error: (_, _) => _ErrorState(
        title: 'Aktivitas gagal dimuat',
        onRetry: () => ref.invalidate(activitySnapshotProvider(session)),
      ),
      data: (snapshot) {
        final canCompose = canCreate && snapshot.branch != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(
              title: 'Aktivitas harian',
              description: 'GPS diambil saat aktivitas dikirim.',
              actionLabel: canCompose ? 'Catat' : null,
              onAction: canCompose
                  ? () =>
                        showActivityForm(context, ref, branch: snapshot.branch!)
                  : null,
            ),
            if (!canCreate) ...[
              const SizedBox(height: AppSpacing.sm),
              const _InfoNote(
                text: 'Akun ini belum memiliki izin daily-activity:create.',
              ),
            ] else if (snapshot.branch == null) ...[
              const SizedBox(height: AppSpacing.sm),
              const _InfoNote(
                text:
                    'Cabang employee belum dapat dibaca. Aktivitas tidak dapat dikirim tanpa branch ID dari server.',
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (snapshot.activities.isEmpty)
              const AppStateView(
                kind: AppViewStateKind.empty,
                title: 'Belum ada aktivitas bulan ini',
                message: 'Aktivitas yang dikirim akan muncul di sini.',
              )
            else
              ...snapshot.activities.map(
                (activity) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _RecordCard(
                    title: activity.title,
                    amount: _activityLabel(activity.type),
                    subtitle:
                        '${_date(activity.activityDate)} · ${activity.branchName}',
                    status:
                        '${_time(activity.startTime)}–${_time(activity.endTime)}',
                    actions: [
                      if (canReadDetail)
                        TextButton(
                          onPressed: () => _showActivityDetail(
                            context,
                            session,
                            activity.id,
                          ),
                          child: const Text('Rincian'),
                        ),
                      if (canUpdate)
                        TextButton(
                          onPressed: () => showActivityForm(
                            context,
                            ref,
                            branch: snapshot.branch,
                            existing: activity,
                          ),
                          child: const Text('Ubah'),
                        ),
                      if (canDelete)
                        TextButton(
                          onPressed: () => _confirmMutation(
                            context,
                            ref,
                            title: 'Hapus aktivitas?',
                            message: 'Data akan dihapus dari server.',
                            action: () => ref
                                .read(essMutationProvider.notifier)
                                .deleteActivity(activity.id),
                          ),
                          child: const Text('Hapus'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TravelPanel extends ConsumerWidget {
  const _TravelPanel({required this.session});
  final FeatureSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(travelSnapshotProvider(session));
    return state.when(
      loading: () => const AppStateView.loading(
        title: 'Memuat perjalanan',
        message: 'Mengambil perjalanan dan klaim biaya.',
      ),
      error: (_, _) => _ErrorState(
        title: 'Perjalanan gagal dimuat',
        onRetry: () => ref.invalidate(travelSnapshotProvider(session)),
      ),
      data: (snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: 'Perjalanan dan klaim',
            description: 'Ajukan perjalanan atau biaya aktual.',
            actionLabel: 'Buat',
            onAction: () => showTravelMenu(context, ref, snapshot),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Perjalanan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (snapshot.trips.isEmpty)
            const AppStateView(
              kind: AppViewStateKind.empty,
              title: 'Belum ada perjalanan',
              message: 'Pengajuan perjalanan Anda akan muncul di sini.',
            )
          else
            ...snapshot.trips.map(
              (trip) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RecordCard(
                  title: trip.destination,
                  amount: _money(trip.estimatedCost),
                  subtitle: '${_date(trip.startDate)}–${_date(trip.endDate)}',
                  status: trip.status,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('Klaim biaya', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (snapshot.claims.isEmpty)
            const AppStateView(
              kind: AppViewStateKind.empty,
              title: 'Belum ada klaim',
              message: 'Klaim biaya Anda akan muncul di sini.',
            )
          else
            ...snapshot.claims.map(
              (claim) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RecordCard(
                  title: _activityLabel(claim.category),
                  amount: _money(claim.amount),
                  subtitle: _date(claim.expenseDate),
                  status: claim.status,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          const _InfoNote(
            text:
                'Aksi persetujuan loan dan perjalanan diproses melalui Approval Center. EWA masih memakai action domain karena backend belum menghubungkannya ke workflow generik.',
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.status,
    this.actions = const [],
  });
  final String title;
  final String amount;
  final String subtitle;
  final String status;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(amount, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: AppStatusChip(
                label: _statusLabel(status),
                tone: _tone(status),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.xs,
            children: actions,
          ),
        ],
      ],
    ),
  );
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.input),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.onRetry});
  final String title;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppStateView(
    kind: AppViewStateKind.error,
    title: title,
    message: 'Periksa koneksi dan coba lagi.',
    actionLabel: 'Coba lagi',
    onAction: onRetry,
  );
}

Future<void> _showLoanDetail(
  BuildContext context,
  WidgetRef ref,
  FeatureSession session,
  EmployeeLoan loan,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => Consumer(
    builder: (context, ref, _) {
      final state = ref.watch(
        loanDetailProvider((session: session, id: loan.id)),
      );
      return SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: state.when(
          loading: () => const AppStateView.loading(
            title: 'Memuat jadwal',
            message: 'Mengambil cicilan dan amortisasi server.',
          ),
          error: (_, _) => const AppStateView(
            kind: AppViewStateKind.error,
            title: 'Jadwal gagal dimuat',
            message: 'Periksa izin dan koneksi lalu coba lagi.',
          ),
          data: (detail) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Rincian pinjaman',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Total pembayaran ${_money(detail.amortization.totalPayment)}',
                ),
                Text(
                  'Total bunga ${_money(detail.amortization.totalInterest)}',
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Cicilan server',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (detail.installments.isEmpty)
                  const Text('Jadwal cicilan belum diterbitkan.')
                else
                  ...detail.installments.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_money(item.amount)),
                      subtitle: Text(_date(item.dueDate)),
                      trailing: AppStatusChip(
                        label: _statusLabel(item.status),
                        tone: _tone(item.status),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  ),
);

Future<void> _showEwaDetail(
  BuildContext context,
  FeatureSession session,
  String id,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => Consumer(
    builder: (context, ref, _) {
      final state = ref.watch(ewaDetailProvider((session: session, id: id)));
      return SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: state.when(
          loading: () => const AppStateView.loading(
            title: 'Memuat rincian EWA',
            message: 'Mengambil status terbaru dari server.',
          ),
          error: (_, _) => const AppStateView(
            kind: AppViewStateKind.error,
            title: 'Rincian EWA gagal dimuat',
            message: 'Periksa izin dan koneksi lalu coba lagi.',
          ),
          data: (request) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                request.requestCode ?? 'Rincian EWA',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _money(request.amount),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: AppStatusChip(
                  label: _statusLabel(request.status),
                  tone: _tone(request.status),
                ),
              ),
              if (request.reason != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(request.reason!),
              ],
            ],
          ),
        ),
      );
    },
  ),
);

Future<void> _showActivityDetail(
  BuildContext context,
  FeatureSession session,
  String id,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => Consumer(
    builder: (context, ref, _) {
      final state = ref.watch(
        activityDetailProvider((session: session, id: id)),
      );
      return SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: state.when(
          loading: () => const AppStateView.loading(
            title: 'Memuat rincian aktivitas',
            message: 'Mengambil data terbaru dari server.',
          ),
          error: (_, _) => const AppStateView(
            kind: AppViewStateKind.error,
            title: 'Rincian aktivitas gagal dimuat',
            message: 'Periksa izin dan koneksi lalu coba lagi.',
          ),
          data: (activity) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                activity.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('${_activityLabel(activity.type)} · ${activity.branchName}'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_date(activity.activityDate)} · ${_time(activity.startTime)}–${_time(activity.endTime)}',
              ),
              if (activity.description != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(activity.description!),
              ],
              if (activity.notes != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(activity.notes!),
              ],
            ],
          ),
        ),
      );
    },
  ),
);

Future<void> _confirmMutation(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
  required Future<void> Function() action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Kembali'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Lanjutkan'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await action();
    if (context.mounted) {
      _snack(context, 'Perubahan telah dikonfirmasi server.');
    }
  } catch (error) {
    if (context.mounted) _snack(context, _errorMessage(error), error: true);
  }
}

String _areaLabel(EssArea area) => switch (area) {
  EssArea.loan => 'Pinjaman karyawan',
  EssArea.ewa => 'Earned Wage Access',
  EssArea.activity => 'Aktivitas harian',
  EssArea.travel => 'Perjalanan dan klaim',
};

String _money(double value) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
).format(value);

String _date(DateTime? value) => value == null
    ? 'Tanggal belum tersedia'
    : DateFormat('d MMM yyyy', 'id_ID').format(value);

String _time(DateTime value) => DateFormat('HH:mm').format(value);

String _activityLabel(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

String _statusLabel(String status) => _activityLabel(status);

AppStatusTone _tone(String status) => switch (status.toUpperCase()) {
  'APPROVED' ||
  'ACTIVE' ||
  'PAID' ||
  'REIMBURSED' ||
  'COMPLETED' => AppStatusTone.success,
  'REJECTED' || 'OVERDUE' => AppStatusTone.danger,
  'PENDING' || 'REQUESTED' || 'SUBMITTED' => AppStatusTone.warning,
  'CANCELLED' || 'CANCELED' => AppStatusTone.neutral,
  _ => AppStatusTone.info,
};

String _errorMessage(Object error) {
  final text = error.toString();
  if (text.startsWith('ApiException(') && text.contains(': ')) {
    return text.substring(text.indexOf(': ') + 2);
  }
  return 'Permintaan gagal. Periksa data dan koneksi lalu coba lagi.';
}

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ),
  );
}
