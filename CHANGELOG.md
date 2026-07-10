# Releases

## 0.0.4

* Hash Android `content://` URIs through `ContentResolver.openFileDescriptor`
  and one `zfh_fd_hash` JNI call when the provider exposes an fd. Zig owns the
  read loop but never closes the descriptor; Kotlin closes it after hashing.
  Providers that expose only a stream retain the existing streaming fallback.
* Add `fileHash(..., useMmap: true)` for stable regular local files. mmap stays
  disabled by default and is ignored for Android `content://` descriptors.
* Update the bundled `zig-files-hash` core to `v0.0.7` and C ABI v4, and
  rebuild the native prebuilt matrix for the new ABI.
* Document fd ownership, cancellation, stream fallback, and mmap constraints.

---

## 0.0.3

* Keep iOS and macOS XCFramework headers limited to the public C API headers
  so Zig source files, tests, and internals are not bundled in published
  native artifacts.
* Add per-platform prebuilt artifact checks to CI after each native build.
* Strengthen prebuilt validation for CI and pub.dev publishing by rejecting
  unexpected Zig source/test files inside generated prebuilts.
* Update the bundled `zig-files-hash` core to `v0.0.6`, which fixes upstream
  Windows MSVC static C ABI linking by bundling Zig compiler-rt. This package's
  Windows artifacts use a different build path, so no Flutter Windows behavior
  change is expected from that upstream fix.

---

## 0.0.2

* Add dartdoc comments for the public Dart API, including `fileHash`,
  `stringHash`, `HashAlgorithm`, `HashOptions`, cancellation types, and package
  exceptions.
* Improve pub.dev score readiness by documenting the exported API surface.
* Simplify README badges to match the React Native package style: package
  version and monthly downloads.
* Align the pub.dev publishing workflow with tag-based GitHub Actions
  publishing.

---

## 0.0.1

* Initial release of `flutter_file_hash`, a Flutter wrapper around the
  `zig-files-hash` native core.
* Add `fileHash` for native file hashing on Android, iOS, macOS, Linux, and
  Windows, with support for filesystem paths, `file://` URI strings, and Android
  `content://` streams.
* Add `stringHash` for UTF-8 strings and base64 payloads already in Dart memory.
* Support SHA-224, SHA-256, SHA-384, SHA-512, SHA-512/224, SHA-512/256, MD5,
  SHA-1, HMAC variants, BLAKE3, keyed BLAKE3, and seeded XXH3-64.
* Return lowercase hex digests and validate key/seed options before native calls.
* Add cooperative cancellation for long-running file hashes.
* Bundle prebuilt Zig native artifacts through Flutter FFI/native assets so app
  developers do not need a local Zig toolchain.
