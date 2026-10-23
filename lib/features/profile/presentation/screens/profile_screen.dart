import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:hrm_app/features/profile/profile_providers.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/services/app_metadata.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    super.key,
    required this.onThemeToggle,
    required this.onSignOut,
    required this.isDarkMode,
    this.onOpenAccountSecurity,
    this.onOpenPayroll,
  });

  final VoidCallback onThemeToggle;
  final VoidCallback onSignOut;
  final bool isDarkMode;
  final VoidCallback? onOpenAccountSecurity;
  final VoidCallback? onOpenPayroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(profileControllerProvider);
    final faceIdBuilder = ref.watch(profileFaceIdBuilderProvider);
    final load = ref.watch(profileLoadStateProvider);
    final session = ref.watch(featureSessionProvider);
    final requestContext = ref.watch(requestContextProvider);
    final support = ref.watch(employeeSupportProvider(session));
    final version = ref.watch(appVersionProvider);
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    final identity = [
      employee.employeeNumber ?? employee.id,
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
          onRefresh: () async {
            await ref.read(profileControllerProvider.notifier).refresh();
            ref.invalidate(employeeSupportProvider(session));
            await ref.read(employeeSupportProvider(session).future);
          },
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
                  key: const ValueKey('profile-identity'),
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
                  KeyedSubtree(
                    key: const ValueKey('profile-contact'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppSectionLabel('Kontak'),
                        _InfoGroup(items: contacts),
                      ],
                    ),
                  ),
                ],
                if (employment.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  KeyedSubtree(
                    key: const ValueKey('profile-employment'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppSectionLabel('Kepegawaian'),
                        _InfoGroup(items: employment),
                      ],
                    ),
                  ),
                ],
                support.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (snapshot) {
                    final supervisor = snapshot.reportingLine.primarySupervisor;
                    if (supervisor == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _InfoGroup(
                        items: [
                          (
                            label: 'Atasan',
                            value: supervisor.position == null
                                ? supervisor.name
                                : '${supervisor.name} · ${supervisor.position}',
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: ValueKey('profile-documents'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppSectionLabel('Dokumen'),
                      support.when(
                        loading: () => const AppStateView.loading(
                          title: 'Memuat dokumen',
                          message: 'Mengambil metadata dokumen privat.',
                        ),
                        error: (error, _) => AppStateView(
                          kind: error is ApiException && error.statusCode == 403
                              ? AppViewStateKind.permission
                              : AppViewStateKind.error,
                          title: 'Dokumen gagal dimuat',
                          message: 'Metadata dokumen tidak dapat diambil.',
                          actionLabel: 'Coba lagi',
                          onAction: () =>
                              ref.invalidate(employeeSupportProvider(session)),
                        ),
                        data: (snapshot) {
                          if (!snapshot.canReadAttachments) {
                            return const AppStateView(
                              kind: AppViewStateKind.permission,
                              title: 'Dokumen terbatas',
                              message:
                                  'Akun ini tidak memiliki izin employee:read.',
                            );
                          }
                          if (snapshot.attachments.isEmpty) {
                            return const AppStateView(
                              kind: AppViewStateKind.empty,
                              title: 'Dokumen belum tersedia',
                              message:
                                  'Slip gaji, kontrak, dan sertifikat akan muncul setelah endpoint dokumen terintegrasi.',
                            );
                          }
                          return AppSurfaceCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Column(
                              children: snapshot.attachments.indexed
                                  .map((entry) {
                                    final item = entry.$2;
                                    return Column(
                                      children: [
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const AppIconTile(
                                            icon: Icons.description_outlined,
                                          ),
                                          title: Text(item.name),
                                          subtitle: Text(
                                            item.documentType ??
                                                item.mimeType ??
                                                'Dokumen privat',
                                          ),
                                        ),
                                        if (entry.$1 <
                                            snapshot.attachments.length - 1)
                                          const Divider(),
                                      ],
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (onOpenPayroll != null &&
                    requestContext?.hasPermission('payroll:read') == true) ...[
                  const SizedBox(height: 10),
                  AppSurfaceCard(
                    key: const ValueKey('profile-payslip'),
                    onTap: onOpenPayroll,
                    semanticLabel: 'Buka slip gaji',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: const Row(
                        children: [
                          AppIconTile(icon: Icons.receipt_long_outlined),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Slip gaji'),
                                SizedBox(height: 2),
                                Text('Buka dengan PIN pribadi'),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const AppSectionLabel(
                  'Pengaturan',
                  key: ValueKey('profile-settings'),
                ),
                AppSurfaceCard(
                  key: const ValueKey('profile-preferences'),
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
                AppSurfaceCard(
                  key: const ValueKey('profile-face-id'),
                  onTap: faceIdBuilder == null
                      ? null
                      : () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: faceIdBuilder)),
                  semanticLabel: faceIdBuilder == null
                      ? 'Face ID belum tersedia'
                      : 'Kelola Face ID',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.face_retouching_natural_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kelola Face ID',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                faceIdBuilder == null
                                    ? 'Belum tersedia pada konfigurasi ini'
                                    : 'Siap digunakan di perangkat ini',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          faceIdBuilder == null
                              ? Icons.lock_outline_rounded
                              : Icons.chevron_right_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                if (onOpenAccountSecurity != null) ...[
                  const SizedBox(height: 10),
                  AppSurfaceCard(
                    onTap: onOpenAccountSecurity,
                    semanticLabel: 'Buka keamanan akun',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.security_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Keamanan akun',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Atur MFA dan sesi perangkat',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ],
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
                  key: const ValueKey('profile-sign-out'),
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
