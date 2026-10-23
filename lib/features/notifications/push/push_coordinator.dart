import 'dart:async';

import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';
import 'package:hrm_app/features/notifications/push/push_registration.dart';
import 'package:uuid/uuid.dart';

enum PushStatus {
  disabled,
  denied,
  registering,
  simulated,
  consoleReady,
  failed,
}

class PushCoordinator {
  PushCoordinator({
    required this.mode,
    required this.adapter,
    required this.identity,
    required this.platform,
    required Duration timeout,
    required this.registryForSession,
    this.onStatus,
  }) : _timeout = timeout {
    if (timeout <= Duration.zero) {
      throw ArgumentError('Timeout must be positive.');
    }
  }

  final PushMode mode;
  final PushAdapter adapter;
  final InstallationIdentity identity;
  final String platform;
  final Duration _timeout;
  final DeviceRegistrationRepository Function(FeatureSession)
  registryForSession;
  final void Function(PushStatus)? onStatus;
  final _events = StreamController<PushEvent>.broadcast(sync: true);
  Future<void> _tail = Future.value();
  Future<void>? _disposal;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<PushEvent>? _eventSubscription;
  FeatureSession? _session;
  _Binding? _binding;
  DeviceRegistration? _command;
  String? _registeredToken;
  bool _tokenResetFailed = false;
  int _generation = 0;
  PushStatus _status = PushStatus.disabled;

  PushStatus get status => _status;
  Stream<PushEvent> get events => _events.stream;

  bool _current(int generation) =>
      _disposal == null &&
      generation == _generation &&
      (_session?.isCurrent ?? false);

  Future<void> bind(FeatureSession session) {
    if (_disposal != null) return Future.value();
    if (mode == PushMode.disabled ||
        session.context?.userId == null ||
        session.context?.activeCompanyId == null ||
        !session.isCurrent) {
      return unbind();
    }
    if (_sameSession(_session, session)) {
      _session = session;
      return _tail;
    }
    final generation = ++_generation;
    _session = session;
    _command = null;
    _registeredToken = null;
    _cancelSubscriptions();
    _setStatus(PushStatus.registering);
    // Capture the registry before context invalidation, never resolve it in cleanup.
    DeviceRegistrationRepository registry;
    try {
      registry = registryForSession(session);
    } on Object {
      _setStatus(PushStatus.failed);
      return _enqueue(_cleanup);
    }
    return _enqueue(() async {
      await _cleanup();
      if (_current(generation)) await _activate(generation, registry);
    });
  }

  Future<void> retry() {
    final generation = _generation;
    return _enqueue(() async {
      if (!_current(generation)) return;
      final binding = _binding;
      if (binding == null) {
        await _activate(generation, registryForSession(_session!));
      } else {
        final permission = await adapter.requestPermission().timeout(_timeout);
        if (!_current(generation)) return;
        if (permission != PushPermission.authorized) {
          _setStatus(PushStatus.denied);
          return;
        }
        await _reconcile(generation);
      }
    });
  }

  Future<void> unbind() {
    _generation++;
    _session = null;
    _command = null;
    _registeredToken = null;
    _cancelSubscriptions();
    _setStatus(PushStatus.disabled);
    return _enqueue(_cleanup);
  }

  Future<void> _activate(
    int generation,
    DeviceRegistrationRepository registry,
  ) async {
    if (_tokenResetFailed) {
      _tokenResetFailed = !await _bestEffort(adapter.deleteToken);
      if (!_current(generation)) return;
      if (_tokenResetFailed) {
        _setStatus(PushStatus.failed);
        return;
      }
    }
    final permission = await adapter.requestPermission().timeout(_timeout);
    if (!_current(generation)) return;
    if (permission != PushPermission.authorized) {
      _setStatus(PushStatus.denied);
      return;
    }
    final id = await identity.getOrCreate().timeout(_timeout);
    if (!_current(generation)) return;
    _binding = _Binding(registry, id);
    _tokenSubscription = adapter.tokenChanges.listen(
      (_) {
        if (_current(generation)) {
          unawaited(_enqueue(() => _reconcile(generation)));
        }
      },
      onError: (Object _) {
        if (_current(generation)) _setStatus(PushStatus.failed);
      },
    );
    _eventSubscription = adapter.events.listen(
      (event) {
        if (_current(generation)) _events.add(event);
      },
      onError: (Object _) {
        if (_current(generation)) _setStatus(PushStatus.failed);
      },
    );
    await _reconcile(generation);
  }

  Future<void> _reconcile(int generation) async {
    while (_current(generation)) {
      final binding = _binding;
      if (binding == null) return;
      final token = await adapter.getToken().timeout(_timeout);
      if (!_current(generation)) return;
      if (token == null || token.isEmpty) {
        _setStatus(PushStatus.failed);
        return;
      }
      if (_registeredToken == token) {
        _setStatus(
          mode == PushMode.firebase
              ? PushStatus.consoleReady
              : PushStatus.simulated,
        );
        return;
      }
      if (_command?.token != token) {
        _command = DeviceRegistration(
          installationId: binding.installationId,
          platform: platform,
          token: token,
          idempotencyKey: const Uuid().v4(),
        );
      }
      final command = _command!;
      _setStatus(PushStatus.registering);
      await binding.registry.register(command).timeout(_timeout);
      if (!_current(generation)) return;
      _registeredToken = token;
      // Read again after POST; rotations in flight coalesce to the latest token.
      final latest = await adapter.getToken().timeout(_timeout);
      if (!_current(generation)) return;
      if (latest == token) {
        _setStatus(
          mode == PushMode.firebase
              ? PushStatus.consoleReady
              : PushStatus.simulated,
        );
        return;
      }
    }
  }

  Future<void> _cleanup() async {
    final binding = _binding;
    _binding = null;
    if (binding != null) {
      await _bestEffort(
        () => binding.registry.unregister(
          binding.installationId,
          idempotencyKey: const Uuid().v4(),
        ),
      );
    }
    if (mode != PushMode.disabled) {
      _tokenResetFailed = !await _bestEffort(adapter.deleteToken);
    }
  }

  Future<bool> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation().timeout(_timeout);
      return true;
    } on Object {
      // Offline cleanup cannot guarantee removal on a future remote registry.
      return false;
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final generation = _generation;
    _tail = _tail.then((_) => operation()).catchError((Object _) {
      if (_current(generation)) _setStatus(PushStatus.failed);
    });
    return _tail;
  }

  void _cancelSubscriptions() {
    final tokens = _tokenSubscription;
    final events = _eventSubscription;
    _tokenSubscription = null;
    _eventSubscription = null;
    if (tokens != null) unawaited(_bestEffort(tokens.cancel));
    if (events != null) unawaited(_bestEffort(events.cancel));
  }

  void _setStatus(PushStatus status) {
    if (_status == status) return;
    _status = status;
    onStatus?.call(status);
  }

  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    final cleanup = unbind();
    return _disposal = cleanup.then((_) async {
      await _bestEffort(adapter.dispose);
      await _events.close();
    });
  }
}

bool _sameSession(FeatureSession? a, FeatureSession b) =>
    a != null &&
    a.revision == b.revision &&
    a.context?.userId == b.context?.userId &&
    a.context?.employeeId == b.context?.employeeId &&
    a.context?.activeCompanyId == b.context?.activeCompanyId;

class _Binding {
  const _Binding(this.registry, this.installationId);
  final DeviceRegistrationRepository registry;
  final String installationId;
}
