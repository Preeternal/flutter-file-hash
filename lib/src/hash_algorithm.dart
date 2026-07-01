/// Hash algorithms supported by `flutter_file_hash`.
enum HashAlgorithm {
  /// SHA-224.
  sha224('SHA-224', 0),

  /// SHA-256.
  sha256('SHA-256', 1),

  /// SHA-384.
  sha384('SHA-384', 2),

  /// SHA-512.
  sha512('SHA-512', 3),

  /// SHA-512/224.
  sha512_224('SHA-512/224', 4),

  /// SHA-512/256.
  sha512_256('SHA-512/256', 5),

  /// MD5.
  md5('MD5', 6),

  /// SHA-1.
  sha1('SHA-1', 7),

  /// XXH3 64-bit hash, optionally seeded with `HashOptions.seed`.
  xxh3_64('XXH3-64', 8, supportsSeed: true),

  /// BLAKE3, optionally keyed with a 32-byte `HashOptions.key`.
  blake3('BLAKE3', 9, supportsKey: true, keyLength: 32),

  /// HMAC-SHA-224.
  hmacSha224('HMAC-SHA-224', 10, requiresKey: true),

  /// HMAC-SHA-256.
  hmacSha256('HMAC-SHA-256', 11, requiresKey: true),

  /// HMAC-SHA-384.
  hmacSha384('HMAC-SHA-384', 12, requiresKey: true),

  /// HMAC-SHA-512.
  hmacSha512('HMAC-SHA-512', 13, requiresKey: true),

  /// HMAC-MD5.
  hmacMd5('HMAC-MD5', 14, requiresKey: true),

  /// HMAC-SHA-1.
  hmacSha1('HMAC-SHA-1', 15, requiresKey: true);

  const HashAlgorithm(
    this.label,
    this.zigId, {
    this.supportsKey = false,
    this.requiresKey = false,
    this.supportsSeed = false,
    this.keyLength,
  });

  /// Human-readable algorithm name.
  final String label;

  /// Numeric algorithm identifier used by the Zig C ABI.
  final int zigId;

  /// Whether the algorithm accepts an optional key.
  final bool supportsKey;

  /// Whether the algorithm requires a key.
  final bool requiresKey;

  /// Whether the algorithm accepts an optional seed.
  final bool supportsSeed;

  /// Required key length in bytes, when the algorithm has one.
  final int? keyLength;
}
