import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/payroll/domain/payroll_models.dart';
import 'package:hrm_app/features/payroll/domain/payroll_repository.dart';
import 'package:hrm_app/features/payroll/domain/payslip_unlock_vault.dart';

const _unset = Object();

class PayrollState {
  const PayrollState({
    this.summaries = const [],
    this.pinStatus,
    this.detail,
    this.pdf,
    this.unlockExpiresAt,
    this.loading = false,
    this.submitting = false,
    this.error,
  });

  final List<PayslipSummary> summaries;
  final PayslipPinStatus? pinStatus;
  final PayslipDetail? detail;
  final PayslipPdf? pdf;
  final DateTime? unlockExpiresAt;
  final bool loading;
  final bool submitting;
  final Object? error;

  bool get unlocked => unlockExpiresAt != null;

  PayrollState copyWith({
    List<PayslipSummary>? summaries,
    Object? pinStatus = _unset,
    Object? detail = _unset,
    Object? pdf = _unset,
    Object? unlockExpiresAt = _unset,
    bool? loading,
    bool? submitting,
    Object? error = _unset,
  }) => PayrollState(
    summaries: summaries ?? this.summaries,
    pinStatus: identical(pinStatus, _unset)
        ? this.pinStatus
        : pinStatus as PayslipPinStatus?,
    detail: identical(detail, _unset) ? this.detail : detail as PayslipDetail?,
    pdf: identical(pdf, _unset) ? this.pdf : pdf as PayslipPdf?,
    unlockExpiresAt: identical(unlockExpiresAt, _unset)
        ? this.unlockExpiresAt
        : unlockExpiresAt as DateTime?,
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    error: identical(error, _unset) ? this.error : error,
  );
}

class PayrollController extends StateNotifier<PayrollState> {
  PayrollController({
    required PayrollRepository repository,
    required PayslipUnlockVault vault,
    required RequestContext? Function() context,
    required bool Function() isCurrent,
    DateTime Function()? now,
  }) : _repository = repository,
       _vault = vault,
       _context = context,
       _isCurrent = isCurrent,
       _now = now ?? DateTime.now,
       super(const PayrollState());

  final PayrollRepository _repository;
  final PayslipUnlockVault _vault;
  final RequestContext? Function() _context;
  final bool Function() _isCurrent;
  final DateTime Function() _now;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(loading: true, error: null);
    try {
      final results = await Future.wait<Object>([
        _repository.getPayslips(),
        _repository.getPinStatus(),
      ]);
      if (!_canPublish(generation)) return;
      state = state.copyWith(
        summaries: results[0] as List<PayslipSummary>,
        pinStatus: results[1] as PayslipPinStatus,
        loading: false,
        error: null,
      );
    } catch (error) {
      if (_canPublish(generation)) {
        state = state.copyWith(loading: false, error: error);
      }
    }
  }

  Future<bool> setPin({
    required String currentPassword,
    required String pin,
  }) async {
    final generation = ++_generation;
    state = state.copyWith(submitting: true, error: null);
    try {
      await _repository.setPin(currentPassword: currentPassword, pin: pin);
      final status = await _repository.getPinStatus();
      if (!_canPublish(generation)) return false;
      state = state.copyWith(pinStatus: status, submitting: false, error: null);
      return true;
    } catch (error) {
      if (_canPublish(generation)) {
        state = state.copyWith(submitting: false, error: error);
      }
      return false;
    }
  }

  Future<bool> unlock(String pin) async {
    lock();
    final generation = ++_generation;
    state = state.copyWith(submitting: true, error: null);
    try {
      final grant = await _repository.unlock(pin);
      final context = _context();
      if (!_canPublish(generation) || context == null) return false;
      if (!_vault.store(context, grant, _now())) {
        state = state.copyWith(
          submitting: false,
          error: const ApiException(
            'Sesi buka slip gaji sudah kedaluwarsa. Masukkan PIN kembali.',
            code: 'PAYSLIP_UNLOCK_INVALID',
          ),
        );
        return false;
      }
      state = state.copyWith(
        unlockExpiresAt: grant.expiresAt,
        submitting: false,
        error: null,
      );
      return true;
    } catch (error) {
      if (_canPublish(generation)) {
        state = state.copyWith(submitting: false, error: error);
      }
      return false;
    }
  }

  Future<bool> loadDetail(String id) async {
    final grant = _grant();
    if (grant == null) return false;
    final generation = ++_generation;
    state = state.copyWith(loading: true, detail: null, pdf: null, error: null);
    try {
      final detail = await _repository.getDetail(
        id: id,
        unlockToken: grant.token,
      );
      if (!_canPublish(generation)) return false;
      state = state.copyWith(loading: false, detail: detail, error: null);
      return true;
    } catch (error) {
      if (_isUnlockInvalid(error)) {
        _lockWithError(error);
      } else if (_canPublish(generation)) {
        state = state.copyWith(loading: false, error: error);
      }
      return false;
    }
  }

  Future<bool> loadPdf(String id) async {
    final grant = _grant();
    if (grant == null) return false;
    final generation = ++_generation;
    state = state.copyWith(loading: true, pdf: null, error: null);
    try {
      final pdf = await _repository.getPdf(id: id, unlockToken: grant.token);
      if (!_canPublish(generation)) return false;
      state = state.copyWith(loading: false, pdf: pdf, error: null);
      return true;
    } catch (error) {
      if (_isUnlockInvalid(error)) {
        _lockWithError(error);
      } else if (_canPublish(generation)) {
        state = state.copyWith(loading: false, error: error);
      }
      return false;
    }
  }

  void lock() {
    _generation++;
    _vault.clear();
    if (!_disposed) {
      state = state.copyWith(
        detail: null,
        pdf: null,
        unlockExpiresAt: null,
        loading: false,
        submitting: false,
        error: null,
      );
    }
  }

  PayslipUnlockGrant? _grant() {
    final context = _context();
    final grant = context == null ? null : _vault.read(context, _now());
    if (grant == null) {
      _lockWithError(
        const ApiException(
          'Masukkan PIN untuk membuka slip gaji.',
          code: 'PAYSLIP_UNLOCK_REQUIRED',
        ),
      );
    }
    return grant;
  }

  void _lockWithError(Object error) {
    _generation++;
    _vault.clear();
    if (!_disposed) {
      state = state.copyWith(
        detail: null,
        pdf: null,
        unlockExpiresAt: null,
        loading: false,
        submitting: false,
        error: error,
      );
    }
  }

  bool _isUnlockInvalid(Object error) =>
      error is ApiException && error.code == 'PAYSLIP_UNLOCK_INVALID';

  bool _canPublish(int generation) =>
      !_disposed && _isCurrent() && generation == _generation;

  @override
  void dispose() {
    _vault.clear();
    _generation++;
    _disposed = true;
    super.dispose();
  }
}
