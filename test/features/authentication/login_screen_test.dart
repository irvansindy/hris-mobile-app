import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/authentication/presentation/screens/login_screen.dart';

void main() {
  testWidgets('login validates email and hides unsupported methods', (
    tester,
  ) async {
    final repository = _FailureRepository(
      const AuthenticationFailure('Email atau kata sandi salah.'),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'email-tidak-valid',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'Password1!',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();

    expect(find.text('Masukkan alamat email yang valid'), findsOneWidget);
    expect(repository.loginCalls, 0);
    expect(find.textContaining('Lupa kata sandi'), findsNothing);
    expect(find.textContaining('Face ID'), findsNothing);
    expect(find.textContaining('QR'), findsNothing);
  });

  testWidgets('login surfaces credential, lockout, and network failures', (
    tester,
  ) async {
    final failures = <Failure>[
      const AuthenticationFailure('Email atau kata sandi salah.'),
      const RateLimitFailure('Terlalu banyak percobaan. Coba lagi nanti.'),
      const NetworkFailure('Server tidak dapat dijangkau.'),
    ];
    for (final failure in failures) {
      final repository = _FailureRepository(failure);
      await tester.pumpWidget(_app(repository, key: UniqueKey()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'employee@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'Password1!',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();

      expect(find.text(failure.message), findsOneWidget);
      expect(repository.loginCalls, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('login reflows at 320dp with 200 percent text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _app(
        _FailureRepository(
          const NetworkFailure('Server tidak dapat dijangkau.'),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  AuthRepository repository, {
  Key? key,
  TextScaler textScaler = TextScaler.noScaling,
}) => ProviderScope(
  key: key,
  overrides: [authRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: const LoginScreen(),
  ),
);

class _FailureRepository implements AuthRepository {
  _FailureRepository(this.failure);

  final Failure failure;
  int loginCalls = 0;

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
    loginCalls++;
    return FailureResult(failure);
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() async {}
}
