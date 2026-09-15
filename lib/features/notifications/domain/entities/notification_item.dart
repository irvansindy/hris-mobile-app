class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.isRead,
    this.message,
    this.type = 'INFO',
    this.resource,
    this.action,
    this.referenceId,
    this.createdAt,
  });
  final String id;
  final String title;
  final String? message;
  final String type;
  final String? resource;
  final String? action;
  final String? referenceId;
  final bool isRead;
  final DateTime? createdAt;
  bool get isApproval =>
      action != null &&
      const {
        'approve',
        'approved',
        'reject',
        'rejected',
        'approval',
        'submitted',
        'submit',
        'pending',
      }.contains(action!.toLowerCase());
}

class NotificationInbox {
  const NotificationInbox({
    required this.items,
    required this.limit,
    this.busy = false,
    this.actionError,
  });
  final List<NotificationItem> items;
  final int limit;
  final bool busy;
  final String? actionError;
  bool get canLoadMore => items.length >= limit;
}
