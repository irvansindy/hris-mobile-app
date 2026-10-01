import 'package:flutter/material.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/demo/demo_store.dart';

const _blue = Color(0xff315b8c);
const _mid = Color(0xff8fabc8);
const _pale = Color(0xffd8e2ed);

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
                (record) => (record['date'] as String).startsWith(
                  '${now.year}-${now.month.toString().padLeft(2, '0')}',
                ),
              )
              .toList();
          final times = rows
              .map((record) => DateTime.parse(record['in'] as String).toLocal())
              .toList();
          final average = times.isEmpty
              ? null
              : times.fold<int>(
                      0,
                      (sum, time) => sum + time.hour * 60 + time.minute,
                    ) ~/
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
