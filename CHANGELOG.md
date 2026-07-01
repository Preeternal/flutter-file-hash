## 0.0.1

* Initial Zig-backed Flutter package for native file and string hashing.
* Add `fileHash`, `stringHash`, HMAC, keyed BLAKE3, seeded XXH3-64, and
  cooperative cancellation.
* Add native prebuilts delivery through Flutter FFI/native assets.
* Add Android `content://` streaming through the Android opener and the shared
  Zig hash core.
