import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/models/attendance_correction_seed.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/attendance_requests/attendance_request_dependencies.dart';
import 'package:hrm_app/features/attendance_requests/attendance_request_providers.dart';
import 'package:hrm_app/features/attendance_requests/domain/entities/attendance_request.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

enum AttendanceRequestTab { correction, overtime }

class AttendanceRequestsScreen extends ConsumerStatefulWidget {
  const AttendanceRequestsScreen({
    super.key,
    this.initialTab = AttendanceRequestTab.correction,
    this.openComposer = false,
    this.initialAttendance,
  });

  final AttendanceRequestTab initialTab;
  final bool openComposer;
  final AttendanceCorrectionSeed? initialAttendance;

  @override
  ConsumerState<AttendanceRequestsScreen> createState() =>
      _AttendanceRequestsScreenState();
}

class _AttendanceRequestsScreenState
    extends ConsumerState<AttendanceRequestsScreen> {
  late AttendanceRequestTab _tab = widget.initialTab;
  bool _pendingOnly = false;
  bool _busy = false;
  bool _composerOpened = false;

  @override
  void initState() {
    super.initState();
    if (widget.openComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openComposer());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(featureSessionProvider);
    final permissions =
        ref.watch(requestContextProvider)?.permissions ?? const [];
    final query = AttendanceRequestQuery(
      session: session,
      status: _pendingOnly ? 'PENDING' : null,
    );
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(query),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
            ),
            children: [
              const AppDetailHeader(
                title: 'Koreksi & lembur',
                subtitle: 'Status pengajuan dari server',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSegmentedControl<AttendanceRequestTab>(
                values: const [
                  AttendanceRequestTab.correction,
                  AttendanceRequestTab.overtime,
                ],
                selected: _tab,
                labelBuilder: (value) =>
                    value == AttendanceRequestTab.correction
                    ? 'Koreksi'
                    : 'Lembur',
                onSelected: _busy
                    ? (_) {}
                    : (value) => setState(() => _tab = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSegmentedControl<bool>(
                values: const [false, true],
                selected: _pendingOnly,
                labelBuilder: (value) => value ? 'Menunggu' : 'Semua',
                onSelected: _busy
                    ? (_) {}
                    : (value) => setState(() => _pendingOnly = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: _createButton(permissions),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_tab == AttendanceRequestTab.correction)
                _CorrectionContent(
                  state: ref.watch(attendanceCorrectionsProvider(query)),
                  onRetry: () =>
                      ref.invalidate(attendanceCorrectionsProvider(query)),
                  onOpen: _showCorrectionDetail,
                )
              else
                _OvertimeContent(
                  state: ref.watch(overtimeRequestsProvider(query)),
                  onRetry: () =>
                      ref.invalidate(overtimeRequestsProvider(query)),
                  onOpen: (item) => _showOvertimeDetail(item, permissions),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createButton(List<String> permissions) {
    if (_tab == AttendanceRequestTab.overtime &&
        !permissions.contains('attendance:create')) {
      return const SizedBox.shrink();
    }
    return FilledButton.icon(
      key: ValueKey(
        _tab == AttendanceRequestTab.correction
            ? 'create-correction'
            : 'create-overtime',
      ),
      onPressed: _busy ? null : _openComposer,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        _tab == AttendanceRequestTab.correction
            ? 'Ajukan koreksi'
            : 'Ajukan lembur',
      ),
    );
  }

  Future<void> _refresh(AttendanceRequestQuery query) async {
    if (_tab == AttendanceRequestTab.correction) {
      final _ = await ref.refresh(attendanceCorrectionsProvider(query).future);
    } else {
      final _ = await ref.refresh(overtimeRequestsProvider(query).future);
    }
  }

  Future<void> _openComposer() async {
    if (_busy || !mounted || (_composerOpened && widget.openComposer)) return;
    _composerOpened = true;
    if (_tab == AttendanceRequestTab.correction) {
      final command = await showModalBottomSheet<CreateAttendanceCorrection>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        sheetAnimationStyle: AppMotion.sheetStyleOf(context),
        builder: (_) =>
            _CorrectionForm(initialAttendance: widget.initialAttendance),
      );
      if (command != null) await _submitCorrection(command);
    } else {
      final command = await showModalBottomSheet<CreateOvertimeRequest>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        sheetAnimationStyle: AppMotion.sheetStyleOf(context),
        builder: (_) => const _OvertimeForm(),
      );
      if (command != null) await _submitOvertime(command);
    }
  }

  Future<void> _submitCorrection(CreateAttendanceCorrection command) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(attendanceRequestRepositoryProvider)
          .createCorrection(command);
      ref.invalidate(attendanceCorrectionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koreksi berhasil dikirim dan menunggu persetujuan.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitOvertime(CreateOvertimeRequest command) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(attendanceRequestRepositoryProvider)
          .createOvertime(command);
      ref.invalidate(overtimeRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan lembur berhasil dikirim.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCorrectionDetail(AttendanceCorrectionRequest item) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        sheetAnimationStyle: AppMotion.sheetStyleOf(context),
        builder: (_) => _CorrectionDetail(item: item),
      );

  Future<void> _showOvertimeDetail(
    OvertimeRequest item,
    List<String> permissions,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: AppMotion.sheetStyleOf(context),
    builder: (_) => _OvertimeDetail(
      item: item,
      canReadPay: permissions.contains('attendance:read'),
    ),
  );
}

class _CorrectionContent extends StatelessWidget {
  const _CorrectionContent({
    required this.state,
    required this.onRetry,
    required this.onOpen,
  });

  final AsyncValue<List<AttendanceCorrectionRequest>> state;
  final VoidCallback onRetry;
  final ValueChanged<AttendanceCorrectionRequest> onOpen;

  @override
  Widget build(BuildContext context) => state.when(
    loading: () => const AppStateView.loading(
      title: 'Memuat koreksi absensi',
      message: 'Mengambil status koreksi milik akun ini.',
    ),
    error: (error, _) => AppStateView(
      kind: error is ApiException && error.statusCode == 403
          ? AppViewStateKind.permission
          : AppViewStateKind.error,
      title: 'Koreksi absensi gagal dimuat',
      message: _errorMessage(error),
      actionLabel: 'Coba lagi',
      onAction: onRetry,
    ),
    data: (items) => items.isEmpty
        ? const AppStateView(
            key: ValueKey('correction-empty'),
            kind: AppViewStateKind.empty,
            title: 'Belum ada koreksi',
            message: 'Ajukan koreksi bila waktu absensi server tidak sesuai.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Riwayat koreksi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in items) ...[
                _RequestCard(
                  key: ValueKey('correction-${item.id}'),
                  title: 'Koreksi ${_date(item.date)}',
                  subtitle: _correctionSummary(item),
                  status: item.status,
                  onTap: () => onOpen(item),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
  );
}

class _OvertimeContent extends StatelessWidget {
  const _OvertimeContent({
    required this.state,
    required this.onRetry,
    required this.onOpen,
  });

  final AsyncValue<List<OvertimeRequest>> state;
  final VoidCallback onRetry;
  final ValueChanged<OvertimeRequest> onOpen;

  @override
  Widget build(BuildContext context) => state.when(
    loading: () => const AppStateView.loading(
      title: 'Memuat pengajuan lembur',
      message: 'Mengambil status lembur milik akun ini.',
    ),
    error: (error, _) => AppStateView(
      kind: error is ApiException && error.statusCode == 403
          ? AppViewStateKind.permission
          : AppViewStateKind.error,
      title: error is ApiException && error.statusCode == 403
          ? 'Riwayat lembur tidak tersedia'
          : 'Pengajuan lembur gagal dimuat',
      message: _errorMessage(error),
      actionLabel: 'Coba lagi',
      onAction: onRetry,
    ),
    data: (items) => items.isEmpty
        ? const AppStateView(
            key: ValueKey('overtime-empty'),
            kind: AppViewStateKind.empty,
            title: 'Belum ada pengajuan lembur',
            message: 'Pengajuan yang dikirim akan tampil di sini.',
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Riwayat lembur',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in items) ...[
                _RequestCard(
                  key: ValueKey('overtime-${item.id}'),
                  title: 'Lembur ${_date(item.date)}',
                  subtitle:
                      '${_dateTime(item.startTime)} sampai ${_dateTime(item.endTime)}',
                  status: item.status,
                  onTap: () => onOpen(item),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final AttendanceRequestStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    onTap: onTap,
    semanticLabel: '$title, ${_statusLabel(status)}',
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppIconTile(icon: Icons.schedule_outlined),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              AppStatusChip(
                label: _statusLabel(status),
                tone: _statusTone(status),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

class _CorrectionForm extends StatefulWidget {
  const _CorrectionForm({this.initialAttendance});
  final AttendanceCorrectionSeed? initialAttendance;

  @override
  State<_CorrectionForm> createState() => _CorrectionFormState();
}

class _CorrectionFormState extends State<_CorrectionForm> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late DateTime _date = DateUtils.dateOnly(
    widget.initialAttendance?.date ?? DateTime.now(),
  );
  late DateTime? _checkIn = widget.initialAttendance?.checkedInAt;
  late DateTime? _checkOut = widget.initialAttendance?.checkedOutAt;
  late bool _changeCheckIn = widget.initialAttendance?.checkedInAt != null;
  late bool _changeCheckOut = widget.initialAttendance?.checkedOutAt != null;

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
          Text('Ajukan koreksi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Record absensi baru berubah setelah server menyetujui koreksi.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          _PickerButton(
            key: const ValueKey('correction-date'),
            icon: Icons.calendar_today_outlined,
            label: 'Tanggal: ${_dateLabel(_date)}',
            onPressed: widget.initialAttendance == null ? _pickDate : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            value: _changeCheckIn,
            onChanged: (value) => setState(() {
              _changeCheckIn = value;
              if (value && _checkIn == null) {
                _checkIn = _at(_date, const TimeOfDay(hour: 8, minute: 0));
              }
            }),
            title: const Text('Koreksi waktu masuk'),
            contentPadding: EdgeInsets.zero,
          ),
          if (_changeCheckIn)
            _PickerButton(
              key: const ValueKey('correction-check-in'),
              icon: Icons.login_rounded,
              label: 'Masuk: ${_time(_checkIn)}',
              onPressed: () => _pickTime(checkIn: true),
            ),
          SwitchListTile.adaptive(
            value: _changeCheckOut,
            onChanged: (value) => setState(() {
              _changeCheckOut = value;
              if (value && _checkOut == null) {
                _checkOut = _at(_date, const TimeOfDay(hour: 17, minute: 0));
              }
            }),
            title: const Text('Koreksi waktu pulang'),
            contentPadding: EdgeInsets.zero,
          ),
          if (_changeCheckOut)
            _PickerButton(
              key: const ValueKey('correction-check-out'),
              icon: Icons.logout_rounded,
              label: 'Pulang: ${_time(_checkOut)}',
              onPressed: () => _pickTime(checkIn: false),
            ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey('correction-reason'),
            controller: _reason,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alasan koreksi',
              alignLabelWithHint: true,
            ),
            validator: (value) => value == null || value.trim().length < 3
                ? 'Alasan minimal 3 karakter.'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('correction-submit'),
            onPressed: _submit,
            child: const Text('Kirim koreksi'),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateUtils.dateOnly(DateTime.now()),
    );
    if (value == null || !mounted) return;
    setState(() {
      _date = value;
      if (_checkIn != null) {
        _checkIn = _at(value, TimeOfDay.fromDateTime(_checkIn!));
      }
      if (_checkOut != null) {
        _checkOut = _at(value, TimeOfDay.fromDateTime(_checkOut!));
      }
    });
  }

  Future<void> _pickTime({required bool checkIn}) async {
    final current = checkIn ? _checkIn : _checkOut;
    final value = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(current),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (checkIn) {
        _checkIn = _at(_date, value);
      } else {
        _checkOut = _at(_date, value);
      }
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    if (!_changeCheckIn && !_changeCheckOut) {
      _notice('Pilih minimal satu waktu yang dikoreksi.');
      return;
    }
    final checkIn = _changeCheckIn ? _checkIn : null;
    final checkOut = _changeCheckOut ? _checkOut : null;
    if (checkIn != null && checkOut != null && !checkOut.isAfter(checkIn)) {
      _notice('Waktu pulang harus setelah waktu masuk.');
      return;
    }
    Navigator.pop(
      context,
      CreateAttendanceCorrection(
        attendanceId: widget.initialAttendance?.attendanceId,
        date: _date,
        requestedCheckIn: checkIn,
        requestedCheckOut: checkOut,
        reason: _reason.text.trim(),
        idempotencyKey: const Uuid().v4(),
      ),
    );
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _OvertimeForm extends StatefulWidget {
  const _OvertimeForm();

  @override
  State<_OvertimeForm> createState() => _OvertimeFormState();
}

class _OvertimeFormState extends State<_OvertimeForm> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  DateTime? _start;
  DateTime? _end;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = _start != null && _end != null && _end!.isAfter(_start!)
        ? _end!.difference(_start!).inMinutes / 60
        : null;
    return SingleChildScrollView(
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
              'Ajukan lembur',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pilih waktu aktual. Status dan estimasi bayaran ditentukan server.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            _PickerButton(
              key: const ValueKey('overtime-start'),
              icon: Icons.play_circle_outline_rounded,
              label: _start == null
                  ? 'Pilih waktu mulai'
                  : 'Mulai: ${_dateTime(_start!)}',
              onPressed: () => _pick(start: true),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PickerButton(
              key: const ValueKey('overtime-end'),
              icon: Icons.stop_circle_outlined,
              label: _end == null
                  ? 'Pilih waktu selesai'
                  : 'Selesai: ${_dateTime(_end!)}',
              onPressed: () => _pick(start: false),
            ),
            if (duration != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Durasi dari pilihan Anda: ${duration.toStringAsFixed(2)} jam.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('overtime-reason'),
              controller: _reason,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alasan lembur',
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Alasan lembur wajib diisi.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('overtime-submit'),
              onPressed: _submit,
              child: const Text('Kirim pengajuan lembur'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final current = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? _start ?? now,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = _at(date, time);
      if (start) {
        _start = value;
        if (_end != null && !_end!.isAfter(value)) _end = null;
      } else {
        _end = value;
      }
    });
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    if (_start == null || _end == null) {
      _notice('Lengkapi waktu mulai dan selesai.');
      return;
    }
    if (!_end!.isAfter(_start!)) {
      _notice('Waktu selesai harus setelah waktu mulai.');
      return;
    }
    Navigator.pop(
      context,
      CreateOvertimeRequest(
        startTime: _start!,
        endTime: _end!,
        reason: _reason.text.trim(),
        idempotencyKey: const Uuid().v4(),
      ),
    );
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      minimumSize: const Size.fromHeight(56),
    ),
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

class _CorrectionDetail extends ConsumerWidget {
  const _CorrectionDetail({required this.item});
  final AttendanceCorrectionRequest item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = AttendanceCorrectionDetailQuery(
      session: ref.watch(featureSessionProvider),
      id: item.id,
    );
    return ref
        .watch(attendanceCorrectionDetailProvider(query))
        .when(
          loading: () => const AppStateView.loading(
            title: 'Memuat detail koreksi',
            message: 'Mengambil timeline terbaru dari server.',
          ),
          error: (error, _) => AppStateView(
            kind: AppViewStateKind.error,
            title: 'Detail koreksi gagal dimuat',
            message: _errorMessage(error),
            actionLabel: 'Coba lagi',
            onAction: () =>
                ref.invalidate(attendanceCorrectionDetailProvider(query)),
          ),
          data: (value) => _CorrectionDetailBody(item: value),
        );
  }
}

class _CorrectionDetailBody extends StatelessWidget {
  const _CorrectionDetailBody({required this.item});
  final AttendanceCorrectionRequest item;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.xs,
      AppSpacing.screenHorizontal,
      AppSpacing.lg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Detail koreksi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            AppStatusChip(
              label: _statusLabel(item.status),
              tone: _statusTone(item.status),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSurfaceCard(
          child: Column(
            children: [
              _DetailRow(label: 'Tanggal', value: _date(item.date)),
              _DetailRow(
                label: 'Waktu masuk',
                value: _time(item.requestedCheckIn),
              ),
              _DetailRow(
                label: 'Waktu pulang',
                value: _time(item.requestedCheckOut),
              ),
              _DetailRow(label: 'Alasan', value: item.reason),
              if (item.rejectionReason case final reason?)
                _DetailRow(label: 'Alasan ditolak', value: reason),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Status server', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _TimelineEvent(label: 'Dikirim', value: _dateTime(item.createdAt)),
        if (item.approvedAt case final value?)
          _TimelineEvent(label: 'Disetujui', value: _dateTime(value)),
        if (item.updatedAt.isAfter(item.createdAt) && item.approvedAt == null)
          _TimelineEvent(label: 'Diperbarui', value: _dateTime(item.updatedAt)),
      ],
    ),
  );
}

class _OvertimeDetail extends ConsumerWidget {
  const _OvertimeDetail({required this.item, required this.canReadPay});
  final OvertimeRequest item;
  final bool canReadPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenHorizontal,
      AppSpacing.xs,
      AppSpacing.screenHorizontal,
      AppSpacing.lg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Detail lembur',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            AppStatusChip(
              label: _statusLabel(item.status),
              tone: _statusTone(item.status),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSurfaceCard(
          child: Column(
            children: [
              _DetailRow(label: 'Tanggal', value: _date(item.date)),
              _DetailRow(label: 'Mulai', value: _dateTime(item.startTime)),
              _DetailRow(label: 'Selesai', value: _dateTime(item.endTime)),
              _DetailRow(
                label: 'Durasi server',
                value: '${item.durationHours} jam',
              ),
              _DetailRow(label: 'Alasan', value: item.reason),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Estimasi bayaran server',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!canReadPay)
          const AppStateView(
            kind: AppViewStateKind.permission,
            title: 'Estimasi tidak dapat dibuka',
            message: 'Akun ini tidak memiliki izin attendance:read.',
          )
        else
          ref
              .watch(overtimePayProvider(item))
              .when(
                loading: () => const AppStateView.loading(
                  title: 'Menghitung estimasi',
                  message: 'Menunggu hasil perhitungan server.',
                ),
                error: (error, _) => AppStateView(
                  kind: AppViewStateKind.error,
                  title: 'Estimasi belum tersedia',
                  message: _errorMessage(error),
                  actionLabel: 'Coba lagi',
                  onAction: () => ref.invalidate(overtimePayProvider(item)),
                ),
                data: (value) => AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(value.amount),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${value.durationHours} jam, ${value.dayType == 'HOLIDAY' ? 'hari libur' : 'hari kerja'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

String _errorMessage(Object error) {
  if (error is ApiException) {
    return switch (error.statusCode) {
      403 => 'Akun ini belum memiliki permission yang dibutuhkan server.',
      404 => 'Pengajuan tidak ditemukan. Muat ulang daftar.',
      409 => 'Pengajuan serupa sudah ada atau statusnya telah berubah.',
      _ => error.message,
    };
  }
  return 'Data belum dapat dimuat. Periksa koneksi lalu coba lagi.';
}

String _correctionSummary(AttendanceCorrectionRequest value) {
  final parts = <String>[];
  if (value.requestedCheckIn != null) {
    parts.add('Masuk ${_time(value.requestedCheckIn)}');
  }
  if (value.requestedCheckOut != null) {
    parts.add('Pulang ${_time(value.requestedCheckOut)}');
  }
  return parts.join(', ');
}

String _statusLabel(AttendanceRequestStatus status) => switch (status) {
  AttendanceRequestStatus.pending => 'Menunggu',
  AttendanceRequestStatus.approved => 'Disetujui',
  AttendanceRequestStatus.rejected => 'Ditolak',
  AttendanceRequestStatus.cancelled => 'Dibatalkan',
};

AppStatusTone _statusTone(AttendanceRequestStatus status) => switch (status) {
  AttendanceRequestStatus.pending => AppStatusTone.warning,
  AttendanceRequestStatus.approved => AppStatusTone.success,
  AttendanceRequestStatus.rejected => AppStatusTone.danger,
  AttendanceRequestStatus.cancelled => AppStatusTone.neutral,
};

DateTime _at(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

String _date(DateTime value) => _dateLabel(value.toLocal());

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _time(DateTime? value) {
  if (value == null) return 'Tidak diubah';
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _dateTime(DateTime value) => '${_date(value)} ${_time(value)}';
