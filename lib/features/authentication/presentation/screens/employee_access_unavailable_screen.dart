import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';

class EmployeeAccessUnavailableScreen extends StatelessWidget {
  const EmployeeAccessUnavailableScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AppSurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIconTile(
                      icon: Icons.badge_outlined,
                      size: 64,
                      iconSize: 30,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Akses karyawan belum tersedia',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Akun berhasil masuk, tetapi belum terhubung ke employee dan company aktif. Hubungi administrator HR untuk memperbaiki penautan akun.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Keluar dari akun'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
