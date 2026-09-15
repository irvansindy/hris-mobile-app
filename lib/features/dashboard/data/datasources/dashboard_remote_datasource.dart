import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/dashboard/domain/entities/dashboard_snapshot.dart';

abstract interface class DashboardRemoteDataSource {
  Future<DashboardSnapshot> fetch(
    RequestContext context,
    DashboardSnapshot fallback,
  );
}

class DioDashboardRemoteDataSource implements DashboardRemoteDataSource {
  const DioDashboardRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<DashboardSnapshot> fetch(
    RequestContext context,
    DashboardSnapshot fallback,
  ) async {
    final employeeId = context.employeeId;
    if (employeeId == null || context.activeCompanyId == null) {
      return DashboardSnapshot(
        employee: _employee(context, fallback.employee),
        leaveBalances: const [],
        announcements: const [],
      );
    }

    final responses = await Future.wait<_SectionResponse>([
      _safeGet('/leave/balances/employee', {'employeeId': employeeId}),
      _safeGet('/notifications', {'limit': 3}),
    ]);

    final balances = _leaveBalances(responses[0].data);
    final notifications = _announcements(responses[1].data);
    return DashboardSnapshot(
      employee: _employee(context, fallback.employee),
      leaveBalances: balances,
      announcements: notifications,
      monthlySummary: MonthlySummary(
        remainingLeave: balances.fold<int>(
          0,
          (sum, item) => sum + (item.total - item.used).clamp(0, item.total),
        ),
      ),
      leaveBalancesAvailable: responses[0].error == null,
      monthlySummaryAvailable: false,
      attendanceAvailable: false,
      announcementsAvailable: responses[1].error == null,
      leaveBalancesError: responses[0].error,
      announcementsError: responses[1].error,
      unreadNotifications: _unreadCount(responses[1].data),
    );
  }

  Future<_SectionResponse> _safeGet(
    String path,
    Map<String, Object?> query,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      return _SectionResponse(
        data: ApiEnvelope.fromJson(response.data ?? const {}).data,
      );
    } on DioException catch (error) {
      return _SectionResponse(error: mapDioException(error).message);
    } on FormatException {
      return const _SectionResponse(
        error: 'Format respons server tidak valid.',
      );
    }
  }

  DashboardEmployee _employee(
    RequestContext context,
    DashboardEmployee fallback,
  ) {
    final name = context.displayName?.trim();
    final emailName = context.email?.split('@').first.trim();
    final effectiveName = name != null && name.isNotEmpty
        ? name
        : emailName != null && emailName.isNotEmpty
        ? emailName
        : fallback.name;
    return DashboardEmployee(
      name: effectiveName,
      initials: _initials(effectiveName),
      avatarColorIndex: effectiveName.hashCode.abs() % 4,
    );
  }

  List<LeaveBalance> _leaveBalances(Object? data) {
    final list = _asList(data, const ['balances', 'items', 'leaveBalances']);
    return list.indexed
        .map((entry) {
          final (index, item) = entry;
          final typeObject = item['leaveType'] ?? item['type'];
          final type = typeObject is Map
              ? _text(typeObject, const ['name', 'label', 'code'])
              : typeObject?.toString();
          final total = _integer(item, const [
            'quota',
            'total',
            'entitled',
            'allocated',
          ]);
          final remaining = _integer(item, const [
            'remaining',
            'balance',
            'available',
            'remainingDays',
          ], fallback: total);
          final used = _integer(item, const [
            'used',
            'taken',
            'usedDays',
          ], fallback: (total - remaining).clamp(0, total));
          return LeaveBalance(
            type: type ?? 'Leave',
            total: total,
            used: used,
            colorIndex: index % 4,
          );
        })
        .toList(growable: false);
  }

  List<Announcement> _announcements(Object? data) {
    final items = _asList(data, const ['items', 'notifications']);
    return items
        .where((item) {
          final type = _text(item, const ['category', 'type'])?.toUpperCase();
          return type?.contains('ANNOUNCEMENT') == true;
        })
        .take(3)
        .map((item) {
          final created = _date(item, const ['createdAt', 'created_at']);
          return Announcement(
            title: _text(item, const ['title', 'subject']) ?? 'Notification',
            body: _text(item, const ['message', 'body', 'content']) ?? '',
            time: _relativeTime(created),
            category: _text(item, const ['category', 'type']) ?? 'HRMS',
          );
        })
        .toList(growable: false);
  }

  int _unreadCount(Object? data) {
    final direct = _asMap(data);
    final explicit = direct['unreadCount'];
    if (explicit is num) return explicit.round();
    return _asList(
      data,
      const ['items', 'notifications'],
    ).where((item) => item['isRead'] == false || item['readAt'] == null).length;
  }
}

class _SectionResponse {
  const _SectionResponse({this.data, this.error});
  final Object? data;
  final String? error;
}

Map<String, dynamic> _asMap(Object? data) {
  if (data is Map<String, dynamic>) return data;
  return const {};
}

List<Map<String, dynamic>> _asList(Object? data, List<String> keys) {
  Object? raw = data;
  if (raw is Map<String, dynamic>) {
    final map = raw;
    for (final key in keys) {
      if (map[key] is List) {
        raw = map[key];
        break;
      }
    }
  }
  if (raw is! List) return const [];
  return raw.whereType<Map<String, dynamic>>().toList(growable: false);
}

String? _text(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

int _integer(Map<dynamic, dynamic> map, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) return value.round();
    final parsed = int.tryParse('$value');
    if (parsed != null) return parsed;
  }
  return fallback;
}

DateTime? _date(Map<dynamic, dynamic> map, List<String> keys) {
  final value = _text(map, keys);
  return value == null ? null : DateTime.tryParse(value)?.toLocal();
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}

String _relativeTime(DateTime? date) {
  if (date == null) return '';
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes.clamp(0, 59)} min ago';
  }
  if (difference.inHours < 24) return '${difference.inHours} hours ago';
  return '${difference.inDays} days ago';
}
