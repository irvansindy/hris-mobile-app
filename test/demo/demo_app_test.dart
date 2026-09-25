import 'package:dio/dio.dart';
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
      expect(find.text('Tim contoh · Divisi Marketing'), findsOneWidget);
      expect(find.byType(AppQuickActionFab).hitTestable(), findsNothing);
      await tester.tapAt(const Offset(20, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Absensi').last);
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScreen), findsOneWidget);
      for (final label in ['Catat masuk', 'Catat pulang']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      expect(faceVerificationCalls, 2);
      expect(store.today!['out'], isNotNull);
      await tester.tap(find.text('Kalender').last);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      await tester.tap(find.text('Profil').last);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Pengujian demo · Face ID'), findsOneWidget);
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
}
