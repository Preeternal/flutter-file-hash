#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIG_CORE_DIR="${ROOT_DIR}/third_party/zig-files-hash"
OUT_DIR="${ROOT_DIR}/third_party/zig-files-hash-prebuilt/android"

if ! command -v zig >/dev/null 2>&1; then
  echo "zig is not installed or not in PATH" >&2
  exit 1
fi

if [[ ! -f "${ZIG_CORE_DIR}/build.zig" ]]; then
  echo "zig-files-hash submodule is missing: ${ZIG_CORE_DIR}" >&2
  echo "Run: git submodule update --init --recursive" >&2
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
  rm -rf "${PREFIX_DIR}"
done

echo "Done. Android Zig prebuilts are in:"
echo "  ${OUT_DIR}"
