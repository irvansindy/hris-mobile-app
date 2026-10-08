import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/payroll_providers.dart';
import 'package:intl/intl.dart';

class PayslipDetailScreen extends ConsumerStatefulWidget {
  const PayslipDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PayslipDetailScreen> createState() =>
      _PayslipDetailScreenState();
}

class _PayslipDetailScreenState extends ConsumerState<PayslipDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final detail = ref.read(payrollControllerProvider).detail;
      if (detail?.id != widget.id) {
        ref.read(payrollControllerProvider.notifier).loadDetail(widget.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollControllerProvider);
    final detail = state.detail?.id == widget.id ? state.detail : null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            18,
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Kembali',
                  onPressed: Navigator.of(context).pop,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Rincian slip gaji',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: _lock,
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Kunci'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            if (state.loading && detail == null)
              const AppStateView.loading(
                title: 'Membuka rincian',
                message: 'Memverifikasi sesi slip gaji.',
              )
            else if (state.error != null && detail == null)
              AppStateView(
                kind: AppViewStateKind.error,
                title: 'Rincian terkunci',
                message: state.error is ApiException
                    ? (state.error! as ApiException).message
                    : 'Rincian tidak dapat dibuka.',
              )
            else if (detail != null)
              _Detail(detail: detail)
            else
              const AppStateView(
                kind: AppViewStateKind.empty,
                title: 'Rincian tidak tersedia',
                message: 'Kembali dan masukkan PIN untuk mencoba lagi.',
              ),
          ],
        ),
      ),
    );
  }

  void _lock() {
    ref.read(payrollControllerProvider.notifier).lock();
    Navigator.of(context).pop();
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.detail});

  final PayslipDetail detail;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.periodName ?? 'Periode payroll',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppStatusChip(
              label: detail.status,
              tone: AppStatusTone.success,
              icon: Icons.verified_outlined,
            ),
            if (detail.employeeName != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(detail.employeeName!),
              if (detail.employeeNumber != null)
                Text(
                  detail.employeeNumber!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.section),
      const AppSectionLabel('Ringkasan'),
      AppSurfaceCard(
        child: Column(
          children: [
            _MoneyRow(label: 'Gaji pokok', value: detail.baseSalary),
            const Divider(),
            _MoneyRow(label: 'Total pendapatan', value: detail.totalEarnings),
            const Divider(),
            _MoneyRow(label: 'Total potongan', value: detail.totalDeductions),
            const Divider(),
            _MoneyRow(
              label: 'Diterima bersih',
              value: detail.netPay,
              strong: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.section),
      const AppSectionLabel('Komponen'),
      AppSurfaceCard(
        child: Column(
          children: detail.components.indexed
              .map(
                (entry) => Column(
                  children: [
                    _MoneyRow(label: entry.$2.name, value: entry.$2.amount),
                    if (entry.$1 < detail.components.length - 1)
                      const Divider(),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    ],
  );
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: AppSpacing.sm),
        Text(
          NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp',
            decimalDigits: 0,
          ).format(value),
          textAlign: TextAlign.end,
          style: strong
              ? Theme.of(context).textTheme.titleSmall
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
