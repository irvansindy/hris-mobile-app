import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';

class PayslipUnlockVault {
  PayslipUnlockGrant? _grant;
  ({String userId, String employeeId, String companyId})? _identity;

  bool get isEmpty => _grant == null;

  bool store(RequestContext context, PayslipUnlockGrant grant, DateTime now) {
    clear();
    final identity = _fingerprint(context);
    final token = grant.token.trim();
    if (identity == null || token.isEmpty || !grant.expiresAt.isAfter(now)) {
      return false;
    }
    _identity = identity;
    _grant = PayslipUnlockGrant(token: token, expiresAt: grant.expiresAt);
    return true;
  }

  PayslipUnlockGrant? read(RequestContext context, DateTime now) {
    final grant = _grant;
    if (grant == null ||
        _identity != _fingerprint(context) ||
        !grant.expiresAt.isAfter(now)) {
      clear();
      return null;
    }
    return grant;
  }

  void clear() {
    _grant = null;
    _identity = null;
  }
}

({String userId, String employeeId, String companyId})? _fingerprint(
  RequestContext context,
) {
  final userId = context.userId?.trim();
  final employeeId = context.employeeId?.trim();
  final companyId = context.activeCompanyId?.trim();
  if (userId == null ||
      userId.isEmpty ||
      employeeId == null ||
      employeeId.isEmpty ||
      companyId == null ||
      companyId.isEmpty) {
    return null;
  }
  return (userId: userId, employeeId: employeeId, companyId: companyId);
}
