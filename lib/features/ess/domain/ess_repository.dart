import 'package:hrm_app/features/ess/domain/ess_models.dart';

abstract interface class EssRepository {
  Future<LoanSnapshot> getLoans();
  Future<EmployeeLoan> createLoan(CreateLoanCommand command);
  Future<EmployeeLoan> cancelLoan(String id);
  Future<List<LoanInstallment>> getLoanInstallments(String id);
  Future<LoanAmortization> getLoanAmortization(String id);

  Future<EwaSnapshot> getEwa();
  Future<EwaRequest> getEwaDetail(String id);
  Future<EwaRequest> createEwa(CreateEwaCommand command);
  Future<EwaRequest> cancelEwa(String id);

  Future<ActivitySnapshot> getActivities();
  Future<DailyActivity> getActivityDetail(String id);
  Future<DailyActivity> createActivity(CreateActivityCommand command);
  Future<DailyActivity> updateActivity(
    String id,
    UpdateActivityCommand command,
  );
  Future<void> deleteActivity(String id);

  Future<TravelSnapshot> getTravel();
  Future<BusinessTrip> createTrip(CreateTripCommand command);
  Future<ReceiptUpload> uploadReceipt(ReceiptFile file);
  Future<ExpenseClaim> createClaim(CreateClaimCommand command);
}
