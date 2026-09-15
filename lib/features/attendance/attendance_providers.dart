import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/features/attendance/attendance_dependencies.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_history.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_today.dart';
import 'package:hrm_app/features/attendance/presentation/controllers/attendance_controller.dart';

final attendanceControllerProvider = AsyncNotifierProvider.autoDispose
    .family<AttendanceController, AttendanceToday, FeatureSession>(
      AttendanceController.new,
    );

class AttendanceHistoryQuery {
  const AttendanceHistoryQuery({
    required this.session,
    required this.month,
    this.page = 1,
  });

  final FeatureSession session;
  final String month;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is AttendanceHistoryQuery &&
      other.session == session &&
      other.month == month &&
      other.page == page;

  @override
  int get hashCode => Object.hash(session, month, page);
}

final attendanceHistoryProvider = FutureProvider.autoDispose
    .family<AttendanceHistoryPage, AttendanceHistoryQuery>((ref, query) async {
      final result = await ref
          .watch(attendanceRepositoryProvider)
          .getHistory(month: query.month, page: query.page);
      if (!query.session.isCurrent) {
        throw StateError('Sesi telah berubah. Muat ulang riwayat absensi.');
      }
      return switch (result) {
        Success(:final value) => value,
        FailureResult(:final failure) => throw failure,
      };
    });
