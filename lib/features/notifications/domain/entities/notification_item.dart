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

class NotificationPage {
  NotificationPage({
    required List<NotificationItem> items,
    required this.page,
    required this.totalPages,
    required this.total,
  }) : items = List.unmodifiable(items);
  final List<NotificationItem> items;
  final int page;
  final int totalPages;
  final int total;
}

class NotificationInbox {
  const NotificationInbox({
    required this.items,
    required this.limit,
    required this.page,
    required this.totalPages,
    required this.total,
    this.busy = false,
    this.actionError,
  });
  final List<NotificationItem> items;
  final int limit;
  final int page;
  final int totalPages;
  final int total;
  final bool busy;
  final String? actionError;
  bool get canLoadMore => page < totalPages;

  NotificationInbox copyWith({
    List<NotificationItem>? items,
    bool busy = false,
    String? actionError,
  }) => NotificationInbox(
    items: items ?? this.items,
    limit: limit,
    page: page,
    totalPages: totalPages,
    total: total,
    busy: busy,
    actionError: actionError,
  );
}
