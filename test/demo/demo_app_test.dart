import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hrm_app/main.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:hrm_app/demo/demo_overrides.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:hrm_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:hrm_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:hrm_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:hrm_app/core/widgets/app_navigation.dart';
import 'package:hrm_app/features/account_security/account_security_providers.dart';
import 'package:hrm_app/features/approvals/approval_dependencies.dart';
import 'package:hrm_app/features/ess/ess_providers.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';

void main() {
  testWidgets(
    'demo uses original home, attendance, calendar and profile screens',
    (tester) async {
      var faceVerificationCalls = 0;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DemoStore(prefs);
      await store.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appConfigProvider.overrideWithValue(
              const AppConfig(
                baseUrl: 'https://demo.invalid/api/v1',
                connectTimeout: Duration(seconds: 1),
                receiveTimeout: Duration(seconds: 1),
                enableNetworkLogs: false,
              ),
            ),
            ...demoOverrides(
              store,
              faceVerificationLauncher:
                  ({
                    required context,
                    required employeeId,
                    required companyId,
                  }) async {
                    faceVerificationCalls++;
                    expect(employeeId, 'DEMO001');
                    expect(companyId, 'demo-company');
                    return true;
                  },
            ),
          ],
          child: const HrmsApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      for (final label in ['Beranda', 'Absensi', 'Kalender', 'Profil']) {
        expect(find.text(label), findsWidgets);
      }
      await tester.scrollUntilVisible(find.text('Lihat semua'), 180);
      await tester.tap(find.text('Lihat semua'));
      await tester.pumpAndSettle();
      expect(find.text('Tim Hari Ini · Divisi Marketing'), findsOneWidget);
      expect(find.byType(AppQuickActionFab).hitTestable(), findsNothing);
      await tester.tapAt(const Offset(20, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Absensi').last);
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('attendance-summary-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('attendance-location-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('attendance-metrics-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('attendance-state-section')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('attendance-submit-action')),
        300,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catat masuk'));
      await tester.pumpAndSettle();
      expect(faceVerificationCalls, 1);
      expect(find.text('Catat pulang'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('attendance-submit-action')),
      );
      await tester.tap(find.text('Catat pulang'));
      await tester.pumpAndSettle();
      expect(faceVerificationCalls, 2);
      expect(store.today!['out'], isNotNull);
      await tester.tap(find.text('Kalender').last);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      await tester.tap(find.text('Profil').last);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Kelola Face ID'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'unimplemented demo routes are local errors, never network calls',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://demo.invalid'))
        ..httpClientAdapter = DemoOfflineAdapter();
      for (final path in ['/auth/change-password', '/ewa', '/notifications']) {
        await expectLater(
          dio.post<dynamic>(path),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.data['code'],
              'code',
              'DEMO_UNAVAILABLE',
            ),
          ),
        );
      }
      dio.close();
    },
  );

  test('secondary features use local demo repositories', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = DemoStore(preferences);
    await store.load();
    final container = ProviderContainer(overrides: demoOverrides(store));
    addTearDown(container.dispose);

    final notifications = await container
        .read(notificationRepositoryProvider)
        .load(limit: 50);
    final approvals = await container
        .read(approvalRepositoryProvider)
        .getQueue(page: 1);
    final loans = await container.read(essRepositoryProvider).getLoans();
    final sessions = await container
        .read(accountSecurityRepositoryProvider)
        .loadSessions();

    expect(notifications.items, isNotEmpty);
    expect(approvals.items, isEmpty);
    expect(loans.loans, isEmpty);
    expect(sessions, isEmpty);
  });
}
