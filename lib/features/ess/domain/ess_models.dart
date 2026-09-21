import 'dart:typed_data';

class LoanTypeOption {
  const LoanTypeOption({
    required this.id,
    required this.name,
    this.maxAmount,
    this.maxInstallments,
    this.interestRate,
  });

  final String id;
  final String name;
  final double? maxAmount;
  final int? maxInstallments;
  final double? interestRate;
}

class EmployeeLoan {
  const EmployeeLoan({
    required this.id,
    required this.loanTypeName,
    required this.amount,
    required this.status,
    required this.totalInstallments,
    required this.createdAt,
    this.installmentAmount,
    this.remainingBalance,
  });

  final String id;
  final String loanTypeName;
  final double amount;
  final String status;
  final int totalInstallments;
  final DateTime? createdAt;
  final double? installmentAmount;
  final double? remainingBalance;

  bool get canCancel => status.toUpperCase() == 'PENDING';
}

class LoanInstallment {
  const LoanInstallment({
    required this.id,
    required this.amount,
    required this.status,
    this.dueDate,
    this.paidDate,
  });

  final String id;
  final double amount;
  final String status;
  final DateTime? dueDate;
  final DateTime? paidDate;
}

class LoanAmortization {
  const LoanAmortization({
    required this.principal,
    required this.totalInterest,
    required this.totalPayment,
    required this.rows,
  });

  final double principal;
  final double totalInterest;
  final double totalPayment;
  final List<LoanAmortizationRow> rows;
}

class LoanAmortizationRow {
  const LoanAmortizationRow({
    required this.month,
    required this.principal,
    required this.interest,
    required this.total,
    required this.remaining,
  });
  final int month;
  final double principal;
  final double interest;
  final double total;
  final double remaining;
}

class EwaLimit {
  const EwaLimit({
    required this.maximum,
    required this.remaining,
    required this.totalApproved,
    required this.totalReserved,
    required this.earnedGrossToDate,
  });

  final double maximum;
  final double remaining;
  final double totalApproved;
  final double totalReserved;
  final double earnedGrossToDate;
}

class EwaRequest {
  const EwaRequest({
    required this.id,
    required this.amount,
    required this.status,
    this.requestCode,
    this.reason,
    this.createdAt,
  });

  final String id;
  final double amount;
  final String status;
  final String? requestCode;
  final String? reason;
  final DateTime? createdAt;

  bool get canCancel => status.toUpperCase() == 'PENDING';
}

class EmployeeBranch {
  const EmployeeBranch({required this.id, required this.name});

  final String id;
  final String name;
}

class DailyActivity {
  const DailyActivity({
    required this.id,
    required this.title,
    required this.type,
    required this.activityDate,
    required this.startTime,
    required this.endTime,
    required this.branchName,
    this.description,
    this.notes,
  });

  final String id;
  final String title;
  final String type;
  final DateTime activityDate;
  final DateTime startTime;
  final DateTime endTime;
  final String branchName;
  final String? description;
  final String? notes;
}

class ExpenseCategory {
  const ExpenseCategory({required this.value, required this.label});

  final String value;
  final String label;
}

class BusinessTrip {
  const BusinessTrip({
    required this.id,
    required this.destination,
    required this.purpose,
    required this.startDate,
    required this.endDate,
    required this.estimatedCost,
    required this.status,
  });

  final String id;
  final String destination;
  final String purpose;
  final DateTime startDate;
  final DateTime endDate;
  final double estimatedCost;
  final String status;
}

class ExpenseClaim {
  const ExpenseClaim({
    required this.id,
    required this.category,
    required this.amount,
    required this.expenseDate,
    required this.status,
    this.description,
  });

  final String id;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String status;
  final String? description;
}

class LoanSnapshot {
  const LoanSnapshot({required this.types, required this.loans});
  final List<LoanTypeOption> types;
  final List<EmployeeLoan> loans;
}

class EwaSnapshot {
  const EwaSnapshot({required this.limit, required this.requests});
  final EwaLimit limit;
  final List<EwaRequest> requests;
}

class ActivitySnapshot {
  const ActivitySnapshot({required this.activities, required this.branch});
  final List<DailyActivity> activities;
  final EmployeeBranch? branch;
}

class TravelSnapshot {
  const TravelSnapshot({
    required this.categories,
    required this.trips,
    required this.claims,
  });
  final List<ExpenseCategory> categories;
  final List<BusinessTrip> trips;
  final List<ExpenseClaim> claims;
}

class CreateLoanCommand {
  const CreateLoanCommand({
    required this.loanTypeId,
    required this.amount,
    required this.totalInstallments,
    required this.reason,
  });
  final String loanTypeId;
  final double amount;
  final int totalInstallments;
  final String reason;
}

class CreateEwaCommand {
  const CreateEwaCommand({required this.amount, this.reason});
  final double amount;
  final String? reason;
}

class CreateActivityCommand {
  const CreateActivityCommand({
    required this.branchId,
    required this.title,
    required this.type,
    required this.activityDate,
    required this.startTime,
    required this.endTime,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.description,
    this.notes,
  });
  final String branchId;
  final String title;
  final String type;
  final DateTime activityDate;
  final DateTime startTime;
  final DateTime endTime;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String? description;
  final String? notes;
}

class UpdateActivityCommand {
  const UpdateActivityCommand({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.notes,
  });
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;
  final String? notes;
}

class CreateTripCommand {
  const CreateTripCommand({
    required this.destination,
    required this.purpose,
    required this.startDate,
    required this.endDate,
    required this.estimatedCost,
    this.notes,
  });
  final String destination;
  final String purpose;
  final DateTime startDate;
  final DateTime endDate;
  final double estimatedCost;
  final String? notes;
}

class ReceiptUpload {
  const ReceiptUpload({required this.filePath, required this.originalName});
  final String filePath;
  final String originalName;
}

class ReceiptFile {
  const ReceiptFile({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });
  final Uint8List bytes;
  final String name;
  final String mimeType;
}

class CreateClaimCommand {
  const CreateClaimCommand({
    required this.category,
    required this.amount,
    required this.expenseDate,
    this.tripId,
    this.description,
    this.notes,
    this.receiptFilePath,
  });
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String? tripId;
  final String? description;
  final String? notes;
  final String? receiptFilePath;
}
