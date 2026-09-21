import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hrm_app/core/services/location_service.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/ess/domain/ess_models.dart';
import 'package:hrm_app/features/ess/ess_providers.dart';

Future<void> showLoanForm(
  BuildContext context,
  WidgetRef ref,
  List<LoanTypeOption> types,
) => _sheet(context, _LoanForm(types: types));

Future<void> showEwaForm(BuildContext context, WidgetRef ref, EwaLimit limit) =>
    _sheet(context, _EwaForm(limit: limit));

Future<void> showActivityForm(
  BuildContext context,
  WidgetRef ref, {
  required EmployeeBranch? branch,
  DailyActivity? existing,
}) => _sheet(context, _ActivityForm(branch: branch, existing: existing));

Future<void> showTravelMenu(
  BuildContext context,
  WidgetRef ref,
  TravelSnapshot snapshot,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheetContext) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Buat pengajuan', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          leading: const Icon(Icons.flight_takeoff_rounded),
          title: const Text('Perjalanan dinas'),
          subtitle: const Text('Ajukan tujuan, tanggal, dan estimasi biaya'),
          onTap: () {
            Navigator.pop(sheetContext);
            _sheet(context, const _TripForm());
          },
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Klaim biaya'),
          subtitle: const Text('Tambahkan bukti JPG atau PNG bila ada'),
          onTap: snapshot.categories.isEmpty
              ? null
              : () {
                  Navigator.pop(sheetContext);
                  _sheet(context, _ClaimForm(snapshot: snapshot));
                },
        ),
      ],
    ),
  ),
);

Future<void> _sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: child),
    );

class _LoanForm extends ConsumerStatefulWidget {
  const _LoanForm({required this.types});
  final List<LoanTypeOption> types;

  @override
  ConsumerState<_LoanForm> createState() => _LoanFormState();
}

class _LoanFormState extends ConsumerState<_LoanForm> {
  final _key = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  late String _typeId = widget.types.first.id;
  int _installments = 1;

