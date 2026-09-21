import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/ess/data/dio_ess_repository.dart';
import 'package:hrm_app/features/ess/domain/ess_models.dart';
import 'package:hrm_app/features/ess/domain/ess_repository.dart';

final essRepositoryProvider = Provider<EssRepository>((ref) {
  final session = ref.watch(featureSessionProvider);
  return DioEssRepository(ref.watch(featureDioProvider), () => session.context);
});

final loanSnapshotProvider = FutureProvider.autoDispose
    .family<LoanSnapshot, FeatureSession>((ref, session) async {
      final value = await ref.watch(essRepositoryProvider).getLoans();
      _current(session);
      return value;
    });

final ewaSnapshotProvider = FutureProvider.autoDispose
    .family<EwaSnapshot, FeatureSession>((ref, session) async {
      final value = await ref.watch(essRepositoryProvider).getEwa();
      _current(session);
      return value;
    });

final activitySnapshotProvider = FutureProvider.autoDispose
    .family<ActivitySnapshot, FeatureSession>((ref, session) async {
      final value = await ref.watch(essRepositoryProvider).getActivities();
      _current(session);
      return value;
    });

final travelSnapshotProvider = FutureProvider.autoDispose
    .family<TravelSnapshot, FeatureSession>((ref, session) async {
      final value = await ref.watch(essRepositoryProvider).getTravel();
      _current(session);
      return value;
    });

final loanDetailProvider = FutureProvider.autoDispose
    .family<
      ({List<LoanInstallment> installments, LoanAmortization amortization}),
      ({FeatureSession session, String id})
    >((ref, query) async {
      final repository = ref.watch(essRepositoryProvider);
      final values = await Future.wait([
        repository.getLoanInstallments(query.id),
        repository.getLoanAmortization(query.id),
      ]);
      _current(query.session);
      return (
        installments: values[0] as List<LoanInstallment>,
        amortization: values[1] as LoanAmortization,
      );
    });

final ewaDetailProvider = FutureProvider.autoDispose
    .family<EwaRequest, ({FeatureSession session, String id})>((
      ref,
      query,
    ) async {
      final value = await ref
          .watch(essRepositoryProvider)
          .getEwaDetail(query.id);
      _current(query.session);
      return value;
    });

final activityDetailProvider = FutureProvider.autoDispose
    .family<DailyActivity, ({FeatureSession session, String id})>((
      ref,
      query,
    ) async {
      final value = await ref
          .watch(essRepositoryProvider)
          .getActivityDetail(query.id);
      _current(query.session);
      return value;
    });

final essMutationProvider =
    NotifierProvider<EssMutationController, AsyncValue<void>>(
      EssMutationController.new,
    );

class EssMutationController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> createLoan(CreateLoanCommand command) =>
      _run((repository) => repository.createLoan(command), _loans);

  Future<void> cancelLoan(String id) =>
      _run((repository) => repository.cancelLoan(id), _loans);

  Future<void> createEwa(CreateEwaCommand command) =>
      _run((repository) => repository.createEwa(command), _ewa);

  Future<void> cancelEwa(String id) =>
      _run((repository) => repository.cancelEwa(id), _ewa);

  Future<void> createActivity(CreateActivityCommand command) =>
      _run((repository) => repository.createActivity(command), _activities);

  Future<void> updateActivity(String id, UpdateActivityCommand command) =>
      _run((repository) => repository.updateActivity(id, command), _activities);

  Future<void> deleteActivity(String id) =>
      _run((repository) => repository.deleteActivity(id), _activities);

  Future<void> createTrip(CreateTripCommand command) =>
      _run((repository) => repository.createTrip(command), _travel);

  Future<void> createClaim(
    CreateClaimCommand command, {
    ReceiptFile? receipt,
  }) => _run((repository) async {
    var finalCommand = command;
    if (receipt != null) {
      final uploaded = await repository.uploadReceipt(receipt);
      finalCommand = CreateClaimCommand(
        category: command.category,
        amount: command.amount,
        expenseDate: command.expenseDate,
        tripId: command.tripId,
        description: command.description,
        notes: command.notes,
        receiptFilePath: uploaded.filePath,
      );
    }
    return repository.createClaim(finalCommand);
  }, _travel);

  Future<void> _run(
    Future<Object?> Function(EssRepository repository) action,
    void Function(Ref ref) invalidate,
  ) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final session = ref.read(featureSessionProvider);
    try {
      await action(ref.read(essRepositoryProvider));
      _current(session);
      invalidate(ref);
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }
}

void _loans(Ref ref) => ref.invalidate(loanSnapshotProvider);
void _ewa(Ref ref) => ref.invalidate(ewaSnapshotProvider);
void _activities(Ref ref) => ref.invalidate(activitySnapshotProvider);
void _travel(Ref ref) => ref.invalidate(travelSnapshotProvider);

void _current(FeatureSession session) {
  if (!session.isCurrent) {
    throw StateError('Sesi telah berubah. Muat ulang layanan employee.');
  }
}
