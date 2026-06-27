import 'hash_exception.dart';

typedef HashCancellationDisposer = void Function();

final class HashCancellationController {
  HashCancellationController() : token = HashCancellationToken._(_nextId());

  final HashCancellationToken token;

  void cancel([Object? reason]) {
    token._cancel(reason);
  }
}

final class HashCancellationToken {
  HashCancellationToken._(this.operationId);

  final String operationId;
  bool _isCancelled = false;
  Object? _reason;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _isCancelled;

  Object? get reason => _reason;

  void throwIfCancelled() {
    if (_isCancelled) {
      throw FlutterFileHashCancelledException(reason: _reason);
    }
  }

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

final class FlutterFileHashCancelledException extends FlutterFileHashException {
  const FlutterFileHashCancelledException({this.reason})
    : super(code: 'cancelled', message: 'Hash computation cancelled.');

  final Object? reason;
}

int _nextOperationId = 0;

String _nextId() {
  _nextOperationId += 1;
  return 'flutter-file-hash:$_nextOperationId';
}
