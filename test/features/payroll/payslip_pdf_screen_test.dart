import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/payroll/presentation/screens/payslip_pdf_screen.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hris_mobile/sensitive_screen');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('rejects bytes without a PDF signature', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PayslipPdfScreen(
          bytes: Uint8List.fromList('not-a-pdf'.codeUnits),
          sourceName: 'slip.pdf',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PDF slip gaji tidak valid'), findsOneWidget);
    expect(find.byType(PdfViewer), findsNothing);
  });

  testWidgets('renders a PDF from memory without export controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PayslipPdfScreen(
          bytes: _minimalPdf(),
          sourceName: 'slip-september.pdf',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PdfViewer), findsOneWidget);
    expect(find.text('Bagikan'), findsNothing);
    expect(find.text('Unduh'), findsNothing);
    expect(
      calls.any(
        (call) => call.method == 'setSensitive' && call.arguments == true,
      ),
      isTrue,
    );
  });

  testWidgets('covers content on inactive and disables protection on dispose', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PayslipPdfScreen(
          bytes: _minimalPdf(),
          sourceName: 'slip-september.pdf',
        ),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Konten slip gaji disembunyikan'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    expect(calls.last.method, 'setSensitive');
    expect(calls.last.arguments, false);
  });
}

Uint8List _minimalPdf() => Uint8List.fromList(
  '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n%%EOF'.codeUnits,
);
