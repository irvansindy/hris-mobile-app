import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/app/providers/theme_controller.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/services/app_metadata.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:hrm_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:hrm_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';
import 'package:hrm_app/features/profile/profile_providers.dart';
import 'package:hrm_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _context = RequestContext(
  userId: 'u1',
  employeeId: 'e1',
  activeCompanyId: 'c1',
  companyScope: ['c1'],
  displayName: 'Employee Aktif',
  email: 'employee@example.test',
  permissions: ['employee:read'],
);

void main() {
  test(
    'profile maps server identity, nested job and date-only without salary',
    () async {
      final adapter = _Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final employee = await DioProfileRemoteDataSource(
        dio,
      ).fetch(_context, EmptyProfileLocalDataSource().readCurrentEmployee());
      expect(adapter.request!.path, '/employees/e1');
      expect(adapter.request!.queryParameters, isEmpty);
      expect(employee.id, 'EMP001');
      expect(employee.department, 'Operasional');
      expect(employee.role, 'Staff');
      expect(employee.location, 'Kantor Pusat');
      expect(employee.joinDate, '1 Mei 2026');
      expect(employee.salary, 0);
    },
  );
  for (final defect in ['identity', 'company', 'schema', 'failure']) {
    test('profile rejects $defect without silent fallback', () async {
      final dio = Dio()..httpClientAdapter = _Adapter(defect: defect);
      addTearDown(dio.close);
      await expectLater(
        DioProfileRemoteDataSource(
          dio,
        ).fetch(_context, EmptyProfileLocalDataSource().readCurrentEmployee()),
        throwsFormatException,
      );
    });
  }
  test('employee without employee:read sends no protected request', () async {
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    await expectLater(
      DioProfileRemoteDataSource(dio).fetch(
        const RequestContext(
          userId: 'u1',
          employeeId: 'e1',
          activeCompanyId: 'c1',
          companyScope: ['c1'],
        ),
        EmptyProfileLocalDataSource().readCurrentEmployee(),
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
    expect(adapter.request, isNull);
  });
  test(
    'controller exposes failure, retains session identity and can retry',
    () async {
      final adapter = _Adapter(defect: 'identity');
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            ProfileRepositoryImpl(
              EmptyProfileLocalDataSource(),
              DioProfileRemoteDataSource(dio),
              () => _context,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final failed = Completer<void>();
      final sub = container.listen(profileLoadStateProvider, (_, next) {
        if (next.hasError && !failed.isCompleted) failed.complete();
      });
      addTearDown(sub.close);
      container.read(profileControllerProvider);
      await failed.future.timeout(const Duration(seconds: 5));
      expect(container.read(profileControllerProvider).name, 'Employee Aktif');
      expect(container.read(profileLoadStateProvider).hasError, isTrue);
      adapter.defect = null;
      await container.read(profileControllerProvider.notifier).refresh();
      expect(container.read(profileLoadStateProvider).hasError, isFalse);
      expect(container.read(profileControllerProvider).name, 'Employee Server');
    },
  );
  test(
    'app version comes from platform metadata, including build overrides',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'HRIS',
        packageName: 'test.hris',
        version: '2.7.3',
        buildNumber: '42',
        buildSignature: '',
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(appVersionProvider.future), '2.7.3+42');
    },
  );
  test(
    'theme preference restores on a new container and survives account teardown',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      expect(first.read(themeControllerProvider), ThemeMode.light);
      await first.read(themeControllerProvider.notifier).toggle();
      first.dispose();
      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(second.dispose);
      expect(second.read(themeControllerProvider), ThemeMode.dark);
    },
  );
  testWidgets(
    'profile shows real metadata and read-only language without dead push menu',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(
              ProfileRepositoryImpl(
                EmptyProfileLocalDataSource(),
                null,
                () => _context,
              ),
            ),
            appVersionProvider.overrideWith((ref) async => '2.7.3+42'),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: ProfileScreen(
              onThemeToggle: () {},
              onSignOut: () {},
              isDarkMode: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Versi aplikasi'), 400);
      expect(find.text('2.7.3+42'), findsOneWidget);
      expect(find.text('Indonesia'), findsOneWidget);
      expect(find.text('Push Aktif'), findsNothing);
      expect(find.text('1.4.0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Adapter implements HttpClientAdapter {
  _Adapter({this.defect});
  String? defect;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'success': defect != 'failure',
        'data': defect == 'schema'
            ? []
            : {
                'id': defect == 'identity' ? 'e2' : 'e1',
                'companyId': defect == 'company' ? 'c2' : 'c1',
                'employeeNumber': 'EMP001',
                'fullName': 'Employee Server',
                'email': 'employee@example.test',
                'department': {'name': 'Operasional'},
                'position': {'name': 'Staff'},
                'branch': {'name': 'Kantor Pusat'},
                'joinDate': '2026-05-01T00:00:00.000Z',
                'salary': 99999999,
              },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
