import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/calendar/data/datasources/calendar_remote_datasource.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';

void main() {
  for (final period in [
    (year: 2024, month: 2),
    (year: 2026, month: 12),
    (year: 2027, month: 1),
  ]) {
    test(
      'resolved self calendar maps date-only ${period.year}/${period.month}',
      () async {
        final adapter = _CalendarAdapter(period.year, period.month);
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(dio.close);
        final data = await DioCalendarRemoteDataSource(
          dio,
          employeeId: 'employee-1',
        ).loadMonth(period.year, period.month);
        expect(adapter.request!.path, '/work-calendars/me/resolved');
        expect(adapter.request!.queryParameters, {
          'year': period.year,
          'month': period.month,
        });
        expect(
          data.eventsByDay.length,
          DateTime(period.year, period.month + 1, 0).day,
        );
        expect(data.eventsByDay[1]!.single.label, 'Shift pagi');
        expect(data.eventsByDay[2]!.single.tone, CalendarEventTone.purple);
        expect(data.eventsByDay[3]!.single.tone, CalendarEventTone.danger);
      },
    );
  }
  for (final defect in [
    'identity',
    'period',
    'date',
    'incomplete',
    'failure',
  ]) {
    test(
      'calendar rejects $defect rather than showing empty success',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _CalendarAdapter(2026, 9, defect: defect);
        addTearDown(dio.close);
        await expectLater(
          DioCalendarRemoteDataSource(
            dio,
            employeeId: 'employee-1',
          ).loadMonth(2026, 9),
          throwsFormatException,
        );
      },
    );
  }
}

class _CalendarAdapter implements HttpClientAdapter {
  _CalendarAdapter(this.year, this.month, {this.defect});
  final int year;
  final int month;
  final String? defect;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final count = DateTime(year, month + 1, 0).day;
    return ResponseBody.fromString(
      jsonEncode({
        'success': defect != 'failure',
        'data': {
          'employee': {
            'id': defect == 'identity' ? 'another-employee' : 'employee-1',
          },
          'period': {
            'year': year,
            'month': defect == 'period' ? month + 1 : month,
          },
          'days': [
            for (
              var day = 1;
              day <= (defect == 'incomplete' ? count - 1 : count);
              day++
            )
              {
                'date': defect == 'date' && day == 1
                    ? '$year-02-31'
                    : '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
                'isWorkingDay': day != 2 && day != 3,
                'dayType': day == 3 ? 'HOLIDAY' : 'WORKDAY',
                'label': 'Shift pagi',
                'scheduleSource': 'SHIFT_FORMULA',
                'workStart': '08:00',
                'workEnd': '17:00',
                'absence': day == 2
                    ? {'category': 'CUTI', 'label': 'Cuti tahunan'}
                    : null,
              },
          ],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
