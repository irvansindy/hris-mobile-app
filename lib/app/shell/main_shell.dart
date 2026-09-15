import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_navigation.dart';
import 'package:hrm_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:hrm_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:hrm_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:hrm_app/features/profile/presentation/screens/profile_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({
    super.key,
    required this.themeMode,
    required this.onThemeToggle,
    required this.onSignOut,
    this.navigationShell,
    this.quickActions = const [],
    this.scrollControllers,
  }) : assert(scrollControllers == null || scrollControllers.length == 4);

  final ThemeMode themeMode;
  final VoidCallback onThemeToggle;
  final VoidCallback onSignOut;
  final StatefulNavigationShell? navigationShell;
  final List<AppQuickActionItem> quickActions;
  final List<ScrollController>? scrollControllers;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _items = [
    AppNavigationItem(
      label: 'Beranda',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    AppNavigationItem(
      label: 'Absensi',
      icon: Icons.schedule_outlined,
      selectedIcon: Icons.schedule_rounded,
    ),
    AppNavigationItem(
      label: 'Kalender',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    AppNavigationItem(
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  late final List<ScrollController> _ownedScrollControllers;
  int _standaloneIndex = 0;
  bool _quickActionsVisible = false;
  Timer? _successTimer;

  int get _currentIndex =>
      widget.navigationShell?.currentIndex ?? _standaloneIndex;
  List<ScrollController> get _scrollControllers =>
      widget.scrollControllers ?? _ownedScrollControllers;

  @override
  void initState() {
    super.initState();
    _ownedScrollControllers = widget.scrollControllers == null
        ? List.generate(4, (_) => ScrollController())
        : [];
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    for (final controller in _ownedScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingSuccess = ref.watch(loginSuccessPendingProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final reduceMotion = AppMotion.disabledOf(context);
    if (pendingSuccess && session != null && _successTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _successTimer != null) return;
        if (reduceMotion) {
          ref.read(loginSuccessPendingProvider.notifier).state = false;
          return;
        }
        _successTimer = Timer(const Duration(milliseconds: 1400), () {
          if (!mounted) return;
          ref.read(loginSuccessPendingProvider.notifier).state = false;
          setState(() => _successTimer = null);
        });
      });
    }

    final body = widget.navigationShell ?? _standaloneBody();
    return PopScope(
      canPop: !_quickActionsVisible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeQuickActions();
      },
      child: Stack(
        children: [
          Scaffold(
            body: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (_quickActionsVisible &&
                    notification.direction != ScrollDirection.idle) {
                  setState(() => _quickActionsVisible = false);
                }
                return false;
              },
              child: body,
            ),
            bottomNavigationBar: AppFloatingNavigation(
              items: _items,
              selectedIndex: _currentIndex,
              onDestinationSelected: _selectDestination,
              onCenterPressed: _openAttendance,
              quickActionsExpanded: _quickActionsVisible,
            ),
          ),
          if (_quickActionsVisible)
            AppQuickActionOverlay(
              actions: widget.quickActions,
              onDismiss: _closeQuickActions,
            ),
          if (_currentIndex == 0 && widget.quickActions.isNotEmpty)
            Positioned(
              right: 22,
              bottom: 106 + MediaQuery.paddingOf(context).bottom,
              child: AppQuickActionFab(
                expanded: _quickActionsVisible,
                onPressed: _toggleQuickActions,
              ),
            ),
          if (pendingSuccess && session != null && !reduceMotion)
            _LoginSuccessOverlay(name: session.userName),
        ],
      ),
    );
  }

  Widget _standaloneBody() {
    final screens = [
      HomeScreen(onOpenAttendance: _openAttendance),
      const AttendanceScreen(),
      const CalendarScreen(),
      ProfileScreen(
        onThemeToggle: widget.onThemeToggle,
        onSignOut: _signOut,
        isDarkMode: widget.themeMode == ThemeMode.dark,
      ),
    ];
    return IndexedStack(
      index: _standaloneIndex,
      children: List.generate(
        screens.length,
        (index) => PrimaryScrollController(
          controller: _scrollControllers[index],
          child: screens[index],
        ),
      ),
    );
  }

  void _selectDestination(int index) {
    HapticFeedback.selectionClick();
    _closeQuickActions();
    if (index == _currentIndex) {
      final controller = _scrollControllers[index];
      if (controller.hasClients) {
        _scrollToStart(controller);
      }
      return;
    }
    if (widget.navigationShell case final navigationShell?) {
      navigationShell.goBranch(index);
    } else {
      setState(() => _standaloneIndex = index);
    }
  }

  void _openAttendance() {
    HapticFeedback.mediumImpact();
    _closeQuickActions();
    if (_currentIndex == 1) {
      final controller = _scrollControllers[1];
      if (controller.hasClients) {
        _scrollToStart(controller);
      }
      return;
    }
    if (widget.navigationShell case final navigationShell?) {
      navigationShell.goBranch(1);
    } else {
      setState(() => _standaloneIndex = 1);
    }
  }

  void _scrollToStart(ScrollController controller) {
    if (AppMotion.disabledOf(context)) {
      controller.jumpTo(0);
    } else {
      controller.animateTo(
        0,
        duration: AppMotion.standard,
        curve: AppMotion.enterCurve,
      );
    }
  }

  void _toggleQuickActions() {
    if (widget.quickActions.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _quickActionsVisible = !_quickActionsVisible);
  }

  void _closeQuickActions() {
    if (!_quickActionsVisible) return;
    setState(() => _quickActionsVisible = false);
  }

  void _signOut() {
    ref.read(loginSuccessPendingProvider.notifier).state = false;
    widget.onSignOut();
  }
}

class ShellBranchScrollController extends StatelessWidget {
  const ShellBranchScrollController({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      PrimaryScrollController(controller: controller, child: child);
}

class _LoginSuccessOverlay extends StatelessWidget {
  const _LoginSuccessOverlay({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final displayName = name?.trim();
    final greeting = displayName == null || displayName.isEmpty
        ? 'Sesi karyawan siap digunakan.'
        : 'Selamat datang, $displayName.';
    return Positioned.fill(
      child: IgnorePointer(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: greeting,
          child: ColoredBox(
            color: AppColors.primary,
            child: Stack(
              children: [
                const Positioned(
                  top: -120,
                  right: -100,
                  child: _OverlayCircle(size: 300, opacity: 0.07),
                ),
                const Positioned(
                  bottom: -140,
                  left: -90,
                  child: _OverlayCircle(size: 280, opacity: 0.05),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 78,
                          height: 78,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Berhasil masuk',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          greeting,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.76),
                              ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Sesi karyawan siap digunakan.',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayCircle extends StatelessWidget {
  const _OverlayCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}
