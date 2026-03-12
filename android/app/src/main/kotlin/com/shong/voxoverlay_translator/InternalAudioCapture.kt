package com.shong.voxoverlay_translator

import android.media.*
import android.media.projection.MediaProjection
import android.os.Build

class InternalAudioCapture(
    private val projection: MediaProjection,
    private val onAudioChunk: (ByteArray, Int) -> Unit
) {

    private var recorder: AudioRecord? = null

    @Volatile
    private var isRecording = false

    private var recordingThread: Thread? = null

    fun startRecording() {

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw RuntimeException("Internal audio capture requires Android 10+")
        }

        val sampleRate = 16000

        val config = AudioPlaybackCaptureConfiguration.Builder(projection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .build()

        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ) * 2

        recorder = AudioRecord.Builder()
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setAudioPlaybackCaptureConfig(config)
            .build()

        if (recorder?.state != AudioRecord.STATE_INITIALIZED) {
            throw RuntimeException("AudioRecord initialization failed")
        }

        recorder?.startRecording()
        isRecording = true

        recordingThread = Thread {

            val buffer = ByteArray(bufferSize)

            while (isRecording) {

                val read = recorder?.read(buffer, 0, buffer.size) ?: 0

                if (read > 0) {

                    // send PCM chunk to consumer
                    onAudioChunk(buffer, read)

                } else if (read < 0) {

                    break
                }
            }
        }

        recordingThread?.start()
    }

    fun stopRecording() {

        isRecording = false

        try {
            recorder?.stop()
        } catch (_: Exception) {
        }

        recorder?.release()
        recorder = null

        try {
            recordingThread?.join()
        } catch (_: Exception) {
        }

        recordingThread = null
    }
}