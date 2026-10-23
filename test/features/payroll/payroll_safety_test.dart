import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payroll feature does not persist or log sensitive values', () {
    final source = _featureSource();

    expect(source, isNot(contains('SharedPreferences')));
    expect(source, isNot(contains('FlutterSecureStorage')));
    expect(source, isNot(contains('Hive.')));
    expect(source, isNot(contains('debugPrint(')));
    expect(
      source,
      isNot(matches(RegExp(r'(^|[^A-Za-z])print\(', multiLine: true))),
    );
  });

  test('employee flow never uses the admin payroll unlock header', () {
    final source = _featureSource();

    expect(source, isNot(contains('X-Payroll-Unlock-Token')));
    expect(source, contains('X-Payslip-Unlock'));
  });

  test('PDF viewer uses memory bytes without file or export APIs', () {
    final source = File(
      'lib/features/payroll/presentation/screens/payslip_pdf_screen.dart',
    ).readAsStringSync();

    expect(source, contains('PdfViewer.data'));
    expect(source, isNot(contains('PdfViewer.file')));
    expect(source, isNot(contains('writeAsBytes')));
    expect(source, isNot(contains('share')));
  });

  test('platform privacy implementations remain wired', () {
    final android = File(
      'android/app/src/main/kotlin/com/example/hrm_app/MainActivity.kt',
    ).readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(android, contains('FLAG_SECURE'));
    expect(ios, contains('UIScreen.main.isCaptured'));
    expect(ios, contains('Konten sensitif dilindungi'));
  });
}

String _featureSource() => Directory('lib/features/payroll')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .map((file) => file.readAsStringSync())
    .join('\n');
