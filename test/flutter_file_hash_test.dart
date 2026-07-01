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
    expect(xxh3SeedFromLabel(''), '0xcbf29ce484222325');
    expect(xxh3SeedFromLabel('media-cache-v1'), '0x091677a156a7756e');
    expect(xxh3SeedFromLabel('dfg'), '0xca972b18f45fcbd8');
    expect(xxh3SeedFromLabel('🔐-cache-v1'), '0x269d7c32f94972b3');
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

  test('hashes file input through the Zig file hasher', () async {
    final tempDir = await Directory.systemTemp.createTemp('flutter_file_hash_');
    try {
      final file = File.fromUri(tempDir.uri.resolve('input.txt'));
      await file.writeAsString('abc');

      expect(await fileHash(file.path), stringHash('abc'));
      expect(await fileHash(file.uri.toString()), stringHash('abc'));
      expect(
        await fileHash(file.path, algorithm: HashAlgorithm.xxh3_64),
        stringHash('abc', algorithm: HashAlgorithm.xxh3_64),
      );

      final seed = xxh3SeedFromLabel('media-cache-v1');
      expect(
        await fileHash(
          file.path,
          algorithm: HashAlgorithm.xxh3_64,
          hashOptions: HashOptions(seed: seed),
        ),
        stringHash(
          'abc',
          algorithm: HashAlgorithm.xxh3_64,
          hashOptions: HashOptions(seed: seed),
        ),
      );

      final highBitSeed = xxh3SeedFromLabel('dfg');
      expect(
        await fileHash(
          file.path,
          algorithm: HashAlgorithm.xxh3_64,
          hashOptions: HashOptions(seed: highBitSeed),
        ),
        stringHash(
          'abc',
          algorithm: HashAlgorithm.xxh3_64,
          hashOptions: HashOptions(seed: highBitSeed),
        ),
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('normalizes XXH3 seeds before native calls', () {
    expect(
      stringHash(
        'abc',
        algorithm: HashAlgorithm.xxh3_64,
        hashOptions: const HashOptions(seed: 12345),
      ),
      stringHash(
        'abc',
        algorithm: HashAlgorithm.xxh3_64,
        hashOptions: const HashOptions(seed: '0x0000000000003039'),
      ),
    );
    expect(
      stringHash(
        'abc',
        algorithm: HashAlgorithm.xxh3_64,
        hashOptions: const HashOptions(seed: '18446744073709551615'),
      ),
      stringHash(
        'abc',
        algorithm: HashAlgorithm.xxh3_64,
        hashOptions: const HashOptions(seed: '0xffffffffffffffff'),
      ),
    );
    expect(
      stringHash(
        'abc',
        algorithm: HashAlgorithm.xxh3_64,
        hashOptions: HashOptions(seed: BigInt.from(12345)),
      ),
      stringHash(
        'abc',
        algorithm: HashAlgorithm.xxh3_64,
        hashOptions: const HashOptions(seed: '0x0000000000003039'),
      ),
    );
    expect(
      stringHash(
        'abc',
        algorithm: HashAlgorithm.xxh3_64,
        hashOptions: const HashOptions(seed: '12345678901234567890'),
      ),
      stringHash(
        'abc',
        algorithm: HashAlgorithm.xxh3_64,
        hashOptions: const HashOptions(seed: '0xab54a98ceb1f0ad2'),
      ),
    );
  });

  test('rejects invalid XXH3 seeds before native calls', () {
    for (final seed in <Object>[
      -1,
      '-1',
      'abc',
      '0x10000000000000000',
      '18446744073709551616',
      true,
    ]) {
      expect(
        () => stringHash(
          'abc',
          algorithm: HashAlgorithm.xxh3_64,
          hashOptions: HashOptions(seed: seed),
        ),
        throwsA(isA<FlutterFileHashException>()),
      );
    }
  });

  test('cancels before opening file input', () async {
    final controller = HashCancellationController();
    controller.cancel('stop');

    expect(
      fileHash('missing.txt', cancellationToken: controller.token),
      throwsA(
        isA<FlutterFileHashCancelledException>()
            .having((error) => error.code, 'code', 'cancelled')
            .having((error) => error.reason, 'reason', 'stop'),
      ),
    );
  });

  test('cancels before hashing string input', () {
    final controller = HashCancellationController();
    controller.cancel();

    expect(
      () => stringHash('abc', cancellationToken: controller.token),
      throwsA(isA<FlutterFileHashCancelledException>()),
    );
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
