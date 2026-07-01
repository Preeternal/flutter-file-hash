import 'hash_exception.dart';

/// Function returned by cancellation subscriptions to remove the listener.
typedef HashCancellationDisposer = void Function();

/// Coordinates cooperative cancellation for a hash operation.
final class HashCancellationController {
  /// Creates a cancellation controller with a fresh [token].
  HashCancellationController() : token = HashCancellationToken._(_nextId());

  /// Token passed to hashing calls that should observe this controller.
  final HashCancellationToken token;

  /// Requests cancellation for operations using [token].
  void cancel([Object? reason]) {
    token._cancel(reason);
  }
}

/// Read-only cancellation token passed to hashing calls.
final class HashCancellationToken {
  HashCancellationToken._(this.operationId);

  /// Internal operation identifier used to pair Dart and native cancellation.
  final String operationId;
  bool _isCancelled = false;
  Object? _reason;
  final List<void Function()> _listeners = [];

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Optional reason supplied to [HashCancellationController.cancel].
  Object? get reason => _reason;

  /// Throws [FlutterFileHashCancelledException] if the token is cancelled.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw FlutterFileHashCancelledException(reason: _reason);
    }
  }

  /// Registers [listener] to be called when cancellation is requested.
  HashCancellationDisposer onCancel(void Function() listener) {
    if (_isCancelled) {
      listener();
      return () {};
    }

    _listeners.add(listener);
    return () {
      _listeners.remove(listener);
    };
  }

  void _cancel(Object? reason) {
    if (_isCancelled) {
      return;
    }

    _isCancelled = true;
    _reason = reason;

    final listeners = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

/// Exception thrown when a hash operation is cancelled cooperatively.
final class FlutterFileHashCancelledException extends FlutterFileHashException {
  /// Creates a cancellation exception with an optional [reason].
  const FlutterFileHashCancelledException({this.reason})
    : super(code: 'cancelled', message: 'Hash computation cancelled.');

  /// Optional reason supplied by the caller that requested cancellation.
  final Object? reason;
}

int _nextOperationId = 0;

String _nextId() {
  _nextOperationId += 1;
  return 'flutter-file-hash:$_nextOperationId';
}
