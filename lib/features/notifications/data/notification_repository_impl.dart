import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/notifications/domain/entities/notification_item.dart';
import 'package:hrm_app/features/notifications/domain/repositories/notification_repository.dart';

class DioNotificationRepository implements NotificationRepository {
  const DioNotificationRepository(this._dio, this.context);
  final Dio _dio;
  final RequestContext context;

  @override
  Future<List<NotificationItem>> load({required int limit}) async {
    final response = await _request(
      'GET',
      '/notifications',
      query: {'limit': limit},
    );
    final raw = response.requireListData();
    final ids = <String>{};
    return List.unmodifiable(
      raw.map((item) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            (item['id'] as String).isEmpty ||
            item['title'] is! String ||
            (item['title'] as String).trim().isEmpty ||
            item['isRead'] is! bool ||
            !ids.add(item['id'] as String)) {
          throw const FormatException('Notifikasi tidak valid.');
        }
        if ((item['userId'] != null && item['userId'] != context.userId) ||
            (item['companyId'] != null &&
                item['companyId'] != context.activeCompanyId)) {
          throw const FormatException(
            'Notifikasi tidak sesuai akun/perusahaan aktif.',
          );
        }
        return NotificationItem(
          id: item['id'] as String,
          title: item['title'] as String,
          isRead: item['isRead'] as bool,
          message: _text(item['message']),
          type: _text(item['type']) ?? 'INFO',
          resource: _text(item['resource']),
          action: _text(item['action']),
          referenceId: _text(item['referenceId']),
          createdAt: DateTime.tryParse(
            _text(item['createdAt']) ?? '',
          )?.toLocal(),
        );
      }),
    );
  }

  @override
  Future<int> unreadCount() async {
    final data = (await _request(
      'GET',
      '/notifications/unread-count',
    )).requireObjectData();
    if (data['count'] is! int || (data['count'] as int) < 0) {
      throw const FormatException('Jumlah notifikasi tidak valid.');
    }
    return data['count'] as int;
  }

  @override
  Future<void> read(List<String> ids) async {
    if (ids.isEmpty || ids.any((id) => id.isEmpty)) {
      throw ArgumentError('ID notifikasi diperlukan.');
    }
    await _request('PUT', '/notifications/read', data: {'ids': ids});
  }

  @override
  Future<void> readAll() async {
    await _request('PUT', '/notifications/read-all');
  }

  @override
  Future<void> delete(String id) async {
    final normalized = id.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalized)) {
      throw ArgumentError('ID notifikasi tidak valid.');
    }
    await _request(
      'DELETE',
      '/notifications/${Uri.encodeComponent(normalized)}',
    );
  }

  Future<ApiEnvelope> _request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    if (context.userId == null || context.activeCompanyId == null) {
      throw const ApiException('Sesi akun belum tersedia.');
    }
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
      );
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success) throw FormatException(envelope.message);
      return envelope;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
