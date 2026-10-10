import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
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
          companyId: 'company-1',
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
            companyId: 'company-1',
          ).loadMonth(2026, 9),
          throwsFormatException,
        );
      },
    );
  }

  test('next shift supports cross-month result and nullable shift', () async {
    final adapter = _CalendarAdapter(2026, 9);
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioCalendarRemoteDataSource(
      dio,
      employeeId: 'employee-1',
      companyId: 'company-1',
    );

    final result = await remote.loadNextShift(DateTime(2026, 9, 30));
    expect(result.shift?.date, DateTime(2026, 10, 1));
    expect(adapter.request!.path, '/work-calendars/me/next-shift');
    expect(adapter.request!.queryParameters, {'from': '2026-09-30'});

    adapter.defect = 'no-next-shift';
    expect((await remote.loadNextShift(DateTime(2026, 9, 30))).shift, isNull);
  });

  test('next shift rejects malformed payload and maps network error', () async {
    final adapter = _CalendarAdapter(2026, 9, defect: 'bad-next-shift');
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioCalendarRemoteDataSource(
      dio,
      employeeId: 'employee-1',
      companyId: 'company-1',
    );

    await expectLater(
      remote.loadNextShift(DateTime(2026, 9, 30)),
      throwsFormatException,
    );
    adapter.defect = 'network';
    await expectLater(
      remote.loadNextShift(DateTime(2026, 9, 30)),
      throwsA(isA<ApiException>()),
    );
  });

  test('holiday list is tenant scoped and preserves JL', () async {
    final adapter = _CalendarAdapter(2026, 9);
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioCalendarRemoteDataSource(
      dio,
      employeeId: 'employee-1',
      companyId: 'company-1',
    );

    final holidays = await remote.loadHolidays(2026);
    expect(holidays.single.type, 'JL');
    expect(adapter.request!.path, '/work-calendars/holidays/list');
    expect(adapter.request!.queryParameters, {'year': 2026});
  });

  test('shift swap lists and candidates preserve empty states', () async {
    final adapter = _CalendarAdapter(2026, 9, defect: 'empty-shift-swaps');
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioCalendarRemoteDataSource(
      dio,
      employeeId: 'employee-1',
      companyId: 'company-1',
    );

    expect(await remote.loadMyShiftSwaps(), isEmpty);
    expect(await remote.loadMyShiftSwapApprovals(), isEmpty);
    expect(
      await remote.loadShiftSwapCandidates(DateTime(2026, 10, 1)),
      isEmpty,
    );
  });

  test(
    'shift swap create and cancel use employee routes and safe requestId',
    () async {
      final adapter = _CalendarAdapter(2026, 9);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final remote = DioCalendarRemoteDataSource(
        dio,
        employeeId: 'employee-1',
        companyId: 'company-1',
      );

      final created = await remote.createShiftSwap(
        CreateShiftSwapCommand(
          targetEmployeeId: 'employee-2',
          shiftDate: DateTime(2026, 10, 1),
          reason: 'Tukar jadwal keluarga',
        ),
      );
      expect(created.status, ShiftSwapStatus.pending);
      expect(adapter.request!.path, '/work-calendars/shift-swaps');
      expect(adapter.request!.data, {
        'targetEmployeeId': 'employee-2',
        'shiftDate': '2026-10-01',
        'reason': 'Tukar jadwal keluarga',
      });

      await remote.cancelShiftSwap('request-1');
      expect(
        adapter.request!.path,
        '/work-calendars/shift-swaps/request-1/cancel',
      );
      expect(adapter.request!.method, 'PATCH');
      await expectLater(
        remote.cancelShiftSwap('../request-1'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('foreign shift swap ownership is rejected', () async {
    final adapter = _CalendarAdapter(2026, 9, defect: 'foreign-shift-swap');
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final remote = DioCalendarRemoteDataSource(
      dio,
      employeeId: 'employee-1',
      companyId: 'company-1',
    );

    await expectLater(remote.loadMyShiftSwaps(), throwsFormatException);
  });
}

class _CalendarAdapter implements HttpClientAdapter {
  _CalendarAdapter(this.year, this.month, {this.defect});
  final int year;
  final int month;
  String? defect;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (defect == 'network') {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    if (options.path == '/work-calendars/me/next-shift') {
      return _json({
        'timezone': 'Asia/Jakarta',
        'serverDate': '2026-09-30',
        'fromDate': '2026-09-30',
        'throughDate': '2026-12-31',
        'employee': {'id': 'employee-1'},
        'shift': defect == 'no-next-shift'
            ? null
            : {
                if (defect != 'bad-next-shift') 'date': '2026-10-01',
                'isWorkingDay': true,
                'dayType': 'WD',
                'label': 'Shift malam',
                'workStart': '22:00',
                'workEnd': '06:00',
                'crossesMidnight': true,
              },
      });
    }
    if (options.path == '/work-calendars/holidays/list') {
      return _json([
        {
          'id': 'holiday-1',
          'companyId': 'company-1',
          'date': '2026-08-17T00:00:00.000Z',
          'year': 2026,
          'name': 'Cuti bersama',
          'type': 'JL',
        },
      ]);
    }
    if (options.path == '/work-calendars/shift-swaps/candidates/my') {
      return _json({
        'requester': {'id': 'employee-1', 'companyId': 'company-1'},
        'approver': {'id': 'employee-3'},
        'candidates': defect == 'empty-shift-swaps'
            ? <Object?>[]
            : [
                {
                  'id': 'employee-2',
                  'employeeNumber': 'EMP002',
                  'fullName': 'Budi',
                },
              ],
      });
    }
    if (options.path == '/work-calendars/shift-swaps/my') {
      return _json(defect == 'empty-shift-swaps' ? <Object?>[] : [_swap()]);
    }
    if (options.path == '/work-calendars/shift-swaps/approvals/my') {
      return _json(
        defect == 'empty-shift-swaps' ? <Object?>[] : [_swap(approval: true)],
      );
    }
    if (options.path == '/work-calendars/shift-swaps') {
      return _json(_swap());
    }
    if (options.path.endsWith('/cancel')) return _json(null);
    final count = DateTime(year, month + 1, 0).day;
    return _json({
      'employee': {
        'id': defect == 'identity' ? 'another-employee' : 'employee-1',
      },
      'period': {'year': year, 'month': defect == 'period' ? month + 1 : month},
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
            'dayType': day == 3 ? 'JL' : 'WD',
            'label': 'Shift pagi',
            'scheduleSource': 'SHIFT_FORMULA',
            'workStart': day == 3 ? null : '08:00',
            'workEnd': day == 3 ? null : '17:00',
            'absence': day == 2
                ? {'category': 'CUTI', 'label': 'Cuti tahunan'}
                : null,
          },
      ],
    }, success: defect != 'failure');
  }

  Map<String, Object?> _swap({bool approval = false}) => {
    'id': 'request-1',
    'companyId': defect == 'foreign-shift-swap' ? 'company-2' : 'company-1',
    'requesterEmployeeId': approval ? 'employee-2' : 'employee-1',
    'targetEmployeeId': approval ? 'employee-3' : 'employee-2',
    'approverEmployeeId': approval ? 'employee-1' : 'employee-3',
    'shiftDate': '2026-10-01T00:00:00.000Z',
    'reason': 'Tukar jadwal keluarga',
    'status': 'PENDING',
    'createdAt': '2026-09-29T08:00:00.000Z',
    'updatedAt': '2026-09-29T08:00:00.000Z',
    'requesterEmployee': {
      'id': approval ? 'employee-2' : 'employee-1',
      'fullName': approval ? 'Siti' : 'Maya',
      'employeeNumber': approval ? 'EMP002' : 'EMP001',
    },
    'targetEmployee': {
      'id': approval ? 'employee-3' : 'employee-2',
      'fullName': approval ? 'Budi' : 'Siti',
      'employeeNumber': approval ? 'EMP003' : 'EMP002',
    },
  };

  ResponseBody _json(Object? data, {bool success = true}) =>
      ResponseBody.fromString(
        jsonEncode({'success': success, 'data': data}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}
