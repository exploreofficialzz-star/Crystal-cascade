package com.chastechgroup.crystalcascade

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.chastechgroup.crystalcascade/install_source"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInstallerPackageName") {
                try {
                    val installer: String? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        // getInstallerPackageName() is deprecated from API 30+.
                        packageManager.getInstallSourceInfo(packageName).installingPackageName
                    } else {
                        @Suppress("DEPRECATION")
                        packageManager.getInstallerPackageName(packageName)
                    }
                    result.success(installer)
                } catch (e: Exception) {
                    // Unknown/unavailable — Paystack fallback path treats this as "not Play Store".
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
