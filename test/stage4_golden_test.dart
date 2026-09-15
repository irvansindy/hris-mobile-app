import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/services/app_metadata.dart';
import 'package:hrm_app/core/services/clock.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/calendar/calendar_dependencies.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:hrm_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:hrm_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:hrm_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';
import 'package:hrm_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:hrm_app/features/profile/domain/entities/employee.dart';
import 'package:hrm_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:hrm_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';

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
    for (final screen in ['home', 'calendar', 'notifications', 'profile']) {
      testWidgets(
        '$screen fixture golden at 390x844 ${dark ? 'dark' : 'light'}',
        (tester) async {
          final previousShadows = debugDisableShadows;
          debugDisableShadows = false;
          try {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final child = switch (screen) {
              'home' => HomeScreen(
                onOpenAttendance: () {},
                onOpenRequests: () {},
                onOpenCalendar: () {},
                onOpenNotifications: () {},
                notificationUnreadCount: 1,
              ),
              'calendar' => const CalendarScreen(),
              'notifications' => const NotificationsScreen(),
              _ => ProfileScreen(
                onThemeToggle: () {},
                onSignOut: () {},
                isDarkMode: dark,
              ),
            };
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  clockProvider.overrideWithValue(() => DateTime(2026, 9, 14)),
                  calendarRepositoryProvider.overrideWithValue(_Calendar()),
                  dashboardRepositoryProvider.overrideWithValue(_Dashboard()),
                  notificationRepositoryProvider.overrideWithValue(
                    _Notifications(),
                  ),
                  profileRepositoryProvider.overrideWithValue(_Profile()),
                  appVersionProvider.overrideWith(
                    (ref) async => 'Fixture build',
                  ),
                ],
                child: MaterialApp(
                  theme: dark ? AppTheme.dark : AppTheme.light,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 30, bottom: 20),
                    ),
                    child: child!,
                  ),
                  home: RepaintBoundary(
                    key: const ValueKey('fixture-screen'),
                    child: child,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byKey(const ValueKey('fixture-screen')),
              matchesGoldenFile(
                'goldens/stage4/${screen}_fixture_${dark ? 'dark' : 'light'}.png',
              ),
            );
          } finally {
            debugDisableShadows = previousShadows;
          }
        },
      );
    }
  }
}

class _Dashboard implements DashboardRepository {
  @override
  DashboardSnapshot get current => const DashboardSnapshot(
    employee: DashboardEmployee(
      name: 'Fixture Employee',
      initials: 'FE',
      avatarColorIndex: 0,
    ),
    leaveBalances: [],
    announcements: [],
  );

  @override
  Future<DashboardSnapshot> refresh() async => current;
}

class _Calendar implements CalendarRepository {
  @override
  CalendarData get current => CalendarData(
    focusedDate: DateTime(2026, 9, 14),
    eventsByDay: const {
      14: [
        CalendarEvent(
          'Fixture shift',
          CalendarEventTone.primary,
          time: '08:00 - 17:00',
          detail: 'Fixture, bukan data server',
        ),
      ],
      16: [
        CalendarEvent(
          'Fixture cuti',
          CalendarEventTone.purple,
          time: 'Seharian',
        ),
      ],
      20: [
        CalendarEvent(
          'Fixture libur',
          CalendarEventTone.danger,
          time: 'Seharian',
        ),
      ],
    },
  );
  @override
  Future<CalendarData> loadMonth(int year, int month) async => current;
}

class _Notifications implements NotificationRepository {
  @override
  Future<List<NotificationItem>> load({required int limit}) async => const [
    NotificationItem(
      id: 'fixture-notification-1',
      title: 'Fixture approval',
      message: 'Fixture, bukan notifikasi server.',
      isRead: false,
      type: 'SUCCESS',
      action: 'approved',
      resource: 'leave',
    ),
    NotificationItem(
      id: 'fixture-notification-2',
      title: 'Fixture informasi',
      message: 'Fixture untuk regresi tampilan inbox.',
      isRead: true,
    ),
  ];
  @override
  Future<int> unreadCount() async => 1;
  @override
  Future<void> read(List<String> ids) async {}
  @override
  Future<void> readAll() async {}
}

class _Profile implements ProfileRepository {
  @override
  Employee get currentEmployee => const Employee(
    id: 'FIXTURE-01',
    name: 'Fixture Employee',
    role: 'Fixture Staff',
    department: 'Fixture Departemen',
    email: 'fixture@example.test',
    phone: '',
    location: 'Fixture Kantor',
    joinDate: '14 Sep 2026',
    salary: 0,
    initials: 'FE',
    avatarColorIndex: 0,
  );
  @override
  Future<Employee> refresh() async => currentEmployee;
}
