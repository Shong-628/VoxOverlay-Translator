package com.shong.voxoverlay_translator

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class AudioBridge(private val activity: Activity) : PluginRegistry.ActivityResultListener {

    private val CHANNEL = "voxoverlay/audio"
    private var pendingResult: MethodChannel.Result? = null

    fun configure(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "startInternalCapture") {
                    pendingResult = result
                    val manager = activity.getSystemService(Activity.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    val intent = manager.createScreenCaptureIntent()
                    activity.startActivityForResult(intent, 1001)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == 1001 && resultCode == Activity.RESULT_OK && data != null) {
            val filePath = "${activity.externalCacheDir?.absolutePath}/internal_audio.wav"

            // Start the Foreground Service to handle recording
            val serviceIntent = Intent(activity, ProjectionService::class.java).apply {
                putExtra("RESULT_CODE", resultCode)
                putExtra("DATA", data)
                putExtra("PATH", filePath)
            }
            activity.startForegroundService(serviceIntent)

            // Return the path to Flutter immediately so it knows where the file will be
            pendingResult?.success(filePath)
            return true
        }
        pendingResult?.error("ERROR", "Permission denied", null)
        return false
    }
}