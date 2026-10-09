import 'package:flutter/services.dart';

class SensitiveScreenController {
  const SensitiveScreenController();

  static const _channel = MethodChannel('hris_mobile/sensitive_screen');

  Future<void> enable() => _setSensitive(true);

  Future<void> disable() => _setSensitive(false);

  Future<void> _setSensitive(bool value) async {
    try {
      await _channel.invokeMethod<void>('setSensitive', value);
    } on MissingPluginException {
      // Unsupported platforms still use the in-app privacy cover.
    } on PlatformException {
      // The viewer remains usable when a platform cannot enforce protection.
    }
  }
}
