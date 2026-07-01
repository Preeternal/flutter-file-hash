import 'dart:convert' as convert;
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'android_file_hash.dart';
import 'hash_algorithm.dart';
import 'hash_cancellation.dart';
import 'hash_exception.dart';
import 'hash_options.dart';
import 'option_codec.dart';
import 'zig_stream_hasher.dart';

Future<String> fileHash(
  String path, {
  HashAlgorithm algorithm = HashAlgorithm.sha256,
  HashOptions? hashOptions,
  HashCancellationToken? cancellationToken,
}) async {
  final normalizedOptions = normalizeHashOptions(algorithm, hashOptions);
  cancellationToken?.throwIfCancelled();

  if (AndroidFileHash.shouldUsePlatformOpener(path)) {
    return AndroidFileHash.fileHash(
      path,
      algorithm: algorithm,
      options: normalizedOptions,
      cancellationToken: cancellationToken,
    );
  }

  final dartPath = _normalizeDartFilePath(path);
  return _fileHashNative(
    dartPath,
    algorithm,
    normalizedOptions,
    cancellationToken,
  );
}

String stringHash(
  String input, {
  HashAlgorithm algorithm = HashAlgorithm.sha256,
  HashInputEncoding encoding = HashInputEncoding.utf8,
  HashOptions? hashOptions,
  HashCancellationToken? cancellationToken,
}) {
  final normalizedOptions = normalizeHashOptions(algorithm, hashOptions);
  cancellationToken?.throwIfCancelled();
  final inputBytes = _decodeInput(input, encoding);
  final result = _hashBytes(inputBytes, algorithm, normalizedOptions);
  cancellationToken?.throwIfCancelled();
  return result;
}

String xxh3SeedFromLabel(String label) {
  var hash = _fnv1a64OffsetBasis;

  for (final byte in convert.utf8.encode(label)) {
    hash ^= BigInt.from(byte);
    hash = (hash * _fnv1a64Prime) & _u64Max;
  }

  return formatU64SeedHex(hash);
}

Future<String> _fileHashNative(
  String path,
  HashAlgorithm algorithm,
  NormalizedHashOptions options,
  HashCancellationToken? cancellationToken,
) async {
  cancellationToken?.throwIfCancelled();
  final operation = cancellationToken == null ? null : ZigHashOperation();
  final operationAddress = operation?.address ?? 0;
  final operationLength = operation?.length ?? 0;
  HashCancellationDisposer? disposeCancel;

  try {
    disposeCancel = cancellationToken?.onCancel(() {
      try {
        operation?.cancel();
      } catch (_) {
        // The active native call will surface cancellation or its own error.
      }
    });

    final result = await Isolate.run(
      () => zigFileHashPath(
        path,
        algorithm,
        options,
        operationPtrAddress: operationAddress,
        operationLen: operationLength,
      ),
    );
    cancellationToken?.throwIfCancelled();
    return result;
  } catch (_) {
    cancellationToken?.throwIfCancelled();
    rethrow;
  } finally {
    disposeCancel?.call();
    operation?.dispose();
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

String _normalizeDartFilePath(String path) {
  try {
    final uri = Uri.parse(path);
    if (uri.scheme.toLowerCase() == 'file') {
      return uri.toFilePath(windows: Platform.isWindows);
    }
  } on FormatException {
    return path;
  }

  return path;
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

final BigInt _u64Max = (BigInt.one << 64) - BigInt.one;
final BigInt _fnv1a64OffsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
final BigInt _fnv1a64Prime = BigInt.parse('100000001b3', radix: 16);
