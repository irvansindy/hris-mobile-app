import 'package:flutter_riverpod/flutter_riverpod.dart';

class RequestContext {
  const RequestContext({
    required this.userId,
    required this.employeeId,
    required this.activeCompanyId,
    required this.companyScope,
    this.displayName,
    this.email,
    this.roles = const [],
    this.permissions = const [],
    this.hasGlobalRole = false,
    this.maxRolePriority = 0,
  });

  final String? userId;
  final String? employeeId;
  final String? activeCompanyId;
  final List<String> companyScope;
  final String? displayName;
  final String? email;
  final List<String> roles;
  final List<String> permissions;
  final bool hasGlobalRole;
  final int maxRolePriority;

  factory RequestContext.fromSessionJson(Map<String, dynamic> json) {
    final companyScope = _stringList(json['companyScope']);
    final companyId = _string(json['companyId']);
    final name = _string(json['name']);
    final firstName = _string(json['firstName']);
    final lastName = _string(json['lastName']);
    final composedName = [
      ?firstName,
      ?lastName,
    ].where((part) => part.isNotEmpty).join(' ');

    return RequestContext(
      userId: _string(json['id']) ?? _string(json['userId']),
      employeeId: _string(json['employeeId']),
      activeCompanyId: companyId ?? companyScope.firstOrNull,
      companyScope: companyScope,
      displayName: name ?? (composedName.isEmpty ? null : composedName),
      email: _string(json['email']),
      roles: _stringList(json['roles']),
      permissions: _stringList(json['permissions']),
      hasGlobalRole: json['hasGlobalRole'] == true,
      maxRolePriority: _integer(json['maxRolePriority']),
    );
  }

  RequestContext selectCompany(String companyId) {
    if (!companyScope.contains(companyId)) {
      throw ArgumentError.value(
        companyId,
        'companyId',
        'Outside company scope',
      );
    }
    return RequestContext(
      userId: userId,
      employeeId: employeeId,
      activeCompanyId: companyId,
      companyScope: companyScope,
      displayName: displayName,
      email: email,
      roles: roles,
      permissions: permissions,
      hasGlobalRole: hasGlobalRole,
      maxRolePriority: maxRolePriority,
    );
  }

  bool hasPermission(String permission) {
    if (roles.any((role) => role.toUpperCase() == 'SUPER_ADMIN')) return true;
    final separator = permission.indexOf(':');
    if (separator <= 0 || separator == permission.length - 1) return false;
    final resource = permission.substring(0, separator);
    final action = permission.substring(separator + 1);
    final alias = const {
      'organization': 'org',
      'attendance': 'att',
      'recruitment': 'rec',
      'dashboard': 'dash',
      'travel-expense': 'travel',
    }[resource];
    return permissions.contains('$resource:$action') ||
        permissions.contains('$resource:*') ||
        (alias != null &&
            (permissions.contains('$alias:$action') ||
                permissions.contains('$alias:*')));
  }
}

String? _string(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return List.unmodifiable(
    value.map((item) {
      if (item is String) return _string(item);
      if (item is Map) {
        return _string(item['name']) ??
            _string(item['code']) ??
            _string(item['id']);
      }
      return null;
    }).whereType<String>(),
  );
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

final requestContextProvider = StateProvider<RequestContext?>((ref) => null);
