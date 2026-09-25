import 'package:flutter/material.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/demo/demo_store.dart';

const _blue = Color(0xff315b8c);
const _mid = Color(0xff8fabc8);
const _pale = Color(0xffd8e2ed);

class DemoHomeSections extends StatelessWidget {
  const DemoHomeSections({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tim Hari Ini',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    useRootNavigator: true,
                    useSafeArea: true,
                    builder: (context) => const SafeArea(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Tim contoh · Divisi Marketing'),
                            ListTile(
                              title: Text('6 hadir · 2 cuti'),
                              subtitle: Text(
                                'Ilustrasi desain, bukan kehadiran karyawan nyata.',
                              ),
                            ),
                            ListTile(
                              title: Text('Dina'),
                              subtitle: Text('Cuti tahunan'),
                            ),
                            ListTile(
                              title: Text('Yoga'),
                              subtitle: Text('WFH'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Lihat semua'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 104,
                  height: 32,
                  child: Stack(
                    children: [
                      for (final entry in ['RS', 'DA', 'YP', '+4'].indexed)
                        Positioned(
                          left: entry.$1 * 24,
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: [
                                _blue,
                                const Color(0xff5d87b4),
                                _mid,
                                Theme.of(context).colorScheme.surfaceContainer,
                              ][entry.$1],
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              entry.$2,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: entry.$1 == 3
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '6 hadir · 2 cuti',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'Divisi Marketing · contoh',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(child: _TeamTag('Dina · Cuti tahunan')),
                SizedBox(width: 8),
                Expanded(child: _TeamTag('Yoga · WFH')),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppSurfaceCard(
        child: Row(
          children: [
            const AppIconTile(icon: Icons.schedule_outlined, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shift berikutnya · Senin',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '08.00 – 17.00 · Head Office Jakarta',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Contoh jadwal',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const AppStatusChip(label: 'Reguler', tone: AppStatusTone.neutral),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppSurfaceCard(
        child: Column(
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
                  '90 hari · contoh',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              label: 'Ilustrasi heatmap, bukan riwayat absensi pribadi.',
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    for (final day in [
                      'Sen',
                      'Sel',
                      'Rab',
                      'Kam',
                      'Jum',
                    ].indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text(
                                day.$2,
                                style: const TextStyle(fontSize: 10.5),
                              ),
                            ),
                            for (var i = 0; i < 11; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: [
                                          _blue,
                                          _mid,
                                          _pale,
                                          _blue,
                                          const Color(0xffedf1f6),
                                        ][(i + day.$1 * 3) % 5],
                                        borderRadius: BorderRadius.circular(5),
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
            Row(
              children: [
                for (final item in [
                  ('Kantor', '75%', _blue),
                  ('Remote', '15%', _mid),
                  ('Cuti', '10%', _pale),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 2, color: item.$3),
                          const SizedBox(height: 8),
                          Text(
                            item.$1,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            item.$2,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _TeamTag extends StatelessWidget {
  const _TeamTag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label, style: Theme.of(context).textTheme.bodySmall),
  );
}

class DemoAttendanceSummary extends StatelessWidget {
  const DemoAttendanceSummary({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppSurfaceCard(
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
                Text(
                  'Contoh grafik',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final entry in [
                  (96.0, 62.0, 34.0),
                  (87.0, 54.0, 28.0),
                  (104.0, 46.0, 40.0),
                ].indexed)
                  Flexible(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 110,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final bar in [
                                (entry.$2.$1, _blue),
                                (entry.$2.$2, _mid),
                                (entry.$2.$3, _pale),
                              ])
                                Container(
                                  width: 17,
                                  height: bar.$1,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bar.$2,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _month(entry.$1),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppSurfaceCard(
        child: Row(
          children: [
            const AppIconTile(icon: Icons.location_on_outlined, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Area kantor · simulasi',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Head Office Jakarta · GPS tidak diverifikasi',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const AppStatusChip(label: 'Demo', tone: AppStatusTone.neutral),
          ],
        ),
      ),
      const SizedBox(height: 10),
      ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = store.now();
          final rows = store.attendance
              .where(
                (r) => (r['date'] as String).startsWith(
                  '${now.year}-${now.month.toString().padLeft(2, '0')}',
                ),
              )
              .toList();
          final times = rows
              .map((r) => DateTime.parse(r['in'] as String).toLocal())
              .toList();
          final average = times.isEmpty
              ? null
              : times.fold<int>(0, (sum, t) => sum + t.hour * 60 + t.minute) ~/
                    times.length;
          final values = [
            ('Lembur', '--'),
            (
              'Rata-rata masuk',
              average == null
                  ? '--:--'
                  : '${(average ~/ 60).toString().padLeft(2, '0')}:${(average % 60).toString().padLeft(2, '0')}',
            ),
            ('Telat', '${rows.where((r) => r['status'] == 'Telat').length}×'),
          ];
          return LayoutBuilder(
            builder: (context, constraints) {
              final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.35;
              final cards = values
                  .map(
                    (item) => AppSurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.$2,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList();
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final card in cards)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: card,
                          ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in cards.indexed)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: entry.$1 == 0 ? 0 : 10,
                              ),
                              child: entry.$2,
                            ),
                          ),
                      ],
                    );
            },
          );
        },
      ),
    ],
  );

  String _month(int index) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month - 2 + index);
    return '${const ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'][date.month - 1]} ${date.year % 100}';
  }
}
