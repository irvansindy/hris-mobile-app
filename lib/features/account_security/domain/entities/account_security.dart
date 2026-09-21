enum MfaRuntimeStatus { unknown, enabled, disabled }

class MfaSetup {
  const MfaSetup({required this.secret, required this.qrDataUrl});

  final String secret;
  final String qrDataUrl;
}

class MfaEnableResult {
  const MfaEnableResult({required this.recoveryCodes});

  final List<String> recoveryCodes;
}

class AccountSession {
  const AccountSession({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
    this.userAgent,
    this.ipAddress,
    this.isCurrent,
  });

  final String id;
  final String? userAgent;
  final String? ipAddress;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool? isCurrent;
}

class AccountSessionsState {
  const AccountSessionsState({
    required this.items,
    this.busySessionId,
    this.actionError,
  });

  final List<AccountSession> items;
  final String? busySessionId;
  final String? actionError;
}

class MfaState {
  const MfaState({
    this.status = MfaRuntimeStatus.unknown,
    this.busy = false,
    this.actionError,
  });

  final MfaRuntimeStatus status;
  final bool busy;
  final String? actionError;
}
