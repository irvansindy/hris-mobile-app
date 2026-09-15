import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrm_app/app/providers/theme_controller.dart';
import 'package:hrm_app/app/router/dashboard_route.dart';
import 'package:hrm_app/app/router/notification_route.dart';
import 'package:hrm_app/app/shell/main_shell.dart';
import 'package:hrm_app/app/shell/quick_action_capabilities.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/presentation/screens/change_password_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/employee_access_unavailable_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/login_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/session_splash_screen.dart';
import 'package:hrm_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:hrm_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:hrm_app/features/self_service/presentation/screens/requests_screen.dart';
import 'package:hrm_app/features/self_service/presentation/screens/request_form_screen.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(featureSessionProvider);
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.notify());

  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final scrollControllers = List.generate(4, (_) => ScrollController());
  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (_, state) => _redirect(ref, state),
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: Center(
          child: AppStateView(
            kind: AppViewStateKind.error,
            title: 'Halaman tidak tersedia',
            message: 'Alamat yang dibuka tidak dikenali oleh aplikasi.',
            actionLabel: 'Kembali ke beranda',
            onAction: () => context.go('/home'),
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SessionSplashScreen()),
      GoRoute(path: '/loading', builder: (_, _) => const SessionSplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/change-password',
        builder: (_, _) => ChangePasswordScreen(
          onSignOut: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ),
      GoRoute(
        path: '/employee-access-unavailable',
        builder: (_, _) => EmployeeAccessUnavailableScreen(
          onSignOut: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(
          navigationShell: navigationShell,
          themeMode: ref.read(themeControllerProvider),
          onThemeToggle: () =>
              ref.read(themeControllerProvider.notifier).toggle(),
          onSignOut: () => ref.read(authControllerProvider.notifier).logout(),
          quickActions: buildAvailableQuickActions(
            context: context,
            requestContext: ref.read(requestContextProvider),
            capabilities: ref.read(quickActionCapabilitiesProvider),
          ),
          scrollControllers: scrollControllers,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => ShellBranchScrollController(
                  controller: scrollControllers[0],
                  child: DashboardRoute(
                    onOpenAttendance: () => context.go('/attendance'),
                    onOpenRequests: () => context.push('/requests'),
                    onOpenCalendar: () => context.go('/calendar'),
                    onOpenNotifications: () => context.push('/notifications'),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/attendance',
                builder: (_, _) => ShellBranchScrollController(
                  controller: scrollControllers[1],
                  child: const AttendanceScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, _) => ShellBranchScrollController(
                  controller: scrollControllers[2],
                  child: const CalendarScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => ShellBranchScrollController(
                  controller: scrollControllers[3],
                  child: ProfileScreen(
                    onThemeToggle: () =>
                        ref.read(themeControllerProvider.notifier).toggle(),
                    onSignOut: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                    isDarkMode:
                        ref.read(themeControllerProvider) == ThemeMode.dark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/requests', builder: (_, _) => const RequestsScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationRoute(),
      ),
      GoRoute(
        path: '/requests/leave/new',
        builder: (_, _) => const RequestFormScreen(kind: RequestKind.leave),
      ),
      GoRoute(
        path: '/requests/permission/new',
        builder: (_, _) =>
            const RequestFormScreen(kind: RequestKind.permission),
      ),
      GoRoute(
        path: '/requests/leave/:id',
        builder: (_, state) => RequestDetailScreen(
          id: state.pathParameters['id']!,
          initial: state.extra is EmployeeRequest
              ? state.extra! as EmployeeRequest
              : null,
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
    for (final controller in scrollControllers) {
      controller.dispose();
    }
  });
  return router;
});

String? _redirect(Ref ref, GoRouterState state) {
  final auth = ref.read(authControllerProvider);
  final path = state.uri.path;
  final from = state.uri.queryParameters['from'];

  if (auth.isLoading) {
    if (path == '/login' || path == '/loading') return null;
    return Uri(
      path: '/loading',
      queryParameters: {'from': state.uri.toString()},
    ).toString();
  }

  if (auth.hasError || auth.valueOrNull == null) {
    if (path == '/login') return null;
    final target = path == '/loading' ? from : state.uri.toString();
    return Uri(
      path: '/login',
      queryParameters: _protectedTarget(target) ? {'from': target} : null,
    ).toString();
  }

  final session = auth.requireValue!;
  if (session.mustChangePassword) {
    return path == '/change-password' ? null : '/change-password';
  }
  if (!session.hasEmployeeAccess) {
    return path == '/employee-access-unavailable'
        ? null
        : '/employee-access-unavailable';
  }

  if (_authOnlyPath(path)) {
    return _protectedTarget(from) ? from : '/home';
  }
  return null;
}

bool _authOnlyPath(String path) =>
    path == '/' ||
    path == '/loading' ||
    path == '/login' ||
    path == '/change-password' ||
    path == '/employee-access-unavailable';

bool _protectedTarget(String? value) {
  if (value == null || !value.startsWith('/')) return false;
  final path = Uri.tryParse(value)?.path;
  return path != null && !_authOnlyPath(path);
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
