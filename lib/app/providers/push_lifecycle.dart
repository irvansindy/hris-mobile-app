import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/notifications/push/push_providers.dart';

final pushLifecycleProvider = Provider<void>((ref) {
  if (ref.watch(pushModeProvider) == PushMode.disabled) return;
  final coordinator = ref.watch(pushCoordinatorProvider);
  var alive = true;
  void synchronize() {
    if (!alive) return;
    final auth = ref.read(authControllerProvider);
    final session = auth.valueOrNull;
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
    unawaited(ready ? coordinator.bind(feature) : coordinator.unbind());
  }

  ref.listen<AsyncValue<AuthSession?>>(
    authControllerProvider,
    (_, _) => synchronize(),
  );
  ref.listen<FeatureSession>(featureSessionProvider, (_, _) => synchronize());
  ref.onDispose(() {
    alive = false;
    unawaited(coordinator.unbind());
  });
  scheduleMicrotask(synchronize);
});
