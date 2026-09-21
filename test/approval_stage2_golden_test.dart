import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/approvals/approval_dependencies.dart';
import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';
import 'package:hrm_app/features/approvals/domain/repositories/approval_repository.dart';
import 'package:hrm_app/features/approvals/presentation/screens/approval_center_screen.dart';
import 'package:hrm_app/features/approvals/presentation/screens/approval_delegations_screen.dart';

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
    for (final screen in ['center', 'delegations']) {
      testWidgets('approval $screen golden, dark=$dark', (tester) async {
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                approvalRepositoryProvider.overrideWithValue(
                  const _GoldenApprovals(),
                ),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 30, bottom: 20),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: const ValueKey('approval-stage2-fixture'),
                  child: screen == 'center'
                      ? const ApprovalCenterScreen()
                      : const ApprovalDelegationsScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const ValueKey('approval-stage2-fixture')),
            matchesGoldenFile(
              'goldens/approval_stage2/${screen}_${dark ? 'dark' : 'light'}.png',
            ),
          );
        } finally {
          debugDisableShadows = previousShadows;
        }
      });
    }
  }
}

class _GoldenApprovals implements ApprovalRepository {
  const _GoldenApprovals();

  @override
  Future<WorkflowApprovalPage> getQueue({required int page, int limit = 20}) {
    final items = [
      WorkflowApproval(
        stepId: 'step-leave',
        instanceId: 'approval-leave',
        companyId: 'company-fixture',
        referenceType: 'LEAVE_REQUEST',
        referenceId: 'leave-fixture',
        approvalType: 'LEAVE',
        title: 'Cuti tahunan',
        stepName: 'Persetujuan manager',
        level: 1,
        status: 'PENDING',
        submittedAt: DateTime.utc(2026, 9, 18),
        requesterLabel: 'Maya Anggraini',
      ),
      WorkflowApproval(
        stepId: 'step-overtime',
        instanceId: 'approval-overtime',
        companyId: 'company-fixture',
        referenceType: 'OVERTIME_REQUEST',
        referenceId: 'overtime-fixture',
        approvalType: 'OVERTIME',
        title: 'Lembur proyek September',
        stepName: 'Persetujuan atasan',
        level: 1,
        status: 'PENDING',
        submittedAt: DateTime.utc(2026, 9, 17),
        requesterLabel: 'Raka Pratama',
      ),
    ];
    return Future.value(
      WorkflowApprovalPage(
        items: items,
        page: page,
        totalPages: 1,
        total: items.length,
      ),
    );
  }

  @override
  Future<List<ApprovalDelegation>> getDelegations() async => [
    ApprovalDelegation(
      id: 'delegation-active',
      companyId: 'company-fixture',
      delegatorId: 'manager-fixture',
      delegateId: 'manager-delegate',
      delegateLabel: 'Dimas Pratama',
      startDate: DateTime(2026, 9, 18),
      endDate: DateTime(2026, 9, 22),
      isActive: true,
      reason: 'Perjalanan dinas',
    ),
    ApprovalDelegation(
      id: 'delegation-revoked',
      companyId: 'company-fixture',
      delegatorId: 'manager-fixture',
      delegateId: 'manager-old',
      delegateLabel: 'Sarah Wijaya',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 5),
      isActive: false,
    ),
  ];

  @override
  Future<void> applyAction({
    required String instanceId,
    required WorkflowApprovalAction action,
    String? comment,
  }) => throw UnimplementedError();

  @override
  Future<WorkflowBulkResult> applyBulkAction({
    required List<String> instanceIds,
    required WorkflowApprovalAction action,
    String? comment,
  }) => throw UnimplementedError();

  @override
  Future<ApprovalDelegation> createDelegation(
    CreateApprovalDelegation command,
  ) => throw UnimplementedError();

  @override
  Future<ApprovalDelegation> revokeDelegation(String id) =>
      throw UnimplementedError();
}
