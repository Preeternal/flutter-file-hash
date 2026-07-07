#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIG_CORE_DIR="${ROOT_DIR}/third_party/zig-files-hash"
OUT_DIR="${ROOT_DIR}/third_party/zig-files-hash-prebuilt/ios"
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
  local sdk_name="$1"
  local arch="$2"
  local min_version_flag="$3"
  local input_lib="$4"
  local output_lib="$5"
  local sdk_path
  sdk_path="$(xcrun --sdk "${sdk_name}" --show-sdk-path)"

  xcrun --sdk "${sdk_name}" clang \
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
rm -rf "${OUT_DIR}/ios-arm64" "${OUT_DIR}/ios-simulator-universal"

echo "Building zig-files-hash for iOS device (arm64)..."
build_target "aarch64-ios.13.0" "${TMP_DIR}/ios-arm64.a"

echo "Building zig-files-hash for iOS simulator (arm64)..."
build_target "aarch64-ios.13.0-simulator" "${TMP_DIR}/ios-sim-arm64.a"

echo "Building zig-files-hash for iOS simulator (x86_64)..."
build_target "x86_64-ios.13.0-simulator" "${TMP_DIR}/ios-sim-x86_64.a"

echo "Creating universal simulator static library..."
lipo -create \
  "${TMP_DIR}/ios-sim-arm64.a" \
  "${TMP_DIR}/ios-sim-x86_64.a" \
  -output "${TMP_DIR}/ios-sim-universal.a"

echo "Creating iOS dynamic libraries for Dart FFI native assets..."
create_dylib "iphoneos" "arm64" "-miphoneos-version-min=13.0" \
  "${TMP_DIR}/ios-arm64.a" \
  "${TMP_DIR}/ios-device-arm64.dylib"
create_dylib "iphonesimulator" "arm64" "-mios-simulator-version-min=13.0" \
  "${TMP_DIR}/ios-sim-arm64.a" \
  "${TMP_DIR}/ios-sim-arm64.dylib"
create_dylib "iphonesimulator" "x86_64" "-mios-simulator-version-min=13.0" \
  "${TMP_DIR}/ios-sim-x86_64.a" \
  "${TMP_DIR}/ios-sim-x86_64.dylib"
lipo -create \
  "${TMP_DIR}/ios-sim-arm64.dylib" \
  "${TMP_DIR}/ios-sim-x86_64.dylib" \
  -output "${TMP_DIR}/ios-sim-universal.dylib"

mkdir -p "${OUT_DIR}/ios-arm64" "${OUT_DIR}/ios-simulator-universal"
cp "${TMP_DIR}/ios-device-arm64.dylib" "${OUT_DIR}/ios-arm64/libzig_files_hash_c_api.dylib"
cp "${TMP_DIR}/ios-sim-universal.dylib" "${OUT_DIR}/ios-simulator-universal/libzig_files_hash_c_api.dylib"

mkdir -p "${TMP_DIR}/device" "${TMP_DIR}/sim"
cp "${TMP_DIR}/ios-arm64.a" "${TMP_DIR}/device/libzig_files_hash.a"
cp "${TMP_DIR}/ios-sim-universal.a" "${TMP_DIR}/sim/libzig_files_hash.a"

# Collect only the public C headers; skip all .zig sources, tests, and internals.
mkdir -p "${TMP_DIR}/xcframework-headers"
cp "${ZIG_CORE_DIR}/src/zig_files_hash_c_api.h" \
    "${ZIG_CORE_DIR}/src/zig_files_hash_c_api_generated.h" \
    "${TMP_DIR}/xcframework-headers/"

echo "Creating ZigFilesHash.xcframework..."
xcodebuild -create-xcframework \
  -library "${TMP_DIR}/device/libzig_files_hash.a" \
  -headers "${TMP_DIR}/xcframework-headers" \
  -library "${TMP_DIR}/sim/libzig_files_hash.a" \
  -headers "${TMP_DIR}/xcframework-headers" \
  -output "${OUT_DIR}/ZigFilesHash.xcframework"

echo "Done. iOS Zig prebuilt framework is in:"
echo "  ${OUT_DIR}/ZigFilesHash.xcframework"
echo "Done. iOS Zig dynamic prebuilts are in:"
echo "  ${OUT_DIR}/ios-arm64"
echo "  ${OUT_DIR}/ios-simulator-universal"
