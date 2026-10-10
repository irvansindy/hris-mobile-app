import 'dart:async';

import 'package:hrm_app/app/router/notification_route.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';

class PushNavigation {
  PushNavigation({
    required this.repositoryForSession,
    required this.navigate,
    required this.refreshInbox,
  });
  final NotificationRepository Function(FeatureSession) repositoryForSession;
  final void Function(String) navigate;
  final void Function() refreshInbox;
  final _seen = <String>{};
  FeatureSession? _session;
  PushEvent? _pending;
  bool _acceptAnonymous = true;
  bool _disposed = false;
  int _generation = 0;
  int _tap = 0;
  Timer? _anonymousBatch;

  Future<void> updateSession(FeatureSession? session) async {
    if (_disposed) return;
    final previous = _session;
    if (previous?.revision == session?.revision &&
        previous?.context?.userId == session?.context?.userId &&
        previous?.context?.activeCompanyId ==
            session?.context?.activeCompanyId &&
        previous?.context?.employeeId == session?.context?.employeeId) {
      _session = session;
      return;
    }
    _generation++;
    _anonymousBatch?.cancel();
    _anonymousBatch = null;
    _seen.clear();
    if (previous != null) {
      _pending = null;
      _acceptAnonymous = false;
    }
    _session = session;
    if (session == null || !session.isCurrent) return;
    final pending = _pending;
    _pending = null;
    if (pending != null) await handle(pending);
  }

  Future<void> handle(PushEvent event) async {
    if (_disposed) return;
    final session = _session;
    if (session == null) {
      if (_acceptAnonymous && event.kind != PushEventKind.foreground) {
        // Only bounded ID hints are retained until the first login/restore.
        _pending = PushEvent(
          kind: event.kind,
          notificationId: validPushHint(event.notificationId)
              ? event.notificationId
              : null,
          messageId: _validMessageId(event.messageId) ? event.messageId : null,
        );
      }
      return;
    }
    if (!session.isCurrent) return;
    if (event.kind == PushEventKind.foreground) {
      refreshInbox();
      return;
    }
    final keys = <String>[
      if (_validMessageId(event.messageId)) 'message:${event.messageId}',
      if (validPushHint(event.notificationId))
        'notification:${event.notificationId}',
    ];
    if (keys.isEmpty) {
      if (_anonymousBatch != null) return;
      _anonymousBatch = Timer(Duration.zero, () => _anonymousBatch = null);
    }
    if (keys.any(_seen.contains)) return;
    _seen.addAll(keys);
    while (_seen.length > 100) {
      _seen.remove(_seen.first);
    }
    final generation = _generation;
    final tap = ++_tap;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        tap == _tap &&
        session.isCurrent;
    String location;
    try {
      location = await resolvePushLocation(
        event,
        repositoryForSession(session),
        current,
      );
    } on Object {
      location = '/notifications';
    }
    if (current()) navigate(location);
  }

  void dispose() {
    _disposed = true;
    reset();
  }

  void reset() {
    _generation++;
    _anonymousBatch?.cancel();
    _anonymousBatch = null;
    _session = null;
    _pending = null;
    _acceptAnonymous = false;
    _seen.clear();
  }
}

bool _validMessageId(String? value) =>
    value != null && value.trim().isNotEmpty && value.length <= 200;
