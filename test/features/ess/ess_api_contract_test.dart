import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/ess/data/dio_ess_repository.dart';
import 'package:hrm_app/features/ess/domain/ess_models.dart';

void main() {
  const context = RequestContext(
    userId: 'user-1',
    employeeId: 'employee-1',
    activeCompanyId: 'company-1',
    companyScope: ['company-1'],
    permissions: ['employee:read'],
  );

  test(
    'read endpoints use self routes and active-company loan type query',
    () async {
      final adapter = _EssAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = DioEssRepository(dio, () => context);

      final loans = await repository.getLoans();
      final ewa = await repository.getEwa();
      final activities = await repository.getActivities();
      final travel = await repository.getTravel();

      expect(loans.types.single.maxAmount, 10000000);
      expect(loans.loans.single.status, 'PENDING');
      expect(ewa.limit.remaining, 750000);
      expect(ewa.requests.single.amount, 250000);
      expect(activities.branch?.id, 'branch-1');
      expect(activities.activities.single.title, 'Kunjungan pelanggan');
      expect(travel.categories.single.value, 'TRANSPORTATION');
      expect(travel.trips.single.destination, 'Bandung');
      expect(travel.claims.single.amount, 175000);

      final types = adapter.requests.firstWhere(
        (request) => request.path == '/employee-loans/types',
      );
      expect(types.queryParameters, {'companyId': 'company-1'});
      expect(
        adapter.requests.map((request) => request.path),
        containsAll([
          '/employee-loans/my',
          '/ewa/my/limit',
          '/ewa/my',
          '/daily-activities/my',
          '/employees/employee-1',
          '/travel-expenses/categories',
          '/travel-expenses/trips/my',
          '/travel-expenses/claims/my',
        ]),
      );
    },
  );

  test(
    'loan create uses backend fields and never sends client identity',
    () async {
      final adapter = _EssAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = DioEssRepository(dio, () => context);

      await repository.createLoan(
        const CreateLoanCommand(
          loanTypeId: '11111111-1111-1111-1111-111111111111',
          amount: 1200000,
          totalInstallments: 6,
          reason: 'Kebutuhan keluarga',
        ),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/employee-loans');
      expect(request.data, {
        'loanTypeId': '11111111-1111-1111-1111-111111111111',
        'amount': 1200000.0,
        'totalInstallments': 6,
        'installmentAmount': 200000.0,
        'reason': 'Kebutuhan keluarga',
      });
      expect(request.data, isNot(contains('employeeId')));
      expect(request.data, isNot(contains('companyId')));
      expect(request.data, isNot(contains('tenorMonths')));
    },
  );

  test('EWA create omits server-owned earnings and period fields', () async {
    final adapter = _EssAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final repository = DioEssRepository(dio, () => context);

    await repository.createEwa(
      const CreateEwaCommand(amount: 300000, reason: 'Biaya sekolah'),
    );

    final request = adapter.requests.single;
    expect(request.path, '/ewa');
    expect(request.data, {
      'amountRequested': 300000.0,
      'reason': 'Biaya sekolah',
    });
    expect(request.data, isNot(contains('employeeId')));
    expect(request.data, isNot(contains('companyId')));
    expect(request.data, isNot(contains('earnedGross')));
    expect(request.data, isNot(contains('periodStart')));
    expect(request.data, isNot(contains('periodEnd')));
  });

  test(
    'daily activity sends server branch and captured GPS without identity',
    () async {
      final adapter = _EssAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = DioEssRepository(dio, () => context);

      await repository.createActivity(
        CreateActivityCommand(
          branchId: 'branch-1',
          title: 'Kunjungan pelanggan',
          type: 'SITE_VISIT',
          activityDate: DateTime(2026, 9, 20),
          startTime: DateTime(2026, 9, 20, 9),
          endTime: DateTime(2026, 9, 20, 10),
          latitude: -6.2,
          longitude: 106.8,
          accuracyMeters: 12,
        ),
      );

      final request = adapter.requests.single;
      expect(request.path, '/daily-activities');
      expect(request.data['branchId'], 'branch-1');
      expect(request.data['activityType'], 'SITE_VISIT');
      expect(request.data['latitude'], -6.2);
      expect(request.data, isNot(contains('employeeId')));
      expect(request.data, isNot(contains('companyId')));
    },
  );

  test(
    'travel payloads omit identity and receipt uses multipart endpoint',
    () async {
      final adapter = _EssAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = DioEssRepository(dio, () => context);

      await repository.createTrip(
        CreateTripCommand(
          destination: 'Bandung',
          purpose: 'Pertemuan pelanggan',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 2),
          estimatedCost: 1500000,
        ),
      );
      final receipt = await repository.uploadReceipt(
        ReceiptFile(
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'receipt.jpg',
          mimeType: 'image/jpeg',
        ),
      );
      await repository.createClaim(
        CreateClaimCommand(
          category: 'TRANSPORTATION',
          amount: 175000,
          expenseDate: DateTime(2026, 10, 1),
          receiptFilePath: receipt.filePath,
        ),
      );

      final trip = adapter.requests[0];
      expect(trip.data, isNot(contains('employeeId')));
      expect(trip.data, isNot(contains('companyId')));
      expect(
        adapter.requests[1].path,
        '/travel-expenses/claims/receipt-upload',
      );
      expect(adapter.requests[1].data, isA<FormData>());
      final claim = adapter.requests[2];
      expect(claim.data['receiptFilePath'], 'company-1/employee-1/receipt.jpg');
      expect(claim.data, isNot(contains('ocrExtractedAmount')));
    },
  );

  test('foreign employee/company data is rejected', () async {
    for (final defect in ['foreign-employee', 'foreign-company']) {
      final dio = Dio()..httpClientAdapter = _EssAdapter(defect: defect);
      addTearDown(dio.close);
      final repository = DioEssRepository(dio, () => context);
      await expectLater(repository.getLoans(), throwsFormatException);
    }
  });

  test('loan schedule uses server totals and rows', () async {
    final adapter = _EssAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final repository = DioEssRepository(dio, () => context);

    final installments = await repository.getLoanInstallments('loan-1');
    final amortization = await repository.getLoanAmortization('loan-1');

    expect(installments.single.amount, 210000);
    expect(amortization.totalPayment, 1260000);
    expect(amortization.rows.single.interest, 10000);
  });

  test(
    'permission-gated EWA and activity detail use documented paths',
    () async {
      final adapter = _EssAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = DioEssRepository(dio, () => context);

      expect((await repository.getEwaDetail('ewa-1')).id, 'ewa-1');
      expect(
        (await repository.getActivityDetail('activity-1')).id,
        'activity-1',
      );
      expect(adapter.requests.map((request) => request.path), [
        '/ewa/ewa-1',
        '/daily-activities/activity-1',
      ]);
    },
  );
}

