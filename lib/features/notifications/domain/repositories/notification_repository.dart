import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';

abstract interface class NotificationRepository {
  Future<List<NotificationItem>> load({required int limit});
  Future<int> unreadCount();
  Future<void> read(List<String> ids);
  Future<void> readAll();
  Future<void> delete(String id);
}
