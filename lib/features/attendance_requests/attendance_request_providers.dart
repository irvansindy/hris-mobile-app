import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/attendance_requests/attendance_request_dependencies.dart';
import 'package:hrm_app/features/attendance_requests/domain/entities/attendance_request.dart';

class AttendanceRequestQuery {
  const AttendanceRequestQuery({required this.session, this.status});

  final FeatureSession session;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is AttendanceRequestQuery &&
      other.session == session &&
      other.status == status;

  @override
  int get hashCode => Object.hash(session, status);
}

class AttendanceCorrectionDetailQuery {
  const AttendanceCorrectionDetailQuery({
    required this.session,
    required this.id,
  });

  final FeatureSession session;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is AttendanceCorrectionDetailQuery &&
      other.session == session &&
      other.id == id;

  @override
  int get hashCode => Object.hash(session, id);
}

final attendanceCorrectionsProvider = FutureProvider.autoDispose
    .family<List<AttendanceCorrectionRequest>, AttendanceRequestQuery>((
      ref,
      query,
    ) async {
      final values = await ref
          .watch(attendanceRequestRepositoryProvider)
          .getCorrections(status: query.status);
      if (!query.session.isCurrent) {
        throw StateError('Sesi telah berubah. Muat ulang koreksi absensi.');
      }
      return values;
    });

final attendanceCorrectionDetailProvider = FutureProvider.autoDispose
    .family<AttendanceCorrectionRequest, AttendanceCorrectionDetailQuery>((
      ref,
      query,
    ) async {
      final value = await ref
          .watch(attendanceRequestRepositoryProvider)
          .getCorrection(query.id);
      if (!query.session.isCurrent) {
        throw StateError('Sesi telah berubah. Muat ulang detail koreksi.');
      }
      return value;
    });

final overtimeRequestsProvider = FutureProvider.autoDispose
    .family<List<OvertimeRequest>, AttendanceRequestQuery>((ref, query) async {
      final values = await ref
          .watch(attendanceRequestRepositoryProvider)
          .getOvertimes(status: query.status);
      if (!query.session.isCurrent) {
        throw StateError('Sesi telah berubah. Muat ulang pengajuan lembur.');
      }
      return values;
    });

final overtimePayProvider = FutureProvider.autoDispose
    .family<OvertimePayEstimate, OvertimeRequest>((ref, request) {
      return ref
          .watch(attendanceRequestRepositoryProvider)
          .getOvertimePay(request);
    });
