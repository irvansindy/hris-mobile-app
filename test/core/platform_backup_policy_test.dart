import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const domains = {
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref',
  };

  test('Android disables cloud backup for credential and biometric data', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final app = RegExp(r'<application\b([^>]+)>').firstMatch(manifest)![1]!;
    final attributes = _attributes(app);

    expect(attributes['android:allowBackup'], 'false');
    expect(attributes['android:fullBackupContent'], 'false');
    expect(
      attributes['android:dataExtractionRules'],
      '@xml/data_extraction_rules',
    );
  });

  for (final mode in ['cloud-backup', 'device-transfer']) {
    test('Android excludes all data domains from $mode', () {
      final rules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );
      expect(rules.existsSync(), isTrue, reason: 'Android 12+ privacy policy');
      final body = RegExp(
        '<$mode(?:\\s[^>]*)?>([\\s\\S]*?)</$mode>',
      ).firstMatch(rules.readAsStringSync())![1]!;
      expect(RegExp(r'<include\b').hasMatch(body), isFalse);
      final excludes = RegExp(
        r'<exclude\b([^>]+?)/>',
      ).allMatches(body).map((match) => _attributes(match[1]!));
      expect(excludes.map((entry) => entry['domain']).toSet(), domains);
      expect(excludes.every((entry) => entry['path'] == '.'), isTrue);
    });
  }
}

Map<String, String> _attributes(String value) => {
  for (final match in RegExp(r'([\w:]+)="([^"]*)"').allMatches(value))
    match[1]!: match[2]!,
};
