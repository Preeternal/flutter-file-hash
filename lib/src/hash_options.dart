/// Optional parameters for keyed and seeded hash algorithms.
final class HashOptions {
  /// Creates hash options for algorithms that accept a key or seed.
  const HashOptions({this.key, this.keyEncoding = KeyEncoding.utf8, this.seed});

  /// Secret key used by HMAC algorithms and keyed BLAKE3.
  final String? key;

  /// Encoding used to decode [key].
  final KeyEncoding keyEncoding;

  /// XXH3 unsigned 64-bit seed.
  ///
  /// Accepts an `int`, `BigInt`, decimal string, or `0x` hex string. Use a
  /// string or `BigInt` for values above signed 64-bit range.
  final Object? seed;
}

/// Encoding used for [HashOptions.key].
enum KeyEncoding {
  /// Treat the key as UTF-8 text.
  utf8('utf8'),

  /// Treat the key as hexadecimal bytes.
  hex('hex'),

  /// Treat the key as base64 bytes.
  base64('base64');

  const KeyEncoding(this.label);

  /// Stable label used in error messages and examples.
  final String label;
}

/// Encoding used for `stringHash` input.
enum HashInputEncoding {
  /// Treat the input as UTF-8 text.
  utf8('utf8'),

  /// Treat the input as base64 bytes.
  base64('base64');

  const HashInputEncoding(this.label);

  /// Stable label used in error messages and examples.
  final String label;
}
