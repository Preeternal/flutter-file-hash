# flutter_file_hash

Streaming file and string hashes for Flutter, powered by a shared Zig native
core.

Use it when an app needs to verify downloads, fingerprint media, deduplicate
local files, build fast cache keys, compare local content, or authenticate data
with HMAC or keyed BLAKE3.

`flutter_file_hash` hashes files inside the native core instead of loading full
files into Dart memory. The hashing core is
[`zig-files-hash`](https://github.com/Preeternal/zig-files-hash), exposed through
its C ABI and called from Flutter via native assets.

## Status

This package is in active development and is not published yet. The Dart API and
native build path are usable for local testing.

Web is not part of the first native package scope.

## Highlights

- Streams file data instead of reading the whole file into memory.
- Uses one shared Zig hash engine across platforms.
- Defaults to `SHA-256`.
- Returns lowercase hex strings.
- Supports local filesystem paths.
- Supports `file://` URIs and Android `content://` URIs.
- Supports HMAC, keyed BLAKE3, and seeded XXH3-64.
- Supports cooperative cancellation for file hashing.

## Platform Support

| Platform | Support | Notes |
| --- | --- | --- |
| Android | Native | Filesystem paths through Dart FFI; `content://` through Android opener |
| iOS | Native | Filesystem paths through Dart FFI |
| macOS | Native | Filesystem paths through Dart FFI |
| Linux | Native | Filesystem paths through Dart FFI |
| Windows | Native | Filesystem paths through Dart FFI |
| Web | Not planned yet | Would need a separate WASM/browser path |

## Installation

The package is not on pub.dev yet. Use a path dependency while testing a local
checkout:

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

final uriDigest = await uriHash(Uri.file('/path/to/video.mp4'));

final textDigest = stringHash('hello world');
```

For large payloads, prefer `fileHash`. `stringHash` is intended for strings or
base64 payloads already in Dart memory.

## Cancellation

```dart
final controller = HashCancellationController();

final future = fileHash(
  '/path/to/large-file.bin',
  cancellationToken: controller.token,
);

controller.cancel();

try {
  await future;
} on FlutterFileHashCancelledException {
  // Hashing was cancelled.
}
```

Cancellation is cooperative. File hashing stops at chunk boundaries. Small
`stringHash` calls may complete before cancellation is observed.

## HMAC And Keyed BLAKE3

HMAC is selected by the algorithm:

```dart
final digest = await fileHash(
  '/path/to/upload.bin',
  algorithm: HashAlgorithm.hmacSha256,
  hashOptions: const HashOptions(
    key: 'upload-signing-secret',
    keyEncoding: KeyEncoding.utf8,
  ),
);
```

Keyed BLAKE3 uses the regular `BLAKE3` algorithm with a key. The decoded key
must be 32 bytes:

```dart
final digest = stringHash(
  'payload',
  algorithm: HashAlgorithm.blake3,
  hashOptions: const HashOptions(
    key: '3031323334353637383961626364656630313233343536373839616263646566',
    keyEncoding: KeyEncoding.hex,
  ),
);
```

`keyEncoding` can be `utf8`, `hex`, or `base64`. The default is `utf8`. HMAC
algorithms require `hashOptions.key`; pass `key: ''` explicitly for HMAC with an
empty key.

## Seeded XXH3

`XXH3-64` supports an optional unsigned 64-bit seed. A seed is not secret and
does not make XXH3 cryptographic. It selects a reproducible namespace: the same
bytes, algorithm, and seed produce the same digest.

```dart
final seed = xxh3SeedFromLabel('media-cache-v1');

final digest = await fileHash(
  '/path/to/media.bin',
  algorithm: HashAlgorithm.xxh3_64,
  hashOptions: HashOptions(seed: seed),
);
```

`xxh3SeedFromLabel(label)` derives a deterministic canonical `0x` seed from a
UTF-8 label using FNV-1a 64-bit. Use HMAC or keyed BLAKE3 when authenticity
matters.

## API

### `fileHash(path, ...)`

Hashes a local file path and returns a lowercase hex digest.

```dart
Future<String> fileHash(
  String path, {
  HashAlgorithm algorithm = HashAlgorithm.sha256,
  HashOptions? hashOptions,
  HashCancellationToken? cancellationToken,
});
```

`path` can be:

- a local filesystem path;
- a `file://` URI string;
- an Android `content://` URI string for compatibility.

Prefer `uriHash(Uri)` when the input is already a URI.

### `uriHash(uri, ...)`

Hashes a supported URI and returns a lowercase hex digest.

```dart
Future<String> uriHash(
  Uri uri, {
  HashAlgorithm algorithm = HashAlgorithm.sha256,
  HashOptions? hashOptions,
  HashCancellationToken? cancellationToken,
});
```

Supported URI schemes:

- `file://` on all native platforms;
- `content://` on Android.

### `stringHash(input, ...)`

Hashes a small string or base64 payload and returns a lowercase hex digest.

```dart
String stringHash(
  String input, {
  HashAlgorithm algorithm = HashAlgorithm.sha256,
  HashInputEncoding encoding = HashInputEncoding.utf8,
  HashOptions? hashOptions,
  HashCancellationToken? cancellationToken,
});
```

If `encoding` is omitted, `utf8` is used.

### `HashOptions`

```dart
class HashOptions {
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

| Algorithm | Notes |
| --- | --- |
| `SHA-224` | SHA-2 compatibility variant |
| `SHA-256` | Default general-purpose cryptographic hash |
| `SHA-384` | SHA-2 variant |
| `SHA-512` | SHA-2 variant |
| `SHA-512/224` | SHA-2 compatibility variant |
| `SHA-512/256` | SHA-2 compatibility variant |
| `MD5` | Legacy compatibility; avoid for new security-sensitive designs |
| `SHA-1` | Legacy compatibility; avoid for new security-sensitive designs |
| `XXH3-64` | Fast non-cryptographic checksum; supports optional seed |
| `BLAKE3` | Modern high-performance hash; supports keyed mode |
| `HMAC-SHA-224` | HMAC compatibility variant |
| `HMAC-SHA-256` | Good default HMAC choice |
| `HMAC-SHA-384` | HMAC SHA-2 variant |
| `HMAC-SHA-512` | HMAC SHA-2 variant |
| `HMAC-MD5` | Legacy HMAC compatibility |
| `HMAC-SHA-1` | Legacy HMAC compatibility |

`XXH3-128` is intentionally not exposed because it is not present in
`zig-files-hash` C ABI v3.

## Error Handling

Errors are thrown as `FlutterFileHashException` with a stable `code`.

Common codes:

| Code | Meaning |
| --- | --- |
| `cancelled` | Operation was cancelled |
| `invalid_argument` | Invalid input or option combination |
| `unsupported_algorithm` | Algorithm is not available |
| `invalid_key` | Key cannot be used or has the wrong length |
| `file_not_found` | File or URI cannot be opened |
| `access_denied` | Platform denied access to the file or URI |
| `invalid_path` | Path cannot be interpreted by the native layer |
| `io_error` | File I/O failed |
| `hash_failed` | Native hashing failed unexpectedly |

Key rules:

- HMAC algorithms require `hashOptions.key`.
- `BLAKE3` keyed mode requires a 32-byte key after decoding.
- Other non-HMAC algorithms reject `hashOptions.key`, except keyed `BLAKE3`.
- `hashOptions.seed` is valid only for `XXH3-64`.

## Android URI Streams

Plain filesystem paths use one Dart FFI call into `zfh_context_file_hash`; Zig
opens and streams the file internally.

Android URI inputs cannot be opened with `dart:io File`, so they go through the
Android plugin layer:

```text
ContentResolver.openInputStream(uri)
  -> Kotlin 64 KiB chunk loop
  -> JNI
  -> zfh_hasher_update / zfh_hasher_final
```

This avoids copying `content://` data into a temporary file before hashing.

## License

MIT. See [LICENSE](LICENSE) for details.
