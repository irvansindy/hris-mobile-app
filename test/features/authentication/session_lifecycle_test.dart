import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/token_storage.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:hrm_app/features/authentication/data/dto/auth_session_dto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = SecureTokenStorage(FlutterSecureStorage());
  late _Remote remote;
  late ProviderContainer container;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    remote = _Remote();
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            baseUrl: 'https://api.example.test/api/v1',
            connectTimeout: Duration(seconds: 1),
            receiveTimeout: Duration(seconds: 1),
            enableNetworkLogs: false,
          ),
        ),
        authRemoteDataSourceProvider.overrideWithValue(remote),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'logout clears local identity and credentials before remote completes',
    () async {
      await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);
      await controller.login(email: 'A', password: 'fixture');
      remote.logoutGate = Completer<void>();
      final logout = controller.logout();
      expect(container.read(requestContextProvider), isNull);
      expect(container.read(authControllerProvider).valueOrNull, isNull);
      await remote.logoutStarted.future;
      expect(await storage.readSession(), isNull);
      expect(await storage.readAccessToken(), isNull);
      expect(remote.logoutHeaders, isEmpty);
      expect(remote.logoutRefreshToken, 'refresh-A');
      await controller.login(email: 'B', password: 'fixture');
      remote.logoutGate!.completeError(StateError('offline'));
      await logout;
      expect(container.read(requestContextProvider)?.userId, 'B');
      expect(await storage.readAccessToken(), 'token-B');
    },
  );

  test(
    'late login A cannot overwrite login B or restore a logged-out session',
    () async {
      await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);
      remote.loginGate = Completer<AuthSessionDto>();
      final loginA = controller.login(email: 'A', password: 'fixture');
      await remote.loginStarted.future;
      await controller.logout();
      await controller.login(email: 'B', password: 'fixture');
      remote.loginGate!.complete(_session('A'));
      await loginA;
      expect(container.read(authControllerProvider).requireValue?.userId, 'B');
      expect(container.read(requestContextProvider)?.userId, 'B');
      expect(await storage.readAccessToken(), 'token-B');
    },
  );

  test('late restore A cannot replace a newer login B', () async {
    await storage.saveTokens(accessToken: 'token-A', refreshToken: 'refresh-A');
    await storage.saveSession(_session('A').toStoredJson());
    remote.meGate = Completer<Map<String, dynamic>>();
    final restore = container.read(authControllerProvider.future);
    await remote.meStarted.future;
    final controller = container.read(authControllerProvider.notifier);
    await controller.logout();
    await controller.login(email: 'B', password: 'fixture');
    remote.meGate!.complete({'id': 'A', 'name': 'A'});
    await restore;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authControllerProvider).requireValue?.userId, 'B');
    expect(container.read(requestContextProvider)?.userId, 'B');
    expect(await storage.readAccessToken(), 'token-B');
  });
}

AuthSessionDto _session(String id) => AuthSessionDto(
  userId: id,
  employeeId: 'employee-$id',
  companyId: 'company-$id',
  userName: id,
  accessToken: 'token-$id',
  refreshToken: 'refresh-$id',
);

class _Remote implements AuthRemoteDataSource {
  Completer<AuthSessionDto>? loginGate;
  Completer<Map<String, dynamic>>? meGate;
  Completer<void>? logoutGate;
  final loginStarted = Completer<void>();
  final meStarted = Completer<void>();
  final logoutStarted = Completer<void>();
  Map<String, String>? logoutHeaders;
  String? logoutRefreshToken;
  String? _nextMeId;

  @override
  Future<AuthSessionDto> login({
    required String email,
    required String password,
    String? totp,
  }) async {
    if (!loginStarted.isCompleted) loginStarted.complete();
    final session = await (email == 'A' && loginGate != null
        ? loginGate!.future
        : Future.value(_session(email)));
    _nextMeId = email;
    return session;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<Map<String, dynamic>> me() {
    if (!meStarted.isCompleted) meStarted.complete();
    final loginId = _nextMeId;
    if (loginId != null) {
      _nextMeId = null;
      return Future.value({'id': loginId, 'name': loginId});
    }
    return meGate?.future ?? Future.value({'id': 'A', 'name': 'A'});
  }

  @override
  Future<void> logout({
    String? refreshToken,
    Map<String, String>? headers,
  }) async {
    logoutHeaders = headers;
    logoutRefreshToken = refreshToken;
    if (!logoutStarted.isCompleted) logoutStarted.complete();
    await logoutGate?.future;
  }
}
