import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/account_security/account_security_providers.dart';
import 'package:hrm_app/features/account_security/domain/entities/account_security.dart';
import 'package:hrm_app/features/account_security/domain/repositories/account_security_repository.dart';
import 'package:hrm_app/features/account_security/presentation/screens/account_security_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader(AppTypography.fontFamily)
      ..addFont(
        rootBundle.load('assets/fonts/PlusJakartaSans-VariableFont_wght.ttf'),
      );
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final dark in [false, true]) {
    testWidgets('account security golden ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accountSecurityRepositoryProvider.overrideWithValue(
                const _Repository(),
              ),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: const EdgeInsets.only(top: 30, bottom: 20)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const ValueKey('security-screen'),
                child: AccountSecurityScreen(
                  onCurrentSessionRevoked: () async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('security-screen')),
          matchesGoldenFile(
            'goldens/account_security_stage4/security_${dark ? 'dark' : 'light'}.png',
          ),
        );
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }
}

class _Repository implements AccountSecurityRepository {
  const _Repository();

  @override
  Future<MfaSetup> setupMfa() => throw UnimplementedError();

  @override
  Future<MfaEnableResult> enableMfa(String code) => throw UnimplementedError();

  @override
  Future<void> disableMfa(String code) => throw UnimplementedError();

  @override
  Future<List<AccountSession>> loadSessions() async => [
    AccountSession(
      id: 'session-1',
      userAgent: 'Android 16 · HRIS Mobile',
      ipAddress: '192.0.2.10',
      createdAt: DateTime(2026, 9, 19, 8, 15),
      expiresAt: DateTime(2026, 9, 26, 8, 15),
    ),
    AccountSession(
      id: 'session-2',
      userAgent: 'Chrome · Linux',
      ipAddress: '198.51.100.24',
      createdAt: DateTime(2026, 9, 18, 16, 40),
      expiresAt: DateTime(2026, 9, 25, 16, 40),
    ),
  ];

  @override
  Future<void> revokeSession(String id) async {}
}
