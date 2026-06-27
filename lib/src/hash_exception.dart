class FlutterFileHashException implements Exception {
  const FlutterFileHashException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'FlutterFileHashException($code): $message';
}
