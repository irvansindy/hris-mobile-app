import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/app/router/notification_route.dart';
import 'package:hrm_app/app/router/push_navigation.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hrm_app/features/notifications/push/push_adapter.dart';

const event = PushEvent(
  notificationId: 'n1',
  messageId: 'm1',
  kind: PushEventKind.opened,
);
const item = NotificationItem(
  id: 'n1',
  title: 'Server item',
  isRead: false,
  resource: 'leave',
  referenceId: 'leave-1',
);

void main() {
  test(
    'all supported server resources use existing allowlist destinations',
    () async {
      for (final entry in const {
        'attendance': '/attendance',
        'work_calendar': '/calendar',
        'leave_request': '/requests/leave/leave-1',
        'permission_request': '/requests',
      }.entries) {
        final repo = InboxRepository()
          ..items = [
            NotificationItem(
              id: 'n1',
              title: 'Server',
              isRead: true,
              resource: entry.key,
              referenceId: 'leave-1',
            ),
          ];
        expect(await resolvePushLocation(event, repo, () => true), entry.value);
      }
    },
  );
  test(
    'resolver fetches only current inbox page 1 limit 50 and maps server item',
    () async {
      final repo = InboxRepository();
      expect(
        await resolvePushLocation(event, repo, () => true),
        '/requests/leave/leave-1',
      );
      expect(repo.loads, [(1, 50)]);
      expect(repo.reads, isEmpty);
    },
  );
  test('missing or malicious hint never becomes a route', () async {
    for (final id in <String?>[
      null,
      '',
      'https://evil.invalid/payroll',
      '../payroll',
      'missing',
    ]) {
      final repo = InboxRepository();
      expect(
        await resolvePushLocation(
          PushEvent(notificationId: id, kind: PushEventKind.initial),
          repo,
          () => true,
        ),
        '/notifications',
      );
      expect(repo.loads.length, id == 'missing' ? 1 : 0);
    }
  });
  test(
    'server failure, unknown resource and payslip fall back without bypassing PIN',
    () async {
      final repo = InboxRepository()..fail = true;
      expect(
        await resolvePushLocation(event, repo, () => true),
        '/notifications',
      );
      repo.fail = false;
      for (final resource in [
        'payroll',
        'payslip',
        'approval',
        'https://evil.invalid',
        'unknown',
      ]) {
        repo.items = [
          NotificationItem(
            id: 'n1',
            title: 'Server',
            isRead: false,
            resource: resource,
            referenceId: 'private',
          ),
        ];
        expect(
          await resolvePushLocation(event, repo, () => true),
          '/notifications',
        );
      }
    },
  );
  test('stale lookup cannot return another account resource', () async {
    final repo = InboxRepository()..gate = Completer<NotificationPage>();
    var current = true;
    final result = resolvePushLocation(event, repo, () => current);
    current = false;
    repo.gate!.complete(repo.page());
    expect(await result, '/notifications');
  });
  test(
    'initial before restore keeps one hint and performs fresh lookup after login',
    () async {
      final rig = NavigationRig();
      addTearDown(rig.dispose);
      await rig.navigation.handle(
        const PushEvent(
          notificationId: 'discarded',
          kind: PushEventKind.initial,
        ),
      );
      await rig.navigation.handle(event);
      expect(rig.locations, isEmpty);
      expect(rig.repo.loads, isEmpty);
      await rig.navigation.updateSession(rig.session('A'));
      expect(rig.locations, ['/requests/leave/leave-1']);
      expect(rig.repo.loads, [(1, 50)]);
    },
  );
  test(
    'foreground refreshes without navigation or loading inbox itself',
    () async {
      final rig = NavigationRig();
      addTearDown(rig.dispose);
      await rig.navigation.updateSession(rig.session('A'));
      await rig.navigation.handle(
        const PushEvent(kind: PushEventKind.foreground),
      );
      expect(rig.refreshes, 1);
      expect(rig.locations, isEmpty);
      expect(rig.repo.loads, isEmpty);
    },
  );
  test(
    'initial and opened duplicates use message and notification aliases once',
    () async {
      final rig = NavigationRig();
      addTearDown(rig.dispose);
      await rig.navigation.updateSession(rig.session('A'));
      await rig.navigation.handle(
        const PushEvent(
          notificationId: 'n1',
          messageId: 'm1',
          kind: PushEventKind.initial,
        ),
      );
      await rig.navigation.handle(event);
      await rig.navigation.handle(
        const PushEvent(notificationId: 'n1', kind: PushEventKind.opened),
      );
      expect(rig.locations, hasLength(1));
      expect(rig.repo.loads, hasLength(1));
      expect(rig.repo.reads, isEmpty);
    },
  );
  test(
    'opaque message IDs deduplicate fallback taps without a notification ID',
    () async {
      final rig = NavigationRig();
      addTearDown(rig.dispose);
      await rig.navigation.updateSession(rig.session('A'));
      for (final kind in [PushEventKind.initial, PushEventKind.opened]) {
        await rig.navigation.handle(
          PushEvent(messageId: '0:12345%opaque', kind: kind),
        );
      }
      expect(rig.locations, ['/notifications']);
      expect(rig.repo.loads, isEmpty);
    },
  );
  test(
    'logout drops pending lookup and late events, B verifies its own inbox',
    () async {
      final rig = NavigationRig();
      addTearDown(rig.dispose);
      await rig.navigation.updateSession(rig.session('A'));
      final oldRepo = rig.repo..gate = Completer<NotificationPage>();
      final oldTap = rig.navigation.handle(event);
      rig.lifecycle.advance();
      await rig.navigation.updateSession(null);
      await rig.navigation.handle(event);
      rig.repo = InboxRepository()..items = [];
      await rig.navigation.updateSession(rig.session('B'));
      oldRepo.gate!.complete(oldRepo.page());
      await oldTap;
      expect(rig.locations, isEmpty);
      await rig.navigation.handle(event);
      expect(rig.locations, ['/notifications']);
      expect(rig.repo.loads, [(1, 50)]);
    },
  );
  test('company switch cancels old lookup even for the same user', () async {
    final rig = NavigationRig();
    addTearDown(rig.dispose);
    await rig.navigation.updateSession(rig.session('A'));
    rig.repo.gate = Completer<NotificationPage>();
    final oldTap = rig.navigation.handle(event);
    rig.lifecycle.advance();
    await rig.navigation.updateSession(rig.session('A', company: 'other'));
    rig.repo.gate!.complete(rig.repo.page());
    await oldTap;
    expect(rig.locations, isEmpty);
  });
  test(
    'dedup is bounded to 100 keys and disposed navigation ignores callbacks',
    () async {
      final rig = NavigationRig();
      addTearDown(rig.dispose);
      await rig.navigation.updateSession(rig.session('A'));
      for (var n = 0; n < 101; n++) {
        await rig.navigation.handle(
          PushEvent(notificationId: 'missing-$n', kind: PushEventKind.opened),
        );
      }
      await rig.navigation.handle(
        const PushEvent(
          notificationId: 'missing-100',
          kind: PushEventKind.opened,
        ),
      );
      expect(rig.locations, hasLength(101));
      await rig.navigation.handle(
        const PushEvent(
          notificationId: 'missing-0',
          kind: PushEventKind.opened,
        ),
      );
      expect(rig.locations, hasLength(102));
      rig.navigation.dispose();
      await rig.navigation.handle(event);
      expect(rig.locations, hasLength(102));
    },
  );
}

