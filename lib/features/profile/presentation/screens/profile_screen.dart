import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/profile/profile_providers.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/services/app_metadata.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    super.key,
    required this.onThemeToggle,
    required this.onSignOut,
    required this.isDarkMode,
  });

  final VoidCallback onThemeToggle;
  final VoidCallback onSignOut;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(profileControllerProvider);
    final load = ref.watch(profileLoadStateProvider);
    final version = ref.watch(appVersionProvider);
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    final identity = [
      employee.id,
      employee.department,
      employee.location,
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
    final contacts = <({String label, String value})>[
      if (employee.email.isNotEmpty) (label: 'Email', value: employee.email),
      if (employee.phone.isNotEmpty) (label: 'Telepon', value: employee.phone),
    ];
    final employment = <({String label, String value})>[
      if (employee.joinDate.isNotEmpty)
        (label: 'Tanggal masuk', value: employee.joinDate),
      if (employee.location.isNotEmpty)
        (label: 'Lokasi', value: employee.location),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: ref.read(profileControllerProvider.notifier).refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              18,
              AppSpacing.screenHorizontal,
              AppSpacing.scrollBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    AppInitialAvatar(name: employee.name, size: 88),
                    const SizedBox(height: 14),
                    Text(
                      employee.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (employee.role.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        employee.role,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (identity.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: identity
                            .map(
                              (value) => Container(
                                constraints: const BoxConstraints(
                                  minHeight: 36,
                                  maxWidth: 240,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: AppShadows.card,
                                ),
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
                if (load.isLoading) ...[
                  const SizedBox(height: 20),
                  const AppStateView.loading(
                    title: 'Memuat profil',
                    message: 'Mengambil detail kepegawaian Anda.',
                  ),
                ] else if (load.hasError) ...[
                  const SizedBox(height: 20),
                  AppStateView(
                    kind:
                        load.error is ApiException &&
                            (load.error as ApiException).statusCode == 403
                        ? AppViewStateKind.permission
                        : load.error is ApiException &&
                              (load.error as ApiException).code ==
                                  'NETWORK_ERROR'
                        ? AppViewStateKind.offline
                        : AppViewStateKind.error,
                    title:
                        load.error is ApiException &&
                            (load.error as ApiException).statusCode == 403
                        ? 'Detail kepegawaian terbatas'
                        : 'Detail profil gagal dimuat',
                    message: load.error is ApiException
                        ? (load.error as ApiException).message
                        : 'Respons profil tidak valid. Identitas sesi tetap tersedia.',
                    actionLabel: 'Coba lagi',
                    onAction: ref
                        .read(profileControllerProvider.notifier)
                        .refresh,
                  ),
                ],
                if (contacts.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const AppSectionLabel('Kontak'),
                  _InfoGroup(items: contacts),
                ],
                if (employment.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const AppSectionLabel('Kepegawaian'),
                  _InfoGroup(items: employment),
                ],
                const SizedBox(height: 20),
                const AppSectionLabel('Dokumen'),
                const AppStateView(
                  kind: AppViewStateKind.empty,
                  title: 'Dokumen belum tersedia',
                  message:
                      'Slip gaji, kontrak, dan sertifikat akan muncul setelah endpoint dokumen terintegrasi.',
                ),
                const SizedBox(height: 20),
                const AppSectionLabel('Pengaturan'),
                AppSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mode gelap',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              darkMode
                                  ? 'Tema gelap aktif'
                                  : 'Tema terang aktif',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: darkMode,
                        onChanged: (_) => onThemeToggle(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _InfoGroup(
                  items: [
                    (label: 'Bahasa', value: 'Indonesia'),
                    (
                      label: 'Versi aplikasi',
                      value: version.when(
                        data: (value) => value,
                        loading: () => 'Memuat...',
                        error: (_, _) => 'Tidak tersedia',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onSignOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Keluar'),
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

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.items});
  final List<({String label, String value})> items;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Column(
      children: items.indexed
          .map((entry) {
            return Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            entry.$2.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.$2.value,
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (entry.$1 < items.length - 1) const Divider(),
              ],
            );
          })
          .toList(growable: false),
    ),
  );
}
