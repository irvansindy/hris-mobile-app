import 'package:flutter/widgets.dart';

class PayrollLifecycleLock with WidgetsBindingObserver {
  PayrollLifecycleLock(this._lock);

  final VoidCallback _lock;
  bool _observing = false;

  void start() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  void stop() {
    if (!_observing) return;
    WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _lock();
    }
  }
}
