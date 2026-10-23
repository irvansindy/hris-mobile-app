import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hrm_app/features/notifications/push/push_registration.dart';
import 'package:uuid/uuid.dart';

enum PushPermission { unknown, authorized, denied }

enum PushEventKind { foreground, opened, initial }

class PushEvent {
  const PushEvent({this.messageId, this.notificationId, required this.kind});
  final String? messageId;
  final String? notificationId;
  final PushEventKind kind;
}

abstract interface class PushAdapter {
  Future<PushPermission> requestPermission();
  Future<String?> getToken();
  Stream<String> get tokenChanges;
  Stream<PushEvent> get events;
  Future<void> deleteToken();
  Future<void> dispose();
}

class DisabledPushAdapter implements PushAdapter {
  @override
  Future<PushPermission> requestPermission() async => PushPermission.denied;
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<String> get tokenChanges => const Stream.empty();
  @override
  Stream<PushEvent> get events => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
  @override
  Future<void> dispose() async {}
}

class DummyPushAdapter implements PushAdapter {
  DummyPushAdapter() {
    _requireDebug();
  }

  final _tokens = StreamController<String>.broadcast();
  final _events = StreamController<PushEvent>.broadcast();
  PushPermission _permission = PushPermission.unknown;
  String? _token;
  Future<void>? _disposal;

  @override
  Stream<String> get tokenChanges => _tokens.stream;
  @override
  Stream<PushEvent> get events => _events.stream;

  @override
  Future<PushPermission> requestPermission() async {
    if (_disposal != null) return PushPermission.denied;
    if (_permission == PushPermission.unknown) {
      _permission = PushPermission.authorized;
    }
    return _permission;
  }

  void setPermission(PushPermission permission) {
    if (_disposal == null) _permission = permission;
  }

  @override
  Future<String?> getToken() async {
    if (_disposal != null || _permission != PushPermission.authorized) {
      return null;
    }
    return _token ??= _newToken();
  }

  void rotateToken() {
    if (_disposal != null || _permission != PushPermission.authorized) return;
    _token = _newToken();
    _tokens.add(_token!);
  }

  void emit(PushEvent event) {
    if (_disposal == null) _events.add(event);
  }

  String _newToken() => 'dummy-push-${const Uuid().v4()}';

  @override
  Future<void> deleteToken() async {
    _token = null;
  }

  @override
  Future<void> dispose() {
    _token = null;
    return _disposal ??= Future.wait([
      _tokens.close(),
      _events.close(),
    ]).then((_) {});
  }
}

class DisabledDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  @override
  Future<void> register(DeviceRegistration registration) async =>
      throw UnsupportedError('Push belum diaktifkan.');
  @override
  Future<void> unregister(
    String installationId, {
    required String idempotencyKey,
  }) async => throw UnsupportedError('Push belum diaktifkan.');
}

class DummyDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  DummyDeviceRegistrationRepository() {
    _requireDebug();
  }

  final _registrations = <String, DeviceRegistration>{};
  Map<String, DeviceRegistration> get registrations =>
      Map.unmodifiable(_registrations);
  bool failRegistration = false;
  bool failUnregistration = false;

  @override
  Future<void> register(DeviceRegistration registration) async {
    if (failRegistration) throw StateError('Simulasi registration gagal.');
    if (!registration.token.startsWith('dummy-push-')) {
      throw ArgumentError('Registry simulasi hanya menerima token dummy.');
    }
    _registrations[registration.installationId] = registration;
  }

  @override
  Future<void> unregister(
    String installationId, {
    required String idempotencyKey,
  }) async {
    if (failUnregistration) throw StateError('Simulasi unregister gagal.');
    _registrations.remove(installationId);
  }
}

void _requireDebug() {
  if (!kDebugMode) {
    throw StateError('Simulasi push hanya tersedia pada build debug.');
  }
}
