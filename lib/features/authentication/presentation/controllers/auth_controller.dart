import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';

class AuthController extends AsyncNotifier<AuthSession?> {
  int _operation = 0;
  bool _disposed = false;
  AuthSession? _currentSession;

  @override
  Future<AuthSession?> build() async {
    _disposed = false;
    final operation = ++_operation;
    ref.listen<int>(sessionInvalidationProvider, (previous, next) {
      if (previous == null || previous == next) return;
      _operation++;
      _currentSession = null;
      ref.read(loginSuccessPendingProvider.notifier).state = false;
      ref.read(requestContextProvider.notifier).state = null;
      state = const AsyncData(null);
    });
    ref.onDispose(() {
      _disposed = true;
      _operation++;
    });
    final result = await ref.read(authRepositoryProvider).restoreSession();
    if (_disposed || operation != _operation) return _currentSession;
    return switch (result) {
      Success(:final value) => _setContext(value),
      FailureResult(:final failure) => throw failure,
    };
  }

  Future<void> login({
    required String email,
    required String password,
    String? totp,
  }) async {
    ref.read(authNoticeProvider.notifier).state = null;
    final operation = ++_operation;
    _currentSession = null;
    ref.read(requestContextProvider.notifier).state = null;
    state = const AsyncData(null);
    state = const AsyncLoading();
    final result = await ref.read(loginUseCaseProvider)(
      email: email,
      password: password,
      totp: totp,
    );
    if (_disposed || operation != _operation) return;
    if (result case FailureResult<AuthSession>()) {
      ref.read(loginSuccessPendingProvider.notifier).state = false;
    } else if (result case Success<AuthSession>(
      :final value,
    ) when value.mustChangePassword || !value.hasEmployeeAccess) {
      ref.read(loginSuccessPendingProvider.notifier).state = false;
    }
    state = switch (result) {
      Success(:final value) => AsyncData(_setContext(value)!),
      FailureResult(:final failure) => AsyncError(failure, StackTrace.current),
    };
  }

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = _currentSession;
    if (session == null || !session.mustChangePassword) {
      return const FailureResult(
        AuthenticationFailure('Sesi perubahan kata sandi tidak tersedia.'),
      );
    }
    final result = await ref
        .read(authRepositoryProvider)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
    if (result case Success<void>()) {
      ref.read(authNoticeProvider.notifier).state =
          'Kata sandi berhasil diubah. Silakan masuk kembali.';
      await logout();
    }
    return result;
  }

  Future<void> logout() async {
    _operation++;
    _currentSession = null;
    ref.read(loginSuccessPendingProvider.notifier).state = false;
    ref.read(requestContextProvider.notifier).state = null;
    state = const AsyncData(null);
    await ref.read(authRepositoryProvider).logout();
  }

  AuthSession? _setContext(AuthSession? session) {
    _currentSession = session;
    if (session == null) {
      ref.read(requestContextProvider.notifier).state = null;
      return null;
    }
    final scope = session.companyScope.isEmpty && session.companyId != null
        ? [session.companyId!]
        : session.companyScope;
    ref.read(requestContextProvider.notifier).state = RequestContext(
      userId: session.userId,
      employeeId: session.employeeId,
      activeCompanyId:
          session.companyId ?? (scope.isEmpty ? null : scope.first),
      companyScope: scope,
      displayName: session.userName,
      email: session.email,
      roles: session.roles,
      permissions: session.permissions,
      hasGlobalRole: session.hasGlobalRole,
      maxRolePriority: session.maxRolePriority,
    );
    return session;
  }
}

final authNoticeProvider = StateProvider<String?>((ref) => null);

final loginSuccessPendingProvider = StateProvider<bool>((ref) => false);
