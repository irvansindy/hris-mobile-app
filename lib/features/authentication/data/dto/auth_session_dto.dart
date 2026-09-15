import 'package:hrm_app/core/security/cookie_session.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';

class AuthSessionDto {
  const AuthSessionDto({
    this.accessToken,
    this.refreshToken,
    this.authCookie,
    this.authSetCookies = const [],
    this.csrfToken,
    this.usesCookieAuth = false,
    this.expiresIn,
    this.userId,
    this.employeeId,
    this.companyId,
    this.companyScope = const [],
    this.groupId,
    this.roles = const [],
    this.permissions = const [],
    this.hasGlobalRole = false,
    this.maxRolePriority = 0,
    this.mustChangePassword = false,
    this.userName,
    this.email,
  });

  factory AuthSessionDto.fromLoginJson(
    Map<String, dynamic> json, {
    String? authCookie,
    List<String> authSetCookies = const [],
    bool assumeBrowserCookieAuth = false,
    bool requireBearerTokens = false,
  }) {
    final tokens = json['tokens'] as Map<String, dynamic>? ?? const {};
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    if (_asId(user['id']) == null) {
      throw const FormatException('User ID is missing');
    }
    final result = AuthSessionDto._fromParts(
      tokens: tokens,
      user: user,
      authCookie: authCookie,
      authSetCookies: authSetCookies,
      csrfToken:
          cookieValue(authCookie, 'csrf') ?? json['csrfToken'] as String?,
      usesCookieAuth:
          assumeBrowserCookieAuth || cookieValue(authCookie, 'at') != null,
    );
    if (requireBearerTokens &&
        ((result.accessToken?.isEmpty ?? true) ||
            (result.refreshToken?.isEmpty ?? true))) {
      throw const FormatException(
        'Mobile login response must include access and refresh tokens',
      );
    }
    return result;
  }

  factory AuthSessionDto.fromStoredJson(Map<String, dynamic> json) =>
      AuthSessionDto._fromParts(tokens: json, user: json);

  factory AuthSessionDto._fromParts({
    required Map<String, dynamic> tokens,
    required Map<String, dynamic> user,
    String? authCookie,
    List<String> authSetCookies = const [],
    String? csrfToken,
    bool? usesCookieAuth,
  }) {
    final accessToken = tokens['accessToken'] as String?;
    final cookieAuth = usesCookieAuth ?? tokens['usesCookieAuth'] == true;
    if ((accessToken == null || accessToken.isEmpty) && !cookieAuth) {
      throw const FormatException('Authentication credentials are missing');
    }
    if (cookieAuth &&
        authCookie != null &&
        (csrfToken == null || csrfToken.isEmpty)) {
      throw const FormatException('CSRF token is missing');
    }
    return AuthSessionDto(
      accessToken: accessToken,
      refreshToken: tokens['refreshToken'] as String?,
      authCookie: authCookie,
      authSetCookies: authSetCookies,
      csrfToken: csrfToken,
      usesCookieAuth: cookieAuth,
      expiresIn: _asInt(tokens['expiresIn']),
      userId: _asId(user['id'] ?? user['userId']),
      employeeId: _asId(user['employeeId']),
      companyId: _asId(user['companyId']),
      companyScope: _asStringList(user['companyScope']),
      groupId: _asId(user['groupId']),
      roles: _asStringList(user['roles']),
      permissions: _asStringList(user['permissions']),
      hasGlobalRole: user['hasGlobalRole'] as bool? ?? false,
      maxRolePriority: _asInt(user['maxRolePriority']) ?? 0,
      mustChangePassword: user['mustChangePassword'] as bool? ?? false,
      userName: _userName(user),
      email: user['email'] as String?,
    );
  }

  final String? accessToken;
  final String? refreshToken;
  final String? authCookie;
  final List<String> authSetCookies;
  final String? csrfToken;
  final bool usesCookieAuth;
  final int? expiresIn;
  final String? userId;
  final String? employeeId;
  final String? companyId;
  final List<String> companyScope;
  final String? groupId;
  final List<String> roles;
  final List<String> permissions;
  final bool hasGlobalRole;
  final int maxRolePriority;
  final bool mustChangePassword;
  final String? userName;
  final String? email;

  AuthSession toEntity() => AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresIn: expiresIn,
    userId: userId,
    employeeId: employeeId,
    companyId: companyId,
    companyScope: companyScope,
    groupId: groupId,
    roles: roles,
    permissions: permissions,
    hasGlobalRole: hasGlobalRole,
    maxRolePriority: maxRolePriority,
    mustChangePassword: mustChangePassword,
    userName: userName,
    email: email,
  );

  Map<String, dynamic> toStoredJson() => {
    if (accessToken != null) 'accessToken': accessToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
    if (usesCookieAuth) 'usesCookieAuth': true,
    if (expiresIn != null) 'expiresIn': expiresIn,
    if (userId != null) 'id': userId,
    if (employeeId != null) 'employeeId': employeeId,
    if (companyId != null) 'companyId': companyId,
    'companyScope': companyScope,
    if (groupId != null) 'groupId': groupId,
    'roles': roles,
    'permissions': permissions,
    'hasGlobalRole': hasGlobalRole,
    'maxRolePriority': maxRolePriority,
    'mustChangePassword': mustChangePassword,
    if (userName != null) 'name': userName,
    if (email != null) 'email': email,
  };

  AuthSessionDto mergeUser(Map<String, dynamic> user) =>
      AuthSessionDto._fromParts(
        tokens: toStoredJson(),
        user: user,
        usesCookieAuth: usesCookieAuth,
      );
}

String? _asId(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  if (value is Map) return _asId(value['id']);
  return null;
}

int? _asInt(Object? value) => value is int ? value : int.tryParse('$value');

List<String> _asStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is String) return item;
        if (item is Map) return item['id'] ?? item['name'] ?? item['code'];
        return null;
      })
      .whereType<String>()
      .toList(growable: false);
}

String? _userName(Map<String, dynamic> user) {
  final name = user['name'];
  if (name is String && name.isNotEmpty) return name;
  final combined = [
    user['firstName'],
    user['lastName'],
  ].whereType<String>().join(' ').trim();
  if (combined.isNotEmpty) return combined;
  final email = user['email'] as String?;
  if (email == null || !email.contains('@')) return null;
  return email.split('@').first;
}
