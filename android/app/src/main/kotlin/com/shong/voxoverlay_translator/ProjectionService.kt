package com.shong.voxoverlay_translator

import android.app.*
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.IBinder
import androidx.core.app.NotificationCompat

class ProjectionService : Service() {

    private var mediaProjection: MediaProjection? = null
    private var audioCapture: InternalAudioCapture? = null

    fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, "AUDIO_CAPTURE")
            .setContentTitle("Capturing Internal Audio")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now) // Use your own icon here later
            .build()

        startForeground(1, notification)

        val resultCode = intent!!.getIntExtra("RESULT_CODE", 0)
        val data = intent.getParcelableExtra<Intent>("DATA")!!
        val path = intent.getStringExtra("PATH")!!

        val mpManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = mpManager.getMediaProjection(resultCode, data)

        // Initialize your custom capture class and start
        audioCapture = InternalAudioCapture(mediaProjection!!)
        audioCapture?.startRecording(path)

        // Stop automatically after 5 seconds to match your Flutter fallback logic
        Thread {
            Thread.sleep(5000)
            audioCapture?.stopRecording()
            stopSelf() // Shut down the service
        }.start()

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel("AUDIO_CAPTURE", "Audio Capture", NotificationManager.IMPORTANCE_LOW)
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        audioCapture?.stopRecording()
        mediaProjection?.stop()
        super.onDestroy()
    }
}