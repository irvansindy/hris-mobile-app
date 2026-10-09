import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/security/sensitive_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hris_mobile/sensitive_screen');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('enables and disables platform screen protection', () async {
    const controller = SensitiveScreenController();

    await controller.enable();
    await controller.disable();

    expect(calls.map((call) => call.method), ['setSensitive', 'setSensitive']);
    expect(calls.map((call) => call.arguments), [true, false]);
  });
}
