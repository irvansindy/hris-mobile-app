import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/demo/demo_overrides.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';
import 'package:hrm_app/features/notifications/push/push_providers.dart';
import 'package:hrm_app/features/notifications/push/push_registration.dart';
import 'package:shared_preferences/shared_preferences.dart';

const registration = DeviceRegistration(
  installationId: '0123456789abcdef0123456789abcdef',
  platform: 'ANDROID',
  token: 'dummy-push-example-token',
  idempotencyKey: '12345678-1234-1234-1234-123456789abc',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'disabled has no token or events and cannot request OS permission',
    () async {
      final adapter = DisabledPushAdapter();
      expect(await adapter.requestPermission(), PushPermission.denied);
      expect(await adapter.getToken(), isNull);
      expect(await adapter.tokenChanges.toList(), isEmpty);
      expect(await adapter.events.toList(), isEmpty);
      await adapter.deleteToken();
      await adapter.dispose();
    },
  );

  test(
    'dummy denial remains denied until simulator changes permission',
    () async {
      final adapter = DummyPushAdapter();
      addTearDown(adapter.dispose);
      adapter.setPermission(PushPermission.denied);
      for (var attempt = 0; attempt < 3; attempt++) {
        expect(await adapter.requestPermission(), PushPermission.denied);
        expect(await adapter.getToken(), isNull);
      }
      adapter.setPermission(PushPermission.authorized);
      expect(await adapter.requestPermission(), PushPermission.authorized);
      expect(await adapter.getToken(), startsWith('dummy-push-'));
    },
  );

  test(
    'dummy token is stable until rotation and delete creates a fresh token',
    () async {
      final adapter = DummyPushAdapter();
      addTearDown(adapter.dispose);
      expect(await adapter.getToken(), isNull);
      expect(await adapter.requestPermission(), PushPermission.authorized);
      final initial = await adapter.getToken();
      expect(await adapter.getToken(), initial);
      final changed = adapter.tokenChanges.first;
      adapter.rotateToken();
      final rotated = await changed;
      expect(rotated, isNot(initial));
      expect(await adapter.getToken(), rotated);
      await adapter.deleteToken();
      expect(await adapter.getToken(), isNot(rotated));
      expect(await adapter.getToken(), startsWith('dummy-push-'));
    },
  );

  test(
    'dummy emits foreground/opened/initial hints and closes on dispose',
    () async {
      final adapter = DummyPushAdapter();
      final events = <PushEvent>[];
      final done = Completer<void>();
      final tokenDone = Completer<void>();
      adapter.events.listen(events.add, onDone: done.complete);
      adapter.tokenChanges.listen((_) {}, onDone: tokenDone.complete);
      for (final kind in PushEventKind.values) {
        adapter.emit(
          PushEvent(messageId: 'message', notificationId: 'item', kind: kind),
        );
      }
      await adapter.dispose();
      await Future.wait([done.future, tokenDone.future]);
      expect(events.map((e) => e.kind), [
        PushEventKind.foreground,
        PushEventKind.opened,
        PushEventKind.initial,
      ]);
      expect(
        events.every(
          (e) => e.notificationId == 'item' && e.messageId == 'message',
        ),
        isTrue,
      );
      await adapter.dispose();
      adapter.emit(const PushEvent(kind: PushEventKind.opened));
      adapter.rotateToken();
      adapter.setPermission(PushPermission.authorized);
      expect(await adapter.getToken(), isNull);
      expect(await adapter.requestPermission(), PushPermission.denied);
    },
  );

  test(
    'dummy registry stays in memory and failures preserve previous binding',
    () async {
      final registry = DummyDeviceRegistrationRepository();
      await registry.register(registration);
      expect(
        registry.registrations[registration.installationId]?.token,
        'dummy-push-example-token',
      );
      registry.failRegistration = true;
      await expectLater(
        registry.register(
          const DeviceRegistration(
            installationId: 'another-installation',
            platform: 'IOS',
            token: 'dummy-push-another-token',
            idempotencyKey: 'another-operation-key',
          ),
        ),
        throwsStateError,
      );
      expect(registry.registrations.length, 1);
      registry.failUnregistration = true;
      await expectLater(
        registry.unregister(
          registration.installationId,
          idempotencyKey: registration.idempotencyKey,
        ),
        throwsStateError,
      );
      expect(registry.registrations.length, 1);
      registry.failUnregistration = false;
      await registry.unregister(
        registration.installationId,
        idempotencyKey: registration.idempotencyKey,
      );
      expect(registry.registrations, isEmpty);
    },
  );

  test(
    'providers use disabled by default and dummy registry never reads Dio/Firebase',
    () async {
      var firebaseCalls = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final channel in [
        'plugins.flutter.io/firebase_core',
        'plugins.flutter.io/firebase_messaging',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async {
          firebaseCalls++;
          throw StateError('Firebase must stay disabled');
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(MethodChannel(channel), null),
        );
      }
      for (final mode in ['disabled', 'dummy']) {
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.fromEnvironment(
                productionBuild: false,
                values: {'PUSH_MODE': mode},
              ),
            ),
            dioProvider.overrideWith(
              (_) => throw StateError('No network for dummy push'),
            ),
            featureDioProvider.overrideWith(
              (_) => throw StateError('No network for dummy push'),
            ),
          ],
        );
        final adapter = container.read(pushAdapterProvider);
        expect(
          adapter,
          mode == 'dummy'
              ? isA<DummyPushAdapter>()
              : isA<DisabledPushAdapter>(),
        );
        await adapter.requestPermission();
        await adapter.getToken();
        final registry = container.read(deviceRegistrationRepositoryProvider);
        if (mode == 'dummy') {
          await registry.register(registration);
          await registry.unregister(
            registration.installationId,
            idempotencyKey: registration.idempotencyKey,
          );
        } else {
          await expectLater(
            registry.register(registration),
            throwsUnsupportedError,
          );
          await expectLater(
            registry.unregister(
              registration.installationId,
              idempotencyKey: registration.idempotencyKey,
            ),
            throwsUnsupportedError,
          );
        }
        await adapter.deleteToken();
        container.dispose();
        await adapter.dispose();
      }
      expect(firebaseCalls, 0);
    },
  );

  test(
    'actual demo overrides select dummy even with push disabled in config',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = DemoStore(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(productionBuild: false),
          ),
          ...demoOverrides(store),
        ],
      );
      final adapter = container.read(pushAdapterProvider);
      expect(adapter, isA<DummyPushAdapter>());
      final registry = container.read(deviceRegistrationRepositoryProvider);
      expect(registry, isA<DummyDeviceRegistrationRepository>());
      await adapter.requestPermission();
      await registry.register(registration);
      expect(
        (registry as DummyDeviceRegistrationRepository).registrations.length,
        1,
      );
      container.dispose();
      await adapter.dispose();
      expect(await adapter.getToken(), isNull);
    },
  );
}
