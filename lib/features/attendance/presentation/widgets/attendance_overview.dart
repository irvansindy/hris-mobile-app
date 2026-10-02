import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_history.dart';

class AttendanceOverview extends StatelessWidget {
  const AttendanceOverview({
    super.key,
    required this.contextValue,
    required this.record,
    required this.history,
  });

  final AttendanceContext contextValue;
  final AttendanceEntity record;
  final AsyncValue<AttendanceHistoryPage> history;

  @override
  Widget build(BuildContext context) {
    final page = history.valueOrNull;
    final completePage = page != null && page.totalPages <= 1;
    final items = completePage ? page.items : const <AttendanceEntity>[];
    final present = items
        .where(
          (item) =>
              item.status == AttendanceStatus.onTime ||
              item.status == AttendanceStatus.completed,
        )
        .length;
    final excused = items
        .where((item) => item.status == AttendanceStatus.excused)
        .length;
    final late = items
        .where((item) => item.status == AttendanceStatus.late)
        .length;
    final checkIns = items
        .map((item) => item.checkedInAt?.toLocal())
        .whereType<DateTime>()
        .toList(growable: false);
    final averageMinutes = checkIns.isEmpty
        ? null
        : checkIns.fold<int>(
                0,
                (total, value) => total + value.hour * 60 + value.minute,
              ) ~/
              checkIns.length;
    final counts = [present, excused, late];
    final maximum = counts.fold<int>(
      1,
      (value, item) => item > value ? item : value,
    );

    return Column(
      children: [
        AppSurfaceCard(
          key: const ValueKey('attendance-summary-section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ringkasan',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      completePage ? 'Bulan ini' : 'Menunggu data lengkap',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (!completePage)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Ringkasan bulanan belum tersedia dari server.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Semantics(
                  label:
                      '$present hadir, $excused cuti atau izin, dan $late terlambat bulan ini.',
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final entry in [
                          ('Hadir', present, AppColors.primary),
                          ('Cuti', excused, const Color(0xff8fabc8)),
                          ('Telat', late, const Color(0xffd8e2ed)),
                        ])
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 110,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: 30,
                                      height: entry.$2 == 0
                                          ? 8
                                          : 24 + 78 * entry.$2 / maximum,
                                      decoration: BoxDecoration(
                                        color: entry.$3,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(5),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${entry.$1} ${entry.$2}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LocationSection(
          key: const ValueKey('attendance-location-section'),
          value: contextValue,
          record: record,
        ),
        const SizedBox(height: 10),
        KeyedSubtree(
          key: const ValueKey('attendance-metrics-section'),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                const _AttendanceMetric(label: 'Lembur', value: '--'),
                _AttendanceMetric(
                  label: 'Rata-rata masuk',
                  value: averageMinutes == null
                      ? '--:--'
                      : '${(averageMinutes ~/ 60).toString().padLeft(2, '0')}:${(averageMinutes % 60).toString().padLeft(2, '0')}',
                ),
                _AttendanceMetric(
                  label: 'Telat',
                  value: completePage ? '$late×' : '--',
                ),
              ];
              final stacked =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.35;
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final card in cards) ...[
                      card,
                      if (card != cards.last) const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in cards.indexed)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: entry.$1 == 0 ? 0 : 10),
                        child: entry.$2,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Align(
          key: const ValueKey('attendance-state-section'),
          alignment: Alignment.centerLeft,
          child: AppStatusChip(
            label: record.isActive
                ? 'Sedang bekerja'
                : record.checkedOutAt != null
                ? 'Selesai'
                : 'Belum masuk',
            tone: record.isActive || record.checkedOutAt != null
                ? AppStatusTone.success
                : AppStatusTone.neutral,
          ),
        ),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    super.key,
    required this.value,
    required this.record,
  });

  final AttendanceContext value;
  final AttendanceEntity record;

  @override
  Widget build(BuildContext context) {
    final location = [
      value.branchName,
      value.branchCode,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' • ');
    final locationStatus = switch (record.isWithinRadius) {
      true => ('Di dalam area kantor', AppStatusTone.success),
      false => ('Di luar area kantor', AppStatusTone.danger),
      null => ('Belum diverifikasi', AppStatusTone.neutral),
    };
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final status = AppStatusChip(
                label: locationStatus.$1 == 'Di dalam area kantor'
                    ? 'Valid'
                    : locationStatus.$1,
                tone: locationStatus.$2,
              );
              final locationInfo = Row(
                children: [
                  AppIconTile(
                    icon: Icons.location_on_outlined,
                    foreground: locationStatus.$2 == AppStatusTone.danger
                        ? Theme.of(context).colorScheme.error
                        : null,
                    background: locationStatus.$2 == AppStatusTone.danger
                        ? Theme.of(context).colorScheme.errorContainer
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locationStatus.$1,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (location.isNotEmpty)
                          Text(
                            location,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.35) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [locationInfo, const SizedBox(height: 10), status],
                );
              }
              return Row(
                children: [
                  Expanded(child: locationInfo),
                  const SizedBox(width: 8),
                  status,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value.requiresSelfie
                ? 'GPS dan selfie diverifikasi server saat catat masuk.'
                : 'Lokasi GPS diverifikasi server saat transaksi dikirim.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (value.gpsRadiusMeters case final radius?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Radius kebijakan ${radius.round()} meter',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final warning in value.warnings)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                warning,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _AttendanceMetric extends StatelessWidget {
  const _AttendanceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}
