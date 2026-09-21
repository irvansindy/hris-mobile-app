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

class ApprovalDelegationsScreen extends ConsumerStatefulWidget {
  const ApprovalDelegationsScreen({super.key});

  @override
  ConsumerState<ApprovalDelegationsScreen> createState() =>
      _ApprovalDelegationsScreenState();
}

class _ApprovalDelegationsScreenState
    extends ConsumerState<ApprovalDelegationsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(featureSessionProvider);
    final state = ref.watch(approvalDelegationsProvider(session));
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.refresh(approvalDelegationsProvider(session).future),
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
                title: 'Delegasi approval',
                subtitle: 'Alihkan keputusan selama periode tertentu',
                onBack: () => context.pop(),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const ValueKey('delegation-create'),
                  onPressed: _busy ? null : () => _create(session),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Buat delegasi'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              state.when(
                loading: () => const AppStateView.loading(
                  title: 'Memuat delegasi',
                  message: 'Mengambil periode delegasi terbaru.',
                ),
                error: (_, _) => AppStateView(
                  kind: AppViewStateKind.error,
                  title: 'Delegasi gagal dimuat',
                  message: 'Periksa koneksi lalu coba lagi.',
                  actionLabel: 'Coba lagi',
                  onAction: () =>
                      ref.invalidate(approvalDelegationsProvider(session)),
                ),
                data: (items) => items.isEmpty
                    ? const AppStateView(
                        kind: AppViewStateKind.empty,
                        title: 'Belum ada delegasi',
                        message:
                            'Buat delegasi ketika keputusan perlu dialihkan sementara.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Riwayat delegasi',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final item in items) ...[
                            _DelegationCard(
                              item: item,
                              busy: _busy,
                              onRevoke: item.isActive
                                  ? () => _revoke(session, item)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(FeatureSession session) async {
    final command = await showModalBottomSheet<CreateApprovalDelegation>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: AppMotion.sheetStyleOf(context),
      builder: (_) => const _CreateDelegationSheet(),
    );
    if (command == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(approvalRepositoryProvider).createDelegation(command);
      ref.invalidate(approvalDelegationsProvider(session));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delegasi berhasil dibuat.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_delegationError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(FeatureSession session, ApprovalDelegation item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (context) => AlertDialog(
        title: const Text('Cabut delegasi?'),
        content: const Text(
          'Penerima tidak lagi dapat bertindak atas nama Anda setelah server mengonfirmasi pencabutan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cabut delegasi'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(approvalRepositoryProvider).revokeDelegation(item.id);
      ref.invalidate(approvalDelegationsProvider(session));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delegasi berhasil dicabut.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_delegationError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _DelegationCard extends StatelessWidget {
  const _DelegationCard({
    required this.item,
    required this.busy,
    this.onRevoke,
  });

  final ApprovalDelegation item;
  final bool busy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppIconTile(icon: Icons.people_outline_rounded),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.delegateLabel ?? 'Penerima terdaftar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_date(item.startDate)} sampai ${_date(item.endDate)}',
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            AppStatusChip(
              label: item.isActive ? 'Aktif' : 'Dicabut',
              tone: item.isActive
                  ? AppStatusTone.success
                  : AppStatusTone.neutral,
            ),
          ],
        ),
        if (item.reason case final reason?) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(reason, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (onRevoke != null) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: ValueKey('delegation-revoke-${item.id}'),
            onPressed: busy ? null : onRevoke,
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Cabut delegasi'),
          ),
        ],
      ],
    ),
  );
}

class _CreateDelegationSheet extends StatefulWidget {
  const _CreateDelegationSheet();

  @override
  State<_CreateDelegationSheet> createState() => _CreateDelegationSheetState();
}

class _CreateDelegationSheetState extends State<_CreateDelegationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _delegateController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime? _start;
  DateTime? _end;

  @override
  void dispose() {
    _delegateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.xs,
      AppSpacing.screenHorizontal,
      AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Buat delegasi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Gunakan ID pengguna penerima yang diberikan administrator HRIS.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            key: const ValueKey('delegation-user-id'),
            controller: _delegateController,
            decoration: const InputDecoration(
              labelText: 'ID pengguna penerima',
              hintText: 'Masukkan ID pengguna',
            ),
            autocorrect: false,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'ID pengguna penerima wajib diisi.'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _DateField(
            label: 'Tanggal mulai',
            value: _start,
            onTap: () => _pickDate(start: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DateField(
            label: 'Tanggal selesai',
            value: _end,
            onTap: () => _pickDate(start: false),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _reasonController,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alasan (opsional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const ValueKey('delegation-submit'),
            onPressed: _submit,
            child: const Text('Simpan delegasi'),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickDate({required bool start}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? (_start ?? today) : (_end ?? _start ?? today),
      firstDate: today,
      lastDate: DateTime(today.year + 2, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _start = selected;
        if (_end != null && !_end!.isAfter(selected)) _end = null;
      } else {
        _end = selected;
      }
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi periode delegasi.')),
      );
      return;
    }
    final start = DateTime(_start!.year, _start!.month, _start!.day);
    final end = DateTime(_end!.year, _end!.month, _end!.day, 23, 59, 59);
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal selesai harus setelah tanggal mulai.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      CreateApprovalDelegation(
        delegateId: _delegateController.text.trim(),
        startDate: start,
        endDate: end,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      minimumSize: const Size.fromHeight(56),
    ),
    child: Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(value == null ? label : '$label: ${_date(value!)}'),
        ),
      ],
    ),
  );
}

String _delegationError(Object error) {
  if (error is ApiException) {
    return switch (error.statusCode) {
      403 => 'Anda tidak memiliki izin untuk mengubah delegasi.',
      404 => 'Penerima atau delegasi tidak ditemukan.',
      409 => 'Delegasi sudah berubah. Muat ulang daftar.',
      _ => error.message,
    };
  }
  return 'Delegasi belum dapat disimpan. Coba lagi.';
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
