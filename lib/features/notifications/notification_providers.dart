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
  late FeatureSession _session;

  @override
  Future<NotificationInbox> build() async {
    _session = ref.watch(featureSessionProvider);
    _generation++;
    ref.onDispose(() => _generation++);
    final repo = ref.watch(notificationRepositoryProvider);
    return NotificationInbox(items: await repo.load(limit: 50), limit: 50);
  }

  Future<void> refresh({bool loadMore = false}) async {
    final session = _session;
    final previous = state.asData?.value;
    if (previous?.busy == true || !session.isCurrent) return;
    final generation = ++_generation;
    final limit = (previous?.limit ?? 50) + (loadMore ? 50 : 0);
    final repo = ref.read(notificationRepositoryProvider);
    if (previous == null) {
      state = const AsyncLoading();
    } else {
      state = AsyncData(
        NotificationInbox(
          items: previous.items,
          limit: previous.limit,
          busy: true,
        ),
      );
    }
    final result = await AsyncValue.guard(
      () async => NotificationInbox(
        items: await repo.load(limit: limit),
        limit: limit,
      ),
    );
    if (!session.isCurrent || generation != _generation) return;
    state = result;
    ref.invalidate(notificationUnreadCountProvider);
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
    state = AsyncData(
      NotificationInbox(
        items: previous.items,
        limit: previous.limit,
        busy: true,
      ),
    );
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
      state = AsyncData(NotificationInbox(items: items, limit: previous.limit));
      return true;
    } catch (error) {
      if (session.isCurrent && generation == _generation) {
        state = AsyncData(
          NotificationInbox(
            items: previous.items,
            limit: previous.limit,
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
    state = AsyncData(
      NotificationInbox(
        items: optimisticItems,
        limit: previous.limit,
        busy: true,
      ),
    );
    try {
      await repo.delete(id);
      if (!session.isCurrent || generation != _generation) return false;
      state = AsyncData(
        NotificationInbox(items: optimisticItems, limit: previous.limit),
      );
      ref.invalidate(notificationUnreadCountProvider);
      return true;
    } catch (error) {
      if (session.isCurrent && generation == _generation) {
        state = AsyncData(
          NotificationInbox(
            items: previous.items,
            limit: previous.limit,
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
