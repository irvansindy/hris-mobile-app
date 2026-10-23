class Employee {
  const Employee({
    required this.id,
    this.employeeNumber,
    required this.name,
    required this.role,
    required this.department,
    required this.email,
    required this.phone,
    required this.location,
    required this.joinDate,
    required this.salary,
    required this.initials,
    required this.avatarColorIndex,
  });

  final String id;
  final String? employeeNumber;
  final String name;
  final String role;
  final String department;
  final String email;
  final String phone;
  final String location;
  final String joinDate;
  final int salary;
  final String initials;
  final int avatarColorIndex;
}
