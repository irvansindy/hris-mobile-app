import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';

Future<FirebaseMessaging> initializeDevelopmentFirebase() async {
  if (!kDebugMode || defaultTargetPlatform != TargetPlatform.android) {
    throw StateError('Firebase development hanya tersedia di Android debug.');
  }
  await Firebase.initializeApp();
  final messaging = FirebaseMessaging.instance;
  await messaging.setAutoInitEnabled(false);
  return messaging;
}

class FirebasePushAdapter implements PushAdapter {
  FirebasePushAdapter({
    required this.initialize,
    Stream<RemoteMessage>? foreground,
    Stream<RemoteMessage>? opened,
  }) : _foreground = foreground ?? FirebaseMessaging.onMessage,
       _opened = opened ?? FirebaseMessaging.onMessageOpenedApp {
    _events = StreamController<PushEvent>.broadcast(
      onListen: () => unawaited(_observeStartup()),
    );
  }

  final Future<FirebaseMessaging> Function() initialize;
  final Stream<RemoteMessage> _foreground;
  final Stream<RemoteMessage> _opened;
  late final StreamController<PushEvent> _events;
  final _tokens = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  FirebaseMessaging? _messaging;
  Future<FirebaseMessaging>? _initializing;
  bool _authorized = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _nativeOperations = Future.value();

  // Caller timeouts do not cancel native work; a new token must wait for cleanup.
  Future<T> _serializeNative<T>(Future<T> Function() operation) {
    final result = _nativeOperations.then((_) => operation());
    _nativeOperations = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _observeStartup() async {
    try {
      await _ready();
    } on Object catch (error) {
      _eventError(error);
    }
  }

  Future<FirebaseMessaging> _ready() {
    if (_disposed) return Future.error(StateError('Push sudah ditutup.'));
    if (_messaging case final messaging?) return Future.value(messaging);
    return _initializing ??= _start().whenComplete(() => _initializing = null);
  }

  Future<FirebaseMessaging> _start() async {
    final messaging = await initialize();
    await messaging.setAutoInitEnabled(false);
    if (_disposed) throw StateError('Push sudah ditutup.');
    _subscriptions.addAll([
      _foreground.listen(
        (message) => _emit(message, PushEventKind.foreground),
        onError: _eventError,
      ),
      _opened.listen(
        (message) => _emit(message, PushEventKind.opened),
        onError: _eventError,
      ),
      messaging.onTokenRefresh.listen(
        (token) {
          if (!_disposed && _authorized) _tokens.add(token);
        },
        onError: (Object error) {
          if (!_disposed) _tokens.addError(error);
        },
      ),
    ]);
    // Initial taps must be observed before auth restore, not replayed on account switch.
    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) _emit(initial, PushEventKind.initial);
    } on Object catch (error) {
      _eventError(error);
    }
    _messaging = messaging;
    return messaging;
  }

  void _eventError(Object error) {
    if (!_disposed && _events.hasListener) _events.addError(error);
  }

  void _emit(RemoteMessage message, PushEventKind kind) {
    if (_disposed) return;
    final id = message.data['notificationId'];
    _events.add(
      PushEvent(
        kind: kind,
        messageId: message.messageId,
        notificationId: id is String ? id : null,
      ),
    );
  }

  @override
  Stream<PushEvent> get events => _events.stream;
  @override
  Stream<String> get tokenChanges => _tokens.stream;

  @override
  Future<PushPermission> requestPermission() async {
    final generation = _generation;
    final messaging = await _ready();
    final settings = await messaging.requestPermission();
    if (_disposed || generation != _generation) return PushPermission.denied;
    _authorized =
        !_disposed &&
        settings.authorizationStatus == AuthorizationStatus.authorized;
    return _authorized ? PushPermission.authorized : PushPermission.denied;
  }

  @override
  Future<String?> getToken() async {
    if (_disposed || !_authorized) return null;
    final generation = _generation;
    return _serializeNative(() async {
      if (_disposed || !_authorized || generation != _generation) return null;
      final token = await (await _ready()).getToken();
      return _disposed || !_authorized || generation != _generation
          ? null
          : token;
    });
  }

  @override
  Future<void> deleteToken() async {
    _generation++;
    _authorized = false;
    await _serializeNative(() async {
      final messaging = await _ready();
      await messaging.setAutoInitEnabled(false);
      await messaging.deleteToken();
    });
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _authorized = false;
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    await Future.wait([_events.close(), _tokens.close()]);
  }
}
