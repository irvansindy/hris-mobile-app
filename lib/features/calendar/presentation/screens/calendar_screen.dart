import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/services/clock.dart';
import 'package:hrm_app/features/calendar/calendar_dependencies.dart';
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
  bool _swapBusy = false;

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
    final nextShift = ref.watch(calendarNextShiftProvider);
    final holidays = ref.watch(calendarHolidaysProvider(_displayed.year));
    final shiftSwaps = ref.watch(calendarShiftSwapOverviewProvider);
    final data = month.asData?.value;
    final eventsByDay = _eventsWithHolidays(
      data?.eventsByDay ?? const {},
      holidays.valueOrNull ?? const [],
      _displayed,
    );
    final selectedEvents = eventsByDay[_selectedDay] ?? const [];
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final horizontal = narrow ? 6.0 : AppSpacing.screenHorizontal;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(calendarMonthProvider(period).future),
              ref.refresh(calendarNextShiftProvider.future),
              ref.refresh(calendarHolidaysProvider(_displayed.year).future),
              ref.refresh(calendarShiftSwapOverviewProvider.future),
            ]);
          },
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
                KeyedSubtree(
                  key: const ValueKey('calendar-header'),
                  child: AppPageHeader(
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
                ),
                const SizedBox(height: 18),
                AppSurfaceCard(
                  key: const ValueKey('calendar-month-grid'),
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
                        events: eventsByDay,
                        today: ref.read(clockProvider)(),
                        onSelected: (day) => setState(() => _selectedDay = day),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  key: const ValueKey('calendar-today-action'),
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
                if (data != null &&
                    (data.available || eventsByDay.isNotEmpty)) ...[
                  KeyedSubtree(
                    key: const ValueKey('calendar-legend'),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        for (final tone
                            in eventsByDay.values
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
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  key: const ValueKey('calendar-agenda-header'),
                  'Agenda $_selectedDay ${_monthName(_displayed.month)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                KeyedSubtree(
                  key: const ValueKey('calendar-agenda-content'),
                  child: month.isLoading
                      ? const AppStateView.loading(
                          title: 'Memuat kalender',
                          message: 'Mengambil jadwal kerja Anda dari server.',
                        )
                      : month.hasError
                      ? AppStateView(
                          kind:
                              month.error is ApiException &&
                                  (month.error as ApiException).statusCode ==
                                      403
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
                      : selectedEvents.isEmpty
                      ? const AppStateView(
                          kind: AppViewStateKind.empty,
                          title: 'Agenda belum tersedia',
                          message:
                              'Belum ada jadwal dari server untuk tanggal ini.',
                        )
                      : AppSurfaceCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              for (final event in selectedEvents)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          color: _toneColor(
                                            context,
                                            event.tone,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
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
                ),
                if (holidays.hasError) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppStateView(
                    kind: AppViewStateKind.error,
                    title: 'Hari libur gagal dimuat',
                    message: _message(holidays.error!),
                    actionLabel: 'Coba lagi',
                    onAction: () => ref.invalidate(
                      calendarHolidaysProvider(_displayed.year),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _NextShiftSection(
                  state: nextShift,
                  onRetry: () => ref.invalidate(calendarNextShiftProvider),
                ),
                const SizedBox(height: AppSpacing.lg),
                _ShiftSwapSection(
                  state: shiftSwaps,
                  busy: _swapBusy,
                  onCreate: _openShiftSwapComposer,
                  onCancel: _cancelShiftSwap,
                  onRetry: () =>
                      ref.invalidate(calendarShiftSwapOverviewProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openShiftSwapComposer() async {
    if (_swapBusy) return;
    final shiftDate = DateTime(_displayed.year, _displayed.month, _selectedDay);
    setState(() => _swapBusy = true);
    try {
      final candidates = await ref.read(
        calendarShiftSwapCandidatesProvider(shiftDate).future,
      );
      if (!mounted) return;
      if (candidates.isEmpty) {
        _notice('Tidak ada kandidat tukar shift untuk tanggal ini.');
        return;
      }
      final command = await showModalBottomSheet<CreateShiftSwapCommand>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        sheetAnimationStyle: AppMotion.sheetStyleOf(context),
        builder: (_) =>
            _ShiftSwapForm(shiftDate: shiftDate, candidates: candidates),
      );
      if (command == null || !mounted) return;
      await ref.read(calendarRepositoryProvider).createShiftSwap(command);
      ref.invalidate(calendarShiftSwapOverviewProvider);
      if (mounted) _notice('Tukar shift berhasil diajukan.');
    } catch (error) {
      if (mounted) _notice(_message(error));
    } finally {
      if (mounted) setState(() => _swapBusy = false);
    }
  }

  Future<void> _cancelShiftSwap(String requestId) async {
    if (_swapBusy) return;
    setState(() => _swapBusy = true);
    try {
      await ref.read(calendarRepositoryProvider).cancelShiftSwap(requestId);
      ref.invalidate(calendarShiftSwapOverviewProvider);
      if (mounted) _notice('Pengajuan tukar shift dibatalkan.');
    } catch (error) {
      if (mounted) _notice(_message(error));
    } finally {
      if (mounted) setState(() => _swapBusy = false);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _NextShiftSection extends StatelessWidget {
  const _NextShiftSection({required this.state, required this.onRetry});

  final AsyncValue<NextShiftResult> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Shift berikutnya', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      state.when(
        loading: () => const AppStateView.loading(
          title: 'Memuat shift berikutnya',
          message: 'Mencari jadwal kerja berikutnya dari server.',
        ),
        error: (error, _) => AppStateView(
          kind: AppViewStateKind.error,
          title: 'Shift berikutnya gagal dimuat',
          message: _message(error),
          actionLabel: 'Coba lagi',
          onAction: onRetry,
        ),
        data: (result) {
          final shift = result.shift;
          if (shift == null) {
            return const AppStateView(
              kind: AppViewStateKind.empty,
              title: 'Shift berikutnya belum tersedia',
              message: 'Server belum menemukan jadwal kerja berikutnya.',
            );
          }
          return AppSurfaceCard(
            child: Row(
              children: [
                const AppIconTile(icon: Icons.schedule_rounded),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${_dateLabel(shift.date)} · ${_shiftTime(shift)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class _ShiftSwapSection extends StatelessWidget {
  const _ShiftSwapSection({
    required this.state,
    required this.busy,
    required this.onCreate,
    required this.onCancel,
    required this.onRetry,
  });

  final AsyncValue<ShiftSwapOverview> state;
  final bool busy;
  final VoidCallback onCreate;
  final ValueChanged<String> onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Tukar shift',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            key: const ValueKey('calendar-create-shift-swap'),
            onPressed: busy ? null : onCreate,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Ajukan'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      state.when(
        loading: () => const AppStateView.loading(
          title: 'Memuat tukar shift',
          message: 'Mengambil pengajuan dari server.',
        ),
        error: (error, _) => AppStateView(
          kind: error is ApiException && error.code == 'NETWORK_ERROR'
              ? AppViewStateKind.offline
              : AppViewStateKind.error,
          title: 'Tukar shift gagal dimuat',
          message: _message(error),
          actionLabel: 'Coba lagi',
          onAction: onRetry,
        ),
        data: (overview) {
          if (overview.requests.isEmpty && overview.approvals.isEmpty) {
            return const AppStateView(
              kind: AppViewStateKind.empty,
              title: 'Belum ada pengajuan tukar shift',
              message: 'Pengajuan dari server akan tampil di sini.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final request in overview.requests) ...[
                _ShiftSwapCard(
                  request: request,
                  canCancel: request.status == ShiftSwapStatus.pending,
                  busy: busy,
                  onCancel: onCancel,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              for (final request in overview.approvals) ...[
                _ShiftSwapCard(
                  request: request,
                  canCancel: false,
                  busy: busy,
                  onCancel: onCancel,
                  approval: true,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class _ShiftSwapCard extends StatelessWidget {
  const _ShiftSwapCard({
    required this.request,
    required this.canCancel,
    required this.busy,
    required this.onCancel,
    this.approval = false,
  });

  final ShiftSwapRequest request;
  final bool canCancel;
  final bool busy;
  final ValueChanged<String> onCancel;
  final bool approval;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          approval ? 'Menunggu persetujuan Anda' : request.counterpartName,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_dateLabel(request.shiftDate)} · ${request.reason}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            AppStatusChip(
              label: _shiftSwapStatusLabel(request.status),
              tone: request.status == ShiftSwapStatus.pending
                  ? AppStatusTone.warning
                  : request.status == ShiftSwapStatus.approved
                  ? AppStatusTone.success
                  : AppStatusTone.neutral,
            ),
            const Spacer(),
            if (canCancel)
              TextButton(
                key: ValueKey('cancel-shift-swap-${request.id}'),
                onPressed: busy ? null : () => onCancel(request.id),
                child: const Text('Batalkan'),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ShiftSwapForm extends StatefulWidget {
  const _ShiftSwapForm({required this.shiftDate, required this.candidates});

  final DateTime shiftDate;
  final List<ShiftSwapCandidate> candidates;

  @override
  State<_ShiftSwapForm> createState() => _ShiftSwapFormState();
}

class _ShiftSwapFormState extends State<_ShiftSwapForm> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late String _candidateId = widget.candidates.first.employeeId;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.xs,
      AppSpacing.screenHorizontal,
      AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ajukan tukar shift',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tanggal ${_dateLabel(widget.shiftDate)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            initialValue: _candidateId,
            decoration: const InputDecoration(labelText: 'Rekan kerja'),
            items: [
              for (final candidate in widget.candidates)
                DropdownMenuItem(
                  value: candidate.employeeId,
                  child: Text(
                    '${candidate.fullName} · ${candidate.employeeNumber}',
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) _candidateId = value;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey('shift-swap-reason'),
            controller: _reason,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Alasan'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Alasan wajib diisi.'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('shift-swap-submit'),
            onPressed: _submit,
            child: const Text('Kirim pengajuan'),
          ),
        ],
      ),
    ),
  );

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      CreateShiftSwapCommand(
        targetEmployeeId: _candidateId,
        shiftDate: widget.shiftDate,
        reason: _reason.text.trim(),
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

Map<int, List<CalendarEvent>> _eventsWithHolidays(
  Map<int, List<CalendarEvent>> events,
  List<WorkHoliday> holidays,
  DateTime displayed,
) {
  final result = {
    for (final entry in events.entries)
      entry.key: List<CalendarEvent>.of(entry.value),
  };
  for (final holiday in holidays) {
    if (holiday.date.year != displayed.year ||
        holiday.date.month != displayed.month) {
      continue;
    }
    final day = result.putIfAbsent(holiday.date.day, () => []);
    if (day.any((event) => event.label == holiday.name)) continue;
    day.add(
      CalendarEvent(
        holiday.name,
        CalendarEventTone.danger,
        detail: holiday.type == 'JL' ? 'Libur bersama' : 'Hari libur nasional',
      ),
    );
  }
  return result;
}

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

String _dateLabel(DateTime value) =>
    '${value.day} ${_monthName(value.month)} ${value.year}';

String _shiftTime(CalendarShift shift) {
  final start = shift.workStart;
  final end = shift.workEnd;
  if (start == null || end == null) return 'Jam belum tersedia';
  return '$start - $end${shift.crossesMidnight ? ' · lintas hari' : ''}';
}

String _shiftSwapStatusLabel(ShiftSwapStatus status) => switch (status) {
  ShiftSwapStatus.pending => 'Menunggu',
  ShiftSwapStatus.approved => 'Disetujui',
  ShiftSwapStatus.rejected => 'Ditolak',
  ShiftSwapStatus.cancelled => 'Dibatalkan',
};

String _message(Object error) => error is ApiException
    ? error.message
    : 'Respons server tidak valid. Silakan coba lagi.';
