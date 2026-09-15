import 'package:dio/dio.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/platform_http.dart';
import 'package:hrm_app/core/security/session_cookie_store.dart';
import 'package:hrm_app/core/security/token_storage.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:hrm_app/features/authentication/data/dto/auth_session_dto.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remote,
    this._tokens, {
    SessionLifecycle? lifecycle,
    SessionCookieStore? cookieStore,
  }) : _lifecycle = lifecycle ?? SessionLifecycle(),
       _cookies =
           cookieStore ??
           SessionCookieStore(storage: _tokens, baseUrl: 'https://localhost');
  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;
  final SessionLifecycle _lifecycle;
  final SessionCookieStore _cookies;

  @override
  Future<bool> hasSession() async {
    return _cookies.hasAccessCredential();
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    final revision = _lifecycle.revision;
    try {
      final stored = await _tokens.readSession();
      if (stored == null) {
        if (await hasSession()) {
          await _lifecycle.protect(revision, _tokens.clear);
        }
        return const Success(null);
      }
      final storedDto = AuthSessionDto.fromStoredJson(stored);
      if (!usesBrowserCookieStore && !_hasMobileBearerTokens(storedDto)) {
        await _lifecycle.protect(revision, _tokens.clear);
        return const Success(null);
      }
      if (!_lifecycle.isCurrent(revision)) return const Success(null);
      final me = await _remote.me();
      final user = me['user'] is Map<String, dynamic>
          ? me['user'] as Map<String, dynamic>
          : me;
      final refreshed = await _lifecycle.protect(revision, () async {
        final latest = await _tokens.readSession();
        if (latest == null) return null;
        final dto = AuthSessionDto.fromStoredJson(latest).mergeUser(user);
        _requireUserId(dto);
        // /me updates identity only; refresh owns credential rotation.
        await _tokens.saveSession(dto.toStoredJson());
        return dto.toEntity();
      });
      if (!_lifecycle.isCurrent(revision)) return const Success(null);
      return Success(refreshed);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.code == 'TOKEN_EXPIRED') {
        await _lifecycle.protect(revision, _tokens.clear);
        return const Success(null);
      }
      return FailureResult(mapApiException(error));
    } on DioException catch (error) {
      return FailureResult(mapApiException(mapDioException(error)));
    } on FormatException {
      await _lifecycle.protect(revision, _tokens.clear);
      return const Success(null);
    }
  }

  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) async {
    final revision = _lifecycle.advance();
    var credentialsMayBeStored = false;
    try {
      await _lifecycle.protect(revision, _tokens.clear);
      if (!_lifecycle.isCurrent(revision)) return _sessionChanged;
      final dto = await _remote.login(
        email: email,
        password: password,
        totp: totp,
      );
      credentialsMayBeStored = true;
      await _lifecycle.protect(
        revision,
        () => _save(dto, replaceCredentials: true),
      );
      if (!_lifecycle.isCurrent(revision)) return _sessionChanged;
      final me = await _remote.me();
      final user = me['user'] is Map<String, dynamic>
          ? me['user'] as Map<String, dynamic>
          : me;
      final session = await _lifecycle.protect(revision, () async {
        final latest = await _tokens.readSession();
        if (latest == null) return null;
        final verified = AuthSessionDto.fromStoredJson(latest).mergeUser(user);
        _requireUserId(verified);
        await _tokens.saveSession(verified.toStoredJson());
        return verified.toEntity();
      });
      if (!_lifecycle.isCurrent(revision) || session == null) {
        return _sessionChanged;
      }
      return Success(session);
    } on ApiException catch (error) {
      await _clearUnverified(revision, credentialsMayBeStored);
      return FailureResult(mapApiException(error));
    } on DioException catch (error) {
      await _clearUnverified(revision, credentialsMayBeStored);
      return FailureResult(mapApiException(mapDioException(error)));
    } on FormatException catch (error) {
      await _clearUnverified(revision, credentialsMayBeStored);
      return FailureResult(ServerFailure(error.message));
    } catch (_) {
      await _clearUnverified(revision, credentialsMayBeStored);
      return const FailureResult(
        NetworkFailure('Tidak dapat terhubung ke server.'),
      );
    }
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return const Success(null);
    } on ApiException catch (error) {
      return FailureResult(mapApiException(error));
    } on DioException catch (error) {
      return FailureResult(mapApiException(mapDioException(error)));
    } catch (_) {
      return const FailureResult(
        ServerFailure('Kata sandi tidak dapat diubah saat ini.'),
      );
    }
  }

  @override
  Future<void> logout() async {
    final revision = _lifecycle.advance();
    final snapshot = await _lifecycle.protect(revision, () async {
      final refresh = await _tokens.readRefreshToken();
      final storedSession = await _tokens.readSession();
      final headers = usesBrowserCookieStore
          ? await _cookies.headersFor(_authUri('logout'), method: 'POST')
          : const <String, String>{};
      await _tokens.clear();
      return (
        refresh: refresh,
        headers: headers,
        hadSession: storedSession != null,
      );
    });
    if (snapshot != null &&
        (snapshot.hadSession ||
            snapshot.refresh != null ||
            snapshot.headers.isNotEmpty)) {
      try {
        await _remote.logout(
          refreshToken: snapshot.refresh,
          headers: snapshot.headers,
        );
      } on Object {
        // Local logout must still succeed when the server is unavailable.
      }
    }
  }

  static const _sessionChanged = FailureResult<AuthSession>(
    ServerFailure('Sesi berubah. Silakan masuk kembali.'),
  );

  Future<void> _save(
    AuthSessionDto dto, {
    bool replaceCredentials = false,
  }) async {
    if (!usesBrowserCookieStore && !_hasMobileBearerTokens(dto)) {
      throw const FormatException(
        'Respons login mobile tidak memuat access token dan refresh token.',
      );
    }
    if (replaceCredentials) await _tokens.clear();
    Set<String> acceptedCookies = const {};
    if (dto.authSetCookies.isNotEmpty) {
      acceptedCookies = await _cookies.capture(
        Headers.fromMap({'set-cookie': dto.authSetCookies}),
        _authUri('login'),
        requireAuthBundle: dto.usesCookieAuth,
      );
    }
    if (dto.usesCookieAuth &&
        !_cookies.usesBrowserCookies &&
        !acceptedCookies.containsAll(const {'at', 'rt', 'csrf'})) {
      throw const FormatException(
        'Cookie autentikasi tidak sesuai kontrak server',
      );
    }
    final accessToken = dto.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      await _tokens.saveTokens(
        accessToken: accessToken,
        refreshToken: dto.refreshToken,
      );
    }
    await _tokens.saveSession(dto.toStoredJson());
  }

  Future<void> _clearUnverified(int revision, bool required) async {
    if (required) await _lifecycle.protect(revision, _tokens.clear);
  }

  void _requireUserId(AuthSessionDto dto) {
    if (dto.userId == null) throw const FormatException('User ID is missing');
  }

  bool _hasMobileBearerTokens(AuthSessionDto dto) =>
      dto.accessToken != null &&
      dto.accessToken!.isNotEmpty &&
      dto.refreshToken != null &&
      dto.refreshToken!.isNotEmpty;

  Uri _authUri(String action) {
    final base = _cookies.baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/auth/$action');
  }
}
