import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';

class DioCalendarRemoteDataSource {
  const DioCalendarRemoteDataSource(
    this._dio, {
    required this.employeeId,
    required this.companyId,
  });
  final Dio _dio;
  final String employeeId;
  final String companyId;

  Future<CalendarData> loadMonth(int year, int month) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/work-calendars/me/resolved',
        queryParameters: {'year': year, 'month': month},
      );
      final data = ApiEnvelope.fromJson(
        response.data ?? const {},
      ).requireObjectData();
      final employee = data['employee'];
      final period = data['period'];
      final days = data['days'];
      if (employee is! Map ||
          employee['id'] != employeeId ||
          period is! Map ||
          period['year'] != year ||
          period['month'] != month ||
          days is! List) {
        throw const FormatException(
          'Identitas atau periode kalender tidak sesuai sesi.',
        );
      }
      final events = <int, List<CalendarEvent>>{};
      final seen = <int>{};
      for (final raw in days) {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Jadwal kalender tidak valid.');
        }
        final date = raw['date'];
        final parsed =
            date is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)
            ? DateTime.tryParse(date)
            : null;
        if (parsed == null ||
            parsed.year != year ||
            parsed.month != month ||
            date !=
                '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' ||
            !seen.add(parsed.day) ||
            raw['isWorkingDay'] is! bool ||
            raw['dayType'] is! String) {
          throw const FormatException(
            'Tanggal atau jadwal kalender tidak valid.',
          );
        }
        final items = <CalendarEvent>[];
        final absence = raw['absence'];
        if (absence != null) {
          if (absence is! Map ||
              absence['label'] is! String ||
              absence['category'] is! String) {
            throw const FormatException('Ketidakhadiran kalender tidak valid.');
          }
          items.add(
            CalendarEvent(
              absence['label'] as String,
              CalendarEventTone.purple,
              detail: absence['category'] as String,
              time: absence['partialDay'] == true
                  ? 'Sebagian hari'
                  : 'Seharian',
            ),
          );
        }
        if (raw['isWorkingDay'] == true) {
          final start = raw['workStart'];
          final end = raw['workEnd'];
          items.add(
            CalendarEvent(
              _text(raw['label']) ??
                  _text(raw['shiftFormulaName']) ??
                  'Jadwal kerja',
              CalendarEventTone.primary,
              time: start is String && end is String ? '$start - $end' : null,
              detail: raw['overrideSource'] == 'SHIFT_SWAP'
                  ? 'Pertukaran shift'
                  : raw['scheduleSource'] == 'SHIFT_FORMULA'
                  ? 'Shift'
                  : 'Kalender kerja',
            ),
          );
        } else if (absence == null) {
          items.add(
            CalendarEvent(
              _text(raw['label']) ?? 'Hari tidak bekerja',
              raw['dayType'] == 'NH' || raw['dayType'] == 'JL'
                  ? CalendarEventTone.danger
                  : CalendarEventTone.info,
              time: 'Seharian',
              detail: _text(raw['notes']),
            ),
          );
        }
        events[parsed.day] = List.unmodifiable(items);
      }
      if (seen.length != DateTime(year, month + 1, 0).day) {
        throw const FormatException('Jadwal kalender bulan ini belum lengkap.');
      }
      return CalendarData(
        focusedDate: DateTime(year, month),
        eventsByDay: Map.unmodifiable(events),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<NextShiftResult> loadNextShift(DateTime from) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/work-calendars/me/next-shift',
        queryParameters: {'from': _dateOnly(from)},
      );
      final data = ApiEnvelope.fromJson(
        response.data ?? const {},
      ).requireObjectData();
      final employee = data['employee'];
      if (employee is! Map || employee['id'] != employeeId) {
        throw const FormatException('Identitas next shift tidak sesuai sesi.');
      }
      final fromDate = _requiredDateOnly(data, 'fromDate');
      final throughDate = _requiredDateOnly(data, 'throughDate');
      if (throughDate.isBefore(fromDate)) {
        throw const FormatException('Rentang next shift tidak valid.');
      }
      final rawShift = data['shift'];
      if (rawShift != null && rawShift is! Map<String, dynamic>) {
        throw const FormatException('Next shift tidak valid.');
      }
      final shift = rawShift == null ? null : _shift(rawShift);
      if (shift != null &&
          (shift.date.isBefore(fromDate) || shift.date.isAfter(throughDate))) {
        throw const FormatException('Tanggal next shift tidak valid.');
      }
      return NextShiftResult(
        timezone: _requiredText(data, 'timezone'),
        serverDate: _requiredDateOnly(data, 'serverDate'),
        fromDate: fromDate,
        throughDate: throughDate,
        shift: shift,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<WorkHoliday>> loadHolidays(int year) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/work-calendars/holidays/list',
        queryParameters: {'year': year},
      );
      return _objectList(response.data, 'Holiday list')
          .map((item) {
            if (_requiredText(item, 'companyId') != companyId ||
                _requiredInteger(item, 'year') != year) {
              throw const FormatException(
                'Holiday tidak sesuai sesi atau tahun.',
              );
            }
            final type = _requiredText(item, 'type');
            if (type != 'NH' && type != 'JL') {
              throw const FormatException('Tipe holiday tidak valid.');
            }
            return WorkHoliday(
              id: _requiredText(item, 'id'),
              date: _requiredDate(item, 'date'),
              name: _requiredText(item, 'name'),
              type: type,
            );
          })
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<ShiftSwapCandidate>> loadShiftSwapCandidates(
    DateTime shiftDate,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/work-calendars/shift-swaps/candidates/my',
        queryParameters: {'shiftDate': _dateOnly(shiftDate)},
      );
      final data = ApiEnvelope.fromJson(
        response.data ?? const {},
      ).requireObjectData();
      final requester = data['requester'];
      final candidates = data['candidates'];
      if (requester is! Map ||
          requester['id'] != employeeId ||
          requester['companyId'] != companyId ||
          candidates is! List ||
          candidates.any((item) => item is! Map<String, dynamic>)) {
        throw const FormatException('Kandidat tukar shift tidak valid.');
      }
      final seen = <String>{};
      return candidates
          .cast<Map<String, dynamic>>()
          .map((item) {
            final id = _requiredText(item, 'id');
            if (id == employeeId || !seen.add(id)) {
              throw const FormatException('Kandidat tukar shift tidak valid.');
            }
            return ShiftSwapCandidate(
              employeeId: id,
              employeeNumber: _requiredText(item, 'employeeNumber'),
              fullName: _requiredText(item, 'fullName'),
            );
          })
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<ShiftSwapRequest>> loadMyShiftSwaps() =>
      _loadShiftSwaps('/work-calendars/shift-swaps/my', approval: false);

  Future<List<ShiftSwapRequest>> loadMyShiftSwapApprovals() => _loadShiftSwaps(
    '/work-calendars/shift-swaps/approvals/my',
    approval: true,
  );

  Future<ShiftSwapRequest> createShiftSwap(
    CreateShiftSwapCommand command,
  ) async {
    _requireSafeId(command.targetEmployeeId);
    final reason = command.reason.trim();
    if (command.targetEmployeeId == employeeId ||
        reason.isEmpty ||
        reason.length > 1000) {
      throw const ApiException('Data pengajuan tukar shift tidak valid.');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/work-calendars/shift-swaps',
        data: {
          'targetEmployeeId': command.targetEmployeeId,
          'shiftDate': _dateOnly(command.shiftDate),
          'reason': reason,
        },
      );
      final result = _shiftSwap(
        ApiEnvelope.fromJson(response.data ?? const {}).requireObjectData(),
        approval: false,
      );
      if (result.status != ShiftSwapStatus.pending) {
        throw const FormatException('Status tukar shift baru tidak valid.');
      }
      return result;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> cancelShiftSwap(String requestId) async {
    _requireSafeId(requestId);
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/work-calendars/shift-swaps/$requestId/cancel',
      );
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success || envelope.data != null) {
        throw const FormatException(
          'Respons pembatalan tukar shift tidak valid.',
        );
      }
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<ShiftSwapRequest>> _loadShiftSwaps(
    String path, {
    required bool approval,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return _objectList(response.data, 'Shift swap list')
          .map((item) => _shiftSwap(item, approval: approval))
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  CalendarShift _shift(Map<String, dynamic> json) {
    if (json['isWorkingDay'] != true) {
      throw const FormatException('Next shift bukan hari kerja.');
    }
    return CalendarShift(
      date: _requiredDateOnly(json, 'date'),
      label:
          _text(json['label']) ??
          _text(json['shiftFormulaName']) ??
          'Jadwal kerja',
      dayType: _requiredText(json, 'dayType'),
      workStart: _nullableText(json['workStart']),
      workEnd: _nullableText(json['workEnd']),
      crossesMidnight: json['crossesMidnight'] == true,
    );
  }

  ShiftSwapRequest _shiftSwap(
    Map<String, dynamic> json, {
    required bool approval,
  }) {
    final requesterId = _requiredText(json, 'requesterEmployeeId');
    final approverId = _requiredText(json, 'approverEmployeeId');
    if (_requiredText(json, 'companyId') != companyId ||
        (approval ? approverId : requesterId) != employeeId) {
      throw const FormatException('Tukar shift tidak sesuai sesi aktif.');
    }
    final counterpart = approval
        ? json['requesterEmployee']
        : json['targetEmployee'];
    if (counterpart is! Map<String, dynamic>) {
      throw const FormatException('Rekan tukar shift tidak valid.');
    }
    return ShiftSwapRequest(
      id: _requiredText(json, 'id'),
      companyId: companyId,
      requesterEmployeeId: requesterId,
      targetEmployeeId: _requiredText(json, 'targetEmployeeId'),
      approverEmployeeId: approverId,
      shiftDate: _requiredDate(json, 'shiftDate'),
      reason: _requiredText(json, 'reason'),
      status: _shiftSwapStatus(_requiredText(json, 'status')),
      counterpartName: _requiredText(counterpart, 'fullName'),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

String? _nullableText(Object? value) => value == null ? null : _text(value);

String _requiredText(Map<dynamic, dynamic> json, String key) {
  final value = _text(json[key]);
  if (value == null) throw FormatException('$key is invalid');
  return value;
}

int _requiredInteger(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key is invalid');
  return value;
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw FormatException('$key is invalid');
  return parsed;
}

DateTime _requiredDateOnly(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('$key is invalid');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || _dateOnly(parsed) != value) {
    throw FormatException('$key is invalid');
  }
  return parsed;
}

List<Map<String, dynamic>> _objectList(
  Map<String, dynamic>? json,
  String label,
) {
  final data = ApiEnvelope.fromJson(json ?? const {}).requireListData();
  if (data.any((item) => item is! Map<String, dynamic>)) {
    throw FormatException('$label response is invalid');
  }
  return data.cast<Map<String, dynamic>>();
}

ShiftSwapStatus _shiftSwapStatus(String value) => switch (value) {
  'PENDING' => ShiftSwapStatus.pending,
  'APPROVED' => ShiftSwapStatus.approved,
  'REJECTED' => ShiftSwapStatus.rejected,
  'CANCELLED' => ShiftSwapStatus.cancelled,
  _ => throw FormatException('Unknown shift swap status: $value'),
};

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

void _requireSafeId(String value) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(value)) {
    throw const ApiException('ID tukar shift tidak valid.');
  }
}
