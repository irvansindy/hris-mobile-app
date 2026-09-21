import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/approvals/approval_dependencies.dart';
import 'package:hrm_app/features/approvals/approval_providers.dart';
import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';

class ApprovalCenterScreen extends ConsumerStatefulWidget {
  const ApprovalCenterScreen({super.key});

  @override
  ConsumerState<ApprovalCenterScreen> createState() =>
      _ApprovalCenterScreenState();
}

class _ApprovalCenterScreenState extends ConsumerState<ApprovalCenterScreen> {
  int _page = 1;
  bool _busy = false;
  final Set<String> _selected = {};
  Map<String, String> _itemErrors = const {};

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(featureSessionProvider);
    final query = ApprovalQueueQuery(session: session, page: _page);
    final state = ref.watch(approvalQueueProvider(query));
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(approvalQueueProvider(query).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
            ),
            children: [
              AppDetailHeader(
                title: 'Approval Center',
                subtitle: 'Persetujuan yang menunggu keputusan Anda',
                onBack: () => context.pop(),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: const ValueKey('approval-delegations'),
                  onPressed: _busy
                      ? null
                      : () => context.push('/approvals/delegations'),
                  icon: const Icon(Icons.people_outline_rounded),
                  label: const Text('Delegasi'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              state.when(
                loading: () => const AppStateView.loading(
                  title: 'Memuat antrean approval',
                  message: 'Mengambil keputusan yang masih menunggu.',
                ),
                error: (error, _) => AppStateView(
                  kind: error is ApiException && error.statusCode == 403
                      ? AppViewStateKind.permission
                      : AppViewStateKind.error,
                  title: error is ApiException && error.statusCode == 403
                      ? 'Akses Approval Center ditolak'
                      : 'Antrean approval gagal dimuat',
                  message: error is ApiException && error.statusCode == 403
                      ? 'Akun ini belum memiliki permission workflow:approve.'
                      : 'Periksa koneksi lalu muat ulang antrean.',
                  actionLabel: 'Coba lagi',
                  onAction: () => ref.invalidate(approvalQueueProvider(query)),
                ),
                data: (page) => _buildQueue(context, query, page),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueue(
    BuildContext context,
    ApprovalQueueQuery query,
    WorkflowApprovalPage page,
  ) {
    if (page.items.isEmpty) {
      return const AppStateView(
        key: ValueKey('approval-empty'),
        kind: AppViewStateKind.empty,
        title: 'Tidak ada approval menunggu',
        message:
            'Antrean akan terisi saat ada pengajuan yang perlu diputuskan.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QueueSummary(
          total: page.total,
          selected: _selected.length,
          busy: _busy,
          onApproveSelected: _selected.isEmpty
              ? null
              : () => _bulkApprove(query),
          onClearSelection: _selected.isEmpty
              ? null
              : () => setState(_selected.clear),
        ),
        const SizedBox(height: AppSpacing.section),
        Text(
          'Menunggu keputusan',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in page.items) ...[
          _ApprovalCard(
            item: item,
            selected: _selected.contains(item.instanceId),
            busy: _busy,
            error: _itemErrors[item.instanceId],
            onSelected: (value) => setState(() {
              if (value) {
                _selected.add(item.instanceId);
              } else {
                _selected.remove(item.instanceId);
              }
            }),
            onOpen: () => _showDetail(query, item),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _page > 1 && !_busy
                    ? () => setState(() {
                        _page--;
                        _selected.clear();
                        _itemErrors = const {};
                      })
                    : null,
                child: const Text('Sebelumnya'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: page.hasMore && !_busy
                    ? () => setState(() {
                        _page++;
                        _selected.clear();
                        _itemErrors = const {};
                      })
                    : null,
                child: const Text('Berikutnya'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showDetail(ApprovalQueueQuery query, WorkflowApproval item) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        sheetAnimationStyle: AppMotion.sheetStyleOf(context),
        builder: (sheetContext) => _ApprovalDetailSheet(
          item: item,
          busy: _busy,
          onAction: (action) async {
            Navigator.pop(sheetContext);
            await _runAction(query, item, action);
          },
        ),
      );

  Future<void> _runAction(
    ApprovalQueueQuery query,
    WorkflowApproval item,
    WorkflowApprovalAction action,
  ) async {
    if (_busy) return;
    final comment = await showDialog<String?>(
      context: context,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (_) => _ApprovalActionDialog(action: action, item: item),
    );
    if (comment == null || !mounted) return;
    setState(() {
      _busy = true;
      _itemErrors = {..._itemErrors}..remove(item.instanceId);
    });
    try {
      await ref
          .read(approvalRepositoryProvider)
          .applyAction(
            instanceId: item.instanceId,
            action: action,
            comment: comment.isEmpty ? null : comment,
          );
      _selected.remove(item.instanceId);
      ref.invalidate(approvalQueueProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_actionLabel(action)} berhasil disimpan.')),
      );
    } catch (error) {
      final message = _approvalError(error);
      if (error is ApiException &&
          (error.statusCode == 404 || error.statusCode == 409)) {
        ref.invalidate(approvalQueueProvider(query));
      }
      if (mounted) {
        setState(
          () => _itemErrors = {..._itemErrors, item.instanceId: message},
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkApprove(ApprovalQueueQuery query) async {
    if (_busy || _selected.isEmpty) return;
    final comment = await showDialog<String?>(
      context: context,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (_) => _BulkApprovalDialog(count: _selected.length),
    );
    if (comment == null || !mounted) return;
    final requested = _selected.toList(growable: false);
    setState(() {
      _busy = true;
      _itemErrors = const {};
    });
    try {
      final result = await ref
          .read(approvalRepositoryProvider)
          .applyBulkAction(
            instanceIds: requested,
            action: WorkflowApprovalAction.approve,
            comment: comment.isEmpty ? null : comment,
          );
      final errors = {
        for (final item in result.results)
          if (!item.success)
            item.instanceId: item.error ?? 'Approval tidak dapat diproses.',
      };
      _selected
        ..clear()
        ..addAll(errors.keys);
      _itemErrors = errors;
      ref.invalidate(approvalQueueProvider(query));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.successful} berhasil, ${result.failed} perlu ditinjau.',
          ),
        ),
      );
    } catch (error) {
      final message = _approvalError(error);
      if (error is ApiException &&
          (error.statusCode == 404 || error.statusCode == 409)) {
        ref.invalidate(approvalQueueProvider(query));
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({
    required this.total,
    required this.selected,
    required this.busy,
    this.onApproveSelected,
    this.onClearSelection,
  });

  final int total;
  final int selected;
  final bool busy;
  final VoidCallback? onApproveSelected;
  final VoidCallback? onClearSelection;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const AppIconTile(icon: Icons.fact_check_outlined),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$total approval menunggu',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    selected == 0
                        ? 'Pilih item untuk persetujuan sekaligus.'
                        : '$selected item dipilih.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (selected > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: busy ? null : onClearSelection,
                child: const Text('Batalkan pilihan'),
              ),
              FilledButton.icon(
                key: const ValueKey('approval-bulk-submit'),
                onPressed: busy ? null : onApproveSelected,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: AppLoadingIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Setujui terpilih'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.item,
    required this.selected,
    required this.busy,
    required this.onSelected,
    required this.onOpen,
    this.error,
  });

  final WorkflowApproval item;
  final bool selected;
  final bool busy;
  final ValueChanged<bool> onSelected;
  final VoidCallback onOpen;
  final String? error;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    key: ValueKey('approval-card-${item.instanceId}'),
    onTap: busy ? null : onOpen,
    semanticLabel: '${item.title}, menunggu keputusan',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Pilih ${item.title}',
              child: Checkbox(
                key: ValueKey('approval-select-${item.instanceId}'),
                value: selected,
                onChanged: busy ? null : (value) => onSelected(value ?? false),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppStatusChip(
                        label: 'Menunggu',
                        tone: AppStatusTone.warning,
                      ),
                      AppStatusChip(
                        label: _referenceLabel(item.referenceType),
                        tone: AppStatusTone.info,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          item.requesterLabel == null
              ? item.stepName
              : '${item.requesterLabel} · ${item.stepName}',
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Dikirim ${_date(item.submittedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    ),
  );
}

class _ApprovalDetailSheet extends StatelessWidget {
  const _ApprovalDetailSheet({
    required this.item,
    required this.busy,
    required this.onAction,
  });

  final WorkflowApproval item;
  final bool busy;
  final ValueChanged<WorkflowApprovalAction> onAction;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.xs,
      AppSpacing.screenHorizontal,
      AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(item.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tinjau ringkasan server sebelum menentukan keputusan.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(
                label: 'Jenis',
                value: _referenceLabel(item.referenceType),
              ),
              _DetailRow(
                label: 'Pemohon',
                value: item.requesterLabel ?? 'Tidak dicantumkan server',
              ),
              _DetailRow(label: 'Tahap', value: item.stepName),
              _DetailRow(label: 'Dikirim', value: _date(item.submittedAt)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => onAction(WorkflowApprovalAction.approve),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Setujui'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => onAction(WorkflowApprovalAction.reject),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Tolak dengan alasan'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          onPressed: busy
              ? null
              : () => onAction(WorkflowApprovalAction.escalate),
          icon: const Icon(Icons.forward_to_inbox_outlined),
          label: const Text('Eskalasi'),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _ApprovalActionDialog extends StatefulWidget {
  const _ApprovalActionDialog({required this.action, required this.item});
  final WorkflowApprovalAction action;
  final WorkflowApproval item;

  @override
  State<_ApprovalActionDialog> createState() => _ApprovalActionDialogState();
}

class _ApprovalActionDialogState extends State<_ApprovalActionDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reject = widget.action == WorkflowApprovalAction.reject;
    return AlertDialog(
      scrollable: true,
      title: Text('${_actionLabel(widget.action)} ${widget.item.title}?'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          minLines: 3,
          maxLines: 5,
          maxLength: 2000,
          autofocus: reject,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: reject ? 'Alasan penolakan' : 'Catatan (opsional)',
            alignLabelWithHint: true,
          ),
          validator: (value) =>
              reject && (value == null || value.trim().isEmpty)
              ? 'Alasan penolakan wajib diisi.'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kembali'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, _controller.text.trim());
          },
          child: Text(_actionLabel(widget.action)),
        ),
      ],
    );
  }
}

class _BulkApprovalDialog extends StatefulWidget {
  const _BulkApprovalDialog({required this.count});
  final int count;

  @override
  State<_BulkApprovalDialog> createState() => _BulkApprovalDialogState();
}

class _BulkApprovalDialogState extends State<_BulkApprovalDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text('Setujui ${widget.count} item?'),
    content: TextField(
      controller: _controller,
      minLines: 2,
      maxLines: 4,
      maxLength: 2000,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Catatan (opsional)',
        alignLabelWithHint: true,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Kembali'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Setujui terpilih'),
      ),
    ],
  );
}

String _referenceLabel(String value) => switch (value.toUpperCase()) {
  'LEAVE_REQUEST' => 'Cuti',
  'PERMISSION_REQUEST' => 'Izin',
  'OVERTIME_REQUEST' => 'Lembur',
  'ATTENDANCE_CORRECTION' => 'Koreksi absensi',
  'SHIFT_SWAP_REQUEST' => 'Tukar shift',
  'EXPENSE_CLAIM' => 'Reimbursement',
  'BUSINESS_TRIP' => 'Perjalanan dinas',
  'LOAN_REQUEST' => 'Pinjaman',
  'CAREER_MOVEMENT' => 'Perubahan karier',
  _ => 'Pengajuan',
};

String _actionLabel(WorkflowApprovalAction action) => switch (action) {
  WorkflowApprovalAction.approve => 'Setujui',
  WorkflowApprovalAction.reject => 'Tolak',
  WorkflowApprovalAction.escalate => 'Eskalasi',
};

String _approvalError(Object error) {
  if (error is ApiException) {
    return switch (error.statusCode) {
      403 => 'Anda tidak lagi memiliki izin untuk keputusan ini.',
      404 => 'Approval tidak ditemukan. Antrean akan dimuat ulang.',
      409 => 'Approval sudah berubah. Antrean akan dimuat ulang.',
      _ => error.message,
    };
  }
  return 'Keputusan belum dapat disimpan. Coba lagi.';
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
