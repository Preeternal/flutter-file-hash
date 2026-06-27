#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIG_CORE_DIR="${ROOT_DIR}/third_party/zig-files-hash"
OUT_DIR="${ROOT_DIR}/third_party/zig-files-hash-prebuilt/android"
ANDROID_API=24

if ! command -v zig >/dev/null 2>&1; then
  echo "zig is not installed or not in PATH" >&2
  exit 1
fi

if [[ ! -f "${ZIG_CORE_DIR}/build.zig" ]]; then
  echo "zig-files-hash submodule is missing: ${ZIG_CORE_DIR}" >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

find_ndk_dir() {
  if [[ -n "${ANDROID_NDK_HOME:-}" && -d "${ANDROID_NDK_HOME}" ]]; then
    echo "${ANDROID_NDK_HOME}"
    return
  fi

  if [[ -n "${ANDROID_HOME:-}" && -d "${ANDROID_HOME}/ndk" ]]; then
    find "${ANDROID_HOME}/ndk" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -n1
    return
  fi

  if [[ -d "${HOME}/Library/Android/sdk/ndk" ]]; then
    find "${HOME}/Library/Android/sdk/ndk" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -n1
    return
  fi
}

host_tag() {
  case "$(uname -s)" in
    Darwin) echo "darwin-x86_64" ;;
    Linux) echo "linux-x86_64" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows-x86_64" ;;
    *)
      echo "Unsupported host OS for Android NDK lookup: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

android_clang() {
  local abi="$1"
  local ndk_dir="$2"
  local triple

  case "${abi}" in
    arm64-v8a) triple="aarch64-linux-android" ;;
    armeabi-v7a) triple="armv7a-linux-androideabi" ;;
    x86) triple="i686-linux-android" ;;
    x86_64) triple="x86_64-linux-android" ;;
    *)
      echo "Unsupported Android ABI: ${abi}" >&2
      exit 1
      ;;
  esac

  echo "${ndk_dir}/toolchains/llvm/prebuilt/$(host_tag)/bin/${triple}${ANDROID_API}-clang"
}

NDK_DIR="$(find_ndk_dir)"
if [[ -z "${NDK_DIR}" || ! -d "${NDK_DIR}" ]]; then
  echo "Android NDK was not found." >&2
  echo "Set ANDROID_NDK_HOME or install the Android NDK in ANDROID_HOME/ndk." >&2
  exit 1
fi

ABIS=("arm64-v8a" "armeabi-v7a" "x86" "x86_64")
TARGETS=(
  "aarch64-linux-android.24"
  "arm-linux-androideabi.24"
  "x86-linux-android.24"
  "x86_64-linux-android.24"
)

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

for i in "${!ABIS[@]}"; do
  ABI="${ABIS[$i]}"
  TARGET="${TARGETS[$i]}"
  PREFIX_DIR="$(mktemp -d)"

  echo "Building zig-files-hash for ${ABI} (${TARGET})..."
  (
    cd "${ZIG_CORE_DIR}"
    zig build c-api-static \
      -Dtarget="${TARGET}" \
      -Doptimize=ReleaseFast \
      --prefix "${PREFIX_DIR}"
  )

  mkdir -p "${OUT_DIR}/${ABI}"
  cp "${PREFIX_DIR}/lib/libzig_files_hash_c_api_static.a" "${OUT_DIR}/${ABI}/libzig_files_hash.a"

  CC="$(android_clang "${ABI}" "${NDK_DIR}")"
  if [[ ! -x "${CC}" ]]; then
    echo "Android clang was not found or is not executable: ${CC}" >&2
    exit 1
  fi

  echo "Linking Android Dart FFI shared library for ${ABI}..."
  "${CC}" \
    -shared \
    -Wl,--whole-archive "${OUT_DIR}/${ABI}/libzig_files_hash.a" -Wl,--no-whole-archive \
    -Wl,-soname,libzig_files_hash_c_api.so \
    -Wl,-z,max-page-size=16384 \
    -o "${OUT_DIR}/${ABI}/libzig_files_hash_c_api.so"

  rm -rf "${PREFIX_DIR}"
done

echo "Done. Android Zig prebuilts are in:"
echo "  ${OUT_DIR}"
