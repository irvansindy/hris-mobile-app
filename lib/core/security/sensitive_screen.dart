import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SensitiveScreenController {
  const SensitiveScreenController();

  static const _channel = MethodChannel('hris_mobile/sensitive_screen');
  static int _activeScreens = 0;

  Future<void> enable() {
    _activeScreens++;
    return _setSensitive(true);
  }

  Future<void> disable() {
    if (_activeScreens > 0) _activeScreens--;
    return _setSensitive(_activeScreens > 0);
  }

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

class SensitiveScreen extends StatefulWidget {
  const SensitiveScreen({super.key, required this.child});
  final Widget child;

  @override
  State<SensitiveScreen> createState() => _SensitiveScreenState();
}

class _SensitiveScreenState extends State<SensitiveScreen> {
  final _controller = const SensitiveScreenController();

  @override
  void initState() {
    super.initState();
    _controller.enable();
  }

  @override
  void dispose() {
    _controller.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
