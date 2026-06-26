enum HashAlgorithm {
  sha224('SHA-224', 0),
  sha256('SHA-256', 1),
  sha384('SHA-384', 2),
  sha512('SHA-512', 3),
  sha512_224('SHA-512/224', 4),
  sha512_256('SHA-512/256', 5),
  md5('MD5', 6),
  sha1('SHA-1', 7),
  xxh3_64('XXH3-64', 8, supportsSeed: true),
  blake3('BLAKE3', 9, supportsKey: true, keyLength: 32),
  hmacSha224('HMAC-SHA-224', 10, requiresKey: true),
  hmacSha256('HMAC-SHA-256', 11, requiresKey: true),
  hmacSha384('HMAC-SHA-384', 12, requiresKey: true),
  hmacSha512('HMAC-SHA-512', 13, requiresKey: true),
  hmacMd5('HMAC-MD5', 14, requiresKey: true),
  hmacSha1('HMAC-SHA-1', 15, requiresKey: true);

  const HashAlgorithm(
    this.label,
    this.zigId, {
    this.supportsKey = false,
    this.requiresKey = false,
    this.supportsSeed = false,
    this.keyLength,
  });

  final String label;
  final int zigId;
  final bool supportsKey;
  final bool requiresKey;
  final bool supportsSeed;
  final int? keyLength;
}
