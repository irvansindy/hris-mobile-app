import 'package:flutter/material.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';

class SessionSplashScreen extends StatelessWidget {
  const SessionSplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primary,
    body: Semantics(
      container: true,
      liveRegion: true,
      label: 'Memulihkan sesi karyawan',
      child: Stack(
        children: [
          Positioned(
            top: -130,
            right: -110,
            child: _Circle(size: 320, opacity: 0.07),
          ),
          Positioned(
            bottom: -150,
            left: -120,
            child: _Circle(size: 340, opacity: 0.05),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4D000000),
                          offset: Offset(0, 18),
                          blurRadius: 30,
                          spreadRadius: -14,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: AppColors.primary,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'HRIS Mobile',
                    style: Theme.of(
                      context,
                    ).textTheme.displayMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Menyiapkan akses layanan karyawan',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 120,
                      child: AppLoadingIndicator(
                        linear: true,
                        semanticLabel: 'Memulihkan sesi',
                        color: Colors.white,
                        backgroundColor: Color(0x38FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Memulihkan sesi...',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}
