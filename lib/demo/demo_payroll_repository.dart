import 'dart:typed_data';

import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/domain/payroll_repository.dart';

class DemoPayrollRepository implements PayrollRepository {
  String? _pin;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  @override
  Future<List<PayslipSummary>> getPayslips() async => [
    PayslipSummary(
      id: 'demo-payslip-2026-09',
      status: 'APPROVED',
      createdAt: DateTime(2026, 10, 1),
      locked: true,
      periodName: 'September 2026 · Demo',
      payDate: DateTime(2026, 10, 1),
    ),
  ];

  @override
  Future<PayslipPinStatus> getPinStatus() async =>
      PayslipPinStatus(pinSet: _pin != null, lockedUntil: _lockedUntil);

  @override
  Future<void> setPin({
    required String currentPassword,
    required String pin,
  }) async {
    if (currentPassword.trim().isEmpty) {
      throw const ApiException('Kata sandi saat ini wajib diisi.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const ApiException('PIN harus terdiri dari 6 digit.');
    }
    _pin = pin;
    _failedAttempts = 0;
    _lockedUntil = null;
  }

  @override
  Future<PayslipUnlockGrant> unlock(String pin) async {
    final now = DateTime.now();
    if (_lockedUntil?.isAfter(now) == true) {
      throw const ApiException(
        'Terlalu banyak percobaan. Coba lagi dalam 15 menit.',
        statusCode: 429,
        code: 'PAYSLIP_PIN_LOCKED',
      );
    }
    if (_pin == null) {
      throw const ApiException(
        'Atur PIN slip gaji terlebih dahulu.',
        code: 'PAYSLIP_PIN_NOT_SET',
      );
    }
    if (pin != _pin) {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockedUntil = now.add(const Duration(minutes: 15));
        throw const ApiException(
          'Terlalu banyak percobaan. Coba lagi dalam 15 menit.',
          statusCode: 429,
          code: 'PAYSLIP_PIN_LOCKED',
        );
      }
      throw const ApiException(
        'PIN slip gaji tidak sesuai.',
        statusCode: 401,
        code: 'PAYSLIP_PIN_REAUTH_FAILED',
      );
    }
    _failedAttempts = 0;
    return PayslipUnlockGrant(
      token: 'demo-memory-unlock',
      expiresAt: now.add(const Duration(minutes: 2)),
    );
  }

  @override
  Future<PayslipDetail> getDetail({
    required String id,
    required String unlockToken,
  }) async {
    _requireGrant(unlockToken);
    return PayslipDetail(
      id: id,
      status: 'APPROVED',
      employeeName: 'Karyawan Demo',
      employeeNumber: 'DEMO-001',
      periodName: 'September 2026 · Demo',
      payDate: DateTime(2026, 10, 1),
      baseSalary: 7500000,
      totalEarnings: 8250000,
      totalDeductions: 750000,
      netPay: 7500000,
      components: const [
        PayslipComponent(
          code: 'BASE',
          name: 'Gaji pokok demo',
          type: 'EARNING',
          amount: 7500000,
        ),
        PayslipComponent(
          code: 'MEAL',
          name: 'Tunjangan makan demo',
          type: 'EARNING',
          amount: 750000,
        ),
        PayslipComponent(
          code: 'DEDUCTION',
          name: 'Potongan demo',
          type: 'DEDUCTION',
          amount: 750000,
        ),
      ],
    );
  }

  @override
  Future<PayslipPdf> getPdf({
    required String id,
    required String unlockToken,
  }) async {
    _requireGrant(unlockToken);
    return PayslipPdf(
      bytes: Uint8List.fromList('%PDF-1.4\n% demo payslip'.codeUnits),
      sourceName: 'slip-gaji-demo.pdf',
    );
  }

  void _requireGrant(String token) {
    if (token != 'demo-memory-unlock') {
      throw const ApiException(
        'Sesi buka slip gaji sudah kedaluwarsa.',
        statusCode: 401,
        code: 'PAYSLIP_UNLOCK_INVALID',
      );
    }
  }
}
