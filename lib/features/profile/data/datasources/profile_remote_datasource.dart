import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/profile/domain/entities/employee.dart';

abstract interface class ProfileRemoteDataSource {
  Future<Employee> fetch(RequestContext context, Employee fallback);
}

class DioProfileRemoteDataSource implements ProfileRemoteDataSource {
  const DioProfileRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<Employee> fetch(RequestContext context, Employee fallback) async {
    final employeeId = context.employeeId;
    if (employeeId == null) return fallback;
    if (!context.permissions.contains('employee:read')) {
      throw const ApiException(
        'Akun ini tidak memiliki akses detail kepegawaian. Identitas sesi tetap tersedia.',
        statusCode: 403,
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(employeeId)) {
      throw const FormatException('ID employee tidak valid.');
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/employees/$employeeId',
      );
      final data = ApiEnvelope.fromJson(
        response.data ?? const {},
      ).requireObjectData();
      final json = data['employee'] is Map<String, dynamic>
          ? data['employee'] as Map<String, dynamic>
          : data;
      if (json['id'] != employeeId ||
          (json['companyId'] != null &&
              json['companyId'] != context.activeCompanyId)) {
        throw const FormatException(
          'Profil tidak sesuai employee/perusahaan aktif.',
        );
      }
      return _mapEmployee(json, context, fallback);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Employee _mapEmployee(
    Map<String, dynamic> json,
    RequestContext context,
    Employee fallback,
  ) {
    final firstName = _text(json, const ['firstName', 'first_name']);
    final lastName = _text(json, const ['lastName', 'last_name']);
    final fullName =
        _text(json, const ['name', 'fullName']) ??
        [firstName, lastName].whereType<String>().join(' ').trim();
    final name = fullName.isEmpty
        ? context.displayName ?? fallback.name
        : fullName;
    final role =
        _nestedText(
          json,
          const ['position', 'jobPosition'],
          const ['name', 'title'],
        ) ??
        _text(json, const ['positionName', 'jobTitle', 'role']) ??
        fallback.role;
    final department =
        _nestedText(json, const ['department'], const ['name']) ??
        _text(json, const ['departmentName']) ??
        fallback.department;
    final location =
        _nestedText(
          json,
          const ['branch', 'location'],
          const ['name', 'address', 'city'],
        ) ??
        _text(json, const ['workLocation', 'locationName']) ??
        fallback.location;
    return Employee(
      id:
          _text(json, const ['employeeNumber', 'employee_number', 'id']) ??
          fallback.id,
      name: name,
      role: role,
      department: department,
      email:
          _text(json, const ['email', 'workEmail']) ??
          context.email ??
          fallback.email,
      phone:
          _text(json, const ['phone', 'phoneNumber', 'mobilePhone']) ??
          fallback.phone,
      location: location,
      joinDate: _formatDate(
        _text(json, const ['joinDate', 'hireDate', 'joinedAt']),
        fallback.joinDate,
      ),
      salary: 0,
      initials: _initials(name),
      avatarColorIndex: name.hashCode.abs() % 4,
    );
  }
}

String? _text(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String? _nestedText(
  Map<String, dynamic> json,
  List<String> parentKeys,
  List<String> childKeys,
) {
  for (final key in parentKeys) {
    final value = json[key];
    if (value is Map) {
      final result = _text(value, childKeys);
      if (result != null) return result;
    }
  }
  return null;
}

String _formatDate(String? raw, String fallback) {
  final date = raw == null ? null : DateTime.tryParse(raw.split('T').first);
  if (date == null) return fallback;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .take(2)
    .map((word) => word[0].toUpperCase())
    .join();
