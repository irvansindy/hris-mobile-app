import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('development keeps an explicit, development-only HTTP fallback', () {
      final config = AppConfig.fromEnvironment(productionBuild: false);

      expect(config.environment, AppEnvironment.development);
      expect(config.baseUrl, AppConfig.developmentBaseUrl);
      expect(config.enableNetworkLogs, isFalse);
      expect(config.pushMode, PushMode.disabled);
    });

    test('dummy push is allowed in debug, including production data', () {
      for (final environment in ['development', 'production']) {
        final config = AppConfig.fromEnvironment(
          productionBuild: false,
          values: {
            'APP_ENV': environment,
            'BASE_URL': 'https://api.example.test/api/v1',
            'PUSH_MODE': 'dummy',
          },
        );
        expect(config.pushMode, PushMode.dummy);
      }
    });

    test('profile/release rejects dummy push even with valid HTTPS', () {
      expect(
        () => AppConfig.fromEnvironment(
          productionBuild: true,
          values: const {
            'BASE_URL': 'https://api.example.test/api/v1',
            'PUSH_MODE': 'dummy',
          },
        ),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.message,
            'setting',
            contains('PUSH_MODE'),
          ),
        ),
      );
      final config = AppConfig.fromEnvironment(
        productionBuild: true,
        values: const {
          'BASE_URL': 'https://api.example.test/api/v1',
          'PUSH_MODE': 'disabled',
        },
      );
      expect(config.pushMode, PushMode.disabled);
    });

    test('unknown push mode is rejected instead of activating a service', () {
      expect(
        () => AppConfig.fromEnvironment(
          productionBuild: false,
          values: const {'PUSH_MODE': 'firebase'},
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('production requires an explicit BASE_URL', () {
      expect(
        () => AppConfig.fromEnvironment(productionBuild: true),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.message,
            'message',
            contains('BASE_URL wajib diisi'),
          ),
        ),
      );
    });

    test('production rejects HTTP and development environment overrides', () {
      expect(
        () => AppConfig.fromEnvironment(
          productionBuild: true,
          values: const {'BASE_URL': 'http://api.example.test/api/v1'},
        ),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.message,
            'message',
            contains('wajib memakai HTTPS'),
          ),
        ),
      );
      expect(
        () => AppConfig.fromEnvironment(
          productionBuild: true,
          values: const {
            'APP_ENV': 'development',
            'BASE_URL': 'https://api.example.test/api/v1',
          },
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('production accepts HTTPS with logging disabled', () {
      final config = AppConfig.fromEnvironment(
        productionBuild: true,
        values: const {
          'APP_ENV': 'production',
          'BASE_URL': 'https://api.example.test/api/v1',
          'CONNECT_TIMEOUT_MS': '9000',
          'RECEIVE_TIMEOUT_MS': '11000',
          'ENABLE_LOGGING': 'false',
        },
      );

      expect(config.environment, AppEnvironment.production);
      expect(config.baseUrl, 'https://api.example.test/api/v1');
      expect(config.connectTimeout, const Duration(milliseconds: 9000));
      expect(config.receiveTimeout, const Duration(milliseconds: 11000));
    });

    test('production rejects network logging', () {
      expect(
        () => AppConfig.fromEnvironment(
          productionBuild: true,
          values: const {
            'BASE_URL': 'https://api.example.test/api/v1',
            'ENABLE_LOGGING': 'true',
          },
        ),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.message,
            'message',
            contains('ENABLE_LOGGING harus false'),
          ),
        ),
      );
    });

    test('invalid URL and timeout values fail with the setting name', () {
      expect(
        () => AppConfig.fromEnvironment(
          productionBuild: false,
          values: const {'BASE_URL': 'https://user:secret@example.test/api'},
        ),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.message,
            'message',
            contains('tanpa credential'),
          ),
        ),
      );
      expect(
        () => AppConfig.fromEnvironment(
          productionBuild: false,
          values: const {'CONNECT_TIMEOUT_MS': '0'},
        ),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.message,
            'message',
            contains('CONNECT_TIMEOUT_MS'),
          ),
        ),
      );
    });
  });
}
