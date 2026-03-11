package com.shong.voxoverlay_translator

object WhisperBridge {

    init {
        System.loadLibrary("voxoverlay_native")
    }

    external fun transcribe(audioPath: String): String
}