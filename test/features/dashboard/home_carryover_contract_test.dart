import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/dashboard/dashboard_dependencies.dart';
import 'package:hrm_app/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:hrm_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:hrm_app/features/dashboard/presentation/screens/home_screen.dart';

const _fallback = DashboardSnapshot(
  employee: DashboardEmployee(
    name: 'Employee',
    initials: 'E',
    avatarColorIndex: 0,
  ),
  leaveBalances: [],
  announcements: [],
);
const _context = RequestContext(
  userId: 'u1',
  employeeId: 'e1',
  activeCompanyId: 'c1',
  companyScope: ['c1'],
);

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'server carry-over is informational, preserves decimals, and fits 320dp text200 dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final dio = Dio()..httpClientAdapter = _Adapter();
        addTearDown(dio.close);
        final snapshot = (await tester.runAsync(
          () => DioDashboardRemoteDataSource(dio).fetch(_context, _fallback),
        ))!;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardRepositoryProvider.overrideWithValue(
                _Repository(snapshot),
              ),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: HomeScreen(onOpenAttendance: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.textContaining('Cuti bawaan: 2.5 hari'),
          400,
        );
        expect(find.textContaining('Cuti bawaan: 2.5 hari'), findsOneWidget);
        expect(find.textContaining('31 Des 2026'), findsOneWidget);
        expect(find.textContaining('10 dari 12 hari tersisa'), findsOneWidget);
        await tester.ensureVisible(
          find.textContaining('Cuti bawaan: 2.5 hari'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final value in [null, 'invalid', -1, 'Infinity']) {
    test(
      'invalid optional carry-over does not corrupt the available balance: $value',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _Adapter(carryOver: value, expiry: 'invalid');
        addTearDown(dio.close);
        final snapshot = await DioDashboardRemoteDataSource(
          dio,
        ).fetch(_context, _fallback);
        expect(snapshot.leaveBalances.single.total, 12);
        expect(snapshot.leaveBalances.single.used, 2);
        expect(snapshot.leaveBalances.single.carryOverDays, 0);
        expect(snapshot.leaveBalances.single.carryOverExpiredAt, isNull);
        expect(snapshot.leaveBalancesAvailable, isTrue);
      },
    );
  }
}

class _Repository implements DashboardRepository {
  _Repository(this.current);
  @override
  final DashboardSnapshot current;
  @override
  Future<DashboardSnapshot> refresh() async => current;
}

class _Adapter implements HttpClientAdapter {
  _Adapter({this.carryOver = 2.5, this.expiry = '2026-12-31T00:00:00.000Z'});
  final Object? carryOver;
  final String expiry;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': options.path == '/leave/balances/employee'
            ? [
                {
                  'leaveType': {'code': 'ANNUAL', 'name': 'Cuti tahunan'},
                  'quota': 12,
                  'used': 2,
                  'remaining': 10,
                  'carryOverDays': carryOver,
                  'carryOverExpiredAt': expiry,
                  'futureField': {'unknownEnum': 'FUTURE_VALUE'},
                },
              ]
            : [],
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