class _EssAdapter implements HttpClientAdapter {
  _EssAdapter({this.defect});
  final String? defect;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data = _data(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      options.method == 'POST' ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Object? _data(RequestOptions options) =>
      switch ((options.method, options.path)) {
        ('GET', '/employee-loans/types') => [
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'name': 'Pinjaman reguler',
            'maxAmount': '10000000.00',
            'maxInstallments': 12,
            'interestRate': '6.00',
          },
        ],
        ('GET', '/employee-loans/my') => [_loan()],
        ('POST', '/employee-loans') => _loan(),
        ('PATCH', '/employee-loans/loan-1/cancel') => {
          ..._loan(),
          'status': 'CANCELLED',
        },
        ('GET', '/employee-loans/loan-1/installments') => [
          {
            'id': 'installment-1',
            'amount': '210000.00',
            'status': 'PENDING',
            'dueDate': '2026-10-20T00:00:00.000Z',
          },
        ],
        ('GET', '/employee-loans/loan-1/amortization') => {
          'principal': 1200000,
          'totalInterest': 60000,
          'totalPayment': 1260000,
          'rows': [
            {
              'month': 1,
              'principal': 200000,
              'interest': 10000,
              'total': 210000,
              'remaining': 1000000,
            },
          ],
        },
        ('GET', '/ewa/my/limit') => {
          'max': '1000000.00',
          'remaining': '750000.00',
          'totalApproved': '0.00',
          'totalReserved': '250000.00',
          'earnedGrossToDate': '2500000.00',
        },
        ('GET', '/ewa/my') => [_ewa()],
        ('GET', '/ewa/ewa-1') => _ewa(),
        ('POST', '/ewa') => _ewa(),
        ('POST', '/ewa/ewa-1/cancel') => {..._ewa(), 'status': 'CANCELLED'},
        ('GET', '/daily-activities/my') => [_activity()],
        ('GET', '/daily-activities/activity-1') => _activity(),
        ('GET', '/employees/employee-1') => {
          'id': 'employee-1',
          'companyId': 'company-1',
          'branch': {'id': 'branch-1', 'name': 'Jakarta'},
        },
        ('POST', '/daily-activities') ||
        ('PUT', '/daily-activities/activity-1') => _activity(),
        ('DELETE', '/daily-activities/activity-1') => {'id': 'activity-1'},
        ('GET', '/travel-expenses/categories') => [
          {'value': 'TRANSPORTATION', 'label': 'Transportasi'},
        ],
        ('GET', '/travel-expenses/trips/my') => [_trip()],
        ('GET', '/travel-expenses/claims/my') => [_claim()],
        ('POST', '/travel-expenses/trips') => _trip(),
        ('POST', '/travel-expenses/claims/receipt-upload') => {
          'filePath': 'company-1/employee-1/receipt.jpg',
          'originalName': 'receipt.jpg',
        },
        ('POST', '/travel-expenses/claims') => _claim(),
        _ => null,
      };