  LoanTypeOption get _type =>
      widget.types.firstWhere((item) => item.id == _typeId);

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(essMutationProvider).isLoading;
    final maximum = _type.maxInstallments?.clamp(1, 60) ?? 60;
    if (_installments > maximum) _installments = maximum;
    return _FormScaffold(
      title: 'Ajukan pinjaman',
      subtitle: 'Cicilan final dan bunga ditentukan server.',
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _typeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipe pinjaman'),
              items: widget.types
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      if (value != null) {
                        _typeId = value;
                        _installments = 1;
                      }
                    }),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amount,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
                helperText: _type.maxAmount == null
                    ? null
                    : 'Maksimum tipe ini: Rp ${_type.maxAmount!.toStringAsFixed(0)}',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Masukkan nominal yang valid';
                }
                if (_type.maxAmount != null && amount > _type.maxAmount!) {
                  return 'Nominal melebihi maksimum tipe pinjaman';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _installments,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Jumlah cicilan'),
              items: List.generate(
                maximum,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1} bulan'),
                ),
              ),
              onChanged: busy
                  ? null
                  : (value) => setState(() => _installments = value ?? 1),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _reason,
              enabled: !busy,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Alasan'),
              validator: (value) =>
                  value?.trim().isEmpty != false ? 'Alasan wajib diisi' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(busy ? 'Mengirim...' : 'Kirim pengajuan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_key.currentState?.validate() != true) return;
    try {
      await ref
          .read(essMutationProvider.notifier)
          .createLoan(
            CreateLoanCommand(
              loanTypeId: _typeId,
              amount: double.parse(_amount.text),
              totalInstallments: _installments,
              reason: _reason.text,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }
}

class _EwaForm extends ConsumerStatefulWidget {
  const _EwaForm({required this.limit});
  final EwaLimit limit;

  @override
  ConsumerState<_EwaForm> createState() => _EwaFormState();
}

class _EwaFormState extends ConsumerState<_EwaForm> {
  final _key = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(essMutationProvider).isLoading;
    return _FormScaffold(
      title: 'Ajukan EWA',
      subtitle: 'Sisa limit: Rp ${widget.limit.remaining.toStringAsFixed(0)}',
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _amount,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Masukkan nominal yang valid';
                }
                if (amount > widget.limit.remaining) {
                  return 'Nominal melebihi sisa limit';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _reason,
              enabled: !busy,
              maxLines: 3,
              maxLength: 4000,
              decoration: const InputDecoration(labelText: 'Alasan (opsional)'),
              validator: (value) {
                final text = value?.trim() ?? '';
                return text.isNotEmpty && text.length < 3
                    ? 'Alasan minimal 3 karakter'
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(busy ? 'Mengirim...' : 'Kirim pengajuan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_key.currentState?.validate() != true) return;
    try {
      await ref
          .read(essMutationProvider.notifier)
          .createEwa(
            CreateEwaCommand(
              amount: double.parse(_amount.text),
              reason: _reason.text,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }
}

class _ActivityForm extends ConsumerStatefulWidget {
  const _ActivityForm({required this.branch, this.existing});
  final EmployeeBranch? branch;
  final DailyActivity? existing;

  @override
  ConsumerState<_ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends ConsumerState<_ActivityForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.existing?.description,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.notes,
  );
  late DateTime _date = widget.existing?.activityDate ?? DateTime.now();
  late TimeOfDay _start = TimeOfDay.fromDateTime(
    widget.existing?.startTime ?? DateTime.now(),
  );
  late TimeOfDay _end = TimeOfDay.fromDateTime(
    widget.existing?.endTime ?? DateTime.now().add(const Duration(hours: 1)),
  );
  late String _type = widget.existing?.type ?? 'WORK';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(essMutationProvider).isLoading;
    final editing = widget.existing != null;
    return _FormScaffold(
      title: editing ? 'Ubah aktivitas' : 'Catat aktivitas',
      subtitle: editing
          ? 'Lokasi awal tidak diubah.'
          : '${widget.branch?.name ?? 'Cabang belum tersedia'} · GPS diambil saat dikirim',
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!editing) ...[
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipe aktivitas'),
                items:
                    const {
                          'WORK': 'Pekerjaan',
                          'SITE_VISIT': 'Kunjungan site',
                          'SITE_INSPECTION': 'Inspeksi site',
                          'MEETING': 'Rapat',
                          'OTHER': 'Lainnya',
                        }.entries
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.key,
                            child: Text(item.value),
                          ),
                        )
                        .toList(growable: false),
                onChanged: busy
                    ? null
                    : (value) => setState(() => _type = value ?? 'WORK'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: _title,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Judul aktivitas'),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Judul minimal 3 karakter'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              enabled: !busy,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: editing || busy ? null : _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('${_date.day}/${_date.month}/${_date.year}'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => _pickTime(true),
                  child: Text('Mulai ${_start.format(context)}'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => _pickTime(false),
                  child: Text('Selesai ${_end.format(context)}'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _notes,
              enabled: !busy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: busy ? null : _submit,
              icon: Icon(
                editing ? Icons.save_outlined : Icons.my_location_rounded,
              ),
              label: Text(
                busy
                    ? 'Mengirim...'
                    : editing
                    ? 'Simpan perubahan'
                    : 'Ambil GPS dan kirim',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 31)),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickTime(bool start) async {
    final value = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (value != null) setState(() => start ? _start = value : _end = value);
  }

  Future<void> _submit() async {
    if (_key.currentState?.validate() != true) return;
    final start = _combine(_date, _start);
    final end = _combine(_date, _end);
    if (!end.isAfter(start)) {
      _showError(context, 'Waktu selesai harus setelah waktu mulai.');
      return;
    }
    try {
      final notifier = ref.read(essMutationProvider.notifier);
      if (widget.existing case final existing?) {
        await notifier.updateActivity(
          existing.id,
          UpdateActivityCommand(
            title: _title.text,
            description: _description.text,
            notes: _notes.text,
            startTime: start,
            endTime: end,
          ),
        );
      } else {
        final branch = widget.branch;
        if (branch == null) {
          throw StateError('Cabang employee belum tersedia.');
        }
        final position = await ref
            .read(locationServiceProvider)
            .currentPosition();
        if (position.isMocked) {
          throw StateError(
            'Lokasi tiruan terdeteksi. Gunakan lokasi perangkat asli.',
          );
        }
        if (position.accuracyMeters > 100) {
          throw StateError(
            'Akurasi GPS lebih dari 100 meter. Pindah ke area terbuka lalu coba lagi.',
          );
        }
        await notifier.createActivity(
          CreateActivityCommand(
            branchId: branch.id,
            title: _title.text,
            type: _type,
            activityDate: _date,
            startTime: start,
            endTime: end,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracyMeters,
            description: _description.text,
            notes: _notes.text,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }
}

class _TripForm extends ConsumerStatefulWidget {
  const _TripForm();
  @override
  ConsumerState<_TripForm> createState() => _TripFormState();
}

class _TripFormState extends ConsumerState<_TripForm> {
  final _key = GlobalKey<FormState>();
  final _destination = TextEditingController();
  final _purpose = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();

  @override
  void dispose() {
    _destination.dispose();
    _purpose.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(essMutationProvider).isLoading;
    return _FormScaffold(
      title: 'Ajukan perjalanan dinas',
      subtitle: 'Status persetujuan mengikuti workflow server.',
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _destination,
              enabled: !busy,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Tujuan'),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _purpose,
              enabled: !busy,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Keperluan'),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _cost,
              enabled: !busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Estimasi biaya',
                prefixText: 'Rp ',
              ),
              validator: (value) => double.tryParse(value ?? '') == null
                  ? 'Masukkan estimasi biaya'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => _pickDate(true),
                  child: Text('Mulai ${_shortDate(_start)}'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => _pickDate(false),
                  child: Text('Selesai ${_shortDate(_end)}'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _notes,
              enabled: !busy,
              maxLines: 2,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(busy ? 'Mengirim...' : 'Kirim perjalanan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool start) async {
    final initial = start ? _start : _end;
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (value != null) setState(() => start ? _start = value : _end = value);
  }

  Future<void> _submit() async {
    if (_key.currentState?.validate() != true) return;
    try {
      await ref
          .read(essMutationProvider.notifier)
          .createTrip(
            CreateTripCommand(
              destination: _destination.text,
              purpose: _purpose.text,
              startDate: _start,
              endDate: _end,
              estimatedCost: double.parse(_cost.text),
              notes: _notes.text,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }
}

class _ClaimForm extends ConsumerStatefulWidget {
  const _ClaimForm({required this.snapshot});
  final TravelSnapshot snapshot;
  @override
  ConsumerState<_ClaimForm> createState() => _ClaimFormState();
}

class _ClaimFormState extends ConsumerState<_ClaimForm> {
  final _key = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  late String _category = widget.snapshot.categories.first.value;
  String? _tripId;
  DateTime _date = DateTime.now();
  ReceiptFile? _receipt;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(essMutationProvider).isLoading;
    return _FormScaffold(
      title: 'Ajukan klaim biaya',
      subtitle: 'Bukti gambar maksimal 5 MB.',
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: widget.snapshot.categories
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.value,
                      child: Text(item.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: busy
                  ? null
                  : (value) => setState(() => _category = value ?? _category),
            ),
            if (widget.snapshot.trips.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: _tripId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Perjalanan terkait (opsional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tanpa perjalanan'),
                  ),
                  ...widget.snapshot.trips.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(item.destination),
                    ),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() => _tripId = value),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amount,
              enabled: !busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
              ),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                return amount == null || amount <= 0
                    ? 'Masukkan nominal yang valid'
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: busy ? null : _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Tanggal biaya ${_shortDate(_date)}'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              enabled: !busy,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: busy ? null : _pickReceipt,
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(_receipt?.name ?? 'Pilih bukti gambar'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _notes,
              enabled: !busy,
              maxLines: 2,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(busy ? 'Mengunggah...' : 'Kirim klaim'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickReceipt() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final lower = file.name.toLowerCase();
    final mime =
        file.mimeType ?? (lower.endsWith('.png') ? 'image/png' : 'image/jpeg');
    if (!const {'image/jpeg', 'image/png'}.contains(mime) ||
        bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        _showError(context, 'Bukti harus JPG/PNG dan tidak lebih dari 5 MB.');
      }
      return;
    }
    setState(
      () =>
          _receipt = ReceiptFile(bytes: bytes, name: file.name, mimeType: mime),
    );
  }

  Future<void> _submit() async {
    if (_key.currentState?.validate() != true) return;
    try {
      await ref
          .read(essMutationProvider.notifier)
          .createClaim(
            CreateClaimCommand(
              category: _category,
              amount: double.parse(_amount.text),
              expenseDate: _date,
              tripId: _tripId,
              description: _description.text,
              notes: _notes.text,
            ),
            receipt: _receipt,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }
}

class _FormScaffold extends StatelessWidget {
  const _FormScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    ),
  );
}

DateTime _combine(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

String _shortDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

String? _required(String? value) =>
    value?.trim().isEmpty != false ? 'Wajib diisi' : null;

void _showError(BuildContext context, Object error) {
  final raw = error.toString();
  final message = raw.startsWith('ApiException(') && raw.contains(': ')
      ? raw.substring(raw.indexOf(': ') + 2)
      : raw.startsWith('Bad state: ')
      ? raw.substring('Bad state: '.length)
      : raw;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}
