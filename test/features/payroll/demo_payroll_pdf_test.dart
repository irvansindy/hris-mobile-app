import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/demo/demo_payroll_repository.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  test('demo PDF opens and renders one page', () async {
    final nativeLibrary = File('build/native_assets/linux/libpdfium.so');
    if (Platform.isLinux && nativeLibrary.existsSync()) {
      Pdfrx.pdfiumModulePath = nativeLibrary.absolute.path;
    }
    await pdfrxInitialize();
    final repository = DemoPayrollRepository();
    await repository.setPin(currentPassword: 'demo', pin: '135791');
    final grant = await repository.unlock('135791');
    final pdf = await repository.getPdf(id: 'demo', unlockToken: grant.token);
    final document = await PdfDocument.openData(
      pdf.bytes,
      useProgressiveLoading: false,
    );
    addTearDown(document.dispose);
    expect(document.pages, hasLength(1));
    final image = await document.pages.first.render(width: 100, height: 140);
    expect(image, isNotNull);
    image?.dispose();
  });
}
