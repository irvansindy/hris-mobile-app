import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/approvals/approval_dependencies.dart';
import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';
import 'package:hrm_app/features/approvals/domain/repositories/approval_repository.dart';
import 'package:hrm_app/features/approvals/presentation/screens/approval_center_screen.dart';
import 'package:hrm_app/features/approvals/presentation/screens/approval_delegations_screen.dart';

void main() {
  testWidgets('queue covers loading, error retry, and empty states', (
    tester,
  ) async {
    final repo = _ApprovalRepo()..queueGate = Completer();
    await tester.pumpWidget(_app(repo, const ApprovalCenterScreen()));
    await tester.pump();
    expect(find.text('Memuat antrean approval'), findsOneWidget);

    repo.queueGate!.completeError(
      const ApiException('Jaringan terputus.', code: 'NETWORK_ERROR'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Antrean approval gagal dimuat'), findsOneWidget);

    repo.queueGate = null;
    repo.queue = _page(const []);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('approval-empty')), findsOneWidget);
  });

  testWidgets('bulk approval keeps failed item selected with server error', (
    tester,
  ) async {
    final repo = _ApprovalRepo()
      ..queue = _page([_item('instance-a'), _item('instance-b')])
      ..bulkResult = const WorkflowBulkResult(
        total: 1,
        successful: 0,
        failed: 1,
        results: [
          WorkflowBulkItemResult(
            instanceId: 'instance-a',
            success: false,
            error: 'Sudah diproses approver lain.',
          ),
        ],
      );
    await tester.pumpWidget(_app(repo, const ApprovalCenterScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('approval-select-instance-a')));
    await tester.pump();
    expect(find.text('1 item dipilih.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('approval-bulk-submit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Setujui terpilih').last,
    );
    await tester.pumpAndSettle();

    expect(repo.bulkIds, ['instance-a']);
    expect(find.text('Sudah diproses approver lain.'), findsOneWidget);
    expect(find.text('0 berhasil, 1 perlu ditinjau.'), findsOneWidget);
    expect(find.text('1 item dipilih.'), findsOneWidget);
  });

  testWidgets('reject requires a reason and waits for server confirmation', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repo = _ApprovalRepo()
      ..queue = _page([_item('instance-a')])
      ..actionGate = gate;
    await tester.pumpWidget(_app(repo, const ApprovalCenterScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('approval-card-instance-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tolak dengan alasan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Tolak'));
    await tester.pump();
    expect(find.text('Alasan penolakan wajib diisi.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      'Saldo cuti tidak cukup',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tolak'));
    await tester.pump();
    expect(repo.action, WorkflowApprovalAction.reject);
    expect(repo.actionComment, 'Saldo cuti tidak cukup');
    expect(find.text('Tolak berhasil disimpan.'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Tolak berhasil disimpan.'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('queue fits 320dp at 200% text, dark=$dark', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final repo = _ApprovalRepo()..queue = _page([_item('instance-a')]);
      await tester.pumpWidget(
        _app(repo, const ApprovalCenterScreen(), dark: dark, textScale: 2),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cuti Tahunan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('delegation form validates recipient before mutation', (
    tester,
  ) async {
    final repo = _ApprovalRepo();
    await tester.pumpWidget(_app(repo, const ApprovalDelegationsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada delegasi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delegation-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delegation-submit')));
    await tester.pump();
    expect(find.text('ID pengguna penerima wajib diisi.'), findsOneWidget);
    expect(repo.created, isNull);
  });

  testWidgets('active delegation is revoked only after confirmation', (
    tester,
  ) async {
    final repo = _ApprovalRepo()
      ..delegations = [
        ApprovalDelegation(
          id: 'delegation-a',
          companyId: 'company-a',
          delegatorId: 'manager-a',
          delegateId: 'manager-b',
          delegateLabel: 'Manager B',
          startDate: DateTime(2026, 9, 18),
          endDate: DateTime(2026, 9, 20),
          isActive: true,
        ),
      ];
    await tester.pumpWidget(_app(repo, const ApprovalDelegationsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('delegation-revoke-delegation-a')),
    );
    await tester.pumpAndSettle();
    expect(repo.revokedId, isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Cabut delegasi'));
    await tester.pumpAndSettle();
    expect(repo.revokedId, 'delegation-a');
    expect(find.text('Delegasi berhasil dicabut.'), findsOneWidget);
  });
}

Widget _app(
  ApprovalRepository repo,
  Widget home, {
  bool dark = false,
  double textScale = 1,
}) => ProviderScope(
  overrides: [approvalRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: dark ? AppTheme.dark : AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 30),
      ),
      child: child!,
    ),
    home: home,
  ),
);

WorkflowApprovalPage _page(List<WorkflowApproval> items) =>
    WorkflowApprovalPage(
      items: items,
      page: 1,
      totalPages: 1,
      total: items.length,
    );

WorkflowApproval _item(String id) => WorkflowApproval(
  stepId: 'step-$id',
  instanceId: id,
  companyId: 'company-a',
  referenceType: 'LEAVE_REQUEST',
  referenceId: 'leave-$id',
  approvalType: 'LEAVE',
  title: 'Cuti Tahunan',
  stepName: 'Persetujuan manager',
  level: 1,
  status: 'PENDING',
  submittedAt: DateTime.utc(2026, 9, 18),
  requesterLabel: 'Karyawan A',
);

class _ApprovalRepo implements ApprovalRepository {
  WorkflowApprovalPage queue = _page(const []);
  Completer<WorkflowApprovalPage>? queueGate;
  Completer<void>? actionGate;
  WorkflowBulkResult bulkResult = const WorkflowBulkResult(
    total: 0,
    successful: 0,
    failed: 0,
    results: [],
  );
  List<ApprovalDelegation> delegations = const [];
  WorkflowApprovalAction? action;
  String? actionComment;
  List<String>? bulkIds;
  CreateApprovalDelegation? created;
  String? revokedId;

  @override
  Future<WorkflowApprovalPage> getQueue({required int page, int limit = 20}) =>
      queueGate?.future ?? Future.value(queue);

  @override
  Future<void> applyAction({
    required String instanceId,
    required WorkflowApprovalAction action,
    String? comment,
  }) {
    this.action = action;
    actionComment = comment;
    return actionGate?.future ?? Future.value();
  }

  @override
  Future<WorkflowBulkResult> applyBulkAction({
    required List<String> instanceIds,
    required WorkflowApprovalAction action,
    String? comment,
  }) async {
    bulkIds = instanceIds;
    return bulkResult;
  }

  @override
  Future<List<ApprovalDelegation>> getDelegations() async => delegations;

  @override
  Future<ApprovalDelegation> createDelegation(
    CreateApprovalDelegation command,
  ) async {
    created = command;
    return ApprovalDelegation(
      id: 'created-a',
      companyId: 'company-a',
      delegatorId: 'manager-a',
      delegateId: command.delegateId,
      startDate: command.startDate,
      endDate: command.endDate,
      isActive: true,
      reason: command.reason,
    );
  }

  @override
  Future<ApprovalDelegation> revokeDelegation(String id) async {
    revokedId = id;
    final item = delegations.singleWhere((value) => value.id == id);
    return ApprovalDelegation(
      id: item.id,
      companyId: item.companyId,
      delegatorId: item.delegatorId,
      delegateId: item.delegateId,
      delegateLabel: item.delegateLabel,
      startDate: item.startDate,
      endDate: item.endDate,
      isActive: false,
      reason: item.reason,
    );
  }
}
