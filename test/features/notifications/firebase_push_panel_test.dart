import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/notifications/presentation/widgets/push_status_panel.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';
import 'package:hrm_app/features/notifications/push/push_coordinator.dart';
import 'package:hrm_app/features/notifications/push/push_providers.dart';

void main() {
  testWidgets(
    'Console testing exposes token only through explicit copy, not text',
    (tester) async {
      final lifecycle = SessionLifecycle();
      addTearDown(lifecycle.dispose);
      final session = FeatureSession(
        const RequestContext(
          userId: 'employee',
          employeeId: 'e1',
          activeCompanyId: 'company',
          companyScope: ['company'],
        ),
        lifecycle,
        () => true,
      );
      final adapter = DummyPushAdapter();
      addTearDown(adapter.dispose);
      await adapter.requestPermission();
      final token = await adapter.getToken();
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(
              productionBuild: false,
              values: const {'PUSH_MODE': 'firebase'},
            ),
          ),
          featureSessionProvider.overrideWithValue(session),
          pushAdapterProvider.overrideWithValue(adapter),
          pushStatusProvider.overrideWith((_) => PushStatus.consoleReady),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: PushStatusPanel())),
        ),
      );
      expect(find.textContaining('belum terdaftar di backend'), findsOneWidget);
      expect(find.text(token!), findsNothing);
      expect(copied, isNull);
      await tester.tap(find.text('Salin token untuk tes Console'));
      await tester.pump();
      expect(copied, token);
    },
  );
}
