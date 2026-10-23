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
    this.teamSummary = const DashboardTeamSummary(),
    this.nextShift = const DashboardShiftSummary(),
    this.attendancePattern = const DashboardAttendancePattern(),
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
  final DashboardTeamSummary teamSummary;
  final DashboardShiftSummary nextShift;
  final DashboardAttendancePattern attendancePattern;
}

class DashboardTeamMember {
  const DashboardTeamMember({
    required this.initials,
    required this.label,
    required this.detail,
  });

  final String initials;
  final String label;
  final String detail;
}

class DashboardTeamSummary {
  const DashboardTeamSummary({
    this.available = false,
    this.presentCount = 0,
    this.leaveCount = 0,
    this.division,
    this.members = const [],
  });

  final bool available;
  final int presentCount;
  final int leaveCount;
  final String? division;
  final List<DashboardTeamMember> members;
}

class DashboardShiftSummary {
  const DashboardShiftSummary({
    this.available = false,
    this.dayLabel,
    this.timeRange,
    this.location,
    this.typeLabel,
  });

  final bool available;
  final String? dayLabel;
  final String? timeRange;
  final String? location;
  final String? typeLabel;
}

class DashboardAttendancePatternRow {
  const DashboardAttendancePatternRow({
    required this.label,
    required this.levels,
  });

  final String label;
  final List<int> levels;
}

class DashboardAttendancePattern {
  const DashboardAttendancePattern({
    this.available = false,
    this.periodDays = 90,
    this.rows = const [],
    this.onsitePercent = 0,
    this.remotePercent = 0,
    this.leavePercent = 0,
  });

  final bool available;
  final int periodDays;
  final List<DashboardAttendancePatternRow> rows;
  final int onsitePercent;
  final int remotePercent;
  final int leavePercent;
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
    this.carryOverDays = 0,
    this.carryOverExpiredAt,
  });

  final String type;
  final int total;
  final int used;
  final int colorIndex;
  final String? shortLabel;
  final String? note;
  final num carryOverDays;
  final DateTime? carryOverExpiredAt;
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
