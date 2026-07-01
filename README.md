# flutter_file_hash

[![pub version](https://img.shields.io/pub/v/flutter_file_hash.svg)](https://pub.dev/packages/flutter_file_hash)
[![pub downloads](https://img.shields.io/pub/dm/flutter_file_hash.svg)](https://pub.dev/packages/flutter_file_hash)
[![pub points](https://img.shields.io/pub/points/flutter_file_hash.svg)](https://pub.dev/packages/flutter_file_hash/score)
[![pub likes](https://img.shields.io/pub/likes/flutter_file_hash.svg)](https://pub.dev/packages/flutter_file_hash/score)

Native streaming hashes for Flutter files, strings, HMAC, XXH3, and BLAKE3,
powered by a shared Zig core.

Use it when your app needs to verify large downloads, fingerprint media,
deduplicate local files or cached uploads, generate fast cache keys, compare
local content, or authenticate data with HMAC or keyed BLAKE3.

Hash large files without loading them into Dart memory. Native code streams
files in chunks, keeps heavy work off the UI isolate where possible, and returns
a lowercase hex digest. The hashing core is
[`zig-files-hash`](https://github.com/Preeternal/zig-files-hash), exposed
through its C ABI and called from Flutter through FFI/native assets.

## Status

This package targets Flutter native platforms through one shared Zig core and
Flutter native assets. Web is not part of the first native package scope.

The public API is intentionally small: `fileHash` for files and URI strings,
`stringHash` for small in-memory strings or base64 payloads.

## Highlights

- Streams file data from disk instead of loading the whole file into Dart
  memory.
- Uses one shared Zig hash engine across supported native platforms.
- Safe for concurrent calls: each operation owns its native hash state.
- Defaults to `SHA-256` when you do not pass an algorithm.
- Supports cooperative cancellation for long-running file hashes.
- Supports local files, `file://` URIs, and Android `content://` URIs.
- Returns lowercase hex strings for every algorithm.
- Includes SHA variants, HMAC algorithms, XXH3-64, BLAKE3, and keyed BLAKE3.

## Platform Status

| Platform | Status | Engine |
| --- | --- | --- |
| Android | Native | `zig`; `content://` through Android opener |
| iOS | Native | `zig` |
| macOS | Native | `zig` |
| Linux | Native | `zig` |
| Windows | Native | `zig` |
| Web | Not planned yet | Would need a separate WASM/browser path |

## Installation

Use the package from pub.dev:

```yaml
dependencies:
  flutter_file_hash: ^0.0.1
```

For local development, use a path dependency:

```yaml
dependencies:
  flutter_file_hash:
    path: ../flutter-file-hash
```

Local development and release verification steps are documented in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Quick Start

```dart
import 'package:flutter_file_hash/flutter_file_hash.dart';

final digest = await fileHash('/path/to/video.mp4');
// SHA-256 lowercase hex by default

final xxh3 = await fileHash(
  '/path/to/video.mp4',
  algorithm: HashAlgorithm.xxh3_64,
);

final textDigest = stringHash('hello world');
```

For large payloads, prefer `fileHash`. `stringHash` is intended for small
strings or small base64 payloads already in Dart memory.

## Cancel Long Hashes

```dart
import 'package:flutter_file_hash/flutter_file_hash.dart';

final controller = HashCancellationController();

final future = fileHash(
  '/path/to/large-file.bin',
  algorithm: HashAlgorithm.sha256,
  cancellationToken: controller.token,
);

controller.cancel();

try {
  await future;
} on FlutterFileHashCancelledException {
  // Hash was cancelled.
}
```

Cancellation is cooperative. Large file hashes stop at chunk boundaries. Small
`stringHash` calls may finish before cancellation is observed.

## HMAC And Keyed BLAKE3

HMAC is selected by the algorithm:

```dart
final hmac = await fileHash(
  '/path/to/upload.bin',
  algorithm: HashAlgorithm.hmacSha256,
  hashOptions: const HashOptions(
    key: 'super-secret',
    keyEncoding: KeyEncoding.utf8,
  ),
);
```

Keyed BLAKE3 uses the regular `BLAKE3` algorithm with a key. The decoded key
must be 32 bytes:

```dart
final keyed = await fileHash(
  '/path/to/upload.bin',
  algorithm: HashAlgorithm.blake3,
  hashOptions: const HashOptions(
    key: '3031323334353637383961626364656630313233343536373839616263646566',
    keyEncoding: KeyEncoding.hex,
  ),
);
```

`keyEncoding` can be `utf8`, `hex`, or `base64`. The default is `utf8`. For
`BLAKE3`, `hashOptions.key` is optional: omit it for regular BLAKE3, pass it
only when you want keyed BLAKE3.

HMAC algorithms require `hashOptions.key`. If you intentionally need HMAC with
an empty key, pass `key: ''` explicitly; omitting `key` is rejected.

## Seeded XXH3

`XXH3-64` supports an optional unsigned 64-bit seed. Omit it for regular
unseeded XXH3. A seed is not a secret and does not make XXH3 cryptographic. It
selects a reproducible XXH3 namespace: the same bytes, algorithm, and seed
produce the same digest on your backend, CLI tools, and Flutter app.

The most direct use case is server-side verification. For example, your backend
can publish a download manifest with both the expected XXH3 digest and the seed
that was used to compute it:

```dart
const manifestSeed = '12345678901234567890';
const manifestXxh3 = '4b5e0a417dfa7ed2';

final actual = await fileHash(
  '/path/to/downloaded/video.mp4',
  algorithm: HashAlgorithm.xxh3_64,
  hashOptions: const HashOptions(seed: manifestSeed),
);

if (actual != manifestXxh3) {
  throw StateError('Downloaded file failed checksum verification');
}
```

Pass large `u64` seeds from a backend as strings, either decimal or `0x` hex.
Use a string or `BigInt` for values above the signed 64-bit range.

For app-owned namespaces, you can derive a stable seed from a readable label:

```dart
final mediaCacheSeed = xxh3SeedFromLabel('media-cache-v1');

final cacheKey = await fileHash(
  '/path/to/media.bin',
  algorithm: HashAlgorithm.xxh3_64,
  hashOptions: HashOptions(seed: mediaCacheSeed),
);
```

`hashOptions.seed` accepts an `int`, a `BigInt`, a decimal string, or a `0x` hex
string. Values are normalized before native hashing, so `12345`,
`BigInt.from(12345)`, and `'0x3039'` all use the same seed.

`xxh3SeedFromLabel(label)` derives a deterministic seed from a UTF-8 label
using FNV-1a 64-bit. The helper returns a canonical `0x` hex seed, for example
`0x091677a156a7756e`. Use it when the app controls the namespace, such as
`media-cache-v1` or `upload-dedupe-v2`. If a backend or CLI must reproduce the
same hashes, share either the derived seed value or the exact label derivation
rule. Use HMAC or keyed BLAKE3 when authenticity matters.

## API

### `fileHash(path, ...)`

Hashes a file by streaming it from native code.

```dart
final mac = await fileHash(
  '/path/to/upload.bin',
  algorithm: HashAlgorithm.hmacSha256,
  hashOptions: const HashOptions(
    key: 'upload-signing-secret',
    keyEncoding: KeyEncoding.utf8,
  ),
  cancellationToken: controller.token,
);
```

`path` can be:

- a local filesystem path;
- a `file://` URI string;
- an Android `content://` URI string, for example from the system document
  picker.

If `algorithm` is omitted, `SHA-256` is used. Use `hashOptions.key` only with
HMAC algorithms or keyed `BLAKE3`; regular hashes reject keys.

### `stringHash(input, ...)`

Hashes a small Dart string or base64 payload.

```dart
final digest = stringHash(
  'hello world',
  algorithm: HashAlgorithm.sha256,
  encoding: HashInputEncoding.utf8,
);

final fromBase64 = stringHash(
  base64Payload,
  algorithm: HashAlgorithm.blake3,
  encoding: HashInputEncoding.base64,
);
```

If `algorithm` is omitted, `SHA-256` is used. If `encoding` is omitted, `utf8`
is used.

### Request Types

```dart
Future<String> fileHash(
  String path, {
  HashAlgorithm algorithm = HashAlgorithm.sha256,
  HashOptions? hashOptions,
  HashCancellationToken? cancellationToken,
});

String stringHash(
  String input, {
  HashAlgorithm algorithm = HashAlgorithm.sha256,
  HashInputEncoding encoding = HashInputEncoding.utf8,
  HashOptions? hashOptions,
  HashCancellationToken? cancellationToken,
});

final class HashOptions {
  const HashOptions({
    this.key,
    this.keyEncoding = KeyEncoding.utf8,
    this.seed,
  });

  final String? key;
  final KeyEncoding keyEncoding;
  final Object? seed; // int, BigInt, decimal string, or 0x hex string
}
```

## Algorithms

| Algorithm | Use case | Notes |
| --- | --- | --- |
| `SHA-256` | Default general-purpose cryptographic hash | Good default for integrity checks |
| `SHA-384`, `SHA-512` | Stronger SHA-2 variants | Larger output, usually slower |
| `SHA-224`, `SHA-512/224`, `SHA-512/256` | SHA-2 compatibility variants | Useful for protocols requiring these exact digests |
| `MD5`, `SHA-1` | Legacy compatibility | Do not use for new security-sensitive designs |
| `HMAC-SHA-256` | Shared-secret authentication | Good default HMAC choice |
| `HMAC-SHA-224/384/512`, `HMAC-MD5`, `HMAC-SHA-1` | Protocol compatibility | Prefer SHA-256+ for new designs |
| `XXH3-64` | Fast non-cryptographic checksum | Supports optional seed; not authentication |
| `BLAKE3` | Modern high-performance hash | Also supports keyed mode with a 32-byte key |

`XXH3-128` is intentionally not exposed because it is not present in
`zig-files-hash` C ABI v3.

### Output Lengths

| Algorithm | Output length |
| --- | --- |
| `MD5`, `HMAC-MD5` | 16 bytes, 32 hex chars |
| `SHA-1`, `HMAC-SHA-1` | 20 bytes, 40 hex chars |
| `SHA-224`, `HMAC-SHA-224`, `SHA-512/224` | 28 bytes, 56 hex chars |
| `SHA-256`, `HMAC-SHA-256`, `SHA-512/256`, `BLAKE3` | 32 bytes, 64 hex chars |
| `SHA-384`, `HMAC-SHA-384` | 48 bytes, 96 hex chars |
| `SHA-512`, `HMAC-SHA-512` | 64 bytes, 128 hex chars |
| `XXH3-64` | 8 bytes, 16 hex chars |

## Error Handling

Errors are thrown as `FlutterFileHashException` with a stable `code`.

Common error codes:

| Code | Meaning |
| --- | --- |
| `cancelled` | Operation was cancelled |
| `invalid_argument` | Invalid algorithm/options combination |
| `invalid_key` | Key cannot be decoded or has the wrong length |
| `file_not_found` | File or URI cannot be opened |
| `unsupported_algorithm` | Algorithm is not available |
| `access_denied` | Platform denied access to the file or URI |
| `invalid_path` | Path cannot be interpreted by the native layer |
| `io_error` | File I/O failed |
| `hash_failed` | Native hashing failed unexpectedly |

Key rules:

- HMAC algorithms require `hashOptions.key`; pass `key: ''` explicitly for an
  empty HMAC key.
- `BLAKE3` uses keyed mode only when `hashOptions.key` is provided.
- `BLAKE3` keyed mode requires a 32-byte key after decoding.
- Other algorithms reject `hashOptions.key`.
- `hashOptions.seed` is only valid for `XXH3-64`.

## Android URI Streams

Plain filesystem paths use one Dart FFI call into `zfh_context_file_hash`; Zig
opens and streams the file internally.

Android `content://` inputs are the exception to the plain FFI path. They cannot
be opened with `dart:io File` because the bytes come from `ContentResolver`, not
from a normal filesystem path. They go through the Android plugin layer:

```text
ContentResolver.openInputStream(uri)
  -> Kotlin 64 KiB chunk loop
  -> JNI
  -> zfh_hasher_update / zfh_hasher_final
```

This avoids copying `content://` data into a temporary file before hashing. The
Android layer only opens the provider stream and feeds that stream into the same
Zig hash core; it does not add a second Android hash implementation.

In practice, common Flutter pickers may still copy selected provider files into
cache before returning them, but custom pickers can pass a `content://` URI
directly and avoid that extra copy.

## FFI/native-assets Template Usage

`flutter_file_hash` uses Flutter's modern `plugin_ffi`/native-assets path for
the native hash core. The public Dart API talks to one Zig native core through
the C ABI; platform code is used only where the operating system does not expose
a regular file path to Dart.

macOS release builds can print a native-assets packaging warning like:

```text
Code asset "package:flutter_file_hash/src/zig_files_hash_bindings.dart" has
different framework names for different architectures. Picking
"zig_files_hash_c_api.framework" and ignoring "zig_files_hash_c_api1.framework".
```

This comes from Flutter's macOS `code_assets` packaging path when it combines
multiple architectures into one app bundle. The generated app bundle still
contains the expected universal native framework, so the warning can be ignored.

The strategy is to keep `plugin_ffi`/native-assets for the Zig core and adopt
upstream Flutter fixes when macOS native-assets packaging improves. Android
platform code remains limited to URI access, as described in Android URI
Streams. If Flutter ever provides a clean FFI/native-assets path for Android
`content://` inputs, the Android URI bridge can be simplified without changing
the public Dart API or the Zig core.

## Performance

Use physical devices and Release builds for performance claims. Debug,
simulator, emulator, and VM runs are useful for smoke checks, but they do not
represent production throughput.

Current manual measurements live in [doc/benchmarks.md](doc/benchmarks.md).

Practical guidance:

- Use `SHA-256` for general integrity checks.
- Use `XXH3-64` for fast non-security checksums.
- Use `HMAC-SHA-256` for shared-secret authentication.
- Use keyed `BLAKE3` when you need BLAKE3 with a fixed 32-byte secret key.
- Avoid `MD5` and `SHA-1` for new security-sensitive designs.

## Native Implementation

- Hash core:
  [Preeternal/zig-files-hash](https://github.com/Preeternal/zig-files-hash)

Package users do not need a local Zig toolchain; release artifacts include Zig
prebuilts.

## Contributing

Contributions are welcome.

- [Setup](CONTRIBUTING.md#setup)
- [Fast checks](CONTRIBUTING.md#fast-checks)
- [Running during development](CONTRIBUTING.md#running-during-development)
- [Benchmarks](doc/benchmarks.md)

## License

MIT. See [LICENSE](LICENSE) for details.

Built on Flutter's `plugin_ffi`/native-assets template.
