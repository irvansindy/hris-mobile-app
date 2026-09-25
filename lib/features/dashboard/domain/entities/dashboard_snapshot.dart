class DashboardSnapshot {
  const DashboardSnapshot({
    required this.employee,
    required this.leaveBalances,
    required this.announcements,
    this.attendance = const DashboardAttendance(),
    this.monthlySummary = const MonthlySummary(),
    this.attendanceAvailable = false,
    this.leaveBalancesAvailable = false,
    this.monthlySummaryAvailable = false,
    this.announcementsAvailable = false,
    this.leaveBalancesError,
    this.announcementsError,
    this.unreadNotifications = 0,
  });

  final DashboardEmployee employee;
  final List<LeaveBalance> leaveBalances;
  final List<Announcement> announcements;
  final DashboardAttendance attendance;
  final MonthlySummary monthlySummary;
  final bool attendanceAvailable;
  final bool leaveBalancesAvailable;
  final bool monthlySummaryAvailable;
  final bool announcementsAvailable;
  final String? leaveBalancesError;
  final String? announcementsError;
  final int unreadNotifications;
}

class DashboardAttendance {
  const DashboardAttendance({
    this.isClockedIn = false,
    this.clockInTime,
    this.workingMinutes = 0,
  });

  final bool isClockedIn;
  final DateTime? clockInTime;
  final int workingMinutes;
}

class MonthlySummary {
  const MonthlySummary({
    this.attendancePercentage = 0,
    this.lateCount = 0,
    this.overtimeHours = 0,
    this.remainingLeave = 0,
  });

  final int attendancePercentage;
  final int lateCount;
  final num overtimeHours;
  final int remainingLeave;
}

class DashboardEmployee {
  const DashboardEmployee({
    required this.name,
    required this.initials,
    required this.avatarColorIndex,
    this.role,
  });

  final String name;
  final String initials;
  final int avatarColorIndex;
  final String? role;
}

class LeaveBalance {
  const LeaveBalance({
    required this.type,
    required this.total,
    required this.used,
    required this.colorIndex,
    this.shortLabel,
    this.note,
  });

  final String type;
  final int total;
  final int used;
  final int colorIndex;
  final String? shortLabel;
  final String? note;
}

class Announcement {
  const Announcement({
    required this.title,
    required this.body,
    required this.time,
    required this.category,
  });

  final String title;
  final String body;
  final String time;
  final String category;
}
