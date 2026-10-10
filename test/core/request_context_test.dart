import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';

void main() {
  test(
    'permission matching follows exact, wildcard, alias, and super admin',
    () {
      expect(
        _context(['attendance:create']).hasPermission('attendance:create'),
        isTrue,
      );
      expect(
        _context(['attendance:*']).hasPermission('attendance:create'),
        isTrue,
      );
      expect(
        _context(['att:create']).hasPermission('attendance:create'),
        isTrue,
      );
      expect(_context(['att:*']).hasPermission('attendance:create'), isTrue);
      expect(_context(['leave:*']).hasPermission('leave:create'), isTrue);
      expect(_context(['leave:read']).hasPermission('leave:create'), isFalse);
      expect(
        _context(
          const [],
          roles: const ['SUPER_ADMIN'],
        ).hasPermission('attendance:create'),
        isTrue,
      );
    },
  );
}

RequestContext _context(
  List<String> permissions, {
  List<String> roles = const [],
}) => RequestContext(
  userId: 'user-1',
  employeeId: 'employee-1',
  activeCompanyId: 'company-1',
  companyScope: const ['company-1'],
  permissions: permissions,
  roles: roles,
);
