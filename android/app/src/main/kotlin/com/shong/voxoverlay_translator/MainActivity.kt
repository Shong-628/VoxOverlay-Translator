package com.shong.voxoverlay_translator

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {

    private lateinit var audioBridge: AudioBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize and configure the bridge
        audioBridge = AudioBridge(this)
        audioBridge.configure(flutterEngine)
    }

    // Forward the permission result from Android to your AudioBridge
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // If AudioBridge doesn't handle the result, pass it to the superclass
        if (!audioBridge.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}