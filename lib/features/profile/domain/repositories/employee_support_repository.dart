import 'package:hrm_app/features/profile/domain/entities/employee_support.dart';

abstract interface class EmployeeSupportRepository {
  Future<EmployeeSupportSnapshot> load();
}
