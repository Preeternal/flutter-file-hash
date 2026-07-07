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

"${ROOT_DIR}/scripts/check-prebuilts-platform.sh" all

(
  cd "${ROOT_DIR}"
  "${DART_CMD[@]}" pub publish --dry-run
)

echo "Verified pub.dev publish inputs."
