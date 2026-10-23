import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/services/selfie_gateway.dart';
import 'package:hrm_app/features/attendance/attendance_dependencies.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_today.dart';
import 'package:hrm_app/features/attendance/domain/failures/attendance_failure.dart';

class AttendanceController
    extends AutoDisposeFamilyAsyncNotifier<AttendanceToday, FeatureSession> {
  late FeatureSession _session;
  bool _active = false;
  bool _submitting = false;
  @override
  Future<AttendanceToday> build(FeatureSession session) async {
    _session = session;
    _active = true;
    ref.onDispose(() => _active = false);
    final result = await ref
        .watch(attendanceRepositoryProvider)
        .getTodayState();
    return _unwrap(result);
  }

  Future<bool> toggleAttendance({CapturedSelfie? selfie}) async {
    final session = _session;
    if (!_active || !session.isCurrent || _submitting) return false;
    _submitting = true;
    final previous = state.valueOrNull;
    state = const AsyncLoading<AttendanceToday>().copyWithPrevious(state);
    final clockIn = ref.read(clockInProvider);
    final clockOut = ref.read(clockOutProvider);
    late final AttendanceToday latest;
    try {
      latest = _unwrap(
        await ref.read(attendanceRepositoryProvider).getTodayState(),
      );
    } catch (error, stackTrace) {
      if (_active && session.isCurrent) {
        final errorState = AsyncError<AttendanceToday>(error, stackTrace);
        state = previous == null
            ? errorState
            : errorState.copyWithPrevious(AsyncData(previous));
      }
      _submitting = false;
      return false;
    }
    if (!_active || !session.isCurrent) {
      _submitting = false;
      return false;
    }
    if (!latest.canCheckIn && !latest.canCheckOut) {
      state = AsyncError<AttendanceToday>(
        const ValidationFailure(
          'Server belum mengizinkan pencatatan absensi saat ini. Muat ulang status absensi lalu coba lagi.',
        ),
        StackTrace.current,
      ).copyWithPrevious(AsyncData(latest));
      _submitting = false;
      return false;
    }
    if (latest.canCheckIn && latest.context.requiresSelfie && selfie == null) {
      state = AsyncError<AttendanceToday>(
        const ValidationFailure(
          'Kebijakan absensi berubah dan sekarang mewajibkan selfie. Ambil selfie lalu coba lagi.',
        ),
        StackTrace.current,
      ).copyWithPrevious(AsyncData(latest));
      _submitting = false;
      return false;
    }
    final supported = latest.canCheckOut
        ? latest.context.supportsMobileGps
        : latest.context.requiresSelfie
        ? latest.context.supportsFaceRecognition
        : latest.context.supportsMobileGps;
    if (!supported) {
      state = AsyncError<AttendanceToday>(
        const ValidationFailure(
          'Kebijakan perusahaan tidak menyediakan metode absensi yang didukung aplikasi.',
        ),
        StackTrace.current,
      ).copyWithPrevious(AsyncData(latest));
      _submitting = false;
      return false;
    }
    state = const AsyncLoading<AttendanceToday>().copyWithPrevious(
      AsyncData(latest),
    );
    late final Result<AttendanceEntity> result;
    try {
      result = latest.canCheckOut
          ? await clockOut()
          : await clockIn(
              selfie: latest.context.requiresSelfie ? selfie : null,
            );
    } catch (error, stackTrace) {
      if (_active && session.isCurrent) {
        state = AsyncError<AttendanceToday>(
          error,
          stackTrace,
        ).copyWithPrevious(AsyncData(latest));
      }
      _submitting = false;
      return false;
    }
    if (!_active || !session.isCurrent) {
      _submitting = false;
      return false;
    }
    if (result case FailureResult(:final failure)) {
      _submitting = false;
      state = AsyncError<AttendanceToday>(
        latest.canCheckOut && _isMissingOpenCheckout(failure)
            ? AttendanceCorrectionRequiredFailure(failure.message)
            : failure,
        StackTrace.current,
      ).copyWithPrevious(AsyncData(latest));
      return false;
    }
    final punched = (result as Success<AttendanceEntity>).value;
    final safeInterim = latest.copyWith(
      record: punched,
      canCheckIn: false,
      canCheckOut: false,
    );
    try {
      final refreshed = await ref
          .read(attendanceRepositoryProvider)
          .getTodayState();
      if (!_active || !session.isCurrent) {
        _submitting = false;
        return false;
      }
      state = switch (refreshed) {
        Success(:final value) => AsyncData(value),
        FailureResult() => AsyncError<AttendanceToday>(
          const AttendanceRefreshAfterPunchFailure(),
          StackTrace.current,
        ).copyWithPrevious(AsyncData(safeInterim)),
      };
    } catch (_, stackTrace) {
      if (_active && session.isCurrent) {
        state = AsyncError<AttendanceToday>(
          const AttendanceRefreshAfterPunchFailure(),
          stackTrace,
        ).copyWithPrevious(AsyncData(safeInterim));
      }
    }
    _submitting = false;
    return _active && session.isCurrent;
  }

  T _unwrap<T>(Result<T> result) => switch (result) {
    Success(:final value) => value,
    FailureResult(:final failure) => throw failure,
  };

  bool _isMissingOpenCheckout(Failure failure) =>
      failure is ServerFailure &&
      failure.statusCode == 404 &&
      failure.code == 'NOT_FOUND';
}
