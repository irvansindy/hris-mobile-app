import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/features/notifications/push/push_registration.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'db926457-a044-4930-a362-786c288a8485';
DeviceRegistration _command({
  String? id,
  String? token,
  String platform = 'ANDROID',
  String? appVersion,
}) => DeviceRegistration(
  installationId: id ?? 'installation-1234',
  platform: platform,
  token: token ?? 'mock-fcm-token-at-least-twenty-chars',
  idempotencyKey: _key,
  appVersion: appVersion,
);

void main() {
  test(
    'register sends FCM payload and retry retains idempotency header',
    () async {
      final adapter = _RegistryHttp();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repo = DioDeviceRegistrationRepository(dio);
      final command = _command(appVersion: '1.0.0');
      await repo.register(command);
      await repo.register(command);
      expect(adapter.requests.first.method, 'POST');
      expect(adapter.requests.first.path, '/notifications/device-tokens');
      expect(adapter.requests.first.data, {
        'installationId': 'installation-1234',
        'platform': 'ANDROID',
        'provider': 'FCM',
        'token': 'mock-fcm-token-at-least-twenty-chars',
        'appVersion': '1.0.0',
      });
      expect(adapter.requests.map((r) => r.headers['Idempotency-Key']), [
        _key,
        _key,
      ]);
    },
  );
  test('unregister sends JSON body with installation ID only', () async {
    final adapter = _RegistryHttp();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    await DioDeviceRegistrationRepository(
      dio,
    ).unregister('installation-1234', idempotencyKey: _key);
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.data, {
      'installationId': 'installation-1234',
    });
    expect(adapter.requests.single.headers['Idempotency-Key'], _key);
    expect(adapter.requests.single.contentType, Headers.jsonContentType);
  });
  for (final size in [7, 201]) {
    test('rejects installation ID length $size before network', () async {
      final adapter = _RegistryHttp();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repo = DioDeviceRegistrationRepository(dio);
      await expectLater(
        repo.register(_command(id: 'x' * size)),
        throwsArgumentError,
      );
      await expectLater(
        repo.unregister('x' * size, idempotencyKey: _key),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  }
  for (final size in [19, 4097]) {
    test('rejects token length $size before network', () async {
      final adapter = _RegistryHttp();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      await expectLater(
        DioDeviceRegistrationRepository(
          dio,
        ).register(_command(token: 'x' * size)),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    });
  }
  test('accepts boundary lengths and IOS FCM, trims strings', () async {
    final adapter = _RegistryHttp();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final repo = DioDeviceRegistrationRepository(dio);
    await repo.register(
      _command(id: ' 12345678 ', token: 't' * 20, platform: 'IOS'),
    );
    await repo.register(_command(id: 'i' * 200, token: 't' * 4096));
    expect(adapter.requests.first.data['installationId'], '12345678');
    expect(adapter.requests.first.data['platform'], 'IOS');
    expect(adapter.requests.first.data['provider'], 'FCM');
  });
  test('rejects invalid platform version and idempotency key', () async {
    final adapter = _RegistryHttp();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final repo = DioDeviceRegistrationRepository(dio);
    await expectLater(
      repo.register(_command(platform: 'WEB')),
      throwsArgumentError,
    );
    await expectLater(
      repo.register(_command(appVersion: 'v' * 51)),
      throwsArgumentError,
    );
    await expectLater(
      repo.unregister('installation-1234', idempotencyKey: '\ninvalid'),
      throwsArgumentError,
    );
    expect(adapter.requests, isEmpty);
  });
  test('idempotency key follows visible ASCII 16 to 128 contract', () async {
    final adapter = _RegistryHttp();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final repo = DioDeviceRegistrationRepository(dio);
    await expectLater(
      repo.unregister('installation-1234', idempotencyKey: 'x' * 15),
      throwsArgumentError,
    );
    await repo.unregister('installation-1234', idempotencyKey: '!' * 16);
    await repo.unregister('installation-1234', idempotencyKey: '~' * 128);
    await expectLater(
      repo.unregister('installation-1234', idempotencyKey: 'x' * 129),
      throwsArgumentError,
    );
    expect(adapter.requests, hasLength(2));
  });
  test('maps backend validation error without exposing push token', () async {
    final dio = Dio()..httpClientAdapter = _RegistryHttp(status: 422);
    addTearDown(dio.close);
    await expectLater(
      DioDeviceRegistrationRepository(dio).register(_command()),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'VALIDATION_ERROR'),
      ),
    );
  });
  test('rejects false success envelope', () async {
    final dio = Dio()..httpClientAdapter = _RegistryHttp(failure: true);
    addTearDown(dio.close);
    await expectLater(
      DioDeviceRegistrationRepository(dio).register(_command()),
      throwsFormatException,
    );
  });
  test(
    'installation identity persists across instances and namespaces differ',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = await InstallationIdentity(
        prefs,
        'development',
      ).getOrCreate();
      await prefs.reload();
      expect(
        await InstallationIdentity(prefs, 'development').getOrCreate(),
        first,
      );
      expect(first, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(
        await InstallationIdentity(prefs, 'production').getOrCreate(),
        isNot(first),
      );
      final both = await Future.wait([
        InstallationIdentity(prefs, 'development').getOrCreate(),
        InstallationIdentity(prefs, 'development').getOrCreate(),
      ]);
      expect(both, [first, first]);
    },
  );
}

class _RegistryHttp implements HttpClientAdapter {
  _RegistryHttp({this.status, this.failure = false});
  final int? status;
  final bool failure;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': !failure && status == null,
        'message': status == null ? 'Success' : 'Invalid input',
        if (status != null) 'code': 'VALIDATION_ERROR',
        'data': null,
      }),
      status ?? (options.method == 'POST' ? 201 : 200),
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
