// android/app/src/main/cpp/whisper_bridge.cpp
#include "whisper.h"
#include <string>
#include <vector>

extern "C" {
// 1. Initialize the model
__attribute__((visibility("default"))) __attribute__((used))
struct whisper_context* bridge_whisper_init(const char* model_path) {
    struct whisper_context_params cparams = whisper_context_default_params();
    return whisper_init_from_file_with_params(model_path, cparams);
}

// 2. Transcribe and return text
__attribute__((visibility("default"))) __attribute__((used))
const char* bridge_whisper_transcribe(struct whisper_context* ctx, float* pcmf32, int n_samples) {
    if (ctx == nullptr) return "";

    whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.print_progress = false;
    wparams.print_timestamps = false;
    wparams.single_segment = true;
    wparams.language = "en"; // Set to "auto" if you want auto-detect

    if (whisper_full(ctx, wparams, pcmf32, n_samples) != 0) {
        return ""; // Failed to process
    }

    const int n_segments = whisper_full_n_segments(ctx);
    static std::string result; // Static to keep memory alive for Dart to read
    result = "";

    for (int i = 0; i < n_segments; ++i) {
        const char* text = whisper_full_get_segment_text(ctx, i);
        if (text) result += text;
    }

    return result.c_str();
}

// 3. Free memory
__attribute__((visibility("default"))) __attribute__((used))
void bridge_whisper_free(struct whisper_context* ctx) {
    if (ctx != nullptr) {
        whisper_free(ctx);
    }
}
}