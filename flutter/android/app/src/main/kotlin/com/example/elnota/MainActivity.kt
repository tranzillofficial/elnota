package com.example.elnota

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var deviceLinks: MethodChannel? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deviceLinks = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elnota/device_links")
        deviceLinks?.setMethodCallHandler { call, result ->
            if (call.method == "initialLink") {
                val link = intent?.dataString
                intent?.data = null
                result.success(link)
            } else result.notImplemented()
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { deviceLinks?.invokeMethod("link", it) }
        intent.data = null
    }
}
