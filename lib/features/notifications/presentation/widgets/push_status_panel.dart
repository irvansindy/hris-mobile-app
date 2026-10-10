import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';
import 'package:hrm_app/features/notifications/push/push_coordinator.dart';
import 'package:hrm_app/features/notifications/push/push_providers.dart';
import 'package:uuid/uuid.dart';

class PushStatusPanel extends ConsumerStatefulWidget {
  const PushStatusPanel({super.key});
  @override
  ConsumerState<PushStatusPanel> createState() => _PushStatusPanelState();
}

class _PushStatusPanelState extends ConsumerState<PushStatusPanel> {
  final _id = TextEditingController();
  FeatureSession? _session;
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final session = ref.read(featureSessionProvider);
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted && session.isCurrent) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(pushModeProvider);
    if (mode == PushMode.disabled) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Push belum diaktifkan'),
      );
    }
    if (!kDebugMode) return const SizedBox.shrink();
    final session = ref.watch(featureSessionProvider);
    if (_session != null && !_session!.isCurrent) {
      _id.clear();
      _busy = false;
    }
    _session = session;
    final status = ref.watch(pushStatusProvider);
    final adapter = ref.read(pushAdapterProvider);
    final registry = ref.read(deviceRegistrationRepositoryProvider);
    if (adapter is! DummyPushAdapter ||
        registry is! DummyDeviceRegistrationRepository) {
      return const SizedBox.shrink();
    }
    final coordinator = ref.read(pushCoordinatorProvider);
    final ready = session.isCurrent && session.context?.employeeId != null;
    final theme = Theme.of(context);
    final inputBorder =
        (theme.inputDecorationTheme.enabledBorder ?? const OutlineInputBorder())
            .copyWith(borderSide: BorderSide(color: theme.colorScheme.primary));
    Widget button(String label, VoidCallback action) => OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        side: BorderSide(color: theme.colorScheme.primary),
      ),
      onPressed: !ready || _busy ? null : action,
      child: Text(label),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Simulasi push lokal',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(switch (status) {
              PushStatus.disabled => 'Menunggu sesi akun',
              PushStatus.denied => 'Izin simulasi ditolak',
              PushStatus.registering => 'Mendaftarkan perangkat simulasi',
              PushStatus.simulated =>
                'Terdaftar lokal; bukan delivery Firebase',
              PushStatus.failed =>
                'Registrasi simulasi gagal. Coba aktivasi lagi.',
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _id,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'ID notifikasi dari inbox',
              helperText: 'Kosong: buka inbox',
              counterText: '',
              enabledBorder: inputBorder,
              focusedBorder: inputBorder.copyWith(
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const {
                'Foreground': PushEventKind.foreground,
                'Tap / background': PushEventKind.opened,
                'Initial / terminated': PushEventKind.initial,
              }.entries)
                button(
                  entry.key,
                  () => adapter.emit(
                    PushEvent(
                      kind: entry.value,
                      messageId: const Uuid().v4(),
                      notificationId: _id.text.isEmpty ? null : _id.text,
                    ),
                  ),
                ),
              button('Rotasi token', adapter.rotateToken),
              button('Tolak izin', () {
                adapter.setPermission(PushPermission.denied);
                _run(coordinator.retry);
              }),
              button('Izinkan', () {
                adapter.setPermission(PushPermission.authorized);
                _run(coordinator.retry);
              }),
              button('Gagalkan registrasi', () {
                registry.failRegistration = true;
                adapter.rotateToken();
                _run(() async {
                  try {
                    // Let the token stream enqueue rotation before explicit retry.
                    await Future<void>.delayed(Duration.zero);
                    await coordinator.retry();
                  } finally {
                    registry.failRegistration = false;
                  }
                });
              }),
              button('Coba aktivasi lagi', () {
                registry.failRegistration = false;
                _run(coordinator.retry);
              }),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Initial/terminated hanya simulasi event, bukan kill/relaunch OS. Token dummy tidak dikirim ke backend.',
          ),
        ],
      ),
    );
  }
}
