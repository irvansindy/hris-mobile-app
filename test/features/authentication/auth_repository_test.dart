import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/security/token_storage.dart';
import 'package:hrm_app/core/security/session_cookie_store.dart';
import 'package:hrm_app/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:hrm_app/features/authentication/data/dto/auth_session_dto.dart';
import 'package:hrm_app/features/authentication/data/repositories/auth_repository_impl.dart';

void main() {
  test('stores access token after successful login', () async {
    final tokens = _MemoryTokenStorage();
    final repository = AuthRepositoryImpl(
      _SuccessfulRemote(),
      tokens,
      cookieStore: SessionCookieStore(
        storage: tokens,
        baseUrl: 'https://api.example.test/api/v1',
      ),
    );

    final result = await repository.login(
      email: 'user@example.com',
      password: 'secret',
    );

    expect(result, isA<Success>());
    expect(await tokens.readAccessToken(), 'access-token');
    expect(await tokens.readSession(), isNotNull);
    expect(await repository.hasSession(), isTrue);
  });

  test('rejects a legacy cookie-only session on native mobile', () async {
    final tokens = _MemoryTokenStorage();
    await tokens.saveTokens(accessToken: 'stale-bearer');
    final repository = AuthRepositoryImpl(
      _CookieRemote(),
      tokens,
      cookieStore: SessionCookieStore(
        storage: tokens,
        baseUrl: 'https://api.example.test/api/v1',
      ),
    );

    final result = await repository.login(
      email: 'admin@hrms.com',
      password: 'secret',
    );

    expect(result, isA<FailureResult>());
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readCookieHeader(), isNull);
    expect(await tokens.readCsrfToken(), isNull);
    expect(await repository.hasSession(), isFalse);
  });

  test('non-auth cookies cannot create an authenticated session', () async {
    final tokens = _MemoryTokenStorage();
    final remote = _NonAuthCookieRemote();
    final repository = AuthRepositoryImpl(
      remote,
      tokens,
      cookieStore: SessionCookieStore(
        storage: tokens,
        baseUrl: 'https://api.example.test/api/v1',
      ),
    );

    final result = await repository.login(
      email: 'admin@hrms.com',
      password: 'secret',
    );

    expect(result, isA<FailureResult>());
    expect(await repository.hasSession(), isFalse);
    expect(await tokens.readSession(), isNull);
    expect(remote.meCalls, 0);
  });

  test('login credentials are cleared when /me does not verify them', () async {
    final tokens = _MemoryTokenStorage();
    final repository = AuthRepositoryImpl(
      _UnverifiedRemote(),
      tokens,
      cookieStore: SessionCookieStore(
        storage: tokens,
        baseUrl: 'https://api.example.test/api/v1',
      ),
    );

    final result = await repository.login(
      email: 'user@example.com',
      password: 'secret',
    );

    expect(result, isA<FailureResult>());
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
    expect(await tokens.readSession(), isNull);
    expect(await repository.hasSession(), isFalse);
  });
}

class _SuccessfulRemote implements AuthRemoteDataSource {
  @override
  Future<AuthSessionDto> login({
    required String email,
    required String password,
    String? totp,
  }) async => AuthSessionDto(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    email: email,
    userName: 'Test User',
  );

  @override
  Future<Map<String, dynamic>> me() async => {
    'id': 'user-id',
    'email': 'user@example.com',
  };

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout({
    String? refreshToken,
    Map<String, String>? headers,
  }) async {}
}

class _CookieRemote implements AuthRemoteDataSource {
  @override
  Future<AuthSessionDto> login({
    required String email,
    required String password,
    String? totp,
  }) async => AuthSessionDto(
    authCookie: 'at=jwt; rt=refresh-jwt; csrf=csrf-token',
    authSetCookies: const [
      'at=jwt; Max-Age=900; Path=/; HttpOnly; Secure; SameSite=Lax',
      'rt=refresh-jwt; Max-Age=604800; Path=/api/v1/auth; HttpOnly; Secure; SameSite=Lax',
      'csrf=csrf-token; Path=/; Secure; SameSite=Lax',
    ],
    csrfToken: 'csrf-token',
    usesCookieAuth: true,
    email: email,
  );

  @override
  Future<Map<String, dynamic>> me() async => {'id': 'user-id'};

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout({
    String? refreshToken,
    Map<String, String>? headers,
  }) async {}
}

class _NonAuthCookieRemote implements AuthRemoteDataSource {
  int meCalls = 0;

  @override
  Future<AuthSessionDto> login({
    required String email,
    required String password,
    String? totp,
  }) async => AuthSessionDto(
    authCookie: 'at=claimed; csrf=claimed-csrf',
    authSetCookies: const ['theme=dark; Path=/; SameSite=Lax'],
    csrfToken: 'claimed-csrf',
    usesCookieAuth: true,
    email: email,
  );

  @override
  Future<Map<String, dynamic>> me() async {
    meCalls++;
    return {'id': 'user-id'};
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout({
    String? refreshToken,
    Map<String, String>? headers,
  }) async {}
}

class _UnverifiedRemote implements AuthRemoteDataSource {
  @override
  Future<AuthSessionDto> login({
    required String email,
    required String password,
    String? totp,
  }) async => AuthSessionDto(
    accessToken: 'unverified-access',
    refreshToken: 'unverified-refresh',
    userId: 'unverified-user',
    email: email,
  );

  @override
  Future<Map<String, dynamic>> me() async => throw const ApiException(
    'Access token is missing',
    statusCode: 401,
    code: 'AUTHENTICATION_FAILED',
  );

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout({
    String? refreshToken,
    Map<String, String>? headers,
  }) async {}
}

class _MemoryTokenStorage implements TokenStorage {
  String? _accessToken;
  String? _refreshToken;
  String? _cookieHeader;
  String? _csrfToken;
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _cookieState;

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _cookieHeader = null;
    _csrfToken = null;
    _session = null;
    _cookieState = null;
  }

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<String?> readCookieHeader() async => _cookieHeader;

  @override
  Future<String?> readCsrfToken() async => _csrfToken;

  @override
  Future<Map<String, dynamic>?> readCookieState() async => _cookieState;

  @override
  Future<Map<String, dynamic>?> readSession() async => _session;

  @override
  Future<void> saveSession(Map<String, dynamic> session) async {
    _session = session;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> saveCookieSession({
    required String cookieHeader,
    required String csrfToken,
  }) async {
    _cookieHeader = cookieHeader;
    _csrfToken = csrfToken;
  }

  @override
  Future<void> saveCookieState({
    required Map<String, dynamic> state,
    String? cookieHeader,
    String? csrfToken,
  }) async {
    _cookieState = state;
    _cookieHeader = cookieHeader;
    _csrfToken = csrfToken;
  }
}
