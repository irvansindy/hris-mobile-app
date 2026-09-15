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
    expect(workflow, contains('path: test/failures'));
    expect(workflow, isNot(contains('--update-goldens')));
  });

  test('CI pins Flutter and builds a guarded production artifact', () {
    expect(
      workflow,
      contains('FLUTTER_VERSION: 2553f89be1efa62eeb7b3aeea68fc9f80336ee54'),
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
}
