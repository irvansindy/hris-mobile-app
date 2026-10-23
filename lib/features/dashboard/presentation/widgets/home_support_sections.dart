import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';

class HomeSupportSections extends StatelessWidget {
  const HomeSupportSections({
    super.key,
    required this.team,
    required this.shift,
    required this.attendancePattern,
  });

  final DashboardTeamSummary team;
  final DashboardShiftSummary shift;
  final DashboardAttendancePattern attendancePattern;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _TeamSection(key: const ValueKey('home-team-section'), data: team),
      const SizedBox(height: 12),
      _ShiftSection(key: const ValueKey('home-shift-section'), data: shift),
      const SizedBox(height: 12),
      _AttendancePatternSection(
        key: const ValueKey('home-attendance-pattern-section'),
        data: attendancePattern,
      ),
    ],
  );
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({super.key, required this.data});

  final DashboardTeamSummary data;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: !data.available
        ? const _SectionMessage(
            icon: Icons.groups_outlined,
            title: 'Tim hari ini belum tersedia',
            message: 'Endpoint kehadiran tim belum terintegrasi.',
          )
        : data.members.isEmpty
        ? const _SectionMessage(
            icon: Icons.groups_outlined,
            title: 'Belum ada status tim hari ini',
            message: 'Status kehadiran anggota tim belum tersedia.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TeamSectionHeader(onShowAll: () => _showTeamDetails(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _AvatarStack(members: data.members),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.presentCount} hadir · ${data.leaveCount} cuti',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (data.division case final division?)
                        Text(
                          division,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final member in data.members.take(2))
                    _TeamTag('${member.label} · ${member.detail}'),
                ],
              ),
            ],
          ),
  );

  void _showTeamDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            Text(
              data.division == null
                  ? 'Tim Hari Ini'
                  : 'Tim Hari Ini · ${data.division}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final member in data.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(member.initials)),
                title: Text(member.label),
                subtitle: Text(member.detail),
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamSectionHeader extends StatelessWidget {
  const _TeamSectionHeader({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Tim Hari Ini',
      style: Theme.of(context).textTheme.titleMedium,
    );
    final action = TextButton(
      onPressed: onShowAll,
      child: const Text('Lihat semua'),
    );
    if (MediaQuery.textScalerOf(context).scale(1) > 1.45) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, action],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        action,
      ],
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.members});

  final List<DashboardTeamMember> members;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(4).toList(growable: false);
    return SizedBox(
      width: 32 + (visible.length - 1) * 24,
      height: 32,
      child: Stack(
        children: [
          for (final entry in visible.indexed)
            Positioned(
              left: entry.$1 * 24,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _avatarColor(context, entry.$1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Text(
                  entry.$2.initials,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: entry.$1 == 3
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _avatarColor(BuildContext context, int index) => switch (index) {
    0 => AppColors.primary,
    1 => AppColors.chartSecondary,
    2 => AppColors.chartTertiary,
    _ => Theme.of(context).colorScheme.surfaceContainer,
  };
}

class _TeamTag extends StatelessWidget {
  const _TeamTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 44),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _ShiftSection extends StatelessWidget {
  const _ShiftSection({super.key, required this.data});

  final DashboardShiftSummary data;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: !data.available
        ? const _SectionMessage(
            icon: Icons.schedule_outlined,
            title: 'Shift berikutnya belum tersedia',
            message: 'Jadwal shift belum dikembalikan oleh server.',
          )
        : data.dayLabel == null ||
              data.timeRange == null ||
              data.location == null
        ? const _SectionMessage(
            icon: Icons.schedule_outlined,
            title: 'Detail shift belum tersedia',
            message: 'Jadwal berikutnya belum memiliki detail lengkap.',
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final stack = MediaQuery.textScalerOf(context).scale(1) > 1.45;
              final detail = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIconTile(icon: Icons.schedule_outlined, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift berikutnya · ${data.dayLabel}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${data.timeRange} · ${data.location}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    detail,
                    if (data.typeLabel case final label?) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppStatusChip(
                          label: label,
                          tone: AppStatusTone.neutral,
                        ),
                      ),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: detail),
                  if (data.typeLabel case final label?) ...[
                    const SizedBox(width: 8),
                    AppStatusChip(label: label, tone: AppStatusTone.neutral),
                  ],
                ],
              );
            },
          ),
  );
}

class _AttendancePatternSection extends StatelessWidget {
  const _AttendancePatternSection({super.key, required this.data});

  final DashboardAttendancePattern data;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: !data.available
        ? const _SectionMessage(
            icon: Icons.calendar_view_week_outlined,
            title: 'Kehadiran belum tersedia',
            message: 'Ringkasan kehadiran 90 hari belum terintegrasi.',
          )
        : data.rows.isEmpty
        ? const _SectionMessage(
            icon: Icons.calendar_view_week_outlined,
            title: 'Riwayat kehadiran belum tersedia',
            message: 'Belum ada pola kehadiran untuk periode ini.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kehadiran',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${data.periodDays} hari',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Semantics(
                label: 'Pola kehadiran ${data.periodDays} hari',
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      for (final row in data.rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text(
                                  row.label,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                              for (final level in row.levels)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 5),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _levelColor(context, level),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PatternLegend(
                    label: 'Kantor',
                    value: data.onsitePercent,
                    color: AppColors.primary,
                  ),
                  _PatternLegend(
                    label: 'Remote',
                    value: data.remotePercent,
                    color: AppColors.chartSecondary,
                  ),
                  _PatternLegend(
                    label: 'Cuti',
                    value: data.leavePercent,
                    color: AppColors.chartQuaternary,
                  ),
                ],
              ),
            ],
          ),
  );

  Color _levelColor(BuildContext context, int level) => switch (level) {
    3 => AppColors.primary,
    2 => AppColors.chartSecondary,
    1 => AppColors.chartQuaternary,
    _ => Theme.of(context).colorScheme.surfaceContainer,
  };
}

class _PatternLegend extends StatelessWidget {
  const _PatternLegend({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 82,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 2, color: color),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text('$value%', style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppIconTile(icon: icon),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 3),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}
