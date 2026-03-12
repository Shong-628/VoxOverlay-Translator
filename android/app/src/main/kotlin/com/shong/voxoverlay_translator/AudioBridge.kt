package com.shong.voxoverlay_translator

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
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
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        result.error("UNSUPPORTED", "Internal audio capture requires Android 10+", null)
                        return@setMethodCallHandler
                    }

                    pendingResult = result
                    val manager = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    val intent = manager.createScreenCaptureIntent()
                    activity.startActivityForResult(intent, 1001)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == 1001) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                // Using .pcm extension because we are saving raw bytes
                val filePath = "${activity.externalCacheDir?.absolutePath}/internal_audio.pcm"

                val serviceIntent = Intent(activity, ProjectionService::class.java).apply {
                    putExtra("RESULT_CODE", resultCode)
                    putExtra("DATA", data)
                    putExtra("PATH", filePath)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startForegroundService(serviceIntent)
                } else {
                    activity.startService(serviceIntent)
                }

                pendingResult?.success(filePath)
                pendingResult = null
                return true
            } else {
                pendingResult?.error("DENIED", "Media Projection permission denied", null)
                pendingResult = null
            }
        }
        return false
    }
}