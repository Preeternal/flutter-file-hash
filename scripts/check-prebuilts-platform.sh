#!/usr/bin/env bash
# Check that prebuilt artifacts for a specific platform were built correctly.
# Usage: ./scripts/check-prebuilts-platform.sh <platform>
#   platform: android | ios | macos | linux | windows | all
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="${1:-all}"

check_files() {
  local prefix="$1"
  shift

  local missing=()
  local file
  for file in "$@"; do
    [[ -e "${ROOT_DIR}/${prefix}/${file}" ]] || missing+=("${prefix}/${file}")
  done

  if (( ${#missing[@]} > 0 )); then
    echo "Missing ${prefix} Zig prebuilt artifacts:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    exit 1
  fi
}

check_no_extra_sources() {
  local prefix="$1"
  local root="${ROOT_DIR}/${prefix}"

  [[ -d "${root}" ]] || return 0

  local forbidden=()
  local path
  while IFS= read -r path; do
    forbidden+=("${path#${ROOT_DIR}/}")
  done < <(
    find "${root}" \( \
      \( -type f -name '*.zig' \) -o \
      \( -path '*/tests' -o -path '*/tests/*' \) \
    \) -print
  )

  if (( ${#forbidden[@]} > 0 )); then
    echo "Unexpected source/test files in ${prefix} Zig prebuilts:" >&2
    printf '  - %s\n' "${forbidden[@]}" >&2
    exit 1
  fi
}

check_android() {
  local prefix="third_party/zig-files-hash-prebuilt/android"
  check_files "${prefix}" \
    arm64-v8a/libzig_files_hash.a \
    arm64-v8a/libzig_files_hash_c_api.so \
    armeabi-v7a/libzig_files_hash.a \
    armeabi-v7a/libzig_files_hash_c_api.so \
    x86/libzig_files_hash.a \
    x86/libzig_files_hash_c_api.so \
    x86_64/libzig_files_hash.a \
    x86_64/libzig_files_hash_c_api.so
  check_no_extra_sources "${prefix}"
}

check_ios() {
  local prefix="third_party/zig-files-hash-prebuilt/ios"
  check_files "${prefix}" \
    ZigFilesHash.xcframework/Info.plist \
    ios-arm64/libzig_files_hash_c_api.dylib \
    ios-simulator-universal/libzig_files_hash_c_api.dylib
  check_no_extra_sources "${prefix}"
}

check_macos() {
  local prefix="third_party/zig-files-hash-prebuilt/macos"
  check_files "${prefix}" \
    ZigFilesHash.xcframework/Info.plist \
    universal/libzig_files_hash_c_api.dylib
  check_no_extra_sources "${prefix}"
}

check_linux() {
  local prefix="third_party/zig-files-hash-prebuilt/linux"
  check_files "${prefix}" \
    x64/libzig_files_hash_c_api.so \
    arm64/libzig_files_hash_c_api.so
  check_no_extra_sources "${prefix}"
}

check_windows() {
  local prefix="third_party/zig-files-hash-prebuilt/windows"
  check_files "${prefix}" \
    x64/zig_files_hash_c_api.dll \
    arm64/zig_files_hash_c_api.dll
  check_no_extra_sources "${prefix}"
}

case "${PLATFORM}" in
  android)
    check_android
    ;;
  ios)
    check_ios
    ;;
  macos)
    check_macos
    ;;
  linux)
    check_linux
    ;;
  windows)
    check_windows
    ;;
  all)
    check_android
    check_ios
    check_macos
    check_linux
    check_windows
    ;;
  *)
    echo "Unknown platform: ${PLATFORM}. Use: android | ios | macos | linux | windows | all" >&2
    exit 1
    ;;
esac

echo "All expected ${PLATFORM} Zig prebuilt artifacts are present."
