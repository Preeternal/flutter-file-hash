import 'dart:developer' as developer;

import 'package:flutter_file_hash/flutter_file_hash.dart';

Future<void> main() async {
  const path = '/path/to/file.bin';

  final sha256 = await fileHash(path);
  final blake3 = await fileHash(path, algorithm: HashAlgorithm.blake3);
  final hmacSha256 = await fileHash(
    path,
    algorithm: HashAlgorithm.hmacSha256,
    hashOptions: const HashOptions(key: 'secret'),
  );
  final xxh3 = await fileHash(
    path,
    algorithm: HashAlgorithm.xxh3_64,
    hashOptions: HashOptions(seed: xxh3SeedFromLabel('media-cache-v1')),
  );
  final textSha256 = stringHash('hello world');

  developer.log('SHA-256: $sha256');
  developer.log('BLAKE3: $blake3');
  developer.log('HMAC-SHA-256: $hmacSha256');
  developer.log('XXH3-64: $xxh3');
  developer.log('text SHA-256: $textSha256');
}
