import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/config/demo_mode.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';
import 'package:hrm_app/features/notifications/push/push_registration.dart';

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
  };
  ref.onDispose(() => unawaited(adapter.dispose()));
  return adapter;
});

final deviceRegistrationRepositoryProvider =
    Provider<DeviceRegistrationRepository>(
      (ref) => switch (ref.watch(pushModeProvider)) {
        PushMode.disabled => DisabledDeviceRegistrationRepository(),
        PushMode.dummy => DummyDeviceRegistrationRepository(),
      },
    );
