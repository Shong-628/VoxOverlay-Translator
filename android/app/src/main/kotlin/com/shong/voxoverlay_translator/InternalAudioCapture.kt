package com.shong.voxoverlay_translator

import android.media.*
import android.media.projection.MediaProjection
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile

class InternalAudioCapture(private val projection: MediaProjection) {

    private var recorder: AudioRecord? = null
    private var isRecording = false

    fun startRecording(path: String) {
        val sampleRate = 16000

        val config = AudioPlaybackCaptureConfiguration.Builder(projection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .build()

        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

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

        val file = File(path)
        val fos = FileOutputStream(file)

        // 1. Write an empty 44-byte placeholder for the WAV header
        writeWavHeader(fos)

        recorder?.startRecording()
        isRecording = true

        Thread {
            val buffer = ByteArray(bufferSize)
            while (isRecording) {
                val read = recorder?.read(buffer, 0, buffer.size) ?: 0
                if (read > 0) {
                    fos.write(buffer, 0, read)
                }
            }

            // 2. When recording stops, close the stream and finalize the WAV header
            fos.close()
            updateWavHeader(file, sampleRate)
        }.start()
    }

    fun stopRecording() {
        isRecording = false
        recorder?.stop()
        recorder?.release()
    }

    // --- WAV Header Helpers ---

    private fun writeWavHeader(out: FileOutputStream) {
        val header = ByteArray(44) // Placeholder array of zeroes
        out.write(header)
    }

    private fun updateWavHeader(file: File, sampleRate: Int) {
        val raf = RandomAccessFile(file, "rw")
        val fileSize = file.length()
        val channels = 1
        val byteRate = sampleRate * channels * 2

        raf.seek(0)
        raf.writeBytes("RIFF")
        raf.writeInt(Integer.reverseBytes((fileSize - 8).toInt()))
        raf.writeBytes("WAVE")
        raf.writeBytes("fmt ")
        raf.writeInt(Integer.reverseBytes(16))
        raf.writeShort(java.lang.Short.reverseBytes(1.toShort()).toInt()) // PCM format = 1
        raf.writeShort(java.lang.Short.reverseBytes(channels.toShort()).toInt())
        raf.writeInt(Integer.reverseBytes(sampleRate))
        raf.writeInt(Integer.reverseBytes(byteRate))
        raf.writeShort(java.lang.Short.reverseBytes((channels * 2).toShort()).toInt())
        raf.writeShort(java.lang.Short.reverseBytes(16.toShort()).toInt()) // 16-bit
        raf.writeBytes("data")
        raf.writeInt(Integer.reverseBytes((fileSize - 44).toInt()))
        raf.close()
    }
}