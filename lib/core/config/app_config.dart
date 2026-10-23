import 'package:flutter/foundation.dart';

enum AppEnvironment { development, production }

enum PushMode { disabled, dummy, firebase }

class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

class AppConfig {
  static const _definedEnvironment = String.fromEnvironment('APP_ENV');
  static const _definedBaseUrl = String.fromEnvironment('BASE_URL');
  static const _definedConnectTimeout = String.fromEnvironment(
    'CONNECT_TIMEOUT_MS',
  );
  static const _definedReceiveTimeout = String.fromEnvironment(
    'RECEIVE_TIMEOUT_MS',
  );
  static const _definedLogging = String.fromEnvironment('ENABLE_LOGGING');
  static const _definedPushMode = String.fromEnvironment('PUSH_MODE');

  static const developmentBaseUrl = 'http://srv540825.hstgr.cloud:8084/api/v1';

  const AppConfig({
    required this.baseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.enableNetworkLogs,
    this.environment = AppEnvironment.development,
    this.pushMode = PushMode.disabled,
  });

  factory AppConfig.fromEnvironment({
    Map<String, String> values = const {},
    bool? productionBuild,
  }) {
    final isProductionBuild = productionBuild ?? (kReleaseMode || kProfileMode);
    final configuredEnvironment = _value(
      values,
      'APP_ENV',
      _definedEnvironment,
    );
    final environment = _parseEnvironment(
      configuredEnvironment,
      productionBuild: isProductionBuild,
    );
    final baseUrl =
        _value(values, 'BASE_URL', _definedBaseUrl) ??
        (environment == AppEnvironment.development ? developmentBaseUrl : null);
    if (baseUrl == null) {
      throw const AppConfigException(
        'BASE_URL wajib diisi untuk build production. Gunakan URL HTTPS melalui '
        '--dart-define atau --dart-define-from-file.',
      );
    }
    _validateBaseUrl(baseUrl, environment: environment);

    final enableNetworkLogs = _parseBool(
      'ENABLE_LOGGING',
      _value(values, 'ENABLE_LOGGING', _definedLogging) ?? 'false',
    );
    if (environment == AppEnvironment.production && enableNetworkLogs) {
      throw const AppConfigException(
        'ENABLE_LOGGING harus false pada environment production.',
      );
    }

    return AppConfig(
      baseUrl: baseUrl,
      connectTimeout: Duration(
        milliseconds: _parsePositiveMilliseconds(
          'CONNECT_TIMEOUT_MS',
          _value(values, 'CONNECT_TIMEOUT_MS', _definedConnectTimeout) ??
              '15000',
        ),
      ),
      receiveTimeout: Duration(
        milliseconds: _parsePositiveMilliseconds(
          'RECEIVE_TIMEOUT_MS',
          _value(values, 'RECEIVE_TIMEOUT_MS', _definedReceiveTimeout) ??
              '15000',
        ),
      ),
      enableNetworkLogs: enableNetworkLogs,
      environment: environment,
      pushMode: _parsePushMode(
        _value(values, 'PUSH_MODE', _definedPushMode) ?? 'disabled',
        productionBuild: isProductionBuild,
        environment: environment,
      ),
    );
  }

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final bool enableNetworkLogs;
  final AppEnvironment environment;
  final PushMode pushMode;
}

PushMode _parsePushMode(
  String value, {
  required bool productionBuild,
  required AppEnvironment environment,
}) {
  final mode = switch (value.toLowerCase()) {
    'disabled' => PushMode.disabled,
    'dummy' => PushMode.dummy,
    'firebase' => PushMode.firebase,
    _ => throw const AppConfigException(
      'PUSH_MODE harus disabled, dummy, atau firebase.',
    ),
  };
  if (mode == PushMode.firebase &&
      (productionBuild || environment != AppEnvironment.development)) {
    throw const AppConfigException(
      'PUSH_MODE=firebase sementara hanya tersedia pada development debug Android.',
    );
  }
  if (productionBuild && mode == PushMode.dummy) {
    throw const AppConfigException(
      'PUSH_MODE=dummy hanya tersedia pada build debug.',
    );
  }
  return mode;
}

String? _value(
  Map<String, String> values,
  String key,
  String compileTimeValue,
) {
  final value = values.containsKey(key) ? values[key] : compileTimeValue;
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

AppEnvironment _parseEnvironment(
  String? value, {
  required bool productionBuild,
}) {
  final normalized = value?.toLowerCase();
  if (productionBuild && normalized != null && normalized != 'production') {
    throw const AppConfigException(
      'Build release/profile tidak boleh memakai APP_ENV=development.',
    );
  }
  if (productionBuild || normalized == 'production') {
    return AppEnvironment.production;
  }
  if (normalized == null || normalized == 'development') {
    return AppEnvironment.development;
  }
  throw AppConfigException(
    'APP_ENV "$value" tidak valid. Gunakan development atau production.',
  );
}

void _validateBaseUrl(String value, {required AppEnvironment environment}) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasScheme ||
      !uri.hasAuthority ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const AppConfigException(
      'BASE_URL harus berupa URL absolut HTTP(S) tanpa credential, query, atau '
      'fragment, misalnya https://api.example.com/api/v1.',
    );
  }
  if (environment == AppEnvironment.production && uri.scheme != 'https') {
    throw const AppConfigException(
      'BASE_URL production wajib memakai HTTPS; fallback HTTP hanya tersedia '
      'untuk development.',
    );
  }
}

bool _parseBool(String key, String value) {
  switch (value.toLowerCase()) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      throw AppConfigException('$key harus bernilai true atau false.');
  }
}

int _parsePositiveMilliseconds(String key, String value) {
  final milliseconds = int.tryParse(value);
  if (milliseconds == null || milliseconds <= 0) {
    throw AppConfigException('$key harus berupa bilangan bulat positif.');
  }
  return milliseconds;
}
