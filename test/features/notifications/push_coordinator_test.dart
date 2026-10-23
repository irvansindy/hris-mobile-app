import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/app/router/app_router.dart';
import 'package:hrm_app/app/providers/push_lifecycle.dart';
import 'package:hrm_app/core/config/app_config.dart';
import 'package:hrm_app/core/errors/result.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/features/authentication/authentication_dependencies.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/domain/entities/auth_session.dart';
import 'package:hrm_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';
import 'package:hrm_app/features/notifications/push/push_coordinator.dart';
import 'package:hrm_app/features/notifications/push/push_registration.dart';
import 'package:hrm_app/features/notifications/push/push_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Rig rig;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    rig = _Rig(await SharedPreferences.getInstance());
  });
  tearDown(() async {
    await rig.coordinator.dispose();
    rig.lifecycle.dispose();
  });

  test(
    'real Firebase Console mode never reports backend registration success',
    () async {
      final coordinator = PushCoordinator(
        mode: PushMode.firebase,
        adapter: rig.adapter,
        identity: InstallationIdentity(
          await SharedPreferences.getInstance(),
          'console',
        ),
        platform: 'ANDROID',
        timeout: const Duration(seconds: 1),
        registryForSession: (_) => ConsoleDeviceRegistrationRepository(),
      );
      addTearDown(coordinator.dispose);
      await coordinator.bind(rig.session('A'));
      expect(coordinator.status.name, 'consoleReady');
      expect(rig.a.commands, isEmpty);
      await coordinator.unbind();
      expect(coordinator.status, PushStatus.disabled);
    },
  );

  test(
    'bind and same identity refresh register once; retry preserves failed command',
    () async {
      rig.a.failRegister = true;
      await rig.coordinator.bind(rig.session('A'));
      expect(rig.coordinator.status, PushStatus.failed);
      final first = rig.a.commands.single;
      await rig.coordinator.bind(rig.session('A'));
      expect(rig.a.commands.length, 1);
      rig.a.failRegister = false;
      await rig.coordinator.retry();
      expect(rig.a.commands.length, 2);
      expect(rig.a.commands.last.idempotencyKey, first.idempotencyKey);
      expect(rig.a.commands.last.token, first.token);
      expect(rig.coordinator.status, PushStatus.simulated);
      await rig.coordinator.retry();
      expect(rig.a.commands.length, 2);
    },
  );

  test(
    'rotation while register is pending reconciles only the latest token',
    () async {
      rig.a.registerGate = Completer<void>();
      final binding = rig.coordinator.bind(rig.session('A'));
      await rig.a.started.future;
      final first = rig.a.commands.single;
      rig.adapter.rotateToken();
      final intermediate = await rig.adapter.getToken();
      rig.adapter.rotateToken();
      final latest = await rig.adapter.getToken();
      await Future<void>.delayed(Duration.zero);
      rig.a.registerGate!.complete();
      await binding;
      await rig.coordinator.retry();
      expect(rig.a.commands.map((c) => c.token), [first.token, latest]);
      expect(rig.a.commands.last.token, isNot(intermediate));
      expect(rig.a.commands.last.idempotencyKey, isNot(first.idempotencyKey));
      expect(rig.coordinator.status, PushStatus.simulated);
    },
  );

  test(
    'late A response cannot activate B; unregister A precedes register B',
    () async {
      rig.a.registerGate = Completer<void>();
      final bindingA = rig.coordinator.bind(rig.session('A'));
      await rig.a.started.future;
      final tokenA = rig.a.commands.single.token;
      rig.a.unregisterGate = Completer<void>();
      final bindingB = rig.coordinator.bind(rig.session('B'));
      expect(rig.coordinator.status, isNot(PushStatus.simulated));
      rig.a.registerGate!.complete();
      await bindingA;
      await rig.a.cleanupStarted.future;
      expect(rig.b.commands, isEmpty);
      rig.a.unregisterGate!.complete();
      await bindingB;
      expect(rig.operations, ['register-A', 'unregister-A', 'register-B']);
      expect(rig.b.commands.single.token, isNot(tokenA));
      expect(rig.coordinator.status, PushStatus.simulated);
    },
  );

  test(
    'offline logout clears status/events immediately and still deletes token',
    () async {
      await rig.coordinator.bind(rig.session('A'));
      final old = await rig.adapter.getToken();
      final events = <PushEvent>[];
      final subscription = rig.coordinator.events.listen(events.add);
      addTearDown(subscription.cancel);
      rig.a.failUnregister = true;
      rig.adapter.emit(
        const PushEvent(notificationId: 'old', kind: PushEventKind.opened),
      );
      final logout = rig.coordinator.unbind();
      expect(rig.coordinator.status, PushStatus.disabled);
      await logout;
      expect(events, isEmpty);
      expect(await rig.adapter.getToken(), isNot(old));
      await rig.coordinator.bind(rig.session('B'));
      expect(rig.b.commands.single.token, isNot(old));
    },
  );

  test(
    'cleanup timeout allows B while late completion cannot change local status',
    () async {
      await rig.coordinator.bind(rig.session('A'));
      rig.a.unregisterGate = Completer<void>();
      await rig.coordinator.bind(rig.session('B'));
      expect(rig.b.commands.length, 1);
      expect(rig.coordinator.status, PushStatus.simulated);
      rig.a.unregisterGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(rig.coordinator.status, PushStatus.simulated);
    },
  );

  test(
    'permission denial never registers and explicit retry can recover',
    () async {
      rig.adapter.setPermission(PushPermission.denied);
      await rig.coordinator.bind(rig.session('A'));
      expect(rig.coordinator.status, PushStatus.denied);
      await rig.coordinator.retry();
      expect(rig.a.commands, isEmpty);
      rig.adapter.setPermission(PushPermission.authorized);
      await rig.coordinator.retry();
      expect(rig.a.commands.length, 1);
      expect(rig.coordinator.status, PushStatus.simulated);
    },
  );

  test(
    'adapter failure is contained; retry is explicit rather than a loop',
    () async {
      rig.adapter.failPermission = true;
      await rig.coordinator.bind(rig.session('A'));
      expect(rig.coordinator.status, PushStatus.failed);
      expect(rig.a.commands, isEmpty);
      rig.adapter.failPermission = false;
      await rig.coordinator.retry();
      expect(rig.a.commands.length, 1);
    },
  );

  test(
    'company switch cleans old binding even when user ID is unchanged',
    () async {
      await rig.coordinator.bind(rig.session('A'));
      final old = rig.a.commands.single;
      await rig.coordinator.bind(rig.session('A', company: 'other'));
      expect(rig.a.commands.length, 2);
      expect(rig.operations, ['register-A', 'unregister-A', 'register-A']);
      expect(rig.a.commands.last.token, isNot(old.token));
    },
  );

  test(
    'disposed coordinator ignores token/events and cannot bind again',
    () async {
      await rig.coordinator.bind(rig.session('A'));
      await rig.coordinator.dispose();
      rig.adapter.rotateToken();
      rig.adapter.emit(const PushEvent(kind: PushEventKind.foreground));
      await rig.coordinator.bind(rig.session('B'));
      expect(rig.b.commands, isEmpty);
      expect(rig.coordinator.status, PushStatus.disabled);
      expect(await rig.adapter.getToken(), isNull);
    },
  );

  test(
    'disabled mode never invokes adapter permission or registration',
    () async {
      await rig.coordinator.dispose();
      rig.coordinator = rig.create(mode: PushMode.disabled);
      await rig.coordinator.bind(rig.session('A'));
      expect(rig.coordinator.status, PushStatus.disabled);
      expect(rig.adapter.permissionCalls, 0);
      expect(rig.operations, isEmpty);
    },
  );
  test('failed token deletion never reuses A token for B', () async {
    await rig.coordinator.bind(rig.session('A'));
    final old = rig.a.commands.single.token;
    rig.adapter.failDeletion = true;
    await rig.coordinator.bind(rig.session('B'));
    expect(rig.b.commands, isEmpty);
    expect(rig.coordinator.status, PushStatus.failed);
    rig.adapter.failDeletion = false;
    await rig.coordinator.retry();
    expect(rig.b.commands.single.token, isNot(old));
    expect(rig.coordinator.status, PushStatus.simulated);
  });

  test(
    'register timeout does not hang switching and late POST cannot activate A',
    () async {
      rig.a.registerGate = Completer<void>();
      await rig.coordinator.bind(rig.session('A'));
      expect(rig.coordinator.status, PushStatus.failed);
      await rig.coordinator.bind(rig.session('B'));
      expect(rig.coordinator.status, PushStatus.simulated);
      rig.a.registerGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(rig.coordinator.status, PushStatus.simulated);
      expect(rig.operations, ['register-A', 'unregister-A', 'register-B']);
    },
  );

  test(
    'retry observes revoked permission and recovers without duplicate registration',
    () async {
      await rig.coordinator.bind(rig.session('A'));
      rig.adapter.setPermission(PushPermission.denied);
      await rig.coordinator.retry();
      expect(rig.coordinator.status, PushStatus.denied);
      rig.adapter.setPermission(PushPermission.authorized);
      await rig.coordinator.retry();
      expect(rig.coordinator.status, PushStatus.simulated);
      expect(rig.a.commands.length, 1);
    },
  );

  test(
    'app lifecycle waits for restore and follows real auth controller logout/login',
    () async {
      final auth = _AuthRepository();
      final prefs = await SharedPreferences.getInstance();
      final registry = DummyDeviceRegistrationRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appConfigProvider.overrideWithValue(
            AppConfig.fromEnvironment(
              productionBuild: false,
              values: const {'PUSH_MODE': 'dummy'},
            ),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          sessionArtifactCleanerProvider.overrideWithValue((_) async {}),
          deviceRegistrationRepositoryProvider.overrideWithValue(registry),
          dioProvider.overrideWith(
            (_) => throw StateError('Dummy must not read network'),
          ),
          featureDioProvider.overrideWith(
            (_) => throw StateError('Dummy must not read network'),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(pushLifecycleProvider);
      container.read(appRouterProvider);
      await Future<void>.delayed(Duration.zero);
      expect(registry.registrations, isEmpty);
      auth.restored.complete(
        const Success(
          AuthSession(
            userId: 'A',
            employeeId: 'employee-A',
            companyId: 'company-A',
          ),
        ),
      );
      await container.read(authControllerProvider.future);
      await Future<void>.delayed(Duration.zero);
      await container.read(pushCoordinatorProvider).retry();
      expect(container.read(pushStatusProvider), PushStatus.simulated);
      final first = registry.registrations.values.single;
      final controller = container.read(authControllerProvider.notifier);
      await controller.logout();
      await Future<void>.delayed(Duration.zero);
      await container.read(pushCoordinatorProvider).retry();
      expect(registry.registrations, isEmpty);
      expect(container.read(pushStatusProvider), PushStatus.disabled);
      await controller.login(email: 'B', password: 'fixture');
      await Future<void>.delayed(Duration.zero);
      await container.read(pushCoordinatorProvider).retry();
      expect(registry.registrations.values.single.token, isNot(first.token));
      expect(
        registry.registrations.values.single.installationId,
        first.installationId,
      );
      expect(container.read(requestContextProvider)?.userId, 'B');
      for (final blocked in ['must-change', 'no-employee']) {
        await controller.logout();
        await controller.login(email: blocked, password: 'fixture');
        await Future<void>.delayed(Duration.zero);
        await container.read(pushCoordinatorProvider).retry();
        expect(
          container.read(authControllerProvider).requireValue?.userId,
          blocked,
        );
        expect(registry.registrations, isEmpty);
        expect(container.read(pushStatusProvider), PushStatus.disabled);
      }
    },
  );
}

class _AuthRepository implements AuthRepository {
  final restored = Completer<Result<AuthSession?>>();
  @override
  Future<Result<AuthSession?>> restoreSession() => restored.future;
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<Result<AuthSession>> login({
    required String email,
    required String password,
    String? totp,
  }) async => Success(
    AuthSession(
      userId: email,
      employeeId: email == 'no-employee' ? null : 'employee-$email',
      companyId: 'company-$email',
      mustChangePassword: email == 'must-change',
    ),
  );
  @override
  Future<void> logout() async {}
  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => const Success(null);
}

class _Rig {
  _Rig(SharedPreferences preferences)
    : identity = InstallationIdentity(preferences, 'test') {
    a = _Registry('A', operations);
    b = _Registry('B', operations);
    coordinator = create();
  }
  final InstallationIdentity identity;
  final lifecycle = SessionLifecycle();
  final adapter = _Adapter();
  final operations = <String>[];
  late _Registry a;
  late _Registry b;
  late PushCoordinator coordinator;
  RequestContext? current;
  PushCoordinator create({PushMode mode = PushMode.dummy}) => PushCoordinator(
    mode: mode,
    adapter: adapter,
    identity: identity,
    platform: 'ANDROID',
    timeout: const Duration(seconds: 1),
    registryForSession: (session) => session.context!.userId == 'A' ? a : b,
  );
  FeatureSession session(String user, {String? company}) {
    final context = RequestContext(
      userId: user,
      employeeId: 'employee-$user',
      activeCompanyId: company ?? 'company-$user',
      companyScope: [company ?? 'company-$user'],
    );
    current = context;
    return FeatureSession(
      context,
      lifecycle,
      () =>
          current?.userId == context.userId &&
          current?.activeCompanyId == context.activeCompanyId,
    );
  }
}

class _Adapter extends DummyPushAdapter {
  bool failPermission = false;
  bool failDeletion = false;
  int permissionCalls = 0;
  @override
  Future<PushPermission> requestPermission() async {
    permissionCalls++;
    if (failPermission) throw StateError('adapter unavailable');
    return super.requestPermission();
  }

  @override
  Future<void> deleteToken() async {
    if (failDeletion) throw StateError('token deletion unavailable');
    return super.deleteToken();
  }
}

class _Registry implements DeviceRegistrationRepository {
  _Registry(this.user, this.operations);
  final String user;
  final List<String> operations;
  final commands = <DeviceRegistration>[];
  final started = Completer<void>();
  final cleanupStarted = Completer<void>();
  Completer<void>? registerGate;
  Completer<void>? unregisterGate;
  bool failRegister = false;
  bool failUnregister = false;
  @override
  Future<void> register(DeviceRegistration command) async {
    commands.add(command);
    operations.add('register-$user');
    if (!started.isCompleted) started.complete();
    if (failRegister) throw StateError('register offline');
    await registerGate?.future;
  }

  @override
  Future<void> unregister(
    String installationId, {
    required String idempotencyKey,
  }) async {
    operations.add('unregister-$user');
    if (!cleanupStarted.isCompleted) cleanupStarted.complete();
    if (failUnregister) throw StateError('cleanup offline');
    await unregisterGate?.future;
  }
}