  Map<String, Object?> _identity() => {
    'employeeId': defect == 'foreign-employee' ? 'employee-2' : 'employee-1',
    'companyId': defect == 'foreign-company' ? 'company-2' : 'company-1',
  };

  Map<String, Object?> _loan() => {
    'id': 'loan-1',
    ..._identity(),
    'loanTypeId': '11111111-1111-1111-1111-111111111111',
    'loanType': {'name': 'Pinjaman reguler'},
    'amount': '1200000.00',
    'totalInstallments': 6,
    'installmentAmount': '210000.00',
    'remainingBalance': '1200000.00',
    'status': 'PENDING',
    'createdAt': '2026-09-20T01:00:00.000Z',
  };

  Map<String, Object?> _ewa() => {
    'id': 'ewa-1',
    ..._identity(),
    'requestCode': 'EWA-001',
    'amountRequested': '250000.00',
    'status': 'PENDING',
    'createdAt': '2026-09-20T01:00:00.000Z',
  };

  Map<String, Object?> _activity() => {
    'id': 'activity-1',
    ..._identity(),
    'activityType': 'SITE_VISIT',
    'title': 'Kunjungan pelanggan',
    'activityDate': '2026-09-20T00:00:00.000Z',
    'startTime': '2026-09-20T02:00:00.000Z',
    'endTime': '2026-09-20T03:00:00.000Z',
    'branch': {'id': 'branch-1', 'name': 'Jakarta'},
  };

  Map<String, Object?> _trip() => {
    'id': 'trip-1',
    ..._identity(),
    'destination': 'Bandung',
    'purpose': 'Pertemuan pelanggan',
    'startDate': '2026-10-01T00:00:00.000Z',
    'endDate': '2026-10-02T00:00:00.000Z',
    'estimatedCost': '1500000.00',
    'status': 'REQUESTED',
  };

  Map<String, Object?> _claim() => {
    'id': 'claim-1',
    ..._identity(),
    'category': 'TRANSPORTATION',
    'amount': '175000.00',
    'expenseDate': '2026-10-01T00:00:00.000Z',
    'status': 'SUBMITTED',
  };

  @override
  void close({bool force = false}) {}
}
