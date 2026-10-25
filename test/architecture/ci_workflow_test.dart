import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final workflow = File('.github/workflows/mobile-ci.yml').readAsStringSync();

  test('workflow is valid YAML with quality, Android, and iOS jobs', () {
    final yaml = loadYaml(workflow) as YamlMap;
    final jobs = yaml['jobs'] as YamlMap;
    expect(jobs.keys, containsAll(['quality', 'android', 'ios']));
  });

  test('CI runs the required quality gates', () {
    expect(workflow, contains('permissions:\n  contents: read'));
    expect(workflow, contains('git diff --exit-code -- pubspec.lock'));
    expect(
      workflow,
      contains(
        'dart format --output=none --set-exit-if-changed lib test tool integration_test',
      ),
    );
    expect(workflow, contains('flutter analyze'));
    expect(workflow, contains('flutter test --coverage'));
    expect(workflow, contains('test/core/platform_backup_policy_test.dart'));
    expect(workflow, contains('path: test/failures'));
    expect(workflow, isNot(contains('--update-goldens')));
  });

  test('CI pins Flutter and builds a guarded production artifact', () {
    expect(
      workflow,
      contains('FLUTTER_VERSION: 19946f91c8d9de18a4674460d015229cc0b2534f'),
    );
    expect(workflow, contains('flutter build appbundle --release'));
    expect(
      workflow,
      contains('name: android-appbundle-debug-signed-validation'),
    );
    expect(workflow, contains('--dart-define=APP_ENV=production'));
    expect(
      workflow,
      contains('--dart-define=BASE_URL=https://ci.invalid/api/v1'),
    );
    expect(workflow, contains('--dart-define=ENABLE_LOGGING=false'));
    expect(
      workflow,
      contains('build/app/outputs/bundle/release/app-release.aab'),
    );
  });

  test('Android CI runs the credential-free device integration flow', () {
    final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
    final steps = (jobs['android'] as YamlMap)['steps'] as YamlList;
    final integration = steps.cast<YamlMap>().singleWhere(
      (step) => step['name'] == 'Run Android fixture integration tests',
    );
    expect(integration['uses'], 'reactivecircus/android-emulator-runner@v2');
    final settings = integration['with'] as YamlMap;
    expect(settings['api-level'], 35);
    expect(settings['arch'], 'x86_64');
    expect(
      settings['script'],
      contains('integration_test/redesign_flow_test.dart'),
    );
    expect(settings['script'], contains('-d emulator-5554'));
    expect(settings['script'], isNot(contains('.env')));
    expect(settings['script'], isNot(contains('hris-mobile-smoke.json')));
  });

  test('Android upload requires the post-build PDFium integrity gate', () {
    final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
    final steps = ((jobs['android'] as YamlMap)['steps'] as YamlList)
        .cast<YamlMap>()
        .toList();
    final guard = steps.indexWhere(
      (step) => step['name'] == 'Verify native PDFium integrity',
    );
    final build = steps.indexWhere(
      (step) => step['name'] == 'Build release App Bundle',
    );
    final upload = steps.indexWhere(
      (step) => step['name'] == 'Upload Android artifact',
    );
    expect(guard, greaterThan(build));
    expect(upload, greaterThan(guard));
    expect(
      steps[guard]['run'],
      'dart --packages=.dart_tool/package_config.json tool/verify_native_pdfium.dart',
    );
    expect(steps[guard]['continue-on-error'], isNot(true));
    expect(steps[guard]['if'], isNull);
    expect(steps[upload]['if'], isNull);
  });

  test(
    'iOS build validates production on macOS without distribution signing',
    () {
      final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
      final ios = jobs['ios'] as YamlMap;
      expect(ios['runs-on'], 'macos-latest');
      expect(ios['needs'], 'quality');
      final steps = ios['steps'] as YamlList;
      final build = steps.cast<YamlMap>().singleWhere(
        (step) => step['name'] == 'Build iOS without signing',
      );
      expect(
        build['run'],
        contains('flutter build ios --release --no-codesign'),
      );
      expect(build['run'], contains('--dart-define=APP_ENV=production'));
      expect(build['run'], contains('--dart-define=ENABLE_LOGGING=false'));
      expect(workflow, contains('path: build/ios/iphoneos/Runner.app'));
    },
  );

  test(
    'iOS simulator execution is a mandatory gate after the unsigned build',
    () {
      final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
      final steps = ((jobs['ios'] as YamlMap)['steps'] as YamlList)
          .cast<YamlMap>()
          .toList();
      final simulator = steps.where(
        (step) => step['name'] == 'Run iOS simulator tests',
      );
      expect(simulator, hasLength(1));
      final step = simulator.single;
      expect(step['if'], isNull);
      expect(step['continue-on-error'], isNot(true));
      expect(
        steps.indexOf(step),
        greaterThan(
          steps.indexWhere(
            (step) => step['name'] == 'Build iOS without signing',
          ),
        ),
      );
      final command = step['run'] as String;
      expect(command, contains('set -euo pipefail'));
      expect(command, contains('tool/select_ios_simulator.dart'));
      expect(command, contains('-only-testing:RunnerTests'));
      expect(command, contains('integration_test/redesign_flow_test.dart'));
      expect(command, contains('--dart-define=PUSH_MODE=disabled'));
      expect(command, isNot(contains('--dart-define-from-file')));
    },
  );

  test('iOS simulator diagnostics are uploaded even after test failure', () {
    final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
    final steps = ((jobs['ios'] as YamlMap)['steps'] as YamlList)
        .cast<YamlMap>()
        .toList();
    final uploads = steps.where(
      (step) => step['name'] == 'Upload iOS simulator diagnostics',
    );
    expect(uploads, hasLength(1));
    final upload = uploads.single;
    expect(upload['if'], 'always()');
    expect((upload['with'] as YamlMap)['path'], 'build/ios-qa');
    expect(
      steps.indexOf(upload),
      greaterThan(
        steps.indexWhere((step) => step['name'] == 'Run iOS simulator tests'),
      ),
    );
  });
}
