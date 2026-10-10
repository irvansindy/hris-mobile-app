import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/app/router/app_router.dart';
import 'package:hrm_app/app/router/push_navigation.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/notifications/push/push_providers.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';

final pushNavigateProvider = Provider<void Function(String)>(
  (ref) =>
      (location) => ref.read(appRouterProvider).go(location),
);

final pushLifecycleProvider = Provider<void>((ref) {
  if (ref.watch(pushModeProvider) == PushMode.disabled) return;
  final coordinator = ref.watch(pushCoordinatorProvider);
  final adapter = ref.watch(pushAdapterProvider);
  final navigate = ref.watch(pushNavigateProvider);
  var alive = true;
  final navigation = PushNavigation(
    repositoryForSession: (_) => ref.read(notificationRepositoryProvider),
    navigate: (location) {
      if (alive) navigate(location);
    },
    refreshInbox: () {
      if (!alive) return;
      if (ref.exists(notificationUnreadCountProvider)) {
        ref.invalidate(notificationUnreadCountProvider);
      }
      if (ref.exists(notificationInboxProvider)) {
        ref.invalidate(notificationInboxProvider);
      }
    },
  );
  StreamSubscription<PushEvent>? events;
  var eventEpoch = 0;
  String? observedUser;
  (int, String?, String?, String?)? identity;
  void subscribe() {
    final epoch = eventEpoch;
    events = adapter.events.listen((event) {
      if (alive && epoch == eventEpoch) unawaited(navigation.handle(event));
    }, onError: (Object _) {});
  }

  subscribe();
  void synchronize() {
    if (!alive) return;
    final auth = ref.read(authControllerProvider);
    final session = auth.valueOrNull;
    if (observedUser != null && observedUser != session?.userId) {
      navigation.reset();
    }
    observedUser = session?.userId;
    final feature = ref.read(featureSessionProvider);
    final context = feature.context;
    final ready =
        !auth.isLoading &&
        !auth.hasError &&
        session != null &&
        !session.mustChangePassword &&
        session.hasEmployeeAccess &&
        context?.userId == session.userId &&
        context?.employeeId == session.employeeId &&
        (context?.activeCompanyId == session.companyId ||
            session.companyScope.contains(context?.activeCompanyId));
    final nextIdentity = ready
        ? (
            feature.revision,
            context?.userId,
            context?.employeeId,
            context?.activeCompanyId,
          )
        : null;
    if (identity != nextIdentity) {
      identity = nextIdentity;
      eventEpoch++;
      unawaited(events?.cancel());
      subscribe();
    }
    unawaited(navigation.updateSession(ready ? feature : null));
    unawaited(ready ? coordinator.bind(feature) : coordinator.unbind());
  }

  ref.listen<AsyncValue<AuthSession?>>(
    authControllerProvider,
    (_, _) => synchronize(),
  );
  ref.listen<FeatureSession>(featureSessionProvider, (_, _) => synchronize());
  ref.onDispose(() {
    alive = false;
    eventEpoch++;
    navigation.dispose();
    unawaited(events?.cancel());
    unawaited(coordinator.unbind());
  });
  scheduleMicrotask(synchronize);
});
