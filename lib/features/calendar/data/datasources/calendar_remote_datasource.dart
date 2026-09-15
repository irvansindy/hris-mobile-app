import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';

class DioCalendarRemoteDataSource {
  const DioCalendarRemoteDataSource(this._dio, {required this.employeeId});
  final Dio _dio;
  final String employeeId;

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
              raw['dayType'] == 'HOLIDAY'
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
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
