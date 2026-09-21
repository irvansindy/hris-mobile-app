import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/ess/domain/ess_models.dart';
import 'package:hrm_app/features/ess/domain/ess_repository.dart';
import 'package:hrm_app/features/ess/ess_providers.dart';
import 'package:hrm_app/features/ess/presentation/screens/ess_screen.dart';

const _context = RequestContext(
  userId: 'user-1',
  employeeId: 'employee-1',
  activeCompanyId: 'company-1',
  companyScope: ['company-1'],
  permissions: [
    'employee:read',
    'employee-loan:read',
    'ewa:create',
    'ewa:update',
    'daily-activity:create',
    'daily-activity:update',
    'daily-activity:delete',
  ],
);

void main() {
  for (final area in EssArea.values) {
    for (final dark in [false, true]) {
      testWidgets('${area.name} fits 320dp at 200% text, dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              requestContextProvider.overrideWith((ref) => _context),
              essRepositoryProvider.overrideWithValue(_EssRepository()),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              locale: const Locale('id', 'ID'),
              supportedLocales: const [Locale('id', 'ID')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  padding: const EdgeInsets.only(top: 30),
                ),
                child: child!,
              ),
              home: EssScreen(initialArea: area),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Layanan Employee'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Layanan Employee')).dy,
          greaterThanOrEqualTo(46),
        );
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('permission gates hide EWA and activity mutations', (
    tester,
  ) async {
    const readonly = RequestContext(
      userId: 'user-1',
      employeeId: 'employee-1',
      activeCompanyId: 'company-1',
      companyScope: ['company-1'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requestContextProvider.overrideWith((ref) => readonly),
          essRepositoryProvider.overrideWithValue(_EssRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EssScreen(initialArea: EssArea.ewa),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('belum memiliki izin ewa:create'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Ajukan'), findsNothing);
  });

  testWidgets('employee can open every ESS composer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pump(EssArea area) => tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          requestContextProvider.overrideWith((ref) => _context),
          essRepositoryProvider.overrideWithValue(_EssRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: EssScreen(initialArea: area),
        ),
      ),
    );

    await pump(EssArea.loan);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Ajukan'));
    await tester.pumpAndSettle();
    expect(find.text('Ajukan pinjaman'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pump(EssArea.ewa);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Ajukan'));
    await tester.pumpAndSettle();
    expect(find.text('Ajukan EWA'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pump(EssArea.activity);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Catat'));
    await tester.pumpAndSettle();
    expect(find.text('Catat aktivitas'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pump(EssArea.travel);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Buat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Klaim biaya'));
    await tester.pumpAndSettle();
    expect(find.text('Ajukan klaim biaya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('late ESS response is rejected after account switch', () async {
    final pending = Completer<LoanSnapshot>();
    final first = _EssRepository(pendingLoans: pending);
    final second = _EssRepository();
    final container = ProviderContainer(
      overrides: [
        essRepositoryProvider.overrideWith((ref) {
          return ref.watch(requestContextProvider)?.userId == 'user-1'
              ? first
              : second;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(requestContextProvider.notifier).state = _context;
    final firstSession = container.read(featureSessionProvider);
    final firstLoad = container.read(loanSnapshotProvider(firstSession).future);

    container
        .read(requestContextProvider.notifier)
        .state = const RequestContext(
      userId: 'user-2',
      employeeId: 'employee-2',
      activeCompanyId: 'company-2',
      companyScope: ['company-2'],
    );
    final secondSession = container.read(featureSessionProvider);
    expect(
      (await container.read(
        loanSnapshotProvider(secondSession).future,
      )).loans.single.id,
      'loan-1',
    );

    pending.complete(_loanSnapshot);
    await expectLater(firstLoad, throwsStateError);
  });
}

final _loanSnapshot = LoanSnapshot(
  types: const [
    LoanTypeOption(
      id: 'type-1',
      name: 'Pinjaman reguler',
      maxAmount: 10000000,
      maxInstallments: 12,
    ),
  ],
  loans: [
    EmployeeLoan(
      id: 'loan-1',
      loanTypeName: 'Pinjaman reguler',
      amount: 1200000,
      status: 'PENDING',
      totalInstallments: 6,
      createdAt: DateTime(2026, 9, 20),
    ),
  ],
);

class _EssRepository implements EssRepository {
  _EssRepository({this.pendingLoans});
  final Completer<LoanSnapshot>? pendingLoans;

  @override
  Future<LoanSnapshot> getLoans() async =>
      pendingLoans?.future ?? _loanSnapshot;

  @override
  Future<EwaSnapshot> getEwa() async => EwaSnapshot(
    limit: const EwaLimit(
      maximum: 1000000,
      remaining: 750000,
      totalApproved: 0,
      totalReserved: 250000,
      earnedGrossToDate: 2500000,
    ),
    requests: [
      EwaRequest(
        id: 'ewa-1',
        amount: 250000,
        status: 'PENDING',
        requestCode: 'EWA-001',
        createdAt: DateTime(2026, 9, 20),
      ),
    ],
  );

  @override
  Future<EwaRequest> getEwaDetail(String id) async =>
      (await getEwa()).requests.single;

  @override
  Future<ActivitySnapshot> getActivities() async => ActivitySnapshot(
    branch: const EmployeeBranch(id: 'branch-1', name: 'Jakarta'),
    activities: [
      DailyActivity(
        id: 'activity-1',
        title: 'Kunjungan pelanggan',
        type: 'SITE_VISIT',
        activityDate: DateTime(2026, 9, 20),
        startTime: DateTime(2026, 9, 20, 9),
        endTime: DateTime(2026, 9, 20, 10),
        branchName: 'Jakarta',
      ),
    ],
  );

  @override
  Future<DailyActivity> getActivityDetail(String id) async =>
      (await getActivities()).activities.single;

  @override
  Future<TravelSnapshot> getTravel() async => TravelSnapshot(
    categories: const [
      ExpenseCategory(value: 'TRANSPORTATION', label: 'Transportasi'),
    ],
    trips: [
      BusinessTrip(
        id: 'trip-1',
        destination: 'Bandung',
        purpose: 'Pertemuan pelanggan',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 2),
        estimatedCost: 1500000,
        status: 'REQUESTED',
      ),
    ],
    claims: [
      ExpenseClaim(
        id: 'claim-1',
        category: 'TRANSPORTATION',
        amount: 175000,
        expenseDate: DateTime(2026, 10, 1),
        status: 'SUBMITTED',
      ),
    ],
  );

  @override
  Future<EmployeeLoan> createLoan(CreateLoanCommand command) =>
      throw UnimplementedError();
  @override
  Future<EmployeeLoan> cancelLoan(String id) => throw UnimplementedError();
  @override
  Future<List<LoanInstallment>> getLoanInstallments(String id) async =>
      const [];
  @override
  Future<LoanAmortization> getLoanAmortization(String id) async =>
      const LoanAmortization(
        principal: 0,
        totalInterest: 0,
        totalPayment: 0,
        rows: [],
      );
  @override
  Future<EwaRequest> createEwa(CreateEwaCommand command) =>
      throw UnimplementedError();
  @override
  Future<EwaRequest> cancelEwa(String id) => throw UnimplementedError();
  @override
  Future<DailyActivity> createActivity(CreateActivityCommand command) =>
      throw UnimplementedError();
  @override
  Future<DailyActivity> updateActivity(
    String id,
    UpdateActivityCommand command,
  ) => throw UnimplementedError();
  @override
  Future<void> deleteActivity(String id) => throw UnimplementedError();
  @override
  Future<BusinessTrip> createTrip(CreateTripCommand command) =>
      throw UnimplementedError();
  @override
  Future<ReceiptUpload> uploadReceipt(ReceiptFile file) =>
      throw UnimplementedError();
  @override
  Future<ExpenseClaim> createClaim(CreateClaimCommand command) =>
      throw UnimplementedError();
}
