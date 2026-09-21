import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/ess/domain/ess_models.dart';
import 'package:hrm_app/features/ess/domain/ess_repository.dart';
import 'package:hrm_app/features/ess/ess_providers.dart';
import 'package:hrm_app/features/ess/presentation/screens/ess_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(AppTypography.fontFamily)..addFont(
          rootBundle.load('assets/fonts/PlusJakartaSans-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final dark in [false, true]) {
    for (final area in EssArea.values) {
      testWidgets('ESS ${area.name} golden, dark=$dark', (tester) async {
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                requestContextProvider.overrideWith(
                  (ref) => const RequestContext(
                    userId: 'fixture-user',
                    employeeId: 'fixture-employee',
                    activeCompanyId: 'fixture-company',
                    companyScope: ['fixture-company'],
                    permissions: [
                      'employee:read',
                      'employee-loan:read',
                      'ewa:create',
                      'ewa:update',
                      'daily-activity:create',
                      'daily-activity:update',
                      'daily-activity:delete',
                    ],
                  ),
                ),
                essRepositoryProvider.overrideWithValue(
                  const _GoldenEssRepository(),
                ),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                locale: const Locale('id', 'ID'),
                supportedLocales: const [Locale('id', 'ID')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 30, bottom: 20),
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: const ValueKey('ess-stage5-fixture'),
                  child: EssScreen(initialArea: area),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const ValueKey('ess-stage5-fixture')),
            matchesGoldenFile(
              'goldens/ess_stage5/${area.name}_${dark ? 'dark' : 'light'}_320_text200.png',
            ),
          );
        } finally {
          debugDisableShadows = previousShadows;
        }
      });
    }
  }
}

class _GoldenEssRepository implements EssRepository {
  const _GoldenEssRepository();

  @override
  Future<LoanSnapshot> getLoans() async => LoanSnapshot(
    types: const [LoanTypeOption(id: 'type-1', name: 'Pinjaman reguler')],
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
