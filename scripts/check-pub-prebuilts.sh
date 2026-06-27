#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DART_CMD=()

if [[ -n "${DART_BIN:-}" ]]; then
  DART_CMD=("${DART_BIN}")
elif command -v dart >/dev/null 2>&1; then
  DART_CMD=(dart)
elif command -v fvm >/dev/null 2>&1; then
  DART_CMD=(fvm dart)
else
  echo "dart is not installed or not in PATH" >&2
  exit 1
fi

REQUIRED_PATHS=(
  "third_party/zig-files-hash-prebuilt/android/arm64-v8a/libzig_files_hash.a"
  "third_party/zig-files-hash-prebuilt/android/arm64-v8a/libzig_files_hash_c_api.so"
  "third_party/zig-files-hash-prebuilt/android/armeabi-v7a/libzig_files_hash.a"
  "third_party/zig-files-hash-prebuilt/android/armeabi-v7a/libzig_files_hash_c_api.so"
  "third_party/zig-files-hash-prebuilt/android/x86/libzig_files_hash.a"
  "third_party/zig-files-hash-prebuilt/android/x86/libzig_files_hash_c_api.so"
  "third_party/zig-files-hash-prebuilt/android/x86_64/libzig_files_hash.a"
  "third_party/zig-files-hash-prebuilt/android/x86_64/libzig_files_hash_c_api.so"
  "third_party/zig-files-hash-prebuilt/ios/ZigFilesHash.xcframework/Info.plist"
  "third_party/zig-files-hash-prebuilt/ios/ios-arm64/libzig_files_hash_c_api.dylib"
  "third_party/zig-files-hash-prebuilt/ios/ios-simulator-universal/libzig_files_hash_c_api.dylib"
  "third_party/zig-files-hash-prebuilt/macos/ZigFilesHash.xcframework/Info.plist"
  "third_party/zig-files-hash-prebuilt/macos/universal/libzig_files_hash_c_api.dylib"
  "third_party/zig-files-hash-prebuilt/linux/x64/libzig_files_hash_c_api.so"
  "third_party/zig-files-hash-prebuilt/linux/arm64/libzig_files_hash_c_api.so"
  "third_party/zig-files-hash-prebuilt/windows/x64/zig_files_hash_c_api.dll"
  "third_party/zig-files-hash-prebuilt/windows/arm64/zig_files_hash_c_api.dll"
)

missing=()
for path in "${REQUIRED_PATHS[@]}"; do
  if [[ ! -e "${ROOT_DIR}/${path}" ]]; then
    missing+=("${path}")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "Missing native artifacts required for pub.dev publishing:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

(
  cd "${ROOT_DIR}"
  "${DART_CMD[@]}" pub publish --dry-run
)

echo "Verified pub.dev publish inputs."
