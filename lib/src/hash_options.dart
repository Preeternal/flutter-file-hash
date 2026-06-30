final class HashOptions {
  const HashOptions({this.key, this.keyEncoding = KeyEncoding.utf8, this.seed});

  final String? key;
  final KeyEncoding keyEncoding;

  /// XXH3 unsigned 64-bit seed.
  ///
  /// Accepts an `int`, `BigInt`, decimal string, or `0x` hex string. Use a
  /// string or `BigInt` for values above signed 64-bit range.
  final Object? seed;
}

enum KeyEncoding {
  utf8('utf8'),
  hex('hex'),
  base64('base64');

  const KeyEncoding(this.label);

  final String label;
}

enum HashInputEncoding {
  utf8('utf8'),
  base64('base64');

  const HashInputEncoding(this.label);

  final String label;
}
