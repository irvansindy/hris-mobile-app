import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleartext exceptions are restricted to debug builds', () {
    final androidMain = _read('android/app/src/main/AndroidManifest.xml');
    final androidDebug = _read('android/app/src/debug/AndroidManifest.xml');
    final androidProfile = _read('android/app/src/profile/AndroidManifest.xml');
    final iosMain = _read('ios/Runner/Info.plist');
    final iosDebug = _read('ios/Runner/Info-Debug.plist');
    final xcodeProject = _read('ios/Runner.xcodeproj/project.pbxproj');

    expect(androidMain, contains('android:usesCleartextTraffic="false"'));
    expect(androidDebug, contains('android:usesCleartextTraffic="true"'));
    expect(androidProfile, isNot(contains('usesCleartextTraffic="true"')));
    expect(iosMain, isNot(contains('AllowsInsecureHTTPLoads')));
    expect(iosMain, isNot(contains('NSAllowsArbitraryLoads')));
    expect(iosDebug, contains('NSTemporaryExceptionAllowsInsecureHTTPLoads'));
    expect(
      RegExp(
        r'97C147061CF9000F007C117D /\* Debug \*/ = \{[\s\S]*?'
        r'INFOPLIST_FILE = Runner/Info-Debug\.plist;',
      ).hasMatch(xcodeProject),
      isTrue,
    );
    expect(
      RegExp(
        r'97C147071CF9000F007C117D /\* Release \*/ = \{[\s\S]*?'
        r'INFOPLIST_FILE = Runner/Info\.plist;',
      ).hasMatch(xcodeProject),
      isTrue,
    );
    expect(
      RegExp(
        r'249021D4217E4FDB00AE95B9 /\* Profile \*/ = \{[\s\S]*?'
        r'INFOPLIST_FILE = Runner/Info\.plist;',
      ).hasMatch(xcodeProject),
      isTrue,
    );
  });

  test('.env is ignored, unbundled, and documents public keys only', () {
    final gitignore = _read('.gitignore').split('\n');
    final pubspec = _read('pubspec.yaml');
    final exampleLines = _read('.env.example')
        .split('\n')
        .where((line) => line.trim().isNotEmpty && !line.startsWith('#'));
    final keys = exampleLines.map((line) => line.split('=').first).toSet();

    expect(gitignore, contains('.env'));
    expect(pubspec, isNot(contains('- .env')));
    expect(pubspec, isNot(contains('flutter_dotenv:')));
    expect(pubspec, isNot(contains('pretty_dio_logger:')));
    expect(
      keys,
      equals({
        'APP_ENV',
        'BASE_URL',
        'CONNECT_TIMEOUT_MS',
        'RECEIVE_TIMEOUT_MS',
        'ENABLE_LOGGING',
        'PUSH_MODE',
      }),
    );
    expect(
      keys.where(
        (key) => RegExp(
          r'(SECRET|TOKEN|PASSWORD|COOKIE|CSRF|PRIVATE|API_KEY)',
        ).hasMatch(key),
      ),
      isEmpty,
    );
  });
}

String _read(String path) => File(path).readAsStringSync();
