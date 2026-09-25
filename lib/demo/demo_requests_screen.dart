import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/demo/demo_store.dart';

enum _Category { all, leave, overtime, reimbursement }

enum _StatusFilter { all, pending, completed }

class DemoRequestsScreen extends StatefulWidget {
  const DemoRequestsScreen({super.key, required this.store});

  final DemoStore store;

  @override
  State<DemoRequestsScreen> createState() => _DemoRequestsScreenState();
}

class _DemoRequestsScreenState extends State<DemoRequestsScreen> {
  _Category _category = _Category.all;
  _StatusFilter _status = _StatusFilter.all;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final records = [
            ...widget.store.requests.map(_DemoRequest.fromStore),
            ..._DemoRequest.examples,
          ];
          final pending = widget.store.requests
              .where((row) => row['status'] == 'Menunggu')
              .length;
          final completed = widget.store.requests.length - pending;
          final visible = records.where((record) {
            final categoryMatches =
                _category == _Category.all || record.category == _category;
            final statusMatches =
                _status == _StatusFilter.all ||
                (_status == _StatusFilter.pending
                    ? record.status == 'Menunggu'
                    : record.status != 'Menunggu');
            return categoryMatches && statusMatches;
          }).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
            children: [
              AppPageHeader(
                title: 'Pengajuan',
                subtitle: '$pending aktif · $completed selesai',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'Buat Pengajuan',
                      subtitle: 'Cuti, izin, lembur',
                      icon: Icons.add_rounded,
                      primary: true,
                      onTap: _showCreateMenu,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      title: 'Menunggu',
                      subtitle: '$pending perlu approval',
                      icon: Icons.schedule_rounded,
                      onTap: () =>
                          setState(() => _status = _StatusFilter.pending),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (category, label) in [
                      (_Category.all, 'Semua'),
                      (_Category.leave, 'Cuti'),
                      (_Category.overtime, 'Lembur'),
                      (_Category.reimbursement, 'Reimburse'),
                    ]) ...[
                      if (category != _Category.all) const SizedBox(width: 7),
                      _CategoryPill(
                        label: label,
                        selected: _category == category,
                        onTap: () => setState(() => _category = category),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Riwayat',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  PopupMenuButton<_StatusFilter>(
                    tooltip: 'Filter status pengajuan',
                    onSelected: (value) => setState(() => _status = value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _StatusFilter.all,
                        child: Text('Semua'),
                      ),
                      PopupMenuItem(
                        value: _StatusFilter.pending,
                        child: Text('Menunggu'),
                      ),
                      PopupMenuItem(
                        value: _StatusFilter.completed,
                        child: Text('Selesai'),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Text(
                        switch (_status) {
                          _StatusFilter.all => 'Semua',
                          _StatusFilter.pending => 'Menunggu',
                          _StatusFilter.completed => 'Selesai',
                        },
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              if (visible.isEmpty)
                const AppSurfaceCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text('Tidak ada pengajuan pada filter ini.'),
                    ),
                  ),
                )
              else
                for (final record in visible) ...[
                  _HistoryCard(
                    record: record,
                    onTap: () => _showDetail(record),
                  ),
                  const SizedBox(height: 9),
                ],
            ],
          );
        },
      ),
    ),
  );

  void _showCreateMenu() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Buat pengajuan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.beach_access_outlined),
            title: const Text('Cuti'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/requests/leave/new');
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Izin'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/requests/permission/new');
            },
          ),
          ListTile(
            leading: const Icon(Icons.more_time_rounded),
            title: const Text('Lembur'),
            subtitle: const Text('Simulasi penyimpanan lokal belum tersedia'),
            onTap: () {
              Navigator.pop(sheetContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Pengajuan lembur belum tersedia dalam demo lokal.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  void _showDetail(_DemoRequest record) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(record.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(record.subtitle),
          const SizedBox(height: 12),
          Text('Status: ${record.status}'),
          if (record.reason != null) ...[
            const SizedBox(height: 8),
            Text('Alasan: ${record.reason}'),
          ],
          if (record.isExample) ...[
            const SizedBox(height: 14),
            const Text(
              'Contoh tampilan saja; belum tersimpan sebagai transaksi lokal.',
            ),
          ],
          if (!record.isExample && record.status == 'Menunggu') ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () async {
                try {
                  await widget.store.decide(record.id, approve: false);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                } catch (_) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('Pembatalan demo gagal. Coba lagi.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Batalkan pengajuan'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: primary
          ? AppColors.primary
          : Theme.of(context).colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 96 + (MediaQuery.textScalerOf(context).scale(1) - 1) * 55,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: primary ? color : AppColors.primary,
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: primary
                        ? Colors.white70
                        : Theme.of(context).colorScheme.onSurfaceVariant,
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

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: SizedBox(
      height: 44,
      child: Center(
        child: Material(
          color: selected
              ? AppColors.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(99),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              key: ValueKey('request-filter-$label'),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 10,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record, required this.onTap});
  final _DemoRequest record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        const AppIconTile(icon: Icons.insert_drive_file_outlined, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                record.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _SmallStatus(status: record.status),
      ],
    ),
  );
}

class _SmallStatus extends StatelessWidget {
  const _SmallStatus({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      'Menunggu' => (AppColors.warning, AppColors.warningBackground),
      'Disetujui' => (AppColors.success, AppColors.successBackground),
      _ => (AppColors.danger, AppColors.dangerBackground),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground, fontSize: 10),
      ),
    );
  }
}

class _DemoRequest {
  const _DemoRequest({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.category,
    this.reason,
    this.isExample = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String status;
  final _Category category;
  final String? reason;
  final bool isExample;

  factory _DemoRequest.fromStore(DemoRecord row) {
    final start = DateTime.parse(row['start'] as String);
    final kind = row['kind'] as String;
    final days = row['days'] as int;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return _DemoRequest(
      id: row['id'] as String,
      title: '${kind == 'Cuti' ? 'Cuti Tahunan' : 'Izin'} · $days hari',
      subtitle:
          'Diajukan ${start.day} ${months[start.month - 1]} ${start.year}',
      status: row['status'] as String,
      category: _Category.leave,
      reason: row['reason'] as String?,
    );
  }

  static const examples = [
    _DemoRequest(
      id: 'example-overtime',
      title: 'Lembur 3 jam',
      subtitle: 'Contoh · Diajukan 5 Sep 2026',
      status: 'Disetujui',
      category: _Category.overtime,
      isExample: true,
    ),
    _DemoRequest(
      id: 'example-reimbursement',
      title: 'Reimbursement',
      subtitle: 'Contoh · Diajukan 27 Agu 2026',
      status: 'Ditolak',
      category: _Category.reimbursement,
      isExample: true,
    ),
  ];
}