class InboxRepository implements NotificationRepository {
  List<NotificationItem> items = [item];
  final loads = <(int, int)>[];
  final reads = <List<String>>[];
  bool fail = false;
  Completer<NotificationPage>? gate;
  NotificationPage page() =>
      NotificationPage(items: items, page: 1, totalPages: 2, total: 100);
  @override
  Future<NotificationPage> load({int page = 1, int limit = 50}) async {
    loads.add((page, limit));
    if (fail) throw StateError('offline');
    return gate == null ? this.page() : gate!.future;
  }

  @override
  Future<void> read(List<String> ids) async => reads.add(ids);
  @override
  Future<void> readAll() async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<int> unreadCount() async => 1;
}

class NavigationRig {
  final lifecycle = SessionLifecycle();
  InboxRepository repo = InboxRepository();
  final locations = <String>[];
  int refreshes = 0;
  late final navigation = PushNavigation(
    repositoryForSession: (_) => repo,
    navigate: locations.add,
    refreshInbox: () => refreshes++,
  );
  FeatureSession session(String user, {String company = 'company'}) =>
      FeatureSession(
        RequestContext(
          userId: user,
          employeeId: 'employee-$user',
          activeCompanyId: company,
          companyScope: [company],
        ),
        lifecycle,
        () => true,
      );
  void dispose() {
    navigation.dispose();
    lifecycle.dispose();
  }
}
