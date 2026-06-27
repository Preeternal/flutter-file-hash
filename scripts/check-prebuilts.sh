#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REQUIRED_PATHS=(
  "third_party/zig-files-hash-prebuilt/android/arm64-v8a/libzig_files_hash.a"
  "third_party/zig-files-hash-prebuilt/android/armeabi-v7a/libzig_files_hash.a"
  "third_party/zig-files-hash-prebuilt/android/x86/libzig_files_hash.a"
  "third_party/zig-files-hash-prebuilt/android/x86_64/libzig_files_hash.a"
  "third_party/zig-files-hash-prebuilt/ios/ZigFilesHash.xcframework/Info.plist"
  "third_party/zig-files-hash-prebuilt/macos/ZigFilesHash.xcframework/Info.plist"
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
  echo "Missing Zig prebuilt artifacts:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "All expected Zig prebuilt artifacts are present."
