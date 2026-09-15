import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_navigation.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';

void main() {
  testWidgets('Initial avatars are circular at Home and Profile sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Column(
            children: [
              AppInitialAvatar(name: 'Fixture Employee', size: 42),
              AppInitialAvatar(name: 'Fixture Employee', size: 88),
            ],
          ),
        ),
      ),
    );
    final containers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(AppInitialAvatar),
        matching: find.byType(Container),
      ),
    );
    expect(containers, hasLength(2));
    for (final container in containers) {
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.borderRadius, isNull);
    }
    expect(find.text('FE'), findsNWidgets(2));
  });

  Future<void> setNarrowViewport(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Widget app({required Widget child, ThemeMode mode = ThemeMode.light}) =>
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        builder: (context, content) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: content!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ),
        ),
      );

  testWidgets('shared components reflow at 320dp and 200 percent text', (
    tester,
  ) async {
    await setNarrowViewport(tester);
    await tester.pumpWidget(
      app(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              title: 'Riwayat absensi',
              description: 'Catatan yang diterima dari server.',
            ),
            const SizedBox(height: 12),
            const AppStatusChip(
              label: 'Menunggu persetujuan',
              tone: AppStatusTone.warning,
            ),
            const SizedBox(height: 12),
            const AppInitialAvatar(name: 'Nadia Pratama'),
            const SizedBox(height: 12),
            AppBadgeIconButton(
              icon: Icons.notifications_outlined,
              tooltip: 'Notifikasi',
              badgeCount: 7,
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            AppSegmentedControl<String>(
              values: const ['Hari ini', 'Riwayat'],
              selected: 'Hari ini',
              labelBuilder: (value) => value,
              onSelected: (_) {},
            ),
            const SizedBox(height: 12),
            const AppSkeletonBlock(
              semanticLabel: 'Memuat ringkasan absensi',
              height: 72,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final notificationTarget = tester.getSize(find.byTooltip('Notifikasi'));
    expect(notificationTarget.width, greaterThanOrEqualTo(44));
    expect(notificationTarget.height, greaterThanOrEqualTo(44));
  });

  testWidgets('state view explains failure and exposes a working retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      app(
        mode: ThemeMode.dark,
        child: AppStateView(
          kind: AppViewStateKind.offline,
          title: 'Riwayat belum dapat dimuat',
          message: 'Periksa koneksi internet lalu muat ulang riwayat.',
          actionLabel: 'Muat ulang riwayat',
          onAction: () => retried = true,
        ),
      ),
    );

    await tester.tap(find.text('Muat ulang riwayat'));
    expect(retried, isTrue);
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom sheet shell exposes a reachable close action', (
    tester,
  ) async {
    await setNarrowViewport(tester);
    var closed = false;
    await tester.pumpWidget(
      app(
        child: AppBottomSheetShell(
          title: 'Filter riwayat',
          description: 'Pilih periode absensi yang ingin ditampilkan.',
          onClose: () => closed = true,
          child: const TextField(
            decoration: InputDecoration(labelText: 'Periode'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final closeTarget = tester.getSize(find.byTooltip('Tutup'));
    expect(closeTarget.width, greaterThanOrEqualTo(44));
    expect(closeTarget.height, greaterThanOrEqualTo(44));
    await tester.tap(find.byTooltip('Tutup'));
    expect(closed, isTrue);
  });

  testWidgets('floating navigation and quick action controls execute actions', (
    tester,
  ) async {
    await setNarrowViewport(tester);
    var selected = -1;
    var centerPressed = false;
    var dismissed = false;
    var actionPressed = false;
    const items = [
      AppNavigationItem(
        label: 'Beranda',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      AppNavigationItem(
        label: 'Absensi',
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule,
      ),
      AppNavigationItem(
        label: 'Kalender',
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
      ),
      AppNavigationItem(
        label: 'Profil',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Stack(
            children: [
              AppQuickActionOverlay(
                actions: [
                  AppQuickActionItem(
                    label: 'Pengajuan',
                    icon: Icons.description_outlined,
                    onPressed: () => actionPressed = true,
                  ),
                ],
                onDismiss: () => dismissed = true,
              ),
            ],
          ),
          bottomNavigationBar: AppFloatingNavigation(
            items: items,
            selectedIndex: 0,
            onDestinationSelected: (value) => selected = value,
            onCenterPressed: () => centerPressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Profil'));
    await tester.tap(find.byTooltip('Buka absensi'));
    await tester.tap(find.text('Pengajuan'));
    expect(selected, 3);
    expect(centerPressed, isTrue);
    expect(dismissed, isTrue);
    expect(actionPressed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick action backdrop dismisses the panel', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Stack(
            children: [
              AppQuickActionOverlay(
                actions: [
                  AppQuickActionItem(
                    label: 'Pengajuan',
                    icon: Icons.description_outlined,
                    onPressed: () {},
                  ),
                ],
                onDismiss: () => dismissed = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('quick-action-backdrop')));
    expect(dismissed, isTrue);
  });

  testWidgets('quick action panel closes with Escape', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Stack(
            children: [
              AppQuickActionOverlay(
                actions: [
                  AppQuickActionItem(
                    label: 'Pengajuan',
                    icon: Icons.description_outlined,
                    onPressed: () {},
                  ),
                ],
                onDismiss: () => dismissed = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismissed, isTrue);
  });
}
