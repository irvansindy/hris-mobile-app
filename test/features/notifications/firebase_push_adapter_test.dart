import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/features/notifications/push/firebase_push_adapter.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';

void main() {
  test('late permission cannot reactivate push after logout', () async {
    final sdk = _Messaging();
    final adapter = FirebasePushAdapter(initialize: () async => sdk);
    addTearDown(adapter.dispose);
    await adapter.requestPermission();
    sdk.permissionGate = Completer<void>();
    final permission = adapter.requestPermission();
    await Future<void>.delayed(Duration.zero);
    await adapter.deleteToken();
    sdk.permissionGate!.complete();
    expect(await permission, PushPermission.denied);
    expect(await adapter.getToken(), isNull);
    expect(sdk.tokenReads, 0);
  });

  test(
    'new token waits for actual cleanup even after caller timeout',
    () async {
      final sdk = _Messaging();
      final adapter = FirebasePushAdapter(initialize: () async => sdk);
      addTearDown(adapter.dispose);
      await adapter.requestPermission();
      sdk.cleanupGate = Completer<void>();
      final cleanup = adapter.deleteToken();
      await expectLater(
        cleanup.timeout(const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
      await adapter.requestPermission();
      final token = adapter.getToken();
      await Future<void>.delayed(Duration.zero);
      expect(sdk.tokenReads, 0);
      sdk.cleanupGate!.complete();
      await cleanup;
      expect(await token, 'test-fcm-token');
      expect(sdk.calls, ['delete', 'get']);
    },
  );

  test(
    'denied permission never obtains a token; logout stops token access',
    () async {
      final sdk = _Messaging();
      final adapter = FirebasePushAdapter(initialize: () async => sdk);
      addTearDown(adapter.dispose);
      expect(await adapter.getToken(), isNull);
      sdk.authorization = AuthorizationStatus.denied;
      expect(await adapter.requestPermission(), PushPermission.denied);
      expect(await adapter.getToken(), isNull);
      expect(sdk.tokenReads, 0);
      sdk.authorization = AuthorizationStatus.authorized;
      expect(await adapter.requestPermission(), PushPermission.authorized);
      expect(await adapter.getToken(), 'test-fcm-token');
      await adapter.deleteToken();
      expect(sdk.deleted, 1);
      expect(await adapter.getToken(), isNull);
      expect(sdk.autoInit, everyElement(isFalse));
    },
  );

  test(
    'initial and live messages retain only ID hints, dispose stops delivery',
    () async {
      final sdk = _Messaging()
        ..initial = const RemoteMessage(
          messageId: 'initial-1',
          data: {
            'notificationId': 'n1',
            'route': '/payroll',
            'body': 'private',
          },
        );
      final foreground = StreamController<RemoteMessage>.broadcast();
      final opened = StreamController<RemoteMessage>.broadcast();
      addTearDown(foreground.close);
      addTearDown(opened.close);
      final adapter = FirebasePushAdapter(
        initialize: () async => sdk,
        foreground: foreground.stream,
        opened: opened.stream,
      );
      final events = <PushEvent>[];
      final subscription = adapter.events.listen(events.add);
      addTearDown(subscription.cancel);
      await adapter.requestPermission();
      await Future<void>.delayed(Duration.zero);
      expect(events.single.kind, PushEventKind.initial);
      expect(events.single.notificationId, 'n1');
      foreground.add(
        const RemoteMessage(messageId: 'fg', data: {'notificationId': 99}),
      );
      opened.add(
        const RemoteMessage(messageId: 'tap', data: {'notificationId': 'n2'}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events.map((event) => event.kind), [
        PushEventKind.initial,
        PushEventKind.foreground,
        PushEventKind.opened,
      ]);
      expect(events[1].notificationId, isNull);
      expect(events[2].notificationId, 'n2');
      await adapter.dispose();
      foreground.add(const RemoteMessage(messageId: 'late'));
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(3));
    },
  );

  test(
    'initialization failure is recoverable without exposing plugin error',
    () async {
      final sdk = _Messaging();
      var attempts = 0;
      final adapter = FirebasePushAdapter(
        initialize: () async {
          if (++attempts == 1) throw StateError('plugin unavailable');
          return sdk;
        },
      );
      addTearDown(adapter.dispose);
      await expectLater(adapter.requestPermission(), throwsStateError);
      expect(await adapter.requestPermission(), PushPermission.authorized);
      expect(await adapter.getToken(), 'test-fcm-token');
    },
  );
}

class _Messaging implements FirebaseMessaging {
  AuthorizationStatus authorization = AuthorizationStatus.authorized;
  RemoteMessage? initial;
  final autoInit = <bool>[];
  int tokenReads = 0;
  int deleted = 0;
  Completer<void>? permissionGate;
  Completer<void>? cleanupGate;
  final calls = <String>[];
  @override
  Future<void> setAutoInitEnabled(bool enabled) async {
    autoInit.add(enabled);
    await cleanupGate?.future;
  }

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    tokenReads++;
    calls.add('get');
    return 'test-fcm-token';
  }

  @override
  Future<void> deleteToken() async {
    deleted++;
    calls.add('delete');
  }

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<RemoteMessage?> getInitialMessage() async => initial;
  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    await permissionGate?.future;
    return NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.disabled,
      authorizationStatus: authorization,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.disabled,
      criticalAlert: AppleNotificationSetting.disabled,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      sound: AppleNotificationSetting.enabled,
      timeSensitive: AppleNotificationSetting.disabled,
      providesAppNotificationSettings: AppleNotificationSetting.disabled,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
