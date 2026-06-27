#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIG_CORE_DIR="${ROOT_DIR}/third_party/zig-files-hash"
OUT_DIR="${ROOT_DIR}/third_party/zig-files-hash-prebuilt/macos"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

if ! command -v zig >/dev/null 2>&1; then
  echo "zig is not installed or not in PATH" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not installed or not in PATH" >&2
  exit 1
fi

if ! command -v lipo >/dev/null 2>&1; then
  echo "lipo is not installed or not in PATH" >&2
  exit 1
fi

if [[ ! -f "${ZIG_CORE_DIR}/build.zig" ]]; then
  echo "zig-files-hash submodule is missing: ${ZIG_CORE_DIR}" >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

repack_static_library() {
  local input_lib="$1"
  local output_lib="$2"
  local work_dir
  work_dir="$(mktemp -d)"

  (
    cd "${work_dir}"
    xcrun ar -x "${input_lib}"

    local objects=(*.o)
    if [[ ! -e "${objects[0]}" ]]; then
      echo "No object files found in ${input_lib}" >&2
      exit 1
    fi

    chmod u+rw "${objects[@]}"
    xcrun libtool -static -o "${output_lib}" "${objects[@]}"
    xcrun ranlib "${output_lib}"
  )

  rm -rf "${work_dir}"
}

build_target() {
  local target="$1"
  local out_lib="$2"
  local prefix_dir
  prefix_dir="$(mktemp -d)"

  (
    cd "${ZIG_CORE_DIR}"
    zig build c-api-static \
      -Dtarget="${target}" \
      -Doptimize=ReleaseFast \
      --prefix "${prefix_dir}"
  )

  repack_static_library "${prefix_dir}/lib/libzig_files_hash_c_api_static.a" "${out_lib}"
  rm -rf "${prefix_dir}"
}

create_dylib() {
  local arch="$1"
  local min_version_flag="$2"
  local input_lib="$3"
  local output_lib="$4"
  local sdk_path
  sdk_path="$(xcrun --sdk macosx --show-sdk-path)"

  xcrun --sdk macosx clang \
    -dynamiclib \
    -arch "${arch}" \
    -isysroot "${sdk_path}" \
    "${min_version_flag}" \
    -headerpad_max_install_names \
    -Wl,-force_load,"${input_lib}" \
    -install_name "@rpath/libzig_files_hash_c_api.dylib" \
    -o "${output_lib}"
}

mkdir -p "${OUT_DIR}"
rm -rf "${OUT_DIR}/ZigFilesHash.xcframework"
rm -rf "${OUT_DIR}/universal"

echo "Building zig-files-hash for macOS (arm64)..."
build_target "aarch64-macos.11.0" "${TMP_DIR}/macos-arm64.a"

echo "Building zig-files-hash for macOS (x86_64)..."
build_target "x86_64-macos.10.15" "${TMP_DIR}/macos-x86_64.a"

echo "Creating universal macOS static library..."
lipo -create \
  "${TMP_DIR}/macos-arm64.a" \
  "${TMP_DIR}/macos-x86_64.a" \
  -output "${TMP_DIR}/macos-universal.a"

echo "Creating universal macOS dynamic library for Dart FFI native assets..."
create_dylib "arm64" "-mmacosx-version-min=11.0" \
  "${TMP_DIR}/macos-arm64.a" \
  "${TMP_DIR}/macos-arm64.dylib"
create_dylib "x86_64" "-mmacosx-version-min=10.15" \
  "${TMP_DIR}/macos-x86_64.a" \
  "${TMP_DIR}/macos-x86_64.dylib"
lipo -create \
  "${TMP_DIR}/macos-arm64.dylib" \
  "${TMP_DIR}/macos-x86_64.dylib" \
  -output "${TMP_DIR}/macos-universal.dylib"

mkdir -p "${OUT_DIR}/universal"
cp "${TMP_DIR}/macos-universal.dylib" "${OUT_DIR}/universal/libzig_files_hash_c_api.dylib"

mkdir -p "${TMP_DIR}/macos"
cp "${TMP_DIR}/macos-universal.a" "${TMP_DIR}/macos/libzig_files_hash.a"

echo "Creating ZigFilesHash.xcframework..."
xcodebuild -create-xcframework \
  -library "${TMP_DIR}/macos/libzig_files_hash.a" \
  -headers "${ZIG_CORE_DIR}/src" \
  -output "${OUT_DIR}/ZigFilesHash.xcframework"

echo "Done. macOS Zig prebuilt framework is in:"
echo "  ${OUT_DIR}/ZigFilesHash.xcframework"
echo "Done. macOS Zig dynamic prebuilt is in:"
echo "  ${OUT_DIR}/universal"
