import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/sensitive_screen.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/payroll_providers.dart';
import 'package:hrm_app/features/payroll/presentation/controllers/payroll_controller.dart';
import 'package:hrm_app/features/payroll/presentation/screens/payslip_detail_screen.dart';

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = ref.read(requestContextProvider);
      if (context?.hasPermission('payroll:read') == true) {
        ref.read(payrollControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestContext = ref.watch(requestContextProvider);
    if (requestContext?.hasPermission('payroll:read') != true) {
      return const Scaffold(
        body: SafeArea(
          minimum: EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Center(
            child: AppStateView(
              kind: AppViewStateKind.permission,
              title: 'Akses slip gaji terbatas',
              message: 'Akun ini tidak memiliki izin payroll:read.',
            ),
          ),
        ),
      );
    }

    final state = ref.watch(payrollControllerProvider);
    return SensitiveScreen(
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: ref.read(payrollControllerProvider.notifier).load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                18,
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
              ),
              children: [
                _Header(key: const ValueKey('payroll-header')),
                const SizedBox(height: AppSpacing.section),
                const _SecurityNote(key: ValueKey('payroll-security-note')),
                const SizedBox(height: AppSpacing.section),
                KeyedSubtree(
                  key: const ValueKey('payroll-list'),
                  child: _buildList(state),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(PayrollState state) {
    if (state.loading && state.summaries.isEmpty) {
      return const AppStateView.loading(
        title: 'Memuat slip gaji',
        message: 'Mengambil daftar periode yang tersedia.',
      );
    }
    if (state.error != null && state.summaries.isEmpty) {
      return AppStateView(
        kind: AppViewStateKind.error,
        title: 'Slip gaji gagal dimuat',
        message: _message(state.error),
        actionLabel: 'Coba lagi',
        onAction: ref.read(payrollControllerProvider.notifier).load,
      );
    }
    if (state.summaries.isEmpty) {
      return const AppStateView(
        kind: AppViewStateKind.empty,
        title: 'Slip gaji belum tersedia',
        message: 'Belum ada periode payroll untuk akun ini.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionLabel('Riwayat slip gaji'),
        for (final summary in state.summaries) ...[
          _SummaryCard(
            key: ValueKey(summary.id),
            summary: summary,
            onTap: () => _open(summary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Future<void> _open(PayslipSummary summary) async {
    final pinStatus = ref.read(payrollControllerProvider).pinStatus;
    if (pinStatus?.isLockedAt(DateTime.now()) == true) {
      final minutes =
          (pinStatus!.lockedUntil!.difference(DateTime.now()).inSeconds / 60)
              .ceil();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Terlalu banyak percobaan. Coba lagi dalam $minutes menit.',
          ),
        ),
      );
      return;
    }
    if (pinStatus?.pinSet != true) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const _SetupPinSheet(),
      );
      return;
    }
    final opened = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _UnlockSheet(payslipId: summary.id),
    );
    if (opened == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PayslipDetailScreen(id: summary.id),
        ),
      );
    }
    if (mounted &&
        ref.read(payrollControllerProvider).pinStatus?.pinSet == false) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const _SetupPinSheet(),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Kembali',
        onPressed: Navigator.of(context).canPop()
            ? Navigator.of(context).pop
            : null,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Slip gaji', style: Theme.of(context).textTheme.headlineLarge),
            Text(
              'Riwayat payroll terlindungi',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({super.key});

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppIconTile(icon: Icons.lock_outline_rounded),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nominal tetap terkunci',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Masukkan PIN untuk melihat rincian. Akses dikunci kembali saat aplikasi meninggalkan layar aktif.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({super.key, required this.summary, required this.onTap});

  final PayslipSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    onTap: onTap,
    semanticLabel: 'Buka ${_period(summary)}',
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          const AppIconTile(icon: Icons.receipt_long_outlined),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _period(summary),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (summary.runName != null || summary.runNumber != null)
                  Text(
                    [
                      summary.runName,
                      summary.runNumber,
                    ].whereType<String>().join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  summary.payDate == null
                      ? 'Status ${summary.status}'
                      : 'Dibayar ${_date(summary.payDate!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.lock_outline_rounded, size: 20),
        ],
      ),
    ),
  );
}

class _SetupPinSheet extends ConsumerStatefulWidget {
  const _SetupPinSheet();

  @override
  ConsumerState<_SetupPinSheet> createState() => _SetupPinSheetState();
}

class _SetupPinSheetState extends ConsumerState<_SetupPinSheet> {
  final _password = TextEditingController();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  String? _validation;

  @override
  void dispose() {
    _password.dispose();
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollControllerProvider);
    return _SheetBody(
      title: 'Atur PIN slip gaji',
      children: [
        Text(
          'Gunakan enam digit yang hanya Anda ketahui.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('payslip-current-password'),
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Kata sandi saat ini'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey('payslip-new-pin'),
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN baru'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const ValueKey('payslip-confirm-pin'),
          controller: _confirmation,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Ulangi PIN'),
        ),
        if (_validation != null || state.error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _validation ?? _message(state.error),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: state.submitting ? null : _submit,
          child: const Text('Simpan PIN'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_pin.text) ||
        _pin.text != _confirmation.text) {
      setState(() {
        _validation = 'PIN harus sama dan terdiri dari 6 digit.';
      });
      return;
    }
    setState(() => _validation = null);
    final saved = await ref
        .read(payrollControllerProvider.notifier)
        .setPin(currentPassword: _password.text, pin: _pin.text);
    if (saved && mounted) Navigator.of(context).pop();
  }
}

class _UnlockSheet extends ConsumerStatefulWidget {
  const _UnlockSheet({required this.payslipId});

  final String payslipId;

  @override
  ConsumerState<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends ConsumerState<_UnlockSheet> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollControllerProvider);
    return _SheetBody(
      title: 'Masukkan PIN slip gaji',
      children: [
        Text(
          'PIN digunakan untuk membuka rincian pada sesi ini saja.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('payslip-pin'),
          controller: _pin,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN 6 digit'),
        ),
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _message(state.error),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed:
              state.submitting ||
                  state.pinStatus?.isLockedAt(DateTime.now()) == true
              ? null
              : _submit,
          child: const Text('Buka slip gaji'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final controller = ref.read(payrollControllerProvider.notifier);
    final unlocked = await controller.unlock(_pin.text);
    if (!unlocked) {
      if (mounted &&
          ref.read(payrollControllerProvider).pinStatus?.pinSet == false) {
        Navigator.of(context).pop(false);
      }
      return;
    }
    final loaded = await controller.loadDetail(widget.payslipId);
    if (loaded && mounted) Navigator.of(context).pop(true);
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.xs,
      AppSpacing.screenHorizontal,
      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        ...children,
      ],
    ),
  );
}

String _period(PayslipSummary summary) =>
    summary.periodName ??
    '${_months[summary.createdAt.month - 1]} ${summary.createdAt.year}';

String _date(DateTime value) =>
    '${value.day} ${_months[value.month - 1].substring(0, 3)} ${value.year}';

const _months = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _message(Object? error) => error is ApiException
    ? error.message
    : 'Terjadi kendala. Silakan coba lagi.';
