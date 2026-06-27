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

const int _defaultChunkSize = 64 * 1024;

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
  if (cancellationToken != null) {
    return _fileHashCancellable(
      dartPath,
      algorithm,
      normalizedOptions,
      cancellationToken,
    );
  }

  return Isolate.run(
    () => _fileHashSync(dartPath, algorithm, normalizedOptions),
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

Future<String> _fileHashCancellable(
  String path,
  HashAlgorithm algorithm,
  NormalizedHashOptions options,
  HashCancellationToken cancellationToken,
) async {
  RandomAccessFile? file;
  ZigStreamHasher? hasher;
  HashCancellationDisposer? disposeCancel;

  try {
    cancellationToken.throwIfCancelled();
    file = await File(path).open();
    disposeCancel = cancellationToken.onCancel(() {
      final activeFile = file;
      if (activeFile != null) {
        unawaited(activeFile.close().catchError((_) {}));
      }
    });

    hasher = ZigStreamHasher(algorithm, options);
    final buffer = Uint8List(_defaultChunkSize);

    while (true) {
      cancellationToken.throwIfCancelled();
      final read = await file.readInto(buffer);
      cancellationToken.throwIfCancelled();
      if (read == 0) {
        break;
      }

      hasher.update(Uint8List.sublistView(buffer, 0, read));
    }

    final result = hasher.finalHex();
    cancellationToken.throwIfCancelled();
    return result;
  } on FileSystemException catch (error) {
    cancellationToken.throwIfCancelled();
    throw FlutterFileHashException(
      code: 'io_error',
      message: error.message,
      cause: error,
    );
  } catch (_) {
    cancellationToken.throwIfCancelled();
    rethrow;
  } finally {
    disposeCancel?.call();
    hasher?.dispose();
    final activeFile = file;
    if (activeFile != null) {
      try {
        await activeFile.close();
      } on FileSystemException {
        // The file can already be closed by cancellation.
      }
    }
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

const int _u64Max = 0xffffffffffffffff;
const int _fnv1a64OffsetBasis = 0xcbf29ce484222325;
const int _fnv1a64Prime = 0x100000001b3;
