cmake_minimum_required(VERSION 3.22.1)
project(flutter_file_hash)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(CheckLinkerFlag)

set(FLUTTER_FILE_HASH_MAX_PAGE_SIZE_FLAG "-Wl,-z,max-page-size=16384")
check_linker_flag(CXX "${FLUTTER_FILE_HASH_MAX_PAGE_SIZE_FLAG}" FLUTTER_FILE_HASH_LD_SUPPORTS_MAX_PAGE_SIZE)

set(ZIG_API_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../third_party/zig-files-hash/src)
set(ZIG_PREBUILT_LIB
  ${CMAKE_CURRENT_SOURCE_DIR}/../../../../third_party/zig-files-hash-prebuilt/android/${ANDROID_ABI}/libzig_files_hash.a
)

if(NOT EXISTS ${ZIG_PREBUILT_LIB})
  message(
    FATAL_ERROR
    "Zig prebuilt library is missing: ${ZIG_PREBUILT_LIB}. "
    "Run scripts/build-zig-android.sh before building Android."
  )
endif()

add_library(
  flutter_file_hash
  SHARED
  error_mapping.cpp
  jni_utils.cpp
  zig_bridge.cpp
  zig_jni.cpp
)

target_include_directories(
  flutter_file_hash
  PRIVATE
  ${ZIG_API_INCLUDE_DIR}
)

add_library(zig-files-hash STATIC IMPORTED)
set_target_properties(
  zig-files-hash
  PROPERTIES
  IMPORTED_LOCATION ${ZIG_PREBUILT_LIB}
)

find_library(log-lib log)

target_link_libraries(
  flutter_file_hash
  zig-files-hash
  ${log-lib}
)

if(FLUTTER_FILE_HASH_LD_SUPPORTS_MAX_PAGE_SIZE)
  target_link_options(
    flutter_file_hash
    PRIVATE
    "${FLUTTER_FILE_HASH_MAX_PAGE_SIZE_FLAG}"
  )
else()
  message(STATUS "flutter_file_hash: linker does not support ${FLUTTER_FILE_HASH_MAX_PAGE_SIZE_FLAG}; building without 16KB alignment")
endif()
