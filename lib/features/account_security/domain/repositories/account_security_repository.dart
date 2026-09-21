import 'package:hrm_app/features/account_security/domain/entities/account_security.dart';

abstract interface class AccountSecurityRepository {
  Future<MfaSetup> setupMfa();
  Future<MfaEnableResult> enableMfa(String code);
  Future<void> disableMfa(String code);
  Future<List<AccountSession>> loadSessions();
  Future<void> revokeSession(String id);
}
