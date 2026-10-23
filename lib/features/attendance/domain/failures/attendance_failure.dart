import 'package:hrm_app/core/errors/failure.dart';

class AttendanceCorrectionRequiredFailure extends Failure {
  const AttendanceCorrectionRequiredFailure(super.message);
}

class AttendanceRefreshAfterPunchFailure extends Failure {
  const AttendanceRefreshAfterPunchFailure()
    : super(
        'Absensi sudah diterima server, tetapi status terbaru belum dapat dimuat. Muat ulang halaman untuk menyinkronkan data.',
      );
}
