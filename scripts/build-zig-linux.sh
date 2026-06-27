#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIG_CORE_DIR="${ROOT_DIR}/third_party/zig-files-hash"
OUT_DIR="${ROOT_DIR}/third_party/zig-files-hash-prebuilt/linux"

if ! command -v zig >/dev/null 2>&1; then
  echo "zig is not installed or not in PATH" >&2
  exit 1
fi

if [[ ! -f "${ZIG_CORE_DIR}/build.zig" ]]; then
  echo "zig-files-hash submodule is missing: ${ZIG_CORE_DIR}" >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

ARCHES=("x64" "arm64")
TARGETS=("x86_64-linux-gnu" "aarch64-linux-gnu")

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

for i in "${!ARCHES[@]}"; do
  ARCH="${ARCHES[$i]}"
  TARGET="${TARGETS[$i]}"
  PREFIX_DIR="$(mktemp -d)"

  echo "Building zig-files-hash for Linux ${ARCH} (${TARGET})..."
  (
    cd "${ZIG_CORE_DIR}"
    zig build c-api-shared \
      -Dtarget="${TARGET}" \
      -Doptimize=ReleaseFast \
      --prefix "${PREFIX_DIR}"
  )

  mkdir -p "${OUT_DIR}/${ARCH}"
  cp "${PREFIX_DIR}/lib/libzig_files_hash_c_api.so" "${OUT_DIR}/${ARCH}/libzig_files_hash_c_api.so"
  rm -rf "${PREFIX_DIR}"
done

echo "Done. Linux Zig prebuilts are in:"
echo "  ${OUT_DIR}"
