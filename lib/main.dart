import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hrm_app/demo/demo_overrides.dart';
import 'package:hrm_app/core/config/demo_mode.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hrm_app/app/router/app_router.dart';
import 'package:hrm_app/app/shell/main_shell.dart';
import 'package:hrm_app/app/providers/theme_controller.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/presentation/screens/login_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/change_password_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/employee_access_unavailable_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/session_splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:hrm_app/app/shell/main_shell.dart' show MainShell;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final preferences = await SharedPreferences.getInstance();
  DemoStore? demo;
  if (const bool.fromEnvironment('DEMO_MODE')) {
    if (!kDebugMode) {
      throw StateError('Mode demo hanya tersedia pada build debug.');
    }
    demo = DemoStore(preferences);
    await demo.load();
  }
  final config = AppConfig.fromEnvironment();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appConfigProvider.overrideWithValue(config),
        if (demo != null) ...demoOverrides(demo),
      ],
      child: const HrmsApp(),
    ),
  );
}

class HrmsApp extends ConsumerWidget {
  const HrmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final featureSession = ref.watch(featureSessionProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      key: ObjectKey(featureSession),
      title: 'HRMS',
      debugShowCheckedModeBanner: false,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : AppMotion.control,
      routerConfig: router,
      builder: ref.watch(demoModeProvider)
          ? (context, child) => Banner(
              message: 'DEMO',
              location: BannerLocation.topStart,
              child: child!,
            )
          : null,
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({
    super.key,
    required this.themeMode,
    required this.onThemeToggle,
  });

  final ThemeMode themeMode;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final featureSession = ref.watch(featureSessionProvider);
    return auth.when(
      skipLoadingOnRefresh: false,
      data: (session) => switch (session) {
        null => const LoginScreen(),
        _ when session.mustChangePassword => ChangePasswordScreen(
          onSignOut: () => ref.read(authControllerProvider.notifier).logout(),
        ),
        _ when !session.hasEmployeeAccess => EmployeeAccessUnavailableScreen(
          onSignOut: () => ref.read(authControllerProvider.notifier).logout(),
        ),
        _ => MainShell(
          key: ObjectKey(featureSession),
          themeMode: themeMode,
          onThemeToggle: onThemeToggle,
          onSignOut: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      },
      loading: () => const SessionSplashScreen(),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}
