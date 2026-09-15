import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';

void main() {
  group('redesign tokens', () {
    test('use the approved brand palette and spacing scale', () {
      expect(AppColors.primary, const Color(0xFF315B8C));
      expect(AppColors.primaryTint, const Color(0xFFE7EEF6));
      expect(AppColors.lightBg, const Color(0xFFF3F4F6));
      expect(AppColors.darkBg, const Color(0xFF0B1220));
      expect(AppSpacing.screenHorizontal, 20);
      expect(AppSpacing.scrollBottom, 130);
      expect(AppRadius.card, 22);
      expect(AppRadius.sheet, 30);
      expect(AppMotion.emphasized, const Duration(milliseconds: 340));
    });

    test('bundle Plus Jakarta Sans and its license', () {
      final font = File('assets/fonts/PlusJakartaSans-VariableFont_wght.ttf');
      final license = File('assets/fonts/OFL.txt');

      expect(font.existsSync(), isTrue);
      expect(font.lengthSync(), greaterThan(100000));
      expect(license.existsSync(), isTrue);
      expect(license.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
    });
  });

  group('AppTheme', () {
    test('light theme exposes redesign colors and typography', () {
      final theme = AppTheme.light;

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.scaffoldBackgroundColor, AppColors.lightBg);
      expect(
        theme.textTheme.displayLarge?.fontFamily,
        AppTypography.fontFamily,
      );
      expect(theme.textTheme.displayLarge?.fontSize, 30);
      expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w500);
      expect(theme.textTheme.bodyMedium?.fontSize, 12.5);
      expect(
        theme.elevatedButtonTheme.style?.minimumSize?.resolve({}),
        const Size(44, 52),
      );
      expect(theme.navigationBarTheme.height, 76);
    });

    test('dark theme uses the complete dark palette', () {
      final theme = AppTheme.dark;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.primaryLight);
      expect(theme.colorScheme.surface, AppColors.darkSurface);
      expect(theme.colorScheme.error, AppColors.darkDanger);
      expect(theme.scaffoldBackgroundColor, AppColors.darkBg);
      expect(theme.textTheme.bodySmall?.color, AppColors.darkTextSub);
    });

    test('text and control colors meet their contrast thresholds', () {
      final normalTextPairs = <(Color, Color)>[
        (AppColors.lightText, AppColors.lightBg),
        (AppColors.lightTextSub, AppColors.lightBg),
        (AppColors.lightMutedTextOnSurface, AppColors.lightSurface),
        (Colors.white, AppColors.primary),
        (AppColors.darkText, AppColors.darkBg),
        (AppColors.darkTextSub, AppColors.darkSurface),
        (AppColors.primaryLight, AppColors.darkSurface),
        (AppColors.success, AppColors.successBackground),
        (AppColors.warning, AppColors.warningBackground),
        (AppColors.danger, AppColors.dangerBackground),
        (AppColors.darkSuccess, AppColors.darkSuccessBackground),
        (AppColors.darkWarning, AppColors.darkWarningBackground),
        (AppColors.darkDanger, AppColors.darkDangerBackground),
      ];
      final controlPairs = <(Color, Color)>[
        (AppColors.lightControlBorder, AppColors.lightSurface),
        (AppColors.darkControlBorder, AppColors.darkSurface),
      ];

      for (final (foreground, background) in normalTextPairs) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background must meet WCAG AA',
        );
      }
      for (final (foreground, background) in controlPairs) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(3),
          reason: '$foreground on $background must meet non-text contrast',
        );
      }
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = _relativeLuminance(first);
  final secondLuminance = _relativeLuminance(second);
  final lighter = math.max(firstLuminance, secondLuminance);
  final darker = math.min(firstLuminance, secondLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  final value = color.toARGB32();
  final red = (value >> 16) & 0xFF;
  final green = (value >> 8) & 0xFF;
  final blue = value & 0xFF;
  return 0.2126 * _linearize(red) +
      0.7152 * _linearize(green) +
      0.0722 * _linearize(blue);
}

double _linearize(int channel) {
  final normalized = channel / 255;
  return normalized <= 0.03928
      ? normalized / 12.92
      : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
}
