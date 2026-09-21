import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/account_security/data/account_security_repository_impl.dart';
import 'package:hrm_app/features/account_security/domain/entities/account_security.dart';
import 'package:hrm_app/features/account_security/domain/repositories/account_security_repository.dart';

final accountSecurityRepositoryProvider = Provider<AccountSecurityRepository>((
  ref,
) {
  final context = ref.watch(featureSessionProvider).context;
  if (context == null) throw const ApiException('Sesi akun belum tersedia.');
  return DioAccountSecurityRepository(ref.watch(featureDioProvider), context);
});

final accountSessionsProvider =
    AsyncNotifierProvider.autoDispose<
      AccountSessionsController,
      AccountSessionsState
    >(AccountSessionsController.new);

class AccountSessionsController
    extends AutoDisposeAsyncNotifier<AccountSessionsState> {
  int _generation = 0;
  late FeatureSession _session;

  @override
  Future<AccountSessionsState> build() async {
    _session = ref.watch(featureSessionProvider);
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    final items = await ref
        .watch(accountSecurityRepositoryProvider)
        .loadSessions();
    if (!_session.isCurrent || generation != _generation) {
      throw StateError('Sesi telah berubah.');
    }
    return AccountSessionsState(items: items);
  }

  Future<void> refresh() async {
    final session = _session;
    final previous = state.asData?.value;
    if (!session.isCurrent || previous?.busySessionId != null) return;
    final generation = ++_generation;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final items = await ref
          .read(accountSecurityRepositoryProvider)
          .loadSessions();
      return AccountSessionsState(items: items);
    });
    if (session.isCurrent && generation == _generation) state = result;
  }

  Future<AccountSession?> revoke(String id) async {
    final session = _session;
    final previous = state.asData?.value;
    if (!session.isCurrent ||
        previous == null ||
        previous.busySessionId != null) {
      return null;
    }
    AccountSession? target;
    for (final item in previous.items) {
      if (item.id == id) target = item;
    }
    if (target == null) return null;
    final generation = ++_generation;
    state = AsyncData(
      AccountSessionsState(items: previous.items, busySessionId: id),
    );
    try {
      await ref.read(accountSecurityRepositoryProvider).revokeSession(id);
      if (!session.isCurrent || generation != _generation) return null;
      state = AsyncData(
        AccountSessionsState(
          items: previous.items
              .where((item) => item.id != id)
              .toList(growable: false),
        ),
      );
      return target;
    } catch (error) {
      if (session.isCurrent && generation == _generation) {
        state = AsyncData(
          AccountSessionsState(
            items: previous.items,
            actionError: _message(
              error,
              'Sesi gagal dicabut. Silakan coba lagi.',
            ),
          ),
        );
      }
      return null;
    }
  }
}

final mfaControllerProvider =
    NotifierProvider.autoDispose<MfaController, MfaState>(MfaController.new);

class MfaController extends AutoDisposeNotifier<MfaState> {
  late FeatureSession _session;
  int _generation = 0;

  @override
  MfaState build() {
    _session = ref.watch(featureSessionProvider);
    ref.onDispose(() => _generation++);
    return const MfaState();
  }

  Future<MfaSetup?> setup() => _run<MfaSetup>(
    () => ref.read(accountSecurityRepositoryProvider).setupMfa(),
  );

  Future<MfaEnableResult?> enable(String code) => _run<MfaEnableResult>(
    () => ref.read(accountSecurityRepositoryProvider).enableMfa(code),
    successStatus: MfaRuntimeStatus.enabled,
  );

  Future<bool> disable(String code) async {
    final result = await _run<bool>(() async {
      await ref.read(accountSecurityRepositoryProvider).disableMfa(code);
      return true;
    }, successStatus: MfaRuntimeStatus.disabled);
    return result ?? false;
  }

  Future<T?> _run<T>(
    Future<T> Function() operation, {
    MfaRuntimeStatus? successStatus,
  }) async {
    final session = _session;
    if (!session.isCurrent || state.busy) return null;
    final generation = ++_generation;
    final previousStatus = state.status;
    state = MfaState(status: previousStatus, busy: true);
    try {
      final result = await operation();
      if (!session.isCurrent || generation != _generation) return null;
      state = MfaState(status: successStatus ?? previousStatus);
      return result;
    } catch (error) {
      if (session.isCurrent && generation == _generation) {
        state = MfaState(
          status: previousStatus,
          actionError: _message(error, 'Pengaturan MFA gagal disimpan.'),
        );
      }
      return null;
    }
  }
}

String _message(Object error, String fallback) => switch (error) {
  ApiException(:final message) => message,
  ArgumentError(:final message) when message != null => message.toString(),
  FormatException(:final message) => message,
  _ => fallback,
};
