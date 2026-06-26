import 'dart:io';

import 'package:test/test.dart';

import 'package:flutter_file_hash/flutter_file_hash.dart';

void main() {
  test('maps algorithms exposed by zig-files-hash C ABI v3', () {
    expect(HashAlgorithm.sha256.zigId, 1);
    expect(HashAlgorithm.blake3.zigId, 9);
    expect(HashAlgorithm.hmacSha256.zigId, 11);
    expect(
      HashAlgorithm.values.map((algorithm) => algorithm.label),
      isNot(contains('XXH3-128')),
    );
  });

  test('derives deterministic XXH3 seeds from labels', () {
    expect(xxh3SeedFromLabel(''), 0xcbf29ce484222325);
    expect(
      xxh3SeedFromLabel('media-cache-v1'),
      xxh3SeedFromLabel('media-cache-v1'),
    );
    expect(
      xxh3SeedFromLabel('media-cache-v1'),
      isNot(xxh3SeedFromLabel('media-cache-v2')),
    );
  });

  test('requires key for HMAC before native calls', () {
    expect(
      () => stringHash('abc', algorithm: HashAlgorithm.hmacSha256),
      throwsA(
        isA<FlutterFileHashException>().having(
          (error) => error.code,
          'code',
          'invalid_argument',
        ),
      ),
    );
  });

  test('hashes string input through the Zig stream hasher', () {
    expect(
      stringHash('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('hashes file input through the Zig stream hasher', () async {
    final tempDir = await Directory.systemTemp.createTemp('flutter_file_hash_');
    try {
      final file = File.fromUri(tempDir.uri.resolve('input.txt'));
      await file.writeAsString('abc');

      expect(await fileHash(file.path), stringHash('abc'));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('accepts empty key as provided HMAC key', () {
    expect(
      () => stringHash(
        'abc',
        algorithm: HashAlgorithm.hmacSha256,
        hashOptions: const HashOptions(key: ''),
      ),
      returnsNormally,
    );
  });

  test('rejects key for plain algorithms before native calls', () {
    expect(
      () => stringHash('abc', hashOptions: const HashOptions(key: 'secret')),
      throwsA(
        isA<FlutterFileHashException>().having(
          (error) => error.message,
          'message',
          contains('HMAC algorithms or BLAKE3'),
        ),
      ),
    );
  });

  test('rejects seed for non-XXH3 algorithms before native calls', () {
    expect(
      () => stringHash(
        'abc',
        algorithm: HashAlgorithm.blake3,
        hashOptions: const HashOptions(seed: 1),
      ),
      throwsA(
        isA<FlutterFileHashException>().having(
          (error) => error.message,
          'message',
          contains('XXH3-64'),
        ),
      ),
    );
  });

  test('validates BLAKE3 keyed mode key length before native calls', () {
    expect(
      () => stringHash(
        'abc',
        algorithm: HashAlgorithm.blake3,
        hashOptions: const HashOptions(key: 'short'),
      ),
      throwsA(
        isA<FlutterFileHashException>().having(
          (error) => error.message,
          'message',
          contains('32-byte key'),
        ),
      ),
    );
  });
}
