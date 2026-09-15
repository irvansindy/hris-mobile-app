import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/security/token_storage.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders login when no session exists', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    const config = AppConfig(
      baseUrl: 'https://example.test',
      connectTimeout: Duration(seconds: 1),
      receiveTimeout: Duration(seconds: 1),
      enableNetworkLogs: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          appConfigProvider.overrideWithValue(config),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: const HrmsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('EMAIL KANTOR'), findsOneWidget);
    expect(find.text('HRMS Enterprise'), findsNothing);
  });

  testWidgets('renders the four-destination HRIS shell', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    const config = AppConfig(
      baseUrl: 'https://example.test',
      connectTimeout: Duration(seconds: 1),
      receiveTimeout: Duration(seconds: 1),
      enableNetworkLogs: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          appConfigProvider.overrideWithValue(config),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: const MaterialApp(
          home: MainShell(
            themeMode: ThemeMode.light,
            onThemeToggle: _noop,
            onSignOut: _noop,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Absensi'), findsWidgets);
    expect(find.text('Kalender'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Requests'), findsNothing);
  });

  testWidgets('renders login inputs with dark-mode colors', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final preferences = await SharedPreferences.getInstance();
    const config = AppConfig(
      baseUrl: 'https://example.test',
      connectTimeout: Duration(seconds: 1),
      receiveTimeout: Duration(seconds: 1),
      enableNetworkLogs: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          appConfigProvider.overrideWithValue(config),
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: const HrmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
    final inputs = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(inputs, hasLength(2));
    for (final input in inputs) {
      expect(input.style.color, AppColors.darkText);
    }
  });
}

void _noop() {}

class _FakeTokenStorage implements TokenStorage {
  String? accessToken;
  String? refreshToken;
  String? cookieHeader;
  String? csrfToken;
  Map<String, dynamic>? session;
  Map<String, dynamic>? cookieState;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    cookieHeader = null;
    csrfToken = null;
    session = null;
    cookieState = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<String?> readCookieHeader() async => cookieHeader;

  @override
  Future<String?> readCsrfToken() async => csrfToken;

  @override
  Future<Map<String, dynamic>?> readCookieState() async => cookieState;

  @override
  Future<Map<String, dynamic>?> readSession() async => session;

  @override
  Future<void> saveSession(Map<String, dynamic> value) async => session = value;

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> saveCookieSession({
    required String cookieHeader,
    required String csrfToken,
  }) async {
    this.cookieHeader = cookieHeader;
    this.csrfToken = csrfToken;
  }

  @override
  Future<void> saveCookieState({
    required Map<String, dynamic> state,
    String? cookieHeader,
    String? csrfToken,
  }) async {
    cookieState = state;
    this.cookieHeader = cookieHeader;
    this.csrfToken = csrfToken;
  }
}
