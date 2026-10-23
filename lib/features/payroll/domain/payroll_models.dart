import 'dart:typed_data';

class PayslipSummary {
  const PayslipSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.locked,
    this.periodName,
    this.periodStart,
    this.periodEnd,
    this.payDate,
    this.runName,
    this.runNumber,
  });

  final String id;
  final String status;
  final DateTime createdAt;
  final bool locked;
  final String? periodName;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? payDate;
  final String? runName;
  final String? runNumber;
}

class PayslipPinStatus {
  const PayslipPinStatus({required this.pinSet, this.lockedUntil});

  final bool pinSet;
  final DateTime? lockedUntil;

  bool isLockedAt(DateTime now) =>
      lockedUntil != null && lockedUntil!.isAfter(now);
}

class PayslipUnlockGrant {
  const PayslipUnlockGrant({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      other is PayslipUnlockGrant &&
      token == other.token &&
      expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(token, expiresAt);
}

class PayslipComponent {
  const PayslipComponent({
    required this.code,
    required this.name,
    required this.type,
    required this.amount,
  });

  final String code;
  final String name;
  final String type;
  final double amount;
}

class PayslipDetail {
  PayslipDetail({
    required this.id,
    required this.status,
    required this.baseSalary,
    required this.totalEarnings,
    required this.totalDeductions,
    required this.netPay,
    required List<PayslipComponent> components,
    this.employeeName,
    this.employeeNumber,
    this.periodName,
    this.payDate,
  }) : components = List.unmodifiable(components);

  final String id;
  final String status;
  final double baseSalary;
  final double totalEarnings;
  final double totalDeductions;
  final double netPay;
  final List<PayslipComponent> components;
  final String? employeeName;
  final String? employeeNumber;
  final String? periodName;
  final DateTime? payDate;
}

class PayslipPdf {
  PayslipPdf({required Uint8List bytes, required this.sourceName})
    : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final String sourceName;
}
