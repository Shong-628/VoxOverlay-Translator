package com.shong.voxoverlay_translator

import android.app.*
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream

class ProjectionService : Service() {

    private var mediaProjection: MediaProjection? = null
    private var audioCapture: InternalAudioCapture? = null
    private var fileOutputStream: FileOutputStream? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, "AUDIO_CAPTURE")
            .setContentTitle("Capturing Internal Audio")
            .setContentText("Recording system audio...")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(1, notification)

        val resultCode = intent?.getIntExtra("RESULT_CODE", 0) ?: 0
        val data = intent?.getParcelableExtra<Intent>("DATA")
        val path = intent?.getStringExtra("PATH") ?: ""

        if (data == null || path.isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }

        val mpManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = mpManager.getMediaProjection(resultCode, data)

        // Initialize file output
        val file = File(path)
        fileOutputStream = FileOutputStream(file)

        // Initialize capture with the new callback logic
        audioCapture = InternalAudioCapture(mediaProjection!!) { buffer, readSize ->
            // This is the callback from InternalAudioCapture
            fileOutputStream?.write(buffer, 0, readSize)
        }

        audioCapture?.startRecording()

        // Stop automatically after 5 seconds as per your requirement
        Thread {
            Thread.sleep(5000)
            stopSelf()
        }.start()

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "AUDIO_CAPTURE",
            "Audio Capture",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        audioCapture?.stopRecording()
        mediaProjection?.stop()
        try {
            fileOutputStream?.flush()
            fileOutputStream?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()
    }
}