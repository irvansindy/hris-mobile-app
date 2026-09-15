import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/services/clock.dart';
import 'package:hrm_app/features/calendar/calendar_providers.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _displayed;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    _displayed = DateTime(now.year, now.month);
    _selectedDay = now.day;
  }

  int get _daysInMonth =>
      DateTime(_displayed.year, _displayed.month + 1, 0).day;
  int get _leadingCells =>
      DateTime(_displayed.year, _displayed.month, 1).weekday - 1;

  void _moveMonth(int offset) {
    final next = DateTime(_displayed.year, _displayed.month + offset);
    setState(() {
      _displayed = next;
      _selectedDay = _selectedDay.clamp(
        1,
        DateTime(next.year, next.month + 1, 0).day,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final period = (year: _displayed.year, month: _displayed.month);
    final month = ref.watch(calendarMonthProvider(period));
    final data = month.asData?.value;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final horizontal = narrow ? 6.0 : AppSpacing.screenHorizontal;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(calendarMonthProvider(period).future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontal,
              16,
              horizontal,
              AppSpacing.scrollBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: 'Kalender',
                  subtitle:
                      '${_monthName(_displayed.month)} ${_displayed.year}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MonthButton(
                        tooltip: 'Bulan sebelumnya',
                        icon: Icons.chevron_left_rounded,
                        onPressed: () => _moveMonth(-1),
                      ),
                      const SizedBox(width: 8),
                      _MonthButton(
                        tooltip: 'Bulan berikutnya',
                        icon: Icons.chevron_right_rounded,
                        onPressed: () => _moveMonth(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppSurfaceCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 0 : 14,
                    vertical: 18,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children:
                            const [
                                  'Sen',
                                  'Sel',
                                  'Rab',
                                  'Kam',
                                  'Jum',
                                  'Sab',
                                  'Min',
                                ]
                                .map(
                                  (day) => Expanded(
                                    child: Text(
                                      day,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 10.5),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                      ),
                      const SizedBox(height: 8),
                      _CalendarGrid(
                        displayed: _displayed,
                        selectedDay: _selectedDay,
                        leadingCells: _leadingCells,
                        daysInMonth: _daysInMonth,
                        events: data?.eventsByDay ?? const {},
                        today: ref.read(clockProvider)(),
                        onSelected: (day) => setState(() => _selectedDay = day),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      final today = ref.read(clockProvider)();
                      _displayed = DateTime(today.year, today.month);
                      _selectedDay = today.day;
                    }),
                    child: const Text('Hari ini (perangkat)'),
                  ),
                ),
                if (data != null && data.available) ...[
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      for (final tone
                          in data.eventsByDay.values
                              .expand((items) => items)
                              .map((e) => e.tone)
                              .toSet())
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 7,
                              color: _toneColor(context, tone),
                            ),
                            const SizedBox(width: 6),
                            Text(switch (tone) {
                              CalendarEventTone.primary => 'Jadwal kerja',
                              CalendarEventTone.purple => 'Cuti / izin',
                              CalendarEventTone.danger => 'Libur',
                              _ => 'Tidak bekerja',
                            }, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  'Agenda $_selectedDay ${_monthName(_displayed.month)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (month.isLoading)
                  const AppStateView.loading(
                    title: 'Memuat kalender',
                    message: 'Mengambil jadwal kerja Anda dari server.',
                  )
                else if (month.hasError)
                  AppStateView(
                    kind:
                        month.error is ApiException &&
                            (month.error as ApiException).statusCode == 403
                        ? AppViewStateKind.permission
                        : month.error is ApiException &&
                              (month.error as ApiException).code ==
                                  'NETWORK_ERROR'
                        ? AppViewStateKind.offline
                        : AppViewStateKind.error,
                    title: 'Kalender gagal dimuat',
                    message: month.error is ApiException
                        ? (month.error as ApiException).message
                        : 'Respons kalender tidak valid. Silakan coba lagi.',
                    actionLabel: 'Coba lagi',
                    onAction: () =>
                        ref.invalidate(calendarMonthProvider(period)),
                  )
                else if (data?.available != true ||
                    (data?.eventsByDay[_selectedDay]?.isEmpty ?? true))
                  const AppStateView(
                    kind: AppViewStateKind.empty,
                    title: 'Agenda belum tersedia',
                    message: 'Belum ada jadwal dari server untuk tanggal ini.',
                  )
                else
                  AppSurfaceCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final event in data!.eventsByDay[_selectedDay]!)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 76,
                                  child: Text(
                                    event.time ?? 'Waktu belum tersedia',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 3,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: _toneColor(context, event.tone),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.label,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      if (event.detail != null)
                                        Text(
                                          event.detail!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 1,
    borderRadius: BorderRadius.circular(13),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
    ),
  );
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.displayed,
    required this.selectedDay,
    required this.leadingCells,
    required this.daysInMonth,
    required this.onSelected,
    required this.events,
    required this.today,
  });
  final DateTime displayed;
  final int selectedDay;
  final int leadingCells;
  final int daysInMonth;
  final ValueChanged<int> onSelected;
  final Map<int, List<CalendarEvent>> events;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final total = leadingCells + daysInMonth;
    final cellCount = ((total + 6) ~/ 7) * 7;
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cellCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: constraints.maxWidth < 320 ? 0 : 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          final day = index - leadingCells + 1;
          if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
          final selected = day == selectedDay;
          final isToday =
              day == today.day &&
              displayed.month == today.month &&
              displayed.year == today.year;
          return Semantics(
            button: true,
            selected: selected,
            label: '$day ${_monthName(displayed.month)} ${displayed.year}',
            child: Material(
              color: selected
                  ? AppColors.primary
                  : isToday
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                key: ValueKey('calendar-day-$day'),
                onTap: () => onSelected(day),
                borderRadius: BorderRadius.circular(13),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$day',
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: selected || isToday
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      if (events[day]?.isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final tone
                                in events[day]!
                                    .map((e) => e.tone)
                                    .toSet()
                                    .take(3))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: Icon(
                                  Icons.circle,
                                  size: 4,
                                  color: selected
                                      ? Colors.white
                                      : _toneColor(context, tone),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Color _toneColor(BuildContext context, CalendarEventTone tone) =>
    switch (tone) {
      CalendarEventTone.danger => Theme.of(context).colorScheme.error,
      CalendarEventTone.purple =>
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.primaryLight
            : AppColors.info,
      _ => Theme.of(context).colorScheme.primary,
    };

String _monthName(int month) => const [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
][month - 1];
