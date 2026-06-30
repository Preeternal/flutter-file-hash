import 'dart:convert' as convert;
import 'dart:typed_data';

import 'hash_algorithm.dart';
import 'hash_exception.dart';
import 'hash_options.dart';

final class NormalizedHashOptions {
  const NormalizedHashOptions({
    required this.key,
    required this.hasKey,
    required this.seed,
    required this.hasSeed,
  });

  final Uint8List key;
  final bool hasKey;
  final int seed;
  final bool hasSeed;
}

NormalizedHashOptions normalizeHashOptions(
  HashAlgorithm algorithm,
  HashOptions? options,
) {
  final hasKey = options?.key != null;
  final hasSeed = options?.seed != null;

  if (algorithm.requiresKey && !hasKey) {
    throw const FlutterFileHashException(
      code: 'invalid_argument',
      message: 'Key is required for HMAC algorithms.',
    );
  }

  if (hasKey && !algorithm.supportsKey && !algorithm.requiresKey) {
    throw const FlutterFileHashException(
      code: 'invalid_argument',
      message: 'Key is only used for HMAC algorithms or BLAKE3.',
    );
  }

  if (hasSeed && !algorithm.supportsSeed) {
    throw const FlutterFileHashException(
      code: 'invalid_argument',
      message: 'Seed is only used for XXH3-64.',
    );
  }

  final key = hasKey ? _decodeKey(options!) : Uint8List(0);
  final expectedKeyLength = algorithm.keyLength;
  if (expectedKeyLength != null && hasKey && key.length != expectedKeyLength) {
    throw FlutterFileHashException(
      code: 'invalid_argument',
      message:
          '${algorithm.label} keyed mode requires a $expectedKeyLength-byte key.',
    );
  }

  final seed = options?.seed ?? 0;
  if (hasSeed && (seed < 0 || seed.bitLength > 64)) {
    throw const FlutterFileHashException(
      code: 'invalid_argument',
      message: '`seed` must fit into an unsigned 64-bit integer.',
    );
  }

  return NormalizedHashOptions(
    key: key,
    hasKey: hasKey,
    seed: seed,
    hasSeed: hasSeed,
  );
}

Uint8List _decodeKey(HashOptions options) {
  try {
    return switch (options.keyEncoding) {
      KeyEncoding.utf8 => Uint8List.fromList(convert.utf8.encode(options.key!)),
      KeyEncoding.base64 => Uint8List.fromList(
        convert.base64.decode(options.key!),
      ),
      KeyEncoding.hex => _decodeHex(options.key!),
    };
  } on FormatException catch (error) {
    throw FlutterFileHashException(
      code: 'invalid_argument',
      message: '`key` is not valid ${options.keyEncoding.label} data.',
      cause: error,
    );
  }
}

Uint8List _decodeHex(String input) {
  final cleaned = input.replaceAll(RegExp(r'\s+'), '');
  if (cleaned.length.isOdd) {
    throw const FormatException('Hex string must have an even length.');
  }

  final out = Uint8List(cleaned.length ~/ 2);
  for (var i = 0; i < cleaned.length; i += 2) {
    final byte = int.tryParse(cleaned.substring(i, i + 2), radix: 16);
    if (byte == null) {
      throw const FormatException('Hex string contains a non-hex byte.');
    }
    out[i ~/ 2] = byte;
  }

  return out;
}
