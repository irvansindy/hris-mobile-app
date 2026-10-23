import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/demo/demo_secondary_repositories.dart';
import 'package:hrm_app/features/account_security/account_security_providers.dart';
import 'package:hrm_app/features/account_security/domain/entities/account_security.dart';
import 'package:hrm_app/features/account_security/domain/repositories/account_security_repository.dart';
import 'package:hrm_app/features/account_security/presentation/screens/account_security_screen.dart';
import 'package:hrm_app/features/approvals/approval_dependencies.dart';
import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';
import 'package:hrm_app/features/approvals/domain/repositories/approval_repository.dart';
import 'package:hrm_app/features/approvals/presentation/screens/approval_center_screen.dart';
import 'package:hrm_app/features/ess/domain/ess_models.dart';
import 'package:hrm_app/features/ess/domain/ess_repository.dart';
import 'package:hrm_app/features/ess/ess_providers.dart';
import 'package:hrm_app/features/ess/presentation/screens/ess_screen.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';
import 'package:hrm_app/features/notifications/presentation/screens/notifications_screen.dart';

void main() {
  testWidgets('demo and production keep the same Notifications composition', (
    tester,
  ) async {
    const keys = [
      'notifications-header',
      'notifications-filters',
      'notifications-content',
    ];

    final demo = await _notificationOrder(tester, demo: true, keys: keys);
    final production = await _notificationOrder(
      tester,
      demo: false,
      keys: keys,
    );

    expect(demo, orderedEquals(keys));
    expect(production, orderedEquals(demo));
  });

  testWidgets('demo and production keep the same Approval composition', (
    tester,
  ) async {
    const keys = [
      'approval-header',
      'approval-delegations',
      'approval-content',
    ];

    final demo = await _approvalOrder(tester, demo: true, keys: keys);
    final production = await _approvalOrder(tester, demo: false, keys: keys);

    expect(demo, orderedEquals(keys));
    expect(production, orderedEquals(demo));
  });

  testWidgets('demo and production keep the same ESS composition', (
    tester,
  ) async {
    const keys = ['ess-header', 'ess-area-selector', 'ess-content'];

    final demo = await _essOrder(tester, demo: true, keys: keys);
    final production = await _essOrder(tester, demo: false, keys: keys);

    expect(demo, orderedEquals(keys));
    expect(production, orderedEquals(demo));
  });

  testWidgets(
    'demo and production keep the same account security composition',
    (tester) async {
      const keys = [
        'account-security-header',
        'account-security-mfa',
        'account-security-sessions',
      ];

      final demo = await _securityOrder(tester, demo: true, keys: keys);
      final production = await _securityOrder(tester, demo: false, keys: keys);

      expect(demo, orderedEquals(keys));
      expect(production, orderedEquals(demo));
    },
  );
}

Future<List<String>> _notificationOrder(
  WidgetTester tester, {
  required bool demo,
  required List<String> keys,
}) => _pumpAndReadOrder(
  tester,
  keys: keys,
  child: ProviderScope(
    key: UniqueKey(),
    overrides: [
      notificationRepositoryProvider.overrideWithValue(
        demo ? DemoNotifications() : _NotificationFixture(),
      ),
    ],
    child: const MaterialApp(home: NotificationsScreen()),
  ),
);

Future<List<String>> _approvalOrder(
  WidgetTester tester, {
  required bool demo,
  required List<String> keys,
}) => _pumpAndReadOrder(
  tester,
  keys: keys,
  child: ProviderScope(
    key: UniqueKey(),
    overrides: [
      approvalRepositoryProvider.overrideWithValue(
        demo ? DemoApprovals() : _ApprovalFixture(),
      ),
    ],
    child: const MaterialApp(home: ApprovalCenterScreen()),
  ),
);

Future<List<String>> _essOrder(
  WidgetTester tester, {
  required bool demo,
  required List<String> keys,
}) => _pumpAndReadOrder(
  tester,
  keys: keys,
  child: ProviderScope(
    key: UniqueKey(),
    overrides: [
      essRepositoryProvider.overrideWithValue(demo ? DemoEss() : _EssFixture()),
    ],
    child: const MaterialApp(home: EssScreen()),
  ),
);

Future<List<String>> _securityOrder(
  WidgetTester tester, {
  required bool demo,
  required List<String> keys,
}) => _pumpAndReadOrder(
  tester,
  keys: keys,
  child: ProviderScope(
    key: UniqueKey(),
    overrides: [
      accountSecurityRepositoryProvider.overrideWithValue(
        demo ? DemoAccountSecurity() : _SecurityFixture(),
      ),
    ],
    child: MaterialApp(
      home: AccountSecurityScreen(onCurrentSessionRevoked: () async {}),
    ),
  ),
);

Future<List<String>> _pumpAndReadOrder(
  WidgetTester tester, {
  required Widget child,
  required List<String> keys,
}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(child);
  await tester.pumpAndSettle();

  final positions = {
    for (final key in keys)
      key: tester.getTopLeft(find.byKey(ValueKey(key))).dy,
  };
  final ordered = positions.entries.toList()
    ..sort((left, right) => left.value.compareTo(right.value));
  expect(tester.takeException(), isNull);
  return ordered.map((entry) => entry.key).toList(growable: false);
}

class _NotificationFixture extends Fake implements NotificationRepository {
  @override
  Future<NotificationPage> load({int page = 1, int limit = 50}) async =>
      NotificationPage(
        page: page,
        totalPages: 1,
        total: 1,
        items: [
          const NotificationItem(
            id: 'production-notification',
            title: 'Notifikasi server',
            isRead: false,
          ),
        ],
      );

  @override
  Future<int> unreadCount() async => 1;
}

class _ApprovalFixture extends Fake implements ApprovalRepository {
  @override
  Future<WorkflowApprovalPage> getQueue({
    required int page,
    int limit = 20,
  }) async => WorkflowApprovalPage(
    items: [
      WorkflowApproval(
        stepId: 'production-step',
        instanceId: 'production-approval',
        companyId: 'production-company',
        referenceType: 'LEAVE_REQUEST',
        referenceId: 'production-leave',
        approvalType: 'LEAVE',
        title: 'Cuti produksi',
        stepName: 'Persetujuan manager',
        level: 1,
        status: 'PENDING',
        submittedAt: DateTime.utc(2026, 10, 4),
      ),
    ],
    page: page,
    totalPages: 1,
    total: 1,
  );
}

class _EssFixture extends Fake implements EssRepository {
  @override
  Future<LoanSnapshot> getLoans() async => LoanSnapshot(
    types: const [
      LoanTypeOption(id: 'production-loan', name: 'Pinjaman produksi'),
    ],
    loans: const [],
  );
}

class _SecurityFixture extends Fake implements AccountSecurityRepository {
  @override
  Future<List<AccountSession>> loadSessions() async => [
    AccountSession(
      id: 'production-session',
      createdAt: DateTime.utc(2026, 10, 4),
      expiresAt: DateTime.utc(2026, 10, 5),
    ),
  ];
}
