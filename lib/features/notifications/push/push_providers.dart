import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/config/demo_mode.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';
import 'package:hrm_app/features/notifications/push/firebase_push_adapter.dart';
import 'package:hrm_app/features/notifications/push/push_registration.dart';
import 'package:hrm_app/features/notifications/push/push_coordinator.dart';

final pushModeProvider = Provider<PushMode>((ref) {
  final mode = ref.watch(demoModeProvider)
      ? PushMode.dummy
      : ref.watch(appConfigProvider).pushMode;
  if (!kDebugMode && mode == PushMode.dummy) {
    throw StateError('Simulasi push hanya tersedia pada build debug.');
  }
  return mode;
});

final pushAdapterProvider = Provider<PushAdapter>((ref) {
  final PushAdapter adapter = switch (ref.watch(pushModeProvider)) {
    PushMode.disabled => DisabledPushAdapter(),
    PushMode.dummy => DummyPushAdapter(),
    PushMode.firebase => FirebasePushAdapter(
      initialize: initializeDevelopmentFirebase,
    ),
  };
  ref.onDispose(() => unawaited(adapter.dispose()));
  return adapter;
});

final deviceRegistrationRepositoryProvider =
    Provider<DeviceRegistrationRepository>(
      (ref) => switch (ref.watch(pushModeProvider)) {
        PushMode.disabled => DisabledDeviceRegistrationRepository(),
        PushMode.dummy => DummyDeviceRegistrationRepository(),
        PushMode.firebase => ConsoleDeviceRegistrationRepository(),
      },
    );

final pushStatusProvider = StateProvider<PushStatus>(
  (ref) => PushStatus.disabled,
);

final pushCoordinatorProvider = Provider<PushCoordinator>((ref) {
  final config = ref.watch(appConfigProvider);
  final registry = ref.watch(deviceRegistrationRepositoryProvider);
  final status = ref.read(pushStatusProvider.notifier);
  var alive = true;
  final coordinator = PushCoordinator(
    mode: ref.watch(pushModeProvider),
    adapter: ref.watch(pushAdapterProvider),
    identity: InstallationIdentity(
      ref.watch(sharedPreferencesProvider),
      ref.watch(demoModeProvider)
          ? 'demo'
          : '${config.environment.name}:${Uri.parse(config.baseUrl).origin}',
    ),
    platform: defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID',
    timeout: config.receiveTimeout,
    registryForSession: (_) => registry,
    onStatus: (value) {
      if (alive) status.state = value;
    },
  );
  ref.onDispose(() {
    alive = false;
    unawaited(coordinator.dispose());
  });
  return coordinator;
});
