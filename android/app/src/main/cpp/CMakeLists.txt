cmake_minimum_required(VERSION 3.14.1)

project(whisper_flutter)

# Modern whisper/ggml runs best on C11 and C++14 (some newer commits prefer C++17)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17) # Bumped to 17 to be safe with modern ggml updates

# --- CRITICAL: Force Aggressive Optimization ---
# Whisper relies heavily on fast math, but modern ggml requires INFINITY and NAN.
# We use -O3 for speed, but explicitly AVOID the aggressive -ffast-math flag.
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3")

# Prevent SIGILL on older/specific ARM chips (like the Helio P95)
if (ANDROID_ABI STREQUAL "armeabi-v7a")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpu=neon -mfloat-abi=softfp")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpu=neon -mfloat-abi=softfp")
endif()

# -----------------------------------------------------------------------------
# 1. Configure the official whisper.cpp repository
# -----------------------------------------------------------------------------
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)

# Note: This assumes you cloned whisper.cpp directly into src/main/cpp/
add_subdirectory(whisper.cpp)

# -----------------------------------------------------------------------------
# 2. Build your custom Dart FFI Bridge
# -----------------------------------------------------------------------------
add_library(whisper_native SHARED
        whisper_bridge.cpp
)

target_include_directories(whisper_native PRIVATE
        whisper.cpp/include
        whisper.cpp/ggml/include
)

# -----------------------------------------------------------------------------
# 3. Link Everything Together
# -----------------------------------------------------------------------------
find_library(log-lib log)

# Modern whisper.cpp separates ggml into its own target.
# We explicitly link 'ggml' to avoid undefined reference errors.
target_link_libraries(whisper_native
        whisper
        ggml
        ${log-lib}
)