import 'dart:math';

import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceRegistration {
  const DeviceRegistration({
    required this.installationId,
    required this.platform,
    required this.token,
    required this.idempotencyKey,
    this.appVersion,
  });
  final String installationId;
  final String platform;
  final String token;
  final String idempotencyKey;
  final String? appVersion;
}

abstract interface class DeviceRegistrationRepository {
  Future<void> register(DeviceRegistration registration);
  Future<void> unregister(
    String installationId, {
    required String idempotencyKey,
  });
}

// Console testing obtains real FCM tokens without registering them with the HRIS API.
class ConsoleDeviceRegistrationRepository
    implements DeviceRegistrationRepository {
  @override
  Future<void> register(DeviceRegistration registration) async {}
  @override
  Future<void> unregister(
    String installationId, {
    required String idempotencyKey,
  }) async {}
}

class DioDeviceRegistrationRepository implements DeviceRegistrationRepository {
  const DioDeviceRegistrationRepository(this._dio);
  final Dio _dio;

  @override
  Future<void> register(DeviceRegistration registration) async {
    final id = _bounded(registration.installationId, 8, 200);
    final token = _bounded(registration.token, 20, 4096);
    final platform = registration.platform.trim();
    if (!const {'ANDROID', 'IOS'}.contains(platform)) {
      throw ArgumentError('Platform push tidak valid.');
    }
    final version = registration.appVersion == null
        ? null
        : _bounded(registration.appVersion!, 0, 50);
    await _request('POST', {
      'installationId': id,
      'platform': platform,
      'provider': 'FCM',
      'token': token,
      'appVersion': ?version,
    }, registration.idempotencyKey);
  }

  @override
  Future<void> unregister(
    String installationId, {
    required String idempotencyKey,
  }) => _unregister(installationId, idempotencyKey);

  Future<void> _unregister(String installationId, String key) async {
    await _request('DELETE', {
      'installationId': _bounded(installationId, 8, 200),
    }, key);
  }

  Future<void> _request(
    String method,
    Map<String, dynamic> body,
    String key,
  ) async {
    if (!RegExp(r'^[!-~]{16,128}$').hasMatch(key)) {
      throw ArgumentError('Idempotency key tidak valid.');
    }
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        '/notifications/device-tokens',
        data: body,
        options: Options(
          method: method,
          contentType: Headers.jsonContentType,
          headers: {'Idempotency-Key': key},
        ),
      );
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success) {
        throw const FormatException('Konfirmasi registration tidak valid.');
      }
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}

String _bounded(String value, int minimum, int maximum) {
  final result = value.trim();
  if (result.length < minimum || result.length > maximum) {
    throw ArgumentError('Field registration tidak valid.');
  }
  return result;
}

class InstallationIdentity {
  InstallationIdentity(this._preferences, String namespace)
    : _key = 'push.installation.$namespace';
  final SharedPreferences _preferences;
  final String _key;
  static final _pending = <String, Future<String>>{};

  Future<String> getOrCreate() async {
    final pending = _pending[_key];
    if (pending != null) return pending;
    final operation = _load();
    _pending[_key] = operation;
    try {
      return await operation;
    } finally {
      _pending.remove(_key);
    }
  }

  Future<String> _load() async {
    final stored = _preferences.getString(_key);
    if (stored != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(stored)) {
      return stored;
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    if (!await _preferences.setString(_key, id)) {
      throw StateError('Identitas instalasi gagal disimpan.');
    }
    return id;
  }
}
