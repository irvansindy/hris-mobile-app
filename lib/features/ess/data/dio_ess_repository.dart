import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/ess/domain/ess_models.dart';
import 'package:hrm_app/features/ess/domain/ess_repository.dart';

class DioEssRepository implements EssRepository {
  const DioEssRepository(this._dio, this._context);

  final Dio _dio;
  final RequestContext? Function() _context;

  @override
  Future<LoanSnapshot> getLoans() async {
    final context = _requireContext();
    try {
      final responses = await Future.wait([
        _dio.get<Map<String, dynamic>>(
          '/employee-loans/types',
          queryParameters: {'companyId': context.activeCompanyId},
        ),
        _dio.get<Map<String, dynamic>>('/employee-loans/my'),
      ]);
      return LoanSnapshot(
        types: _list(responses[0]).map(_loanType).toList(growable: false),
        loans: _list(
          responses[1],
        ).map((json) => _loan(json, context)).toList(growable: false),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<EmployeeLoan> createLoan(CreateLoanCommand command) async {
    final context = _requireContext();
    if (command.amount <= 0 || command.totalInstallments < 1) {
      throw const ApiException('Nominal dan jumlah cicilan tidak valid.');
    }
    if (command.reason.trim().isEmpty || command.reason.length > 1000) {
      throw const ApiException(
        'Alasan pinjaman wajib diisi, maksimal 1000 karakter.',
      );
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/employee-loans',
        data: {
          'loanTypeId': command.loanTypeId,
          'amount': command.amount,
          'totalInstallments': command.totalInstallments,
          // Backend requires this field, then replaces it with its own schedule.
          'installmentAmount': _roundMoney(
            command.amount / command.totalInstallments,
          ),
          'reason': command.reason.trim(),
        },
      );
      return _loan(_object(response), context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<EmployeeLoan> cancelLoan(String id) async {
    final context = _requireContext();
    _safeId(id);
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/employee-loans/$id/cancel',
      );
      final loan = _loan(_object(response), context);
      if (loan.status.toUpperCase() != 'CANCELLED') {
        throw const FormatException(
          'Server tidak mengonfirmasi pembatalan pinjaman.',
        );
      }
      return loan;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<List<LoanInstallment>> getLoanInstallments(String id) async {
    _requireContext();
    _safeId(id);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/employee-loans/$id/installments',
      );
      return _list(response).map(_installment).toList(growable: false);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<LoanAmortization> getLoanAmortization(String id) async {
    _requireContext();
    _safeId(id);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/employee-loans/$id/amortization',
        queryParameters: const {'method': 'FLAT'},
      );
      final json = _object(response);
      final rawRows = json['rows'];
      if (rawRows is! List || rawRows.any((item) => item is! Map)) {
        throw const FormatException('Jadwal amortisasi tidak valid.');
      }
      return LoanAmortization(
        principal: _money(json, 'principal'),
        totalInterest: _money(json, 'totalInterest'),
        totalPayment: _money(json, 'totalPayment'),
        rows: rawRows
            .cast<Map>()
            .map((raw) {
              final row = Map<String, dynamic>.from(raw);
              return LoanAmortizationRow(
                month: _integer(row, 'month'),
                principal: _money(row, 'principal'),
                interest: _money(row, 'interest'),
                total: _money(row, 'total'),
                remaining: _money(row, 'remaining'),
              );
            })
            .toList(growable: false),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<EwaSnapshot> getEwa() async {
    final context = _requireContext();
    try {
      final responses = await Future.wait([
        _dio.get<Map<String, dynamic>>('/ewa/my/limit'),
        _dio.get<Map<String, dynamic>>('/ewa/my'),
      ]);
      final limit = _object(responses[0]);
      return EwaSnapshot(
        limit: EwaLimit(
          maximum: _money(limit, 'max'),
          remaining: _money(limit, 'remaining'),
          totalApproved: _money(limit, 'totalApproved'),
          totalReserved: _money(limit, 'totalReserved'),
          earnedGrossToDate: _money(limit, 'earnedGrossToDate'),
        ),
        requests: _list(
          responses[1],
        ).map((json) => _ewa(json, context)).toList(growable: false),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<EwaRequest> createEwa(CreateEwaCommand command) async {
    final context = _requireContext();
    if (command.amount <= 0) {
      throw const ApiException('Nominal EWA harus lebih dari nol.');
    }
    if (command.reason case final reason?
        when reason.trim().isNotEmpty && reason.trim().length < 3) {
      throw const ApiException('Alasan EWA minimal 3 karakter.');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ewa',
        data: {
          'amountRequested': command.amount,
          if (command.reason?.trim().isNotEmpty == true)
            'reason': command.reason!.trim(),
        },
      );
      return _ewa(_object(response), context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<EwaRequest> getEwaDetail(String id) async {
    final context = _requireContext();
    _safeId(id);
    try {
      final response = await _dio.get<Map<String, dynamic>>('/ewa/$id');
      return _ewa(_object(response), context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<EwaRequest> cancelEwa(String id) async {
    final context = _requireContext();
    _safeId(id);
    try {
      final response = await _dio.post<Map<String, dynamic>>('/ewa/$id/cancel');
      final request = _ewa(_object(response), context);
      if (request.status.toUpperCase() != 'CANCELLED') {
        throw const FormatException(
          'Server tidak mengonfirmasi pembatalan EWA.',
        );
      }
      return request;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<ActivitySnapshot> getActivities() async {
    final context = _requireContext();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/daily-activities/my',
        queryParameters: {
          'startDate': start.toUtc().toIso8601String(),
          'endDate': end.toUtc().toIso8601String(),
        },
      );
      final branch = context.permissions.contains('employee:read')
          ? await _employeeBranch(context)
          : null;
      return ActivitySnapshot(
        activities: _list(
          response,
        ).map((json) => _activity(json, context)).toList(growable: false),
        branch: branch,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<DailyActivity> createActivity(CreateActivityCommand command) async {
    final context = _requireContext();
    _validateActivity(command.title, command.startTime, command.endTime);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/daily-activities',
        data: {
          'branchId': command.branchId,
          'activityDate': _date(command.activityDate),
          'activityType': command.type,
          'title': command.title.trim(),
          if (command.description?.trim().isNotEmpty == true)
            'description': command.description!.trim(),
          'latitude': command.latitude,
          'longitude': command.longitude,
          'geoAccuracyMeters': command.accuracyMeters,
          'startTime': command.startTime.toUtc().toIso8601String(),
          'endTime': command.endTime.toUtc().toIso8601String(),
          if (command.notes?.trim().isNotEmpty == true)
            'notes': command.notes!.trim(),
        },
      );
      return _activity(_object(response), context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<DailyActivity> getActivityDetail(String id) async {
    final context = _requireContext();
    _safeId(id);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/daily-activities/$id',
      );
      return _activity(_object(response), context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<DailyActivity> updateActivity(
    String id,
    UpdateActivityCommand command,
  ) async {
    final context = _requireContext();
    _safeId(id);
    _validateActivity(command.title, command.startTime, command.endTime);
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/daily-activities/$id',
        data: {
          'title': command.title.trim(),
          'startTime': command.startTime.toUtc().toIso8601String(),
          'endTime': command.endTime.toUtc().toIso8601String(),
          'description': command.description?.trim() ?? '',
          'notes': command.notes?.trim() ?? '',
        },
      );
      return _activity(_object(response), context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<void> deleteActivity(String id) async {
    _requireContext();
    _safeId(id);
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/daily-activities/$id',
      );
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success) {
        throw const FormatException(
          'Server tidak mengonfirmasi penghapusan aktivitas.',
        );
      }
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<TravelSnapshot> getTravel() async {
    final context = _requireContext();
    try {
      final responses = await Future.wait([
        _dio.get<Map<String, dynamic>>('/travel-expenses/categories'),
        _dio.get<Map<String, dynamic>>('/travel-expenses/trips/my'),
        _dio.get<Map<String, dynamic>>('/travel-expenses/claims/my'),
      ]);
      return TravelSnapshot(
        categories: _list(responses[0]).map(_category).toList(growable: false),
        trips: _list(
          responses[1],
        ).map((json) => _trip(json, context)).toList(growable: false),
        claims: _list(
          responses[2],
        ).map((json) => _claim(json, context)).toList(growable: false),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<BusinessTrip> createTrip(CreateTripCommand command) async {
    final context = _requireContext();
    if (command.destination.trim().isEmpty || command.purpose.trim().isEmpty) {
      throw const ApiException('Tujuan dan keperluan perjalanan wajib diisi.');
    }
    if (command.endDate.isBefore(command.startDate) ||
        command.estimatedCost < 0) {
      throw const ApiException(
        'Tanggal atau estimasi biaya perjalanan tidak valid.',
      );
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/travel-expenses/trips',
        data: {
          'destination': command.destination.trim(),
          'purpose': command.purpose.trim(),
          'startDate': _date(command.startDate),
          'endDate': _date(command.endDate),
          'estimatedCost': command.estimatedCost,
          if (command.notes?.trim().isNotEmpty == true)
            'notes': command.notes!.trim(),
        },
      );
      return _trip(_object(response), context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<ReceiptUpload> uploadReceipt(ReceiptFile file) async {
    _requireContext();
    if (file.bytes.isEmpty || file.bytes.length > 5 * 1024 * 1024) {
      throw const ApiException('Ukuran bukti harus antara 1 byte dan 5 MB.');
    }
    if (!const {'image/jpeg', 'image/png'}.contains(file.mimeType)) {
      throw const ApiException('Bukti harus berupa gambar JPG atau PNG.');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/travel-expenses/claims/receipt-upload',
        data: FormData.fromMap({
          'receipt': MultipartFile.fromBytes(
            file.bytes,
            filename: file.name,
            contentType: DioMediaType.parse(file.mimeType),
          ),
        }),
      );
      final json = _object(response);
      return ReceiptUpload(
        filePath: _requiredText(json, 'filePath'),
        originalName: _requiredText(json, 'originalName'),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<ExpenseClaim> createClaim(CreateClaimCommand command) async {
    final context = _requireContext();
    if (command.amount <= 0) {
      throw const ApiException('Nominal klaim harus lebih dari nol.');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/travel-expenses/claims',
        data: {
          if (command.tripId != null) 'tripId': command.tripId,
          'category': command.category,
          'amount': command.amount,
          'expenseDate': _date(command.expenseDate),
          if (command.description?.trim().isNotEmpty == true)
            'description': command.description!.trim(),
          if (command.notes?.trim().isNotEmpty == true)
            'notes': command.notes!.trim(),
          if (command.receiptFilePath != null)
            'receiptFilePath': command.receiptFilePath,
        },
      );
      return _claim(_object(response), context);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  RequestContext _requireContext() {
    final value = _context();
    if (value?.employeeId == null || value?.activeCompanyId == null) {
      throw const ApiException('Sesi employee/company belum tersedia.');
    }
    return value!;
  }

  Future<EmployeeBranch?> _employeeBranch(RequestContext context) async {
    final employeeId = context.employeeId!;
    _safeId(employeeId);
    final response = await _dio.get<Map<String, dynamic>>(
      '/employees/$employeeId',
    );
    final employee = _object(response);
    _identity(employee, context);
    final branch = employee['branch'];
    if (branch is! Map) return null;
    final json = Map<String, dynamic>.from(branch);
    final id = _text(json, 'id');
    final name = _text(json, 'name');
    return id == null || name == null
        ? null
        : EmployeeBranch(id: id, name: name);
  }

  List<Map<String, dynamic>> _list(Response<Map<String, dynamic>> response) {
    final values = ApiEnvelope.fromJson(
      response.data ?? const {},
    ).requireListData();
    if (values.any((item) => item is! Map)) {
      throw const FormatException('Daftar ESS dari server tidak valid.');
    }
    return values
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Map<String, dynamic> _object(Response<Map<String, dynamic>> response) {
    final data = ApiEnvelope.fromJson(
      response.data ?? const {},
    ).requireObjectData();
    for (final key in const [
      'loan',
      'request',
      'activity',
      'trip',
      'claim',
      'employee',
    ]) {
      if (data[key] is Map) return Map<String, dynamic>.from(data[key] as Map);
    }
    return data;
  }

  LoanTypeOption _loanType(Map<String, dynamic> json) => LoanTypeOption(
    id: _requiredText(json, 'id'),
    name: _requiredText(json, 'name'),
    maxAmount: _optionalMoney(json['maxAmount']),
    maxInstallments: _optionalInteger(json['maxInstallments']),
    interestRate: _optionalMoney(json['interestRate']),
  );

  EmployeeLoan _loan(Map<String, dynamic> json, RequestContext context) {
    _identity(json, context);
    final type = json['loanType'];
    return EmployeeLoan(
      id: _requiredText(json, 'id'),
      loanTypeName: type is Map
          ? _requiredText(Map<String, dynamic>.from(type), 'name')
          : _requiredText(json, 'loanTypeId'),
      amount: _money(json, 'amount'),
      status: _requiredText(json, 'status'),
      totalInstallments: _integer(json, 'totalInstallments'),
      installmentAmount: _optionalMoney(json['installmentAmount']),
      remainingBalance: _optionalMoney(json['remainingBalance']),
      createdAt: _optionalDate(json['createdAt']),
    );
  }

  LoanInstallment _installment(Map<String, dynamic> json) => LoanInstallment(
    id: _requiredText(json, 'id'),
    amount: _money(json, 'amount'),
    status: _requiredText(json, 'status'),
    dueDate: _optionalDate(json['dueDate']),
    paidDate: _optionalDate(json['paidDate']),
  );

  EwaRequest _ewa(Map<String, dynamic> json, RequestContext context) {
    _identity(json, context);
    return EwaRequest(
      id: _requiredText(json, 'id'),
      amount: _money(json, 'amountRequested'),
      status: _requiredText(json, 'status'),
      requestCode: _text(json, 'requestCode'),
      reason: _text(json, 'reason'),
      createdAt: _optionalDate(json['createdAt']),
    );
  }

  DailyActivity _activity(Map<String, dynamic> json, RequestContext context) {
    _identity(json, context);
    final branch = json['branch'];
    final branchName = branch is Map
        ? _text(Map<String, dynamic>.from(branch), 'name')
        : null;
    return DailyActivity(
      id: _requiredText(json, 'id'),
      title: _requiredText(json, 'title'),
      type: _requiredText(json, 'activityType'),
      activityDate: _requiredDate(json, 'activityDate'),
      startTime: _requiredDate(json, 'startTime'),
      endTime: _requiredDate(json, 'endTime'),
      branchName: branchName ?? 'Lokasi kerja',
      description: _text(json, 'description'),
      notes: _text(json, 'notes'),
    );
  }

  ExpenseCategory _category(Map<String, dynamic> json) => ExpenseCategory(
    value: _requiredText(json, 'value'),
    label: _requiredText(json, 'label'),
  );

  BusinessTrip _trip(Map<String, dynamic> json, RequestContext context) {
    _identity(json, context);
    return BusinessTrip(
      id: _requiredText(json, 'id'),
      destination: _requiredText(json, 'destination'),
      purpose: _requiredText(json, 'purpose'),
      startDate: _requiredDate(json, 'startDate'),
      endDate: _requiredDate(json, 'endDate'),
      estimatedCost: _money(json, 'estimatedCost'),
      status: _requiredText(json, 'status'),
    );
  }

  ExpenseClaim _claim(Map<String, dynamic> json, RequestContext context) {
    _identity(json, context);
    return ExpenseClaim(
      id: _requiredText(json, 'id'),
      category: _requiredText(json, 'category'),
      amount: _money(json, 'amount'),
      expenseDate: _requiredDate(json, 'expenseDate'),
      status: _requiredText(json, 'status'),
      description: _text(json, 'description'),
    );
  }

  void _identity(Map<String, dynamic> json, RequestContext context) {
    final employee = _text(json, 'employeeId');
    final company = _text(json, 'companyId');
    if ((employee != null && employee != context.employeeId) ||
        (company != null && company != context.activeCompanyId)) {
      throw const FormatException(
        'Data ESS tidak sesuai sesi employee/perusahaan aktif.',
      );
    }
  }
}

void _validateActivity(String title, DateTime start, DateTime end) {
  if (title.trim().length < 3) {
    throw const ApiException('Judul aktivitas minimal 3 karakter.');
  }
  if (!end.isAfter(start)) {
    throw const ApiException('Waktu selesai harus setelah waktu mulai.');
  }
}

String? _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = _text(json, key);
  if (value == null) throw FormatException('Field $key tidak tersedia.');
  return value;
}

double _money(Map<String, dynamic> json, String key) {
  final value = _optionalMoney(json[key]);
  if (value == null || !value.isFinite || value < 0) {
    throw FormatException('Field nominal $key tidak valid.');
  }
  return value;
}

double? _optionalMoney(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text),
  _ => null,
};

int _integer(Map<String, dynamic> json, String key) {
  final value = _optionalInteger(json[key]);
  if (value == null || value < 0) {
    throw FormatException('Field angka $key tidak valid.');
  }
  return value;
}

int? _optionalInteger(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text),
  _ => null,
};

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _optionalDate(json[key]);
  if (value == null) throw FormatException('Field tanggal $key tidak valid.');
  return value;
}

DateTime? _optionalDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

double _roundMoney(double value) => (value * 100).round() / 100;

void _safeId(String id) {
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
    throw const FormatException('ID ESS tidak valid.');
  }
}
