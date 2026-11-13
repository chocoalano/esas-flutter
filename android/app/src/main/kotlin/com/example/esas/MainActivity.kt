package com.example.esas

import android.annotation.SuppressLint
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The handset identifier attendance is bound to (CORE-03).
        //
        // ANDROID_ID is unique per handset, user and signing key, and survives
        // an OS update and a reinstall. `Build.ID` — what the app sent before —
        // is a firmware label shared by every phone on the same build.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "esas/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "androidId" -> result.success(androidId())
                    else -> result.notImplemented()
                }
            }

        // The attendance device key (ADR-D): a separate channel, so the CORE-03
        // identifier above is left exactly as it was.
        DeviceKeyChannel(applicationContext)
            .register(flutterEngine.dartExecutor.binaryMessenger)
    }

    @SuppressLint("HardwareIds")
    private fun androidId(): String? =
        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
}
