/// Base exception type thrown by `flutter_file_hash`.
class FlutterFileHashException implements Exception {
  /// Creates a package exception with a stable [code] and user-facing [message].
  const FlutterFileHashException({
    required this.code,
    required this.message,
    this.cause,
  });

  /// Stable machine-readable error code.
  final String code;

  /// Human-readable error message.
  final String message;

  /// Original error object, when one is available.
  final Object? cause;

  @override
  String toString() => 'FlutterFileHashException($code): $message';
}
