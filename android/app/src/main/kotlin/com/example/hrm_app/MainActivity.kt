package com.example.hrm_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hris_mobile/sensitive_screen"
        ).setMethodCallHandler { call, result ->
            if (call.method != "setSensitive") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val enabled = call.arguments as? Boolean
            if (enabled == null) {
                result.error("INVALID_ARGUMENT", "Expected a boolean value.", null)
                return@setMethodCallHandler
            }
            runOnUiThread {
                if (enabled) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
        }
    }
}
