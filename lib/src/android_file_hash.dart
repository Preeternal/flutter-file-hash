import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'hash_algorithm.dart';
import 'hash_cancellation.dart';
import 'hash_exception.dart';
import 'option_codec.dart';

final class AndroidFileHash {
  AndroidFileHash._();

  static const MethodChannel _channel = MethodChannel('flutter_file_hash');

  static bool shouldUsePlatformOpener(String path) {
    if (!Platform.isAndroid) {
      return false;
    }

    return _uriScheme(path) == 'content';
  }

  static Future<String> fileHash(
    String path, {
    required HashAlgorithm algorithm,
    required NormalizedHashOptions options,
    HashCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();

    final operationId = cancellationToken?.operationId;
    final disposeCancel = cancellationToken?.onCancel(() {
      unawaited(
        _channel
            .invokeMethod<void>('cancelOperation', {'operationId': operationId})
            .catchError((_) {}),
      );
    });

    try {
      final result = await _channel.invokeMethod<String>('fileHashUri', {
        'path': path,
        'algorithmId': algorithm.zigId,
        'hasKey': options.hasKey,
        'key': options.hasKey ? options.key : null,
        'hasSeed': options.hasSeed,
        'seed': options.hasSeed ? options.seedString : null,
        'operationId': operationId,
      });

      cancellationToken?.throwIfCancelled();
      if (result == null) {
        throw const FlutterFileHashException(
          code: 'hash_failed',
          message: 'Android native hash returned null.',
        );
      }
      return result;
    } on PlatformException catch (error) {
      if (cancellationToken?.isCancelled ?? false) {
        cancellationToken?.throwIfCancelled();
      }
      throw FlutterFileHashException(
        code: error.code,
        message: error.message ?? 'Android native hash failed.',
        cause: error,
      );
    } finally {
      disposeCancel?.call();
    }
  }
}

String? _uriScheme(String value) {
  try {
    return Uri.parse(value).scheme.toLowerCase();
  } on FormatException {
    return null;
  }
}
