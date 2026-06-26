import 'dart:convert' as convert;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'hash_algorithm.dart';
import 'hash_exception.dart';
import 'hash_options.dart';
import 'option_codec.dart';
import 'zig_stream_hasher.dart';

const int _defaultChunkSize = 64 * 1024;

Future<String> fileHash(
  String path, {
  HashAlgorithm algorithm = HashAlgorithm.sha256,
  HashOptions? hashOptions,
}) {
  final normalizedOptions = normalizeHashOptions(algorithm, hashOptions);
  return Isolate.run(() => _fileHashSync(path, algorithm, normalizedOptions));
}

String stringHash(
  String input, {
  HashAlgorithm algorithm = HashAlgorithm.sha256,
  HashInputEncoding encoding = HashInputEncoding.utf8,
  HashOptions? hashOptions,
}) {
  final normalizedOptions = normalizeHashOptions(algorithm, hashOptions);
  final inputBytes = _decodeInput(input, encoding);
  return _hashBytes(inputBytes, algorithm, normalizedOptions);
}

int xxh3SeedFromLabel(String label) {
  var hash = _fnv1a64OffsetBasis;

  for (final byte in convert.utf8.encode(label)) {
    hash ^= byte;
    hash = (hash * _fnv1a64Prime) & _u64Max;
  }

  return hash;
}

String _fileHashSync(
  String path,
  HashAlgorithm algorithm,
  NormalizedHashOptions options,
) {
  RandomAccessFile? file;
  ZigStreamHasher? hasher;

  try {
    file = File(path).openSync();
    hasher = ZigStreamHasher(algorithm, options);

    final buffer = Uint8List(_defaultChunkSize);
    while (true) {
      final read = file.readIntoSync(buffer);
      if (read == 0) {
        break;
      }

      hasher.update(Uint8List.sublistView(buffer, 0, read));
    }

    return hasher.finalHex();
  } on FileSystemException catch (error) {
    throw FlutterFileHashException(
      code: 'io_error',
      message: error.message,
      cause: error,
    );
  } finally {
    hasher?.dispose();
    file?.closeSync();
  }
}

String _hashBytes(
  Uint8List bytes,
  HashAlgorithm algorithm,
  NormalizedHashOptions options,
) {
  final hasher = ZigStreamHasher(algorithm, options);
  try {
    if (bytes.isNotEmpty) {
      hasher.update(bytes);
    }
    return hasher.finalHex();
  } finally {
    hasher.dispose();
  }
}

Uint8List _decodeInput(String input, HashInputEncoding encoding) {
  try {
    return switch (encoding) {
      HashInputEncoding.utf8 => Uint8List.fromList(convert.utf8.encode(input)),
      HashInputEncoding.base64 => Uint8List.fromList(
        convert.base64.decode(input),
      ),
    };
  } on FormatException catch (error) {
    throw FlutterFileHashException(
      code: 'invalid_argument',
      message: '`input` is not valid ${encoding.label} data.',
      cause: error,
    );
  }
}

const int _u64Max = 0xffffffffffffffff;
const int _fnv1a64OffsetBasis = 0xcbf29ce484222325;
const int _fnv1a64Prime = 0x100000001b3;
