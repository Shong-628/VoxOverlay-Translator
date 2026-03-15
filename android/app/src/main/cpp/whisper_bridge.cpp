// android/app/src/main/cpp/whisper_bridge.cpp
#include "whisper.h"
#include <string>
#include <vector>
#include <thread>
#include <algorithm>
#include <cstring> // Required for strdup
#include <cstdlib> // Required for free

extern "C" {
// 1. Initialize the model (No changes needed)
__attribute__((visibility("default"))) __attribute__((used))
struct whisper_context* bridge_whisper_init(const char* model_path) {
    struct whisper_context_params cparams = whisper_context_default_params();
    return whisper_init_from_file_with_params(model_path, cparams);
}

// 2. Transcribe and return text safely
__attribute__((visibility("default"))) __attribute__((used))
const char* bridge_whisper_transcribe(struct whisper_context* ctx, float* pcmf32, int n_samples) {
    if (ctx == nullptr) return nullptr; // Return null instead of "" for safety

    whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.print_progress = false;
    wparams.print_timestamps = false;
    wparams.single_segment = true;
    wparams.language = "en";
    wparams.n_threads = std::min(4, (int)std::thread::hardware_concurrency());

    if (whisper_full(ctx, wparams, pcmf32, n_samples) != 0) {
        return nullptr;
    }

    const int n_segments = whisper_full_n_segments(ctx);

    // Use a local string, completely thread-safe
    std::string local_result = "";
    for (int i = 0; i < n_segments; ++i) {
        const char* text = whisper_full_get_segment_text(ctx, i);
        if (text) local_result += text;
    }

    // strdup allocates NEW memory on the heap containing a copy of the string.
    // Dart must read this, then command C++ to free it.
    return strdup(local_result.c_str());
}

// 3. NEW: Free the string memory specifically
__attribute__((visibility("default"))) __attribute__((used))
void bridge_whisper_free_string(const char* str) {
    if (str != nullptr) {
        free((void*)str);
    }
}

// 4. Free model memory (No changes needed)
__attribute__((visibility("default"))) __attribute__((used))
void bridge_whisper_free(struct whisper_context* ctx) {
    if (ctx != nullptr) {
        whisper_free(ctx);
    }
}
}