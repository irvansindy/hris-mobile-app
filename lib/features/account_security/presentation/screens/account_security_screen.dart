import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/account_security/account_security_providers.dart';
import 'package:hrm_app/features/account_security/domain/entities/account_security.dart';

class AccountSecurityScreen extends ConsumerWidget {
  const AccountSecurityScreen({
    super.key,
    required this.onCurrentSessionRevoked,
  });

  final Future<void> Function() onCurrentSessionRevoked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfa = ref.watch(mfaControllerProvider);
    final sessions = ref.watch(accountSessionsProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ref.read(accountSessionsProvider.notifier).refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _PageHeader(onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: AppSpacing.lg),
              _MfaCard(
                state: mfa,
                onSetup: () => _setupMfa(context, ref),
                onDisable: () => _disableMfa(context, ref),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppSectionHeader(
                title: 'Sesi aktif',
                description:
                    'Cabut akses perangkat yang tidak Anda kenali. Daftar server belum menandai perangkat yang sedang dipakai.',
              ),
              const SizedBox(height: AppSpacing.sm),
              sessions.when(
                loading: () => const AppStateView.loading(
                  title: 'Memuat sesi aktif',
                  message: 'Mengambil daftar perangkat dari server.',
                ),
                error: (error, _) => AppStateView(
                  kind: error is ApiException && error.code == 'NETWORK_ERROR'
                      ? AppViewStateKind.offline
                      : AppViewStateKind.error,
                  title: 'Sesi aktif gagal dimuat',
                  message: error is ApiException
                      ? error.message
                      : 'Respons sesi aktif tidak valid.',
                  actionLabel: 'Coba lagi',
                  onAction: ref.read(accountSessionsProvider.notifier).refresh,
                ),
                data: (data) => _SessionsList(
                  state: data,
                  onRevoke: (session) => _revokeSession(context, ref, session),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setupMfa(BuildContext context, WidgetRef ref) async {
    final setup = await ref.read(mfaControllerProvider.notifier).setup();
    if (!context.mounted || setup == null) return;
    final codes = await showModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      sheetAnimationStyle: AppMotion.sheetStyleOf(context),
      builder: (_) => _MfaSetupSheet(setup: setup),
    );
    if (!context.mounted || codes == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (_) => _RecoveryCodesDialog(codes: codes),
    );
  }

  Future<void> _disableMfa(BuildContext context, WidgetRef ref) async {
    final disabled = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (_) => const _DisableMfaDialog(),
    );
    if (!context.mounted || disabled != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('MFA dinonaktifkan oleh server.')),
    );
  }

  Future<void> _revokeSession(
    BuildContext context,
    WidgetRef ref,
    AccountSession session,
  ) async {
    final current = session.isCurrent == true;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (dialogContext) => AlertDialog(
        title: Text(current ? 'Cabut sesi saat ini?' : 'Cabut sesi perangkat?'),
        content: Text(
          current
              ? 'Anda akan dikeluarkan dari aplikasi dan perlu masuk kembali.'
              : 'Perangkat ini tidak akan dapat memperbarui akses setelah sesi dicabut.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cabut sesi'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    final revoked = await ref
        .read(accountSessionsProvider.notifier)
        .revoke(session.id);
    if (!context.mounted || revoked == null) return;
    if (revoked.isCurrent == true) {
      await onCurrentSessionRevoked();
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sesi berhasil dicabut.')));
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: onBack,
        tooltip: 'Kembali',
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surface,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Keamanan akun',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Text(
              'MFA dan perangkat aktif',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
}

class _MfaCard extends StatelessWidget {
  const _MfaCard({
    required this.state,
    required this.onSetup,
    required this.onDisable,
  });

  final MfaState state;
  final VoidCallback onSetup;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final status = switch (state.status) {
      MfaRuntimeStatus.enabled => const AppStatusChip(
        label: 'Aktif pada sesi ini',
        tone: AppStatusTone.success,
        icon: Icons.verified_user_outlined,
      ),
      MfaRuntimeStatus.disabled => const AppStatusChip(
        label: 'Dinonaktifkan',
        tone: AppStatusTone.neutral,
        icon: Icons.shield_outlined,
      ),
      MfaRuntimeStatus.unknown => const AppStatusChip(
        label: 'Status belum tersedia',
        tone: AppStatusTone.warning,
        icon: Icons.info_outline_rounded,
      ),
    };
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.icon),
                ),
                child: Icon(
                  Icons.security_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Autentikasi dua langkah',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    status,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.status == MfaRuntimeStatus.unknown
                ? 'Server belum menyertakan status MFA pada profil sesi. Anda tetap dapat menyiapkan MFA atau menonaktifkannya dengan kode yang valid.'
                : state.status == MfaRuntimeStatus.enabled
                ? 'MFA berhasil diaktifkan selama layar ini terbuka.'
                : 'MFA berhasil dinonaktifkan selama layar ini terbuka.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (state.actionError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                state.actionError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (state.busy)
            const AppLoadingIndicator(
              linear: true,
              semanticLabel: 'Menyimpan pengaturan MFA',
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (state.status != MfaRuntimeStatus.enabled)
                  FilledButton.icon(
                    onPressed: onSetup,
                    icon: const Icon(Icons.qr_code_rounded),
                    label: const Text('Siapkan MFA'),
                  ),
                OutlinedButton.icon(
                  onPressed: onDisable,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Nonaktifkan'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SessionsList extends StatelessWidget {
  const _SessionsList({required this.state, required this.onRevoke});

  final AccountSessionsState state;
  final ValueChanged<AccountSession> onRevoke;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return const AppStateView(
        kind: AppViewStateKind.empty,
        title: 'Tidak ada sesi aktif',
        message: 'Server tidak mengembalikan perangkat aktif untuk akun ini.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.actionError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              state.actionError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final session in state.items) ...[
          _SessionCard(
            session: session,
            busy: state.busySessionId == session.id,
            disabled: state.busySessionId != null,
            onRevoke: () => onRevoke(session),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.busy,
    required this.disabled,
    required this.onRevoke,
  });

  final AccountSession session;
  final bool busy;
  final bool disabled;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd MMM yyyy, HH:mm');
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.devices_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              Text(
                session.userAgent ?? 'Perangkat tidak dikenal',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (session.isCurrent == true)
                const AppStatusChip(
                  label: 'Perangkat ini',
                  tone: AppStatusTone.info,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'IP ${session.ipAddress ?? 'tidak tersedia'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Masuk ${format.format(session.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Berakhir ${format.format(session.expiresAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: disabled ? null : onRevoke,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(busy ? 'Mencabut...' : 'Cabut sesi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MfaSetupSheet extends ConsumerStatefulWidget {
  const _MfaSetupSheet({required this.setup});

  final MfaSetup setup;

  @override
  ConsumerState<_MfaSetupSheet> createState() => _MfaSetupSheetState();
}

class _MfaSetupSheetState extends ConsumerState<_MfaSetupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.clear();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mfa = ref.watch(mfaControllerProvider);
    final qrBytes = _qrBytes(widget.setup.qrDataUrl);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Siapkan MFA',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Pindai kode QR dengan aplikasi autentikator. Secret hanya ditampilkan pada proses ini dan tidak disimpan aplikasi.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Semantics(
                  image: true,
                  label: 'Kode QR MFA untuk dipindai',
                  child: ExcludeSemantics(
                    child: Container(
                      width: 210,
                      height: 210,
                      padding: const EdgeInsets.all(10),
                      color: Colors.white,
                      child: Image.memory(qrBytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Kunci manual',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              AppSurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SelectableText(
                  widget.setup.secret,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(
                  labelText: 'Kode autentikator',
                  hintText: 'Masukkan kode 6 digit',
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  return length < 6 || length > 20
                      ? 'Kode harus 6 sampai 20 karakter.'
                      : null;
                },
              ),
              if (mfa.actionError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    mfa.actionError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: mfa.busy ? null : _enable,
                child: Text(
                  mfa.busy ? 'Memverifikasi...' : 'Verifikasi dan aktifkan',
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: mfa.busy ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enable() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref
        .read(mfaControllerProvider.notifier)
        .enable(_code.text);
    _code.clear();
    if (mounted && result != null) {
      Navigator.pop(context, result.recoveryCodes);
    }
  }
}

class _RecoveryCodesDialog extends StatefulWidget {
  const _RecoveryCodesDialog({required this.codes});

  final List<String> codes;

  @override
  State<_RecoveryCodesDialog> createState() => _RecoveryCodesDialogState();
}

class _RecoveryCodesDialogState extends State<_RecoveryCodesDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Simpan kode pemulihan'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kode ini hanya ditampilkan sekali. Simpan di tempat aman dan jangan bagikan kepada siapa pun.',
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(widget.codes.join('\n')),
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            onChanged: (value) => setState(() => _confirmed = value == true),
            title: const Text('Saya sudah menyimpan kode pemulihan'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: _confirmed ? () => Navigator.pop(context) : null,
        child: const Text('Selesai'),
      ),
    ],
  );
}

class _DisableMfaDialog extends ConsumerStatefulWidget {
  const _DisableMfaDialog();

  @override
  ConsumerState<_DisableMfaDialog> createState() => _DisableMfaDialogState();
}

class _DisableMfaDialogState extends ConsumerState<_DisableMfaDialog> {
  final _code = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _code.clear();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mfa = ref.watch(mfaControllerProvider);
    return AlertDialog(
      title: const Text('Nonaktifkan MFA?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Masukkan kode autentikator atau salah satu kode pemulihan. Perlindungan tambahan akun akan dilepas.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _code,
            autofocus: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(
              labelText: 'Kode verifikasi',
              errorText: _validationError,
            ),
          ),
          if (mfa.actionError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                mfa.actionError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: mfa.busy ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: mfa.busy ? null : _disable,
          child: Text(mfa.busy ? 'Memverifikasi...' : 'Nonaktifkan'),
        ),
      ],
    );
  }

  Future<void> _disable() async {
    final length = _code.text.trim().length;
    if (length < 6 || length > 20) {
      setState(() => _validationError = 'Kode harus 6 sampai 20 karakter.');
      return;
    }
    setState(() => _validationError = null);
    final disabled = await ref
        .read(mfaControllerProvider.notifier)
        .disable(_code.text);
    _code.clear();
    if (mounted && disabled) Navigator.pop(context, true);
  }
}

Uint8List _qrBytes(String value) =>
    base64Decode(value.substring('data:image/png;base64,'.length));
