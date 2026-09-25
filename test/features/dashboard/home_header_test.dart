import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:hrm_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:hrm_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:hrm_app/features/dashboard/presentation/widgets/leave_balance_ring.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    bool dark = false,
    VoidCallback? onOpenNotifications,
    int? unreadCount,
    double width = 320,
    double textScale = 2,
    List<LeaveBalance> balances = const [],
  }) async {
    tester.view.physicalSize = Size(width, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(_Dashboard(balances)),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 30, bottom: 20),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: HomeScreen(
            onOpenAttendance: () {},
            onOpenNotifications: onOpenNotifications,
            notificationUnreadCount: unreadCount,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 400.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Leave ring fits labels at $width dp, text scale $scale', (
        tester,
      ) async {
        await pumpHome(
          tester,
          width: width,
          textScale: scale,
          balances: const [
            LeaveBalance(
              type: 'Cuti tahunan demo',
              total: 12,
              used: 2,
              colorIndex: 0,
            ),
          ],
        );
        await tester.scrollUntilVisible(find.text('hari'), 200);
        await tester.pumpAndSettle();
        final ring = find.byType(LeaveBalanceRing);
        final rect = tester.getRect(ring);
        expect(rect.width, greaterThanOrEqualTo(112));
        expect(rect.height, rect.width);
        final inner = rect.deflate(24);
        for (final label in ['10', 'hari']) {
          final labelRect = tester.getRect(find.text(label));
          expect(inner.contains(labelRect.topLeft), isTrue);
          expect(inner.contains(labelRect.bottomRight), isTrue);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final dark in [false, true]) {
    testWidgets('Home header actions fit at 320dp and 200% text, dark=$dark', (
      tester,
    ) async {
      var opened = 0;
      await pumpHome(
        tester,
        dark: dark,
        onOpenNotifications: () => opened++,
        unreadCount: 12,
      );
      final chat = find.byTooltip('Buka chat');
      final notification = find.byTooltip('Buka notifikasi');
      final avatar = find.byType(AppInitialAvatar);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(avatar).top, greaterThanOrEqualTo(42));
      expect(
        tester.getRect(chat).left,
        greaterThan(tester.getRect(avatar).right),
      );
      expect(
        tester.getRect(notification).left - tester.getRect(chat).right,
        greaterThanOrEqualTo(8),
      );
      expect(tester.getRect(notification).right, lessThanOrEqualTo(300));
      for (final target in [chat, notification]) {
        expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
      }
      final buttons = tester
          .widgetList<AppBadgeIconButton>(find.byType(AppBadgeIconButton))
          .toList();
      expect(buttons.first.badgeCount, isNull);
      expect(buttons.last.badgeCount, 12);
      expect(buttons.every((button) => button.boxed), isTrue);
      await tester.tap(notification);
      expect(opened, 1);
      await tester.tap(chat);
      await tester.pumpAndSettle();
      expect(find.text('Chat belum tersedia'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(chat);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  testWidgets(
    'Standalone Home keeps both actions visible without fake badges',
    (tester) async {
      await pumpHome(tester);
      expect(find.byTooltip('Buka chat'), findsOneWidget);
      expect(find.byTooltip('Buka notifikasi'), findsOneWidget);
      final buttons = tester.widgetList<AppBadgeIconButton>(
        find.byType(AppBadgeIconButton),
      );
      expect(buttons.every((button) => button.badgeCount == null), isTrue);
      await tester.tap(find.byTooltip('Buka notifikasi'));
      await tester.pumpAndSettle();
      expect(find.text('Notifikasi belum tersedia'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Dashboard implements DashboardRepository {
  _Dashboard(this.balances);
  final List<LeaveBalance> balances;
  @override
  DashboardSnapshot get current => DashboardSnapshot(
    employee: const DashboardEmployee(
      name: 'Fixture Employee dengan nama panjang',
      initials: 'FE',
      avatarColorIndex: 0,
    ),
    leaveBalances: balances,
    leaveBalancesAvailable: true,
    announcements: [],
  );

  @override
  Future<DashboardSnapshot> refresh() async => current;
}
