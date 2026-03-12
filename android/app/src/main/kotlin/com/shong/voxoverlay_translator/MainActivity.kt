package com.shong.voxoverlay_translator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent

class MainActivity: FlutterActivity() {

    private var audioBridge: AudioBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Pass 'this' as the activity to the bridge
        audioBridge = AudioBridge(this)
        audioBridge?.let {
            it.configure(flutterEngine)

            // Register the ActivityResultListener with the Flutter Engine's internal registry if needed
            // However, overriding onActivityResult is usually sufficient for simple setups.
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Forward the result to the bridge
        val handled = audioBridge?.onActivityResult(requestCode, resultCode, data) ?: false
        if (!handled) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}