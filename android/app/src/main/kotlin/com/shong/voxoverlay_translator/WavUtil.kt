package com.shong.voxoverlay_translator

import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

class WavUtil {

    fun writeWavFile(pcmData: ByteArray, filePath: String) {
        val file = File(filePath)
        file.parentFile?.mkdirs() // Ensure directories exist

        val totalAudioLen = pcmData.size.toLong()
        val totalDataLen = totalAudioLen + 36
        val sampleRate = 16000
        val channels = 1
        val bitsPerSample = 16
        val byteRate = sampleRate * channels * bitsPerSample / 8

        val header = ByteArray(44)

        // RIFF header
        header[0] = 'R'.code.toByte()
        header[1] = 'I'.code.toByte()
        header[2] = 'F'.code.toByte()
        header[3] = 'F'.code.toByte()
        writeIntToByteArray(header, 4, totalDataLen.toInt()) // Chunk size
        header[8] = 'W'.code.toByte()
        header[9] = 'A'.code.toByte()
        header[10] = 'V'.code.toByte()
        header[11] = 'E'.code.toByte()

        // fmt subchunk
        header[12] = 'f'.code.toByte()
        header[13] = 'm'.code.toByte()
        header[14] = 't'.code.toByte()
        header[15] = ' '.code.toByte()
        writeIntToByteArray(header, 16, 16) // Subchunk1Size
        writeShortToByteArray(header, 20, 1) // AudioFormat PCM
        writeShortToByteArray(header, 22, channels.toShort())
        writeIntToByteArray(header, 24, sampleRate)
        writeIntToByteArray(header, 28, byteRate)
        writeShortToByteArray(header, 32, (channels * bitsPerSample / 8).toShort()) // BlockAlign
        writeShortToByteArray(header, 34, bitsPerSample.toShort())

        // data subchunk
        header[36] = 'd'.code.toByte()
        header[37] = 'a'.code.toByte()
        header[38] = 't'.code.toByte()
        header[39] = 'a'.code.toByte()
        writeIntToByteArray(header, 40, totalAudioLen.toInt())

        // Write to file safely
        FileOutputStream(file).use { output ->
            output.write(header)
            output.write(pcmData)
        }
    }

    // Helper functions to write little-endian data
    private fun writeIntToByteArray(array: ByteArray, offset: Int, value: Int) {
        val buffer = ByteBuffer.allocate(4)
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        buffer.putInt(value)
        System.arraycopy(buffer.array(), 0, array, offset, 4)
    }

    private fun writeShortToByteArray(array: ByteArray, offset: Int, value: Short) {
        val buffer = ByteBuffer.allocate(2)
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        buffer.putShort(value)
        System.arraycopy(buffer.array(), 0, array, offset, 2)
    }
}