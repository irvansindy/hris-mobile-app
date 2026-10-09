import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core never imports a feature', () {
    final violations = _dartFiles('lib/core')
        .where(
          (file) =>
              file.readAsStringSync().contains('package:hrm_app/features/'),
        )
        .map((file) => file.path)
        .toList();

    expect(violations, isEmpty, reason: 'Core must be feature-independent');
  });

  test('domain layers stay framework and infrastructure independent', () {
    const forbidden = [
      'package:flutter/',
      'package:flutter_riverpod/',
      'package:dio/',
      '/data/',
      '/presentation/',
    ];
    final violations = <String>[];
    for (final file in _dartFiles('lib/features')) {
      if (!file.path.contains('/domain/')) continue;
      final source = file.readAsStringSync();
      if (forbidden.any(source.contains)) violations.add(file.path);
    }

    expect(violations, isEmpty, reason: 'Domain must contain pure Dart rules');
  });

  test('presentation never imports a data layer', () {
    final violations = <String>[];
    for (final file in _dartFiles('lib/features')) {
      if (!file.path.contains('/presentation/')) continue;
      if (file.readAsStringSync().contains('/data/')) violations.add(file.path);
    }

    expect(
      violations,
      isEmpty,
      reason: 'Presentation must depend on domain contracts/providers only',
    );
  });

  test('feature presentation never imports demo implementations', () {
    final violations = <String>[];
    for (final file in _dartFiles('lib/features')) {
      if (!file.path.contains('/presentation/')) continue;
      if (file.readAsStringSync().contains('package:hrm_app/demo/')) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Presentation must receive domain data, not demo widgets',
    );
  });

  test('attendance presentation does not select a demo layout', () {
    final violations = <String>[];
    for (final file in _dartFiles('lib/features/attendance/presentation')) {
      final source = file.readAsStringSync();
      if (source.contains('demoModeProvider') ||
          source.contains('demoAttendanceSummaryBuilderProvider')) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Attendance layout must be driven by domain data and capability',
    );
  });

  test('self-service presentation does not select a demo layout', () {
    const forbidden = [
      'demoModeProvider',
      'demoRequestsBuilderProvider',
      'package:hrm_app/demo/',
    ];
    final violations = <String>[];
    for (final file in _dartFiles('lib/features/self_service/presentation')) {
      final source = file.readAsStringSync();
      if (forbidden.any(source.contains)) violations.add(file.path);
    }

    expect(
      violations,
      isEmpty,
      reason: 'Pengajuan layout must be driven by repository data only',
    );
  });

  test('features do not reach into another feature', () {
    final violations = <String>[];
    final featureImport = RegExp(r'package:hrm_app/features/([^/]+)/');
    for (final file in _dartFiles('lib/features')) {
      final relative = file.path.split('lib/features/').last;
      final owner = relative.split('/').first;
      for (final match in featureImport.allMatches(file.readAsStringSync())) {
        if (match.group(1) != owner) violations.add(file.path);
      }
    }

    expect(violations.toSet(), isEmpty, reason: 'Features must stay isolated');
  });

  test('domain core imports are explicitly allowlisted', () {
    const allowed = {
      'package:hrm_app/core/errors/result.dart',
      'package:hrm_app/core/errors/failure.dart',
      'package:hrm_app/core/network/request_context.dart',
      'package:hrm_app/core/services/location_gateway.dart',
      'package:hrm_app/core/services/selfie_gateway.dart',
    };
    final coreImport = RegExp(r"import '([^']*package:hrm_app/core/[^']*)';");
    final violations = <String>[];
    for (final file in _dartFiles('lib/features')) {
      if (!file.path.contains('/domain/')) continue;
      for (final match in coreImport.allMatches(file.readAsStringSync())) {
        if (!allowed.contains(match.group(1))) violations.add(file.path);
      }
    }

    expect(
      violations.toSet(),
      isEmpty,
      reason: 'Review shared domain contracts',
    );
  });
}

Iterable<File> _dartFiles(String path) => Directory(path)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));
