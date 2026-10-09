import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/notifications/data/notification_repository_impl.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';

void main() {
  test('loads pages with fixed limit and validates returned page', () async {
    final adapter = _Pages('valid');
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final repo = DioNotificationRepository(
      dio,
      const RequestContext(
        userId: 'u',
        employeeId: 'e',
        activeCompanyId: 'c',
        companyScope: ['c'],
      ),
    );
    final first = await repo.load();
    final second = await repo.load(page: 2);
    expect(first.page, 1);
    expect(second.page, 2);
    expect(first.totalPages, 2);
    expect(adapter.requests.map((r) => r.queryParameters), [
      {'page': 1, 'limit': 50},
      {'page': 2, 'limit': 50},
    ]);
  });
  test(
    'failed page two preserves items and retries same page, deduplicates IDs',
    () async {
      final repo = _InboxPages();
      final container = ProviderContainer(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(notificationInboxProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(notificationInboxProvider.future);
      final controller = container.read(notificationInboxProvider.notifier);
      await controller.refresh(loadMore: true);
      var state = container.read(notificationInboxProvider).requireValue;
      expect(state.items.map((n) => n.id), ['n1', 'n2']);
      expect(state.page, 1);
      expect(state.actionError, isNotNull);
      expect(state.canLoadMore, isTrue);
      repo.failSecond = false;
      await controller.refresh(loadMore: true);
      state = container.read(notificationInboxProvider).requireValue;
      expect(state.items.map((n) => n.id), ['n1', 'n2', 'n3']);
      expect(state.page, 2);
      expect(state.canLoadMore, isFalse);
      expect(repo.pages, [1, 2, 2]);
      expect(repo.limits, [50, 50, 50]);
      await controller.refresh(loadMore: true);
      expect(repo.pages, [1, 2, 2]);
      await controller.refresh();
      expect(container.read(notificationInboxProvider).requireValue.page, 1);
      expect(
        container
            .read(notificationInboxProvider)
            .requireValue
            .items
            .map((n) => n.id),
        ['n1', 'n2'],
      );
    },
  );
  for (final defect in ['missing', 'fraction', 'negative', 'inconsistent']) {
    test('rejects $defect page metadata before exposing inbox', () async {
      final dio = Dio()..httpClientAdapter = _Pages(defect);
      addTearDown(dio.close);
      final repo = DioNotificationRepository(
        dio,
        const RequestContext(
          userId: 'u',
          employeeId: 'e',
          activeCompanyId: 'c',
          companyScope: ['c'],
        ),
      );
      await expectLater(repo.load(limit: 50), throwsFormatException);
    });
  }
}

class _Pages implements HttpClientAdapter {
  _Pages(this.defect);
  final String defect;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final page = options.queryParameters['page'] as int? ?? 1;
    final meta = <String, Object>{
      'page': defect == 'fraction' ? 1.5 : page,
      'limit': 50,
      'total': defect == 'negative' ? -1 : (defect == 'valid' ? 100 : 1),
      'totalPages': defect == 'valid' ? 2 : 1,
      'hasNextPage':
          defect == 'inconsistent' || (defect == 'valid' && page == 1),
      'hasPreviousPage': page > 1,
    };
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'Success',
        'data': [
          {'id': 'n1', 'title': 'Notice', 'isRead': false},
        ],
        if (defect != 'missing') 'meta': meta,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _InboxPages implements NotificationRepository {
  bool failSecond = true;
  final pages = <int>[];
  final limits = <int>[];
  @override
  Future<NotificationPage> load({int page = 1, int limit = 50}) async {
    pages.add(page);
    limits.add(limit);
    if (page == 2 && failSecond) throw StateError('offline');
    return NotificationPage(
      page: page,
      total: 100,
      totalPages: 2,
      items: [
        for (final id in page == 1 ? ['n1', 'n2'] : ['n2', 'n3'])
          NotificationItem(id: id, title: 'Notice $id', isRead: false),
      ],
    );
  }

  @override
  Future<int> unreadCount() async => 3;
  @override
  Future<void> read(List<String> ids) async {}
  @override
  Future<void> readAll() async {}
  @override
  Future<void> delete(String id) async {}
}
