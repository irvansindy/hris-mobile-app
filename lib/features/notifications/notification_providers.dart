import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/notifications/data/notification_repository_impl.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final context = ref.watch(featureSessionProvider).context;
  if (context == null) throw const ApiException('Sesi akun belum tersedia.');
  return DioNotificationRepository(ref.watch(featureDioProvider), context);
});

final notificationUnreadCountProvider = FutureProvider<int>((ref) {
  ref.watch(featureSessionProvider);
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

final notificationInboxProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationInboxController,
      NotificationInbox
    >(NotificationInboxController.new);

class NotificationInboxController
    extends AutoDisposeAsyncNotifier<NotificationInbox> {
  int _generation = 0;
  bool _reloadBeforeMore = false;
  late FeatureSession _session;

  @override
  Future<NotificationInbox> build() async {
    _session = ref.watch(featureSessionProvider);
    _reloadBeforeMore = false;
    _generation++;
    ref.onDispose(() => _generation++);
    final repo = ref.watch(notificationRepositoryProvider);
    return _inbox(await repo.load());
  }

  Future<void> refresh({bool loadMore = false}) async {
    final session = _session;
    final previous = state.asData?.value;
    if (previous?.busy == true ||
        !session.isCurrent ||
        (loadMore && previous?.canLoadMore != true)) {
      return;
    }
    final generation = ++_generation;
    final append = loadMore && !_reloadBeforeMore;
    final page = append ? previous!.page + 1 : 1;
    final repo = ref.read(notificationRepositoryProvider);
    if (previous == null) {
      state = const AsyncLoading();
    } else {
      state = AsyncData(previous.copyWith(busy: true));
    }
    try {
      final result = await repo.load(page: page);
      if (!session.isCurrent || generation != _generation) return;
      final byId = <String, NotificationItem>{
        if (append)
          for (final item in previous!.items) item.id: item,
        for (final item in result.items) item.id: item,
      };
      state = AsyncData(
        _inbox(result, items: byId.values.toList(growable: false)),
      );
      _reloadBeforeMore = false;
      ref.invalidate(notificationUnreadCountProvider);
    } catch (error, stack) {
      if (!session.isCurrent || generation != _generation) return;
      state = previous == null
          ? AsyncError(error, stack)
          : AsyncData(
              previous.copyWith(
                actionError: 'Notifikasi gagal dimuat. Silakan coba lagi.',
              ),
            );
    }
  }

  Future<bool> markRead({String? id}) async {
    final session = _session;
    final previous = state.asData?.value;
    if (!session.isCurrent || previous == null || previous.busy) return false;
    if (id != null && !previous.items.any((item) => item.id == id)) {
      return false;
    }
    final repo = ref.read(notificationRepositoryProvider);
    final generation = ++_generation;
    state = AsyncData(previous.copyWith(busy: true));
    try {
      if (id == null) {
        await repo.readAll();
      } else {
        await repo.read([id]);
      }
      if (!session.isCurrent || generation != _generation) return false;
      ref.invalidate(notificationUnreadCountProvider);
      final items = previous.items
          .map(
            (item) => id == null || item.id == id
                ? NotificationItem(
                    id: item.id,
                    title: item.title,
                    isRead: true,
                    message: item.message,
                    type: item.type,
                    resource: item.resource,
                    action: item.action,
                    referenceId: item.referenceId,
                    createdAt: item.createdAt,
                  )
                : item,
          )
          .toList(growable: false);
      state = AsyncData(previous.copyWith(items: items));
      return true;
    } catch (error) {
      if (session.isCurrent && generation == _generation) {
        state = AsyncData(
          previous.copyWith(
            actionError: error is ApiException
                ? error.message
                : 'Status baca gagal disimpan. Silakan coba lagi.',
          ),
        );
      }
      return false;
    }
  }

  Future<bool> delete(String id) async {
    final session = _session;
    final previous = state.asData?.value;
    if (!session.isCurrent || previous == null || previous.busy) return false;
    if (!previous.items.any((item) => item.id == id)) return false;
    final repo = ref.read(notificationRepositoryProvider);
    final generation = ++_generation;
    final optimisticItems = previous.items
        .where((item) => item.id != id)
        .toList(growable: false);
    state = AsyncData(previous.copyWith(items: optimisticItems, busy: true));
    try {
      await repo.delete(id);
      if (!session.isCurrent || generation != _generation) return false;
      // Deletion shifts server page offsets; next load must restart at page 1.
      _reloadBeforeMore = true;
      state = AsyncData(previous.copyWith(items: optimisticItems));
      ref.invalidate(notificationUnreadCountProvider);
      return true;
    } catch (error) {
      if (session.isCurrent && generation == _generation) {
        state = AsyncData(
          previous.copyWith(
            actionError: error is ApiException
                ? error.message
                : 'Notifikasi gagal dihapus. Daftar telah dipulihkan.',
          ),
        );
        ref.invalidate(notificationUnreadCountProvider);
      }
      return false;
    }
  }
}

NotificationInbox _inbox(
  NotificationPage result, {
  List<NotificationItem>? items,
}) => NotificationInbox(
  items: items ?? result.items,
  limit: 50,
  page: result.page,
  totalPages: result.totalPages,
  total: result.total,
);
