package com.shong.voxoverlay_translator

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.content.Context
import android.media.projection.MediaProjectionManager

class MainActivity : FlutterActivity() {
    // If you need to handle screen capture, it should be done inside the class.
    /*
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(projectionManager.createScreenCaptureIntent(), 1)
    }
    */
}
