import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/presentation/screens/change_password_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/employee_access_unavailable_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/login_screen.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/presentation/screens/request_form_screen.dart';
import 'package:hrm_app/features/self_service/presentation/screens/requests_screen.dart';
import 'support/redesign_flow_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(AppTypography.fontFamily)..addFont(
          rootBundle.load('assets/fonts/PlusJakartaSans-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final dark in [false, true]) {
    for (final screen in [
      'login',
      'change_password',
      'employee_access',
      'requests',
      'leave_form',
      'permission_form',
      'loading',
      'error',
    ]) {
      testWidgets('$screen fixture golden, 320dp 200% text, dark=$dark', (
        tester,
      ) async {
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        final container = await createRedesignFlowFixture(
          clock: () => DateTime(2026, 9, 14),
        );
        try {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await container.read(authControllerProvider.future);
          if (screen.endsWith('form') || screen == 'requests') {
            await container
                .read(authControllerProvider.notifier)
                .login(
                  email: 'fixture-a@example.test',
                  password: 'FixturePassword1!',
                );
          }
          final child = switch (screen) {
            'login' => const LoginScreen(),
            'change_password' => ChangePasswordScreen(onSignOut: () {}),
            'employee_access' => EmployeeAccessUnavailableScreen(
              onSignOut: () {},
            ),
            'requests' => const RequestsScreen(),
            'leave_form' => const RequestFormScreen(kind: RequestKind.leave),
            'permission_form' => const RequestFormScreen(
              kind: RequestKind.permission,
            ),
            _ => Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: AppStateView(
                    kind: screen == 'loading'
                        ? AppViewStateKind.loading
                        : AppViewStateKind.error,
                    title: screen == 'loading'
                        ? 'Memuat data fixture'
                        : 'Data fixture gagal dimuat',
                    message:
                        'Fixture untuk regresi visual, bukan status server.',
                    actionLabel: screen == 'error' ? 'Muat ulang data' : null,
                    onAction: screen == 'error' ? () {} : null,
                  ),
                ),
              ),
            ),
          };
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: (dark ? AppTheme.dark : AppTheme.light).copyWith(
                  platform: TargetPlatform.android,
                ),
                locale: const Locale('id', 'ID'),
                supportedLocales: const [Locale('id', 'ID')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 30, bottom: 20),
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: const ValueKey('stage5-fixture'),
                  child: child,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const ValueKey('stage5-fixture')),
            matchesGoldenFile(
              'goldens/stage5/${screen}_fixture_${dark ? 'dark' : 'light'}_320_text200.png',
            ),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          debugDisableShadows = previousShadows;
        }
      });
    }
  }
}
