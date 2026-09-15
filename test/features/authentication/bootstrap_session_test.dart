import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/authentication/presentation/screens/login_screen.dart';
import 'package:hrm_app/main.dart';

void main() {
  testWidgets('bootstrap blocks shell until mandatory password change', (
    tester,
  ) async {
    await _pumpGate(
      tester,
      const AuthSession(
        accessToken: 'fixture',
        userId: 'user-1',
        employeeId: 'employee-1',
        companyId: 'company-1',
        mustChangePassword: true,
      ),
    );

    expect(find.text('Ganti kata sandi'), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('bootstrap blocks non-employee account from ESS shell', (
    tester,
  ) async {
    await _pumpGate(
      tester,
      const AuthSession(
        accessToken: 'fixture',
        userId: 'admin-1',
        hasGlobalRole: true,
      ),
    );

    expect(find.text('Akses karyawan belum tersedia'), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('MFA challenge reveals code field and forwards the next code', (
    tester,
  ) async {
    final repository = _MfaRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'employee@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Password1!');
    final firstSubmit = find.widgetWithText(ElevatedButton, 'Masuk');
    await tester.ensureVisible(firstSubmit);
    await tester.pumpAndSettle();
    await tester.tap(firstSubmit);
    await tester.pumpAndSettle();

    expect(find.text('Kode autentikator'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('login-mfa')), '123456');
    final submit = find.widgetWithText(ElevatedButton, 'Masuk');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.lastTotp, '123456');
  });

  testWidgets('mandatory password change returns to login with confirmation', (
    tester,
  ) async {
    final repository = _PasswordRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: AuthGate(themeMode: ThemeMode.light, onThemeToggle: _noop),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'OldPassword1!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPassword2@');
    await tester.enterText(find.byType(TextFormField).at(2), 'NewPassword2@');
    final submit = find.text('Simpan dan masuk kembali');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.changed, isTrue);
    expect(repository.loggedOut, isTrue);
    expect(find.text('EMAIL KANTOR'), findsOneWidget);
    expect(
      find.text('Kata sandi berhasil diubah. Silakan masuk kembali.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpGate(WidgetTester tester, AuthSession session) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Repository(session)),
      ],
      child: const MaterialApp(
        home: AuthGate(themeMode: ThemeMode.light, onThemeToggle: _noop),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _noop() {}

class _Repository implements AuthRepository {
  const _Repository(this.session);

  final AuthSession session;

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<Result<AuthSession?>> restoreSession() async => Success(session);

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() async {}
}

class _MfaRepository implements AuthRepository {
  String? lastTotp;

  @override
  Future<bool> hasSession() async => false;

  @override
  Future<Result<AuthSession?>> restoreSession() async => const Success(null);

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) async {
    lastTotp = totp;
    if (totp == null) {
      return const FailureResult(
        AuthenticationFailure('Kode MFA diperlukan.', code: 'MFA_REQUIRED'),
      );
    }
    return const Success(
      AuthSession(
        accessToken: 'fixture',
        userId: 'user-1',
        employeeId: 'employee-1',
        companyId: 'company-1',
      ),
    );
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() async {}
}

class _PasswordRepository implements AuthRepository {
  bool changed = false;
  bool loggedOut = false;

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<Result<AuthSession?>> restoreSession() async => const Success(
    AuthSession(
      accessToken: 'fixture',
      userId: 'user-1',
      employeeId: 'employee-1',
      companyId: 'company-1',
      mustChangePassword: true,
    ),
  );

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changed = true;
    return const Success(null);
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}
