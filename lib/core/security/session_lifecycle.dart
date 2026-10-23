import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/request_context.dart';

final sessionLifecycleProvider = ChangeNotifierProvider<SessionLifecycle>(
  (ref) => SessionLifecycle(),
);

class SessionLifecycle extends ChangeNotifier {
  int _revision = 0;
  Future<void> _pending = Future.value();

  int get revision => _revision;
  bool isCurrent(int revision) => revision == _revision;

  int advance() {
    _revision++;
    notifyListeners();
    return _revision;
  }

  // Serialize storage writes with clearing, including writes already in flight.
  Future<T?> protect<T>(int revision, Future<T> Function() action) {
    final result = _pending.then<T?>((_) async {
      if (!isCurrent(revision)) return null;
      return action();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  void dispose() {
    _revision++;
    super.dispose();
  }
}

final featureSessionProvider = Provider<FeatureSession>((ref) {
  final lifecycle = ref.watch(sessionLifecycleProvider);
  final contextState = ref.read(requestContextProvider.notifier);
  final context = ref.watch(requestContextProvider);
  final session = FeatureSession(
    context,
    lifecycle,
    () => _sameFeatureIdentity(contextState.state, context),
  );
  ref.onDispose(() {
    if (!_sameFeatureIdentity(contextState.state, context)) {
      session.dispose();
    }
  });
  return session;
});

bool _sameFeatureIdentity(RequestContext? current, RequestContext? previous) =>
    current?.userId == previous?.userId &&
    current?.employeeId == previous?.employeeId &&
    current?.activeCompanyId == previous?.activeCompanyId;

class FeatureSession {
  FeatureSession(this.context, this._lifecycle, this._sameContext)
    : revision = _lifecycle.revision;

  final RequestContext? context;
  final SessionLifecycle _lifecycle;
  final bool Function() _sameContext;
  final int revision;
  bool _active = true;

  bool get isCurrent =>
      _active && _lifecycle.isCurrent(revision) && _sameContext();

  // Cache providers watch featureSessionProvider and register cleanup on dispose.
  void dispose() => _active = false;
}
