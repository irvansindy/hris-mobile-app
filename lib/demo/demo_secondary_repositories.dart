import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/features/account_security/domain/entities/account_security.dart';
import 'package:hrm_app/features/account_security/domain/repositories/account_security_repository.dart';
import 'package:hrm_app/features/approvals/domain/entities/workflow_approval.dart';
import 'package:hrm_app/features/approvals/domain/repositories/approval_repository.dart';
import 'package:hrm_app/features/ess/domain/ess_models.dart';
import 'package:hrm_app/features/ess/domain/ess_repository.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';

class DemoNotifications implements NotificationRepository {
  final List<NotificationItem> _items = [
    NotificationItem(
      id: 'demo-welcome',
      title: 'Mode demo aktif',
      message: 'Data pada perangkat ini tidak dikirim ke server.',
      isRead: false,
      createdAt: DateTime(2026, 10, 4, 8),
    ),
  ];

  @override
  Future<NotificationPage> load({int page = 1, int limit = 50}) async {
    if (page < 1 || limit < 1 || limit > 100) {
      throw ArgumentError('Halaman tidak valid.');
    }
    return NotificationPage(
      items: _items.skip((page - 1) * limit).take(limit).toList(),
      page: page,
      total: _items.length,
      totalPages: (_items.length / limit).ceil(),
    );
  }

  @override
  Future<int> unreadCount() async =>
      _items.where((item) => !item.isRead).length;

  @override
  Future<void> read(List<String> ids) async {
    final selected = ids.toSet();
    _replaceReadWhere((item) => selected.contains(item.id));
  }

  @override
  Future<void> readAll() async => _replaceReadWhere((_) => true);

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((item) => item.id == id);
  }

  void _replaceReadWhere(bool Function(NotificationItem item) test) {
    for (var index = 0; index < _items.length; index++) {
      final item = _items[index];
      if (!test(item)) continue;
      _items[index] = NotificationItem(
        id: item.id,
        title: item.title,
        message: item.message,
        type: item.type,
        resource: item.resource,
        action: item.action,
        referenceId: item.referenceId,
        createdAt: item.createdAt,
        isRead: true,
      );
    }
  }
}

class DemoApprovals implements ApprovalRepository {
  @override
  Future<WorkflowApprovalDetail> getDetail(String instanceId) =>
      _unavailable('Detail approval');

  @override
  Future<WorkflowApprovalPage> getQueue({
    required int page,
    int limit = 20,
  }) async => WorkflowApprovalPage(
    items: const [],
    page: page,
    totalPages: 1,
    total: 0,
  );

  @override
  Future<List<ApprovalDelegation>> getDelegations() async => const [];

  @override
  Future<void> applyAction({
    required String instanceId,
    required WorkflowApprovalAction action,
    String? comment,
    String? subjectEmployeeId,
  }) => _unavailable('Keputusan approval');

  @override
  Future<WorkflowBulkResult> applyBulkAction({
    required List<String> instanceIds,
    required WorkflowApprovalAction action,
    String? comment,
  }) => _unavailable('Approval massal');

  @override
  Future<ApprovalDelegation> createDelegation(
    CreateApprovalDelegation command,
  ) => _unavailable('Delegasi approval');

  @override
  Future<ApprovalDelegation> revokeDelegation(String id) =>
      _unavailable('Delegasi approval');
}

class DemoEss implements EssRepository {
  @override
  Future<AssetPage> getAssets({
    int page = 1,
    int limit = 20,
    AssetAssignmentStatus status = AssetAssignmentStatus.active,
  }) async =>
      AssetPage(items: const [], page: page, total: 0, hasNextPage: false);

  @override
  Future<LoanSnapshot> getLoans() async =>
      const LoanSnapshot(types: [], loans: []);

  @override
  Future<EwaSnapshot> getEwa() async => const EwaSnapshot(
    limit: EwaLimit(
      maximum: 0,
      remaining: 0,
      totalApproved: 0,
      totalReserved: 0,
      earnedGrossToDate: 0,
    ),
    requests: [],
  );

  @override
  Future<ActivitySnapshot> getActivities() async =>
      const ActivitySnapshot(activities: [], branch: null);

  @override
  Future<TravelSnapshot> getTravel() async =>
      const TravelSnapshot(categories: [], trips: [], claims: []);

  @override
  Future<EmployeeLoan> createLoan(CreateLoanCommand command) =>
      _unavailable('Pinjaman');

  @override
  Future<EmployeeLoan> cancelLoan(String id) => _unavailable('Pinjaman');

  @override
  Future<List<LoanInstallment>> getLoanInstallments(String id) =>
      _unavailable('Rincian pinjaman');

  @override
  Future<LoanAmortization> getLoanAmortization(String id) =>
      _unavailable('Amortisasi pinjaman');

  @override
  Future<EwaRequest> getEwaDetail(String id) => _unavailable('EWA');

  @override
  Future<EwaRequest> createEwa(CreateEwaCommand command) => _unavailable('EWA');

  @override
  Future<EwaRequest> cancelEwa(String id) => _unavailable('EWA');

  @override
  Future<DailyActivity> getActivityDetail(String id) =>
      _unavailable('Aktivitas harian');

  @override
  Future<DailyActivity> createActivity(CreateActivityCommand command) =>
      _unavailable('Aktivitas harian');

  @override
  Future<DailyActivity> updateActivity(
    String id,
    UpdateActivityCommand command,
  ) => _unavailable('Aktivitas harian');

  @override
  Future<void> deleteActivity(String id) => _unavailable('Aktivitas harian');

  @override
  Future<BusinessTrip> createTrip(CreateTripCommand command) =>
      _unavailable('Perjalanan dinas');

  @override
  Future<ReceiptUpload> uploadReceipt(ReceiptFile file) =>
      _unavailable('Unggah bukti');

  @override
  Future<ExpenseClaim> createClaim(CreateClaimCommand command) =>
      _unavailable('Klaim biaya');
}

class DemoAccountSecurity implements AccountSecurityRepository {
  @override
  Future<List<AccountSession>> loadSessions() async => const [];

  @override
  Future<MfaSetup> setupMfa() => _unavailable('MFA');

  @override
  Future<MfaEnableResult> enableMfa(String code) => _unavailable('MFA');

  @override
  Future<void> disableMfa(String code) => _unavailable('MFA');

  @override
  Future<void> revokeSession(String id) => _unavailable('Sesi akun');
}

Future<T> _unavailable<T>(String feature) => Future.error(
  ApiException(
    '$feature belum disimulasikan dalam mode demo lokal.',
    code: 'DEMO_UNAVAILABLE',
  ),
);
