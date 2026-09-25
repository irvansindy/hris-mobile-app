import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef DemoRecord = Map<String, dynamic>;

class DemoStore extends ChangeNotifier {
  DemoStore(this.preferences, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  static const storageKey = 'hris.demo.v1';
  final SharedPreferences preferences;
  final DateTime Function() now;
  DemoRecord _data = {};
  bool _writing = false;

  static String day(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  List<DemoRecord> get attendance =>
      List<DemoRecord>.from(_data['attendance'] as List);
  List<DemoRecord> get requests =>
      List<DemoRecord>.from(_data['requests'] as List);
  int get balance =>
      12 -
      requests
          .where((r) => r['kind'] == 'Cuti' && r['status'] == 'Disetujui')
          .fold<int>(0, (sum, r) => sum + (r['days'] as int));
  int get reserved => requests
      .where((r) => r['kind'] == 'Cuti' && r['status'] == 'Menunggu')
      .fold<int>(0, (sum, r) => sum + (r['days'] as int));
  DemoRecord? get today {
    for (final record in attendance) {
      if (record['date'] == day(now())) return record;
    }
    return null;
  }

  Future<void> load() async {
    final raw = preferences.getString(storageKey);
    if (raw == null) {
      await reset();
    } else {
      final decoded = jsonDecode(raw) as DemoRecord;
      if (decoded['version'] != 1 ||
          decoded['attendance'] is! List ||
          decoded['requests'] is! List) {
        throw const FormatException('Data demo tidak valid.');
      }
      _data = decoded;
      notifyListeners();
    }
  }

  Future<void> _commit(void Function(DemoRecord) update) async {
    if (_writing) throw StateError('Penyimpanan sedang berlangsung.');
    _writing = true;
    try {
      final next = jsonDecode(jsonEncode(_data)) as DemoRecord;
      update(next);
      if (!await preferences.setString(storageKey, jsonEncode(next))) {
        throw StateError('Data demo gagal disimpan.');
      }
      _data = next;
      notifyListeners();
    } finally {
      _writing = false;
    }
  }

  Future<void> reset() => _commit((data) {
    final date = now();
    final yesterday = DateTime(date.year, date.month, date.day - 1);
    final earlier = DateTime(date.year, date.month, date.day - 2);
    data
      ..clear()
      ..addAll({
        'version': 1,
        'attendance': [
          for (final pair in [
            (yesterday, 8, 25, 'Telat'),
            (earlier, 7, 55, 'Hadir'),
          ])
            {
              'id': 'seed-${day(pair.$1)}',
              'date': day(pair.$1),
              'in': DateTime(
                pair.$1.year,
                pair.$1.month,
                pair.$1.day,
                pair.$2,
                pair.$3,
              ).toIso8601String(),
              'out': DateTime(
                pair.$1.year,
                pair.$1.month,
                pair.$1.day,
                17,
              ).toIso8601String(),
              'status': pair.$4,
            },
        ],
        'requests': [
          {
            'id': 'seed-leave',
            'kind': 'Cuti',
            'start': day(DateTime(date.year, date.month, date.day - 10)),
            'end': day(DateTime(date.year, date.month, date.day - 9)),
            'days': 2,
            'reason': 'Contoh cuti tahunan demo',
            'status': 'Disetujui',
          },
          {
            'id': 'seed-permission',
            'kind': 'Izin',
            'start': day(earlier),
            'end': day(earlier),
            'days': 1,
            'reason': 'Contoh izin keperluan keluarga',
            'status': 'Disetujui',
          },
        ],
      });
  });

  Future<void> checkIn({bool simulateLate = false}) => _commit((data) {
    if (today != null) throw StateError('Absensi hari ini sudah tercatat.');
    final time = now();
    (data['attendance'] as List).insert(0, {
      'id': 'demo-${time.microsecondsSinceEpoch}',
      'date': day(time),
      'in': time.toIso8601String(),
      'out': null,
      'status': simulateLate || time.hour >= 8 ? 'Telat' : 'Hadir',
    });
  });

  Future<void> checkOut() => _commit((data) {
    final items = data['attendance'] as List;
    final index = items.indexWhere((r) => r['date'] == day(now()));
    if (index < 0) throw StateError('Catat masuk terlebih dahulu.');
    final record = items[index] as DemoRecord;
    if (record['out'] != null) throw StateError('Waktu pulang sudah tercatat.');
    if (now().isBefore(DateTime.parse(record['in'] as String))) {
      throw StateError('Waktu perangkat lebih awal dari waktu masuk.');
    }
    record['out'] = now().toIso8601String();
  });

  static int workDays(DateTime start, DateTime end) {
    var count = 0;
    for (
      var date = DateTime(start.year, start.month, start.day);
      !date.isAfter(end);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      if (date.weekday <= 5) count++;
    }
    return count;
  }

  Future<void> submit(
    String kind,
    DateTime start,
    DateTime end,
    String reason,
  ) => _commit((data) {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    if (!['Cuti', 'Izin'].contains(kind) || reason.trim().isEmpty) {
      throw ArgumentError('Jenis dan alasan wajib diisi.');
    }
    if (last.isBefore(first) || last.difference(first).inDays > 365) {
      throw ArgumentError('Rentang tanggal tidak valid (maksimal 366 hari).');
    }
    final days = workDays(first, last);
    if (days == 0) {
      throw ArgumentError('Pilih minimal satu hari kerja Senin–Jumat.');
    }
    if (requests.any(
      (r) =>
          r['status'] != 'Dibatalkan' &&
          !last.isBefore(DateTime.parse(r['start'] as String)) &&
          !first.isAfter(DateTime.parse(r['end'] as String)),
    )) {
      throw StateError('Tanggal bertumpuk dengan pengajuan yang masih aktif.');
    }
    if (kind == 'Cuti' && days > balance - reserved) {
      throw StateError('Saldo cuti demo tidak cukup.');
    }
    (data['requests'] as List).insert(0, {
      'id': 'request-${now().microsecondsSinceEpoch}',
      'kind': kind,
      'start': day(first),
      'end': day(last),
      'days': days,
      'reason': reason.trim(),
      'status': 'Menunggu',
    });
  });

  Future<void> decide(String id, {required bool approve}) => _commit((data) {
    final record = (data['requests'] as List).cast<DemoRecord>().firstWhere(
      (r) => r['id'] == id,
    );
    if (record['status'] != 'Menunggu') {
      throw StateError('Pengajuan sudah diproses.');
    }
    record['status'] = approve ? 'Disetujui' : 'Dibatalkan';
  });
}
