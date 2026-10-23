import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/features/notifications/push/firebase_push_adapter.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android development obtains and deletes a real FCM token without HRIS registration',
    (tester) async {
      final config = AppConfig.fromEnvironment();
      expect(config.pushMode, PushMode.firebase);
      expect(config.environment, AppEnvironment.development);
      expect(const bool.fromEnvironment('DEMO_MODE'), isFalse);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('FCM development smoke'))),
      );
      final adapter = FirebasePushAdapter(
        initialize: initializeDevelopmentFirebase,
      );
      addTearDown(adapter.dispose);
      expect(
        await adapter.requestPermission().timeout(const Duration(seconds: 30)),
        PushPermission.authorized,
      );
      final token = await adapter.getToken().timeout(
        const Duration(seconds: 60),
      );
      // Assert length only: never emit the FCM registration token in test output.
      expect(token?.length ?? 0, greaterThan(20));
      await adapter.deleteToken().timeout(const Duration(seconds: 30));
      expect(await adapter.getToken(), isNull);
    },
  );
}
