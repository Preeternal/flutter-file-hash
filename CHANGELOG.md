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
