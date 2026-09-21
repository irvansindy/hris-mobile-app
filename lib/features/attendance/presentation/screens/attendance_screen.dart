import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_app/core/errors/failure.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/services/location_gateway.dart';
import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/core/services/selfie_gateway.dart';
import 'package:hrm_app/core/services/selfie_service.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/attendance/attendance_providers.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_context.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:hrm_app/features/attendance/domain/entities/attendance_history.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  CapturedSelfie? _selfie;
  String? _captureError;
  bool _capturing = false;
  int _historyPage = 1;
  DateTime _historyMonth = DateTime(DateTime.now().year, DateTime.now().month);
  AttendanceStatus _filter = AttendanceStatus.onTime;

  String get _monthKey =>
      '${_historyMonth.year}-${_historyMonth.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(featureSessionProvider);
    final today = ref.watch(attendanceControllerProvider(session));
    final value = today.valueOrNull;
    final record = value?.record;
    final policy = value?.context;
    final needsSelfie =
        record?.isActive == false && policy?.requiresSelfie == true;
    final supported =
        record != null &&
        policy != null &&
        (record.isActive
            ? policy.supportsMobileGps
            : needsSelfie
            ? policy.supportsFaceRecognition
            : policy.supportsMobileGps);
    final canSubmit =
        !today.isLoading &&
        record != null &&
        policy != null &&
        supported &&
        (!needsSelfie || _selfie != null);
    final query = AttendanceHistoryQuery(
      session: session,
      month: _monthKey,
      page: _historyPage,
    );
    final history = ref.watch(attendanceHistoryProvider(query));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(attendanceControllerProvider(session).future),
              ref.refresh(attendanceHistoryProvider(query).future),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              16,
              AppSpacing.screenHorizontal,
              AppSpacing.scrollBottom,
            ),
            children: [
              AppPageHeader(
                title: 'Absensi',
                subtitle: 'Log kehadiran Anda',
                trailing: FilledButton(
                  onPressed: () => context.push('/attendance/requests'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Pengajuan'),
                ),
              ),
              const SizedBox(height: 18),
              Text('Ringkasan', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (value != null) ...[
                _AttendanceRecordCard(record: value.record),
                const SizedBox(height: 12),
                _PolicyCard(value: value.context, record: value.record),
              ] else if (today.isLoading)
                const AppStateView.loading(
                  title: 'Memuat absensi',
                  message:
                      'Mengambil record dan kebijakan terbaru dari server.',
                ),
              if (needsSelfie) ...[
                const SizedBox(height: 12),
                _SelfieCard(
                  selfie: _selfie,
                  error: _captureError,
                  isCapturing: _capturing,
                  onCapture: _captureSelfie,
                ),
              ],
              if (today.hasError) ...[
                const SizedBox(height: 12),
                _AttendanceError(
                  error: today.error!,
                  onRetry: () =>
                      ref.invalidate(attendanceControllerProvider(session)),
                  onOpenSettings: _settingsAction(today.error!),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: canSubmit
                      ? () => _confirmAndSubmit(session, record, needsSelfie)
                      : null,
                  icon: today.isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: AppLoadingIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          record?.isActive == true
                              ? Icons.logout_rounded
                              : Icons.login_rounded,
                        ),
                  label: Text(
                    today.isLoading
                        ? 'Memproses...'
                        : record?.isActive == true
                        ? 'Catat pulang'
                        : 'Catat masuk',
                  ),
                ),
              ),
              if (policy != null && !supported) ...[
                const SizedBox(height: 10),
                Text(
                  'Kebijakan perusahaan tidak menyediakan metode absensi yang didukung aplikasi.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 22),
              AppPageHeader(
                title: 'Riwayat',
                subtitle:
                    '${_monthName(_historyMonth.month)} ${_historyMonth.year}',
              ),
              const SizedBox(height: 12),
              _MonthPicker(
                month: _historyMonth,
                onPrevious: () => _changeMonth(-1),
                onNext:
                    _historyMonth.isBefore(
                      DateTime(DateTime.now().year, DateTime.now().month),
                    )
                    ? () => _changeMonth(1)
                    : null,
              ),
              const SizedBox(height: 12),
              _HistoryStatusFilter(
                value: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 12),
              history.when(
                loading: () => const AppStateView.loading(
                  title: 'Memuat riwayat',
                  message: 'Mengambil catatan absensi dari server.',
                ),
                error: (error, _) => AppStateView(
                  kind: AppViewStateKind.error,
                  title: 'Riwayat gagal dimuat',
                  message: _message(error),
                  actionLabel: 'Coba lagi',
                  onAction: () =>
                      ref.invalidate(attendanceHistoryProvider(query)),
                ),
                data: (page) => _HistoryContent(
                  page: page,
                  filter: _filter,
                  onCorrection: (record) => context.push(
                    '/attendance/requests?compose=true',
                    extra: record,
                  ),
                  onPrevious: page.page > 1
                      ? () => setState(() => _historyPage--)
                      : null,
                  onNext: page.hasNextPage
                      ? () => setState(() => _historyPage++)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? _settingsAction(Object error) {
    if (error is! LocationException) return null;
    return switch (error.kind) {
      LocationIssueKind.permissionDeniedForever =>
        () => ref.read(locationServiceProvider).openAppSettings(),
      LocationIssueKind.serviceDisabled =>
        () => ref.read(locationServiceProvider).openLocationSettings(),
      _ => null,
    };
  }

  void _changeMonth(int offset) {
    setState(() {
      _historyMonth = DateTime(
        _historyMonth.year,
        _historyMonth.month + offset,
      );
      _historyPage = 1;
    });
  }

  Future<void> _captureSelfie() async {
    setState(() {
      _capturing = true;
      _captureError = null;
    });
    try {
      final capture = await ref.read(selfieServiceProvider).capture();
      if (mounted && capture != null) setState(() => _selfie = capture);
    } on SelfieException catch (error) {
      if (mounted) setState(() => _captureError = error.message);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _confirmAndSubmit(
    FeatureSession session,
    AttendanceEntity record,
    bool needsSelfie,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: AppMotion.sheetStyleOf(context),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              record.isActive
                  ? 'Konfirmasi catat pulang'
                  : 'Konfirmasi catat masuk',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              needsSelfie
                  ? 'Lokasi perangkat dan selfie akan dikirim untuk diverifikasi server.'
                  : 'Lokasi perangkat akan dikirim untuk diverifikasi server.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Kirim'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await ref
        .read(attendanceControllerProvider(session).notifier)
        .toggleAttendance(selfie: needsSelfie ? _selfie : null);
    if (!mounted || !success) return;
    setState(() {
      _selfie = null;
      _captureError = null;
    });
    ref.invalidate(
      attendanceHistoryProvider(
        AttendanceHistoryQuery(session: session, month: _monthKey),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          record.isActive
              ? 'Waktu pulang tercatat di server.'
              : 'Waktu masuk tercatat di server.',
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.value, required this.record});

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

class _AttendanceRecordCard extends StatelessWidget {
  const _AttendanceRecordCard({required this.record});

  final AttendanceEntity record;

  @override
  Widget build(BuildContext context) {
    final duration = record.checkedInAt == null
        ? null
        : (record.checkedOutAt ?? DateTime.now()).difference(
            record.checkedInAt!,
          );
    return AppSurfaceCard(
      semanticLabel: 'Catatan absensi hari ini dari server',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              Text('Hari ini', style: Theme.of(context).textTheme.titleMedium),
              AppStatusChip(
                label: record.isActive
                    ? 'Sedang bekerja'
                    : record.checkedOutAt != null
                    ? 'Selesai'
                    : 'Belum masuk',
                tone: record.isActive || record.checkedOutAt != null
                    ? AppStatusTone.success
                    : AppStatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _TimeValue(
                  label: 'Masuk',
                  value: _time(record.checkedInAt),
                ),
              ),
              Expanded(
                child: _TimeValue(
                  label: 'Pulang',
                  value: _time(record.checkedOutAt),
                ),
              ),
              Expanded(
                child: _TimeValue(
                  label: 'Durasi',
                  value: duration == null
                      ? 'Belum ada'
                      : '${duration.inHours}j ${duration.inMinutes.remainder(60)}m',
                ),
              ),
            ],
          ),
          if (record.requiresReview) ...[
            const SizedBox(height: AppSpacing.md),
            const AppStatusChip(
              label: 'Menunggu tinjauan',
              tone: AppStatusTone.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeValue extends StatelessWidget {
  const _TimeValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: AppSpacing.xxs),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _SelfieCard extends StatelessWidget {
  const _SelfieCard({
    required this.selfie,
    required this.error,
    required this.isCapturing,
    required this.onCapture,
  });

  final CapturedSelfie? selfie;
  final String? error;
  final bool isCapturing;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selfie verifikasi',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (selfie != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.smallCard),
            child: Semantics(
              image: true,
              label: 'Pratinjau selfie absensi',
              child: Image.memory(
                selfie!.bytes,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          )
        else
          const Text('Ambil foto langsung dengan kamera depan.'),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: isCapturing ? null : onCapture,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(
            isCapturing
                ? 'Membuka kamera...'
                : selfie == null
                ? 'Ambil selfie'
                : 'Ambil ulang',
          ),
        ),
      ],
    ),
  );
}

class _AttendanceError extends StatelessWidget {
  const _AttendanceError({
    required this.error,
    required this.onRetry,
    this.onOpenSettings,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) => AppStateView(
    kind: error is LocationException
        ? AppViewStateKind.permission
        : AppViewStateKind.error,
    title: 'Absensi belum tercatat',
    message: _message(error),
    actionLabel: onOpenSettings == null ? 'Coba lagi' : 'Buka pengaturan',
    onAction: onOpenSettings ?? onRetry,
  );
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    child: Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          tooltip: 'Bulan sebelumnya',
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            '${_monthName(month.month)} ${month.year}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: onNext,
          tooltip: 'Bulan berikutnya',
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _HistoryStatusFilter extends StatelessWidget {
  const _HistoryStatusFilter({required this.value, required this.onChanged});
  final AttendanceStatus value;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) => AppSegmentedControl<AttendanceStatus>(
    values: const [
      AttendanceStatus.onTime,
      AttendanceStatus.excused,
      AttendanceStatus.late,
    ],
    selected: value,
    labelBuilder: (item) => switch (item) {
      AttendanceStatus.onTime => 'Hadir',
      AttendanceStatus.excused => 'Cuti',
      _ => 'Telat',
    },
    onSelected: onChanged,
  );
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.page,
    required this.filter,
    required this.onCorrection,
    required this.onPrevious,
    required this.onNext,
  });

  final AttendanceHistoryPage page;
  final AttendanceStatus filter;
  final ValueChanged<AttendanceEntity> onCorrection;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final items = page.items
        .where((item) {
          if (filter == AttendanceStatus.onTime) {
            return item.status == AttendanceStatus.onTime ||
                item.status == AttendanceStatus.completed;
          }
          return item.status == filter;
        })
        .toList(growable: false);
    if (page.items.isEmpty) {
      return const AppStateView(
        kind: AppViewStateKind.empty,
        title: 'Belum ada riwayat',
        message: 'Server tidak mengembalikan catatan untuk bulan ini.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'Total server',
                  value: '${page.total}',
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'Halaman',
                  value: '${page.page}/${page.totalPages}',
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'Sesuai filter',
                  value: '${items.length}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty)
          const AppStateView(
            kind: AppViewStateKind.empty,
            title: 'Tidak ada status ini',
            message: 'Coba filter lain atau pindah bulan.',
          )
        else
          for (final item in items) ...[
            _HistoryCard(record: item, onCorrection: () => onCorrection(item)),
            const SizedBox(height: AppSpacing.sm),
          ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onPrevious,
                child: const Text('Sebelumnya'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: onNext,
                child: const Text('Berikutnya'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record, required this.onCorrection});
  final AttendanceEntity record;
  final VoidCallback onCorrection;

  @override
  Widget build(BuildContext context) {
    final status = switch (record.status) {
      AttendanceStatus.onTime ||
      AttendanceStatus.completed => ('Hadir', AppStatusTone.success),
      AttendanceStatus.late => ('Telat', AppStatusTone.warning),
      AttendanceStatus.excused => ('Cuti', AppStatusTone.info),
      AttendanceStatus.absent => ('Tidak hadir', AppStatusTone.danger),
      AttendanceStatus.notStarted => ('Belum mulai', AppStatusTone.neutral),
    };
    final date = record.workDate ?? record.checkedInAt;
    return AppSurfaceCard(
      semanticLabel: '${status.$1}, ${_date(date)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _date(date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${_time(record.checkedInAt)} sampai ${_time(record.checkedOutAt)}',
                    ),
                    if (record.officeTimezone case final timezone?)
                      Text(
                        timezone,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              AppStatusChip(label: status.$1, tone: status.$2),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onCorrection,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Ajukan koreksi'),
          ),
        ],
      ),
    );
  }
}

String _time(DateTime? value) {
  if (value == null) return '--:--';
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _date(DateTime? value) {
  if (value == null) return 'Tanggal tidak tersedia';
  final local = value.toLocal();
  return '${local.day} ${_monthName(local.month)} ${local.year}';
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

String _message(Object error) => switch (error) {
  Failure(:final message) => message,
  LocationException(:final message) => message,
  _ => 'Data tidak dapat diproses. Periksa koneksi lalu coba lagi.',
};
