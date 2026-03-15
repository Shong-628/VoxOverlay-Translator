package com.shong.voxoverlay_translator

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "vox_overlay/window"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Listen for messages from your Dart NativeWindowService
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "bringToForeground") {
                bringAppToFront()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun bringAppToFront() {
        // Creates an intent targeting this exact activity
        val intent = Intent(this, MainActivity::class.java)

        // These specific flags force Android to wake the app and pull it to the front
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        startActivity(intent)
    }
}