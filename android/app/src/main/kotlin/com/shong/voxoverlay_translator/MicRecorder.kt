package com.shong.voxoverlay_translator

import android.media.*

class MicRecorder {

    private val sampleRate = 16000

    private val bufferSize =
        AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

    private val recorder = AudioRecord(
        MediaRecorder.AudioSource.MIC,
        sampleRate,
        AudioFormat.CHANNEL_IN_MONO,
        AudioFormat.ENCODING_PCM_16BIT,
        bufferSize
    )

    fun start(onAudio: (ByteArray) -> Unit) {

        recorder.startRecording()

        Thread {

            val buffer = ByteArray(bufferSize)

            while (true) {

                val read =
                    recorder.read(buffer, 0, buffer.size)

                if (read > 0) {

                    onAudio(buffer.copyOf(read))

                }
            }

        }.start()
    }

    fun stop() {
        recorder.stop()
        recorder.release()
    }
}