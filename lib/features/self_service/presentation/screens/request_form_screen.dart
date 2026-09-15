import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/domain/entities/request_command.dart';
import 'package:hrm_app/features/self_service/self_service_dependencies.dart';
import 'package:hrm_app/features/self_service/self_service_providers.dart';
import 'package:uuid/uuid.dart';

class RequestFormScreen extends ConsumerStatefulWidget {
  const RequestFormScreen({super.key, required this.kind});
  final RequestKind kind;

  @override
  ConsumerState<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends ConsumerState<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTimeRange? _range;
  String? _type;
  String? _attachment;
  String? _attachmentName;
  String? _error;
  String? _attemptKey;
  bool _submitting = false;
  bool _picking = false;

  bool get _isLeave => widget.kind == RequestKind.leave;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(featureSessionProvider);
    final canCreate =
        !_isLeave ||
        ref
                .watch(requestContextProvider)
                ?.permissions
                .contains('leave:create') ==
            true;
    if (!canCreate) {
      return Scaffold(
        body: SafeArea(
          minimum: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppDetailHeader(
                title: 'Ajukan cuti',
                subtitle: 'Pengajuan baru',
              ),
              const SizedBox(height: AppSpacing.lg),
              const Expanded(
                child: AppStateView(
                  kind: AppViewStateKind.permission,
                  title: 'Akses pengajuan tidak tersedia',
                  message: 'Akun ini tidak memiliki izin leave:create.',
                ),
              ),
            ],
          ),
        ),
      );
    }
    final leaveTypes = _isLeave
        ? ref.watch(leaveTypesProvider(session))
        : const AsyncValue<List<LeaveTypeOption>>.data([]);
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
            ),
            children: [
              AppDetailHeader(
                title: _isLeave ? 'Ajukan cuti' : 'Ajukan izin',
                subtitle: 'Pengajuan baru',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(
                title: _isLeave ? 'Detail cuti' : 'Detail izin',
                description:
                    'Semua tanggal dan status akhir divalidasi server.',
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isLeave)
                leaveTypes.when(
                  loading: () => const AppLoadingIndicator(
                    linear: true,
                    semanticLabel: 'Memuat jenis cuti',
                  ),
                  error: (_, _) => AppStateView(
                    kind: AppViewStateKind.error,
                    title: 'Jenis cuti gagal dimuat',
                    message:
                        'Form belum dapat dikirim tanpa jenis cuti server.',
                    actionLabel: 'Coba lagi',
                    onAction: () => ref.invalidate(leaveTypesProvider(session)),
                  ),
                  data: (types) => types.isEmpty
                      ? const AppStateView(
                          kind: AppViewStateKind.empty,
                          title: 'Jenis cuti belum tersedia',
                          message:
                              'Server tidak mengembalikan jenis cuti aktif.',
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _type,
                          isExpanded: true,
                          itemHeight: null,
                          selectedItemBuilder: (context) => [
                            for (final type in types)
                              Tooltip(
                                message: type.name,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    type.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Jenis cuti',
                          ),
                          items: [
                            for (final type in types)
                              DropdownMenuItem(
                                value: type.id,
                                child: Text(type.name),
                              ),
                          ],
                          validator: (value) =>
                              value == null ? 'Pilih jenis cuti.' : null,
                          onChanged: _submitting
                              ? null
                              : (value) => setState(() => _type = value),
                        ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(labelText: 'Jenis izin'),
                  items: const [
                    DropdownMenuItem(value: 'SICK', child: Text('Sakit')),
                    DropdownMenuItem(
                      value: 'PERSONAL',
                      child: Text('Keperluan pribadi'),
                    ),
                    DropdownMenuItem(value: 'LATE', child: Text('Terlambat')),
                    DropdownMenuItem(
                      value: 'EARLY_LEAVE',
                      child: Text('Pulang lebih awal'),
                    ),
                    DropdownMenuItem(
                      value: 'LEAVE_OFFICE',
                      child: Text('Keluar kantor'),
                    ),
                    DropdownMenuItem(
                      value: 'BUSINESS_TRIP',
                      child: Text('Perjalanan dinas'),
                    ),
                    DropdownMenuItem(
                      value: 'WORK_FROM_HOME',
                      child: Text('Bekerja dari rumah'),
                    ),
                    DropdownMenuItem(value: 'OTHER', child: Text('Lainnya')),
                  ],
                  validator: (value) =>
                      value == null ? 'Pilih jenis izin.' : null,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _type = value),
                ),
              const SizedBox(height: AppSpacing.md),
              AppSurfaceCard(
                onTap: _submitting ? null : _pickDate,
                semanticLabel: 'Pilih rentang tanggal',
                child: Row(
                  children: [
                    const Icon(Icons.date_range_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _range == null
                            ? 'Pilih rentang tanggal'
                            : '${_date(_range!.start)} sampai ${_date(_range!.end)}',
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              if (_range != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Estimasi ${_workingDays(_range!)} hari kerja Senin sampai Jumat. Hari libur dan hasil akhir ditentukan server.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _reasonController,
                enabled: !_submitting,
                minLines: 4,
                maxLines: 7,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Alasan',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Alasan wajib diisi.'
                    : null,
              ),
              if (_isLeave) ...[
                const SizedBox(height: AppSpacing.md),
                AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Lampiran',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _attachmentName ??
                            'Opsional, kecuali diwajibkan jenis cuti.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _submitting || _picking
                            ? null
                            : _pickAttachment,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(
                          _picking ? 'Membuka galeri...' : 'Pilih foto',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: FilledButton.icon(
                  onPressed: _submitting || leaveTypes.isLoading
                      ? null
                      : _confirm,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: AppLoadingIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_submitting ? 'Mengirim...' : 'Tinjau dan kirim'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDialog<DateTimeRange>(
      context: context,
      useSafeArea: false,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (context) => DateRangePickerDialog(
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 2, 12, 31),
        initialDateRange: _range,
        initialEntryMode: MediaQuery.textScalerOf(context).scale(1) > 1.4
            ? DatePickerEntryMode.inputOnly
            : DatePickerEntryMode.calendar,
      ),
    );
    if (result != null && mounted) setState(() => _range = result);
  }

  Future<void> _pickAttachment() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final extension = file.name.toLowerCase().endsWith('.png')
          ? 'png'
          : 'jpeg';
      setState(() {
        _attachment = 'data:image/$extension;base64,${base64Encode(bytes)}';
        _attachmentName = file.name;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Lampiran tidak dapat dibaca. Coba foto lain.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate() || _range == null) {
      if (_range == null) {
        setState(() => _error = 'Pilih rentang tanggal.');
      }
      return;
    }
    if (_isLeave) {
      final session = ref.read(featureSessionProvider);
      final types =
          ref.read(leaveTypesProvider(session)).valueOrNull ?? const [];
      final selected = types.where((item) => item.id == _type).firstOrNull;
      if (selected?.requiresAttachment == true && _attachment == null) {
        setState(() => _error = 'Jenis cuti ini mewajibkan lampiran foto.');
        return;
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.dialogStyleOf(context),
      builder: (context) => AlertDialog(
        title: const Text('Kirim pengajuan?'),
        content: Text(
          '${_date(_range!.start)} sampai ${_date(_range!.end)}. Setelah dikirim, status mengikuti keputusan server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _submit();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
      _attemptKey ??= const Uuid().v4();
    });
    try {
      final result = await ref
          .read(requestRepositoryProvider)
          .submit(
            SubmitRequestCommand(
              kind: widget.kind,
              type: _type!,
              startDate: _range!.start,
              endDate: _range!.end,
              reason: _reasonController.text,
              attachment: _attachment,
              idempotencyKey: _attemptKey,
            ),
          );
      ref.invalidate(requestPageProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengajuan ${result.id} tersimpan di server.')),
      );
      Navigator.pop(context, result.id);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Pengajuan gagal dikirim. Data form tetap tersimpan di layar untuk dicoba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

int _workingDays(DateTimeRange range) {
  var count = 0;
  for (
    var date = DateTime(range.start.year, range.start.month, range.start.day);
    !date.isAfter(range.end);
    date = date.add(const Duration(days: 1))
  ) {
    if (date.weekday <= DateTime.friday) count++;
  }
  return count;
}
