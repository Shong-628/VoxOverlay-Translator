# android/app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.14.1)

project(whisper_flutter)

# Modern whisper/ggml runs best on C11 and C++14
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 14)

# Prevent SIGILL on older/specific ARM chips (like the Helio P95)
if (ANDROID_ABI STREQUAL "armeabi-v7a")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpu=neon -mfloat-abi=softfp")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpu=neon -mfloat-abi=softfp")
endif()

# -----------------------------------------------------------------------------
# 1. Configure the official whisper.cpp repository
# -----------------------------------------------------------------------------
# Turn off executables, tests, and server builds so we only compile the core library
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)

# Add the cloned repository directory (Ensure the folder is actually named 'whisper.cpp')
add_subdirectory(whisper.cpp)

# -----------------------------------------------------------------------------
# 2. Build your custom Dart FFI Bridge
# -----------------------------------------------------------------------------
# We now ONLY compile your bridge file directly. The rest is handled by the repo.
add_library(whisper_native SHARED
        whisper_bridge.cpp
)

# Tell your bridge where to find "whisper.h" in the new modern repo structure
target_include_directories(whisper_native PRIVATE
        whisper.cpp/include
        whisper.cpp/ggml/include
)

# -----------------------------------------------------------------------------
# 3. Link Everything Together
# -----------------------------------------------------------------------------
find_library(log-lib log)

# Link your bridge code to the official 'whisper' library target and Android logs
target_link_libraries(whisper_native
        whisper
        ${log-lib}
)