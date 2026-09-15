import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/app/router/notification_route.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/notifications/data/notification_repository_impl.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';
import 'package:hrm_app/features/notifications/presentation/screens/notifications_screen.dart';

const _context = RequestContext(
  userId: 'u1',
  employeeId: 'e1',
  activeCompanyId: 'c1',
  companyScope: ['c1'],
);
const _item = NotificationItem(
  id: 'n1',
  title: 'Pengajuan disetujui',
  message: 'Cuti Anda disetujui.',
  isRead: false,
  resource: 'leave',
  action: 'approved',
  referenceId: 'leave-1',
);

void main() {
  testWidgets(
    'inbox retry, load-more and pull-refresh use documented limit only',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo()
        ..fullPage = true
        ..failLoad = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifikasi gagal dimuat'), findsOneWidget);
      repo.failLoad = false;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Muat lebih banyak'),
        500,
        maxScrolls: 30,
      );
      await tester.tap(find.text('Muat lebih banyak'));
      await tester.pumpAndSettle();
      expect(repo.loadLimits, [50, 50, 100]);
      await tester.fling(find.byType(ListView), const Offset(0, 20000), 10000);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(repo.loadLimits, [50, 50, 100, 100]);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'notification uses documented self endpoints, limit and PUT read methods',
    () async {
      final adapter = _Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repo = DioNotificationRepository(dio, _context);
      final items = await repo.load(limit: 100);
      expect(items.single.isApproval, isTrue);
      expect(adapter.requests.first.queryParameters, {'limit': 100});
      expect(await repo.unreadCount(), 3);
      await repo.read(['n1']);
      await repo.readAll();
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /notifications',
        'GET /notifications/unread-count',
        'PUT /notifications/read',
        'PUT /notifications/read-all',
      ]);
      expect(adapter.requests[2].data, {
        'ids': ['n1'],
      });
      expect(adapter.requests[3].data, isNull);
    },
  );
  for (final defect in ['user', 'company', 'schema', 'failure', 'count']) {
    test('notification rejects $defect', () async {
      final dio = Dio()..httpClientAdapter = _Adapter(defect: defect);
      addTearDown(dio.close);
      final repo = DioNotificationRepository(dio, _context);
      await expectLater(
        defect == 'count' ? repo.unreadCount() : repo.load(limit: 50),
        throwsFormatException,
      );
    });
  }
  test('notification routes only supported resources and safe identifiers', () {
    expect(notificationResourceLocation(_item), '/requests/leave/leave-1');
    for (final resource in [
      'payroll',
      'https://evil.invalid',
      'employee',
      'admin',
    ]) {
      expect(
        notificationResourceLocation(
          NotificationItem(
            id: 'n',
            title: 'x',
            isRead: true,
            resource: resource,
          ),
        ),
        isNull,
      );
    }
    expect(
      notificationResourceLocation(
        const NotificationItem(
          id: 'n',
          title: 'x',
          isRead: true,
          resource: 'leave',
          referenceId: '../admin?companyId=other',
        ),
      ),
      '/requests',
    );
  });
  test('failed read keeps unread status and exposes retryable error', () async {
    final repo = _Repo()..failRead = true;
    final container = ProviderContainer(
      overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(notificationInboxProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(notificationInboxProvider.future);
    expect(
      await container
          .read(notificationInboxProvider.notifier)
          .markRead(id: 'n1'),
      isFalse,
    );
    final state = container.read(notificationInboxProvider).requireValue;
    expect(state.items.single.isRead, isFalse);
    expect(state.actionError, isNotNull);
    expect(
      await container
          .read(notificationInboxProvider.notifier)
          .markRead(id: 'outside-list'),
      isFalse,
    );
    repo.failRead = false;
    expect(
      await container
          .read(notificationInboxProvider.notifier)
          .markRead(id: 'n1'),
      isTrue,
    );
    expect(
      container
          .read(notificationInboxProvider)
          .requireValue
          .items
          .single
          .isRead,
      isTrue,
    );
  });
  test('late read result cannot contaminate the next account', () async {
    final first = _Repo()..pendingRead = Completer<void>();
    final second = _Repo();
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWith((ref) {
          return ref.watch(requestContextProvider)?.userId == 'u1'
              ? first
              : second;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(requestContextProvider.notifier).state = _context;
    final sub = container.listen(notificationInboxProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(notificationInboxProvider.future);
    final read = container
        .read(notificationInboxProvider.notifier)
        .markRead(id: 'n1');
    container
        .read(requestContextProvider.notifier)
        .state = const RequestContext(
      userId: 'u2',
      employeeId: 'e2',
      activeCompanyId: 'c2',
      companyScope: ['c2'],
    );
    await container.read(notificationInboxProvider.future);
    first.pendingRead!.complete();
    expect(await read, isFalse);
    expect(
      container
          .read(notificationInboxProvider)
          .requireValue
          .items
          .single
          .isRead,
      isFalse,
    );
  });
  for (final dark in [false, true]) {
    testWidgets(
      'inbox filters and read-all work at 320dp, 200% text, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repo();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  padding: const EdgeInsets.only(top: 30),
                ),
                child: child!,
              ),
              home: const NotificationsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(_item.title), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Notifikasi')).dy,
          greaterThanOrEqualTo(46),
        );
        await tester.tap(find.text('Tandai dibaca'));
        await tester.pumpAndSettle();
        expect(repo.readAllCalls, 1);
        await tester.tap(find.text('Belum dibaca 0'));
        await tester.pumpAndSettle();
        expect(find.text('Belum ada notifikasi'), findsOneWidget);
        await tester.tap(find.text('Approval'));
        await tester.pumpAndSettle();
        expect(find.text(_item.title), findsOneWidget);
        await tester.tap(find.text('Semua'));
        await tester.pumpAndSettle();
        expect(find.text(_item.title), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Repo implements NotificationRepository {
  bool fullPage = false;
  bool failLoad = false;
  final loadLimits = <int>[];
  bool failRead = false;
  int count = 1;
  int readAllCalls = 0;
  Completer<void>? pendingRead;
  @override
  Future<List<NotificationItem>> load({required int limit}) async {
    loadLimits.add(limit);
    if (failLoad) {
      throw const ApiException(
        'Tidak dapat terhubung ke server.',
        code: 'NETWORK_ERROR',
      );
    }
    return fullPage
        ? List.generate(
            limit,
            (index) => NotificationItem(
              id: 'fixture-$index',
              title: 'Fixture inbox $index',
              isRead: false,
            ),
          )
        : [_item];
  }

  @override
  Future<int> unreadCount() async => count;
  @override
  Future<void> read(List<String> ids) async {
    if (failRead) throw StateError('offline');
    if (pendingRead != null) await pendingRead!.future;
    count = 0;
  }

  @override
  Future<void> readAll() async {
    readAllCalls++;
    count = 0;
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter({this.defect});
  final String? defect;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final Object? data = options.path.endsWith('unread-count')
        ? {'count': defect == 'count' ? -1 : 3}
        : options.method == 'GET'
        ? [
            {
              'id': 'n1',
              'title': _item.title,
              'isRead': defect == 'schema' ? 'false' : false,
              'userId': defect == 'user' ? 'u2' : 'u1',
              'companyId': defect == 'company' ? 'c2' : 'c1',
              'type': 'SUCCESS',
              'resource': 'leave',
              'action': 'approved',
              'referenceId': 'leave-1',
            },
          ]
        : null;
    return ResponseBody.fromString(
      jsonEncode({'success': defect != 'failure', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
