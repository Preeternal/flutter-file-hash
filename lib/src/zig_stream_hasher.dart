import 'dart:convert' as convert;
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as pkg_ffi;

import 'hash_algorithm.dart';
import 'hash_exception.dart';
import 'hex.dart';
import 'option_codec.dart';
import 'zig_files_hash_bindings.dart' as zfh;

String zigFileHashPath(
  String path,
  HashAlgorithm algorithm,
  NormalizedHashOptions options, {
  bool useMmap = false,
  int operationPtrAddress = 0,
  int operationLen = 0,
}) {
  _ensureCompatibleApi();

  final pathBytes = Uint8List.fromList(convert.utf8.encode(path));
  final pathPtr = pkg_ffi.calloc<ffi.Uint8>(pathBytes.length);
  final outLen = zfh.zfhMaxDigestLength();
  final outPtr = pkg_ffi.calloc<ffi.Uint8>(outLen);
  final writtenLenPtr = pkg_ffi.calloc<ffi.Size>();
  final ctxPtrPtr = pkg_ffi.calloc<ffi.Pointer<zfh.ZfhContext>>();
  ffi.Pointer<zfh.ZfhContext>? ctxPtr;
  final request = _buildRequest(
    options,
    useMmap: useMmap,
    operationPtrAddress: operationPtrAddress,
    operationLen: operationLen,
  );

  try {
    pathPtr.asTypedList(pathBytes.length).setAll(0, pathBytes);
    _check(zfh.zfhContextCreate(ctxPtrPtr));
    ctxPtr = ctxPtrPtr.value;

    _check(
      zfh.zfhContextFileHash(
        ctxPtr,
        algorithm.zigId,
        pathPtr,
        pathBytes.length,
        request.requestPtr,
        outPtr,
        outLen,
        writtenLenPtr,
      ),
    );

    return hexEncode(
      Uint8List.fromList(outPtr.asTypedList(writtenLenPtr.value)),
    );
  } finally {
    request.dispose();
    if (ctxPtr != null && ctxPtr != ffi.nullptr) {
      zfh.zfhContextDestroy(ctxPtr);
    }
    pkg_ffi.calloc.free(ctxPtrPtr);
    pkg_ffi.calloc.free(writtenLenPtr);
    pkg_ffi.calloc.free(outPtr);
    pkg_ffi.calloc.free(pathPtr);
  }
}

final class ZigHashOperation {
  ZigHashOperation() {
    _ensureCompatibleApi();

    final stateSize = zfh.zfhOperationStateSize();
    final stateAlign = zfh.zfhOperationStateAlign();
    final stateStorage = _allocateAligned(stateSize, stateAlign);
    _stateBasePtr = stateStorage.basePtr;
    _statePtr = stateStorage.alignedPtr;
    _stateLen = stateStorage.len;

    try {
      _check(zfh.zfhOperationInitInplace(_statePtr, _stateLen));
      _initialized = true;
    } catch (_) {
      pkg_ffi.calloc.free(_stateBasePtr);
      rethrow;
    }
  }

  late final ffi.Pointer<ffi.Uint8> _stateBasePtr;
  late final ffi.Pointer<ffi.Void> _statePtr;
  late final int _stateLen;
  bool _initialized = false;
  bool _disposed = false;

  int get address => _statePtr.address;

  int get length => _stateLen;

  void cancel() {
    if (!_initialized || _disposed) {
      return;
    }
    _check(zfh.zfhOperationCancel(_statePtr, _stateLen));
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    if (_initialized) {
      pkg_ffi.calloc.free(_stateBasePtr);
    }
    _disposed = true;
  }
}

final class ZigStreamHasher {
  ZigStreamHasher(this.algorithm, this.options) {
    _ensureCompatibleApi();

    final stateSize = zfh.zfhHasherStateSize();
    final stateAlign = zfh.zfhHasherStateAlign();
    final stateStorage = _allocateAligned(stateSize, stateAlign);
    _stateBasePtr = stateStorage.basePtr;
    _statePtr = stateStorage.alignedPtr;
    _stateLen = stateStorage.len;

    final request = _buildRequest(options);
    try {
      _check(
        zfh.zfhHasherInitInplace(
          algorithm.zigId,
          request.requestPtr,
          _statePtr,
          _stateLen,
        ),
      );
      _initialized = true;
    } finally {
      request.dispose();
    }
  }

  final HashAlgorithm algorithm;
  final NormalizedHashOptions options;

  late final ffi.Pointer<ffi.Uint8> _stateBasePtr;
  late final ffi.Pointer<ffi.Void> _statePtr;
  late final int _stateLen;
  bool _initialized = false;
  bool _disposed = false;
  bool _finalized = false;

  void update(Uint8List data) {
    _ensureUsable();
    if (data.isEmpty) {
      return;
    }

    final dataPtr = pkg_ffi.calloc<ffi.Uint8>(data.length);
    try {
      dataPtr.asTypedList(data.length).setAll(0, data);
      _check(zfh.zfhHasherUpdate(_statePtr, _stateLen, dataPtr, data.length));
    } finally {
      pkg_ffi.calloc.free(dataPtr);
    }
  }

  String finalHex() {
    _ensureUsable();
    final outLen = zfh.zfhMaxDigestLength();
    final outPtr = pkg_ffi.calloc<ffi.Uint8>(outLen);
    final writtenLenPtr = pkg_ffi.calloc<ffi.Size>();

    try {
      _check(
        zfh.zfhHasherFinal(_statePtr, _stateLen, outPtr, outLen, writtenLenPtr),
      );
      _finalized = true;
      return hexEncode(
        Uint8List.fromList(outPtr.asTypedList(writtenLenPtr.value)),
      );
    } finally {
      pkg_ffi.calloc.free(writtenLenPtr);
      pkg_ffi.calloc.free(outPtr);
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    if (_initialized) {
      pkg_ffi.calloc.free(_stateBasePtr);
    }
    _disposed = true;
  }

  void _ensureUsable() {
    if (_disposed) {
      throw const FlutterFileHashException(
        code: 'invalid_state',
        message: 'Hasher has already been disposed.',
      );
    }
    if (_finalized) {
      throw const FlutterFileHashException(
        code: 'invalid_state',
        message: 'Hasher has already been finalized.',
      );
    }
  }
}

void _ensureCompatibleApi() {
  final version = zfh.zfhApiVersion();
  if (version != zfh.zfhApiVersionExpected) {
    throw FlutterFileHashException(
      code: 'incompatible_native_api',
      message:
          'zig-files-hash C ABI version $version is not compatible with expected version ${zfh.zfhApiVersionExpected}.',
    );
  }
}

void _check(int code) {
  if (code == zfh.zfhOk) {
    return;
  }

  throw FlutterFileHashException(
    code: _errorCode(code),
    message: zfh.zfhErrorMessage(code).cast<pkg_ffi.Utf8>().toDartString(),
  );
}

String _errorCode(int code) {
  return switch (code) {
    1 => 'invalid_argument',
    2 => 'unsupported_algorithm',
    3 => 'invalid_key',
    4 => 'invalid_key',
    5 => 'buffer_too_small',
    6 => 'cancelled',
    7 => 'invalid_state',
    8 => 'file_not_found',
    9 => 'access_denied',
    10 => 'invalid_path',
    11 => 'io_error',
    _ => 'hash_failed',
  };
}

_RequestAllocation _buildRequest(
  NormalizedHashOptions options, {
  bool useMmap = false,
  int operationPtrAddress = 0,
  int operationLen = 0,
}) {
  final hasOperation = operationPtrAddress != 0 && operationLen > 0;
  final hasOptions = options.hasKey || options.hasSeed || useMmap;
  if (!hasOptions && !hasOperation) {
    return _RequestAllocation.empty();
  }

  final requestPtr = pkg_ffi.calloc<zfh.ZfhRequest>();
  final optionsPtr = hasOptions
      ? pkg_ffi.calloc<zfh.ZfhOptions>()
      : ffi.nullptr;
  ffi.Pointer<ffi.Uint8>? keyPtr;

  if (optionsPtr != ffi.nullptr) {
    optionsPtr.ref
      ..structSize = ffi.sizeOf<zfh.ZfhOptions>()
      ..flags = 0
      ..seed = 0
      ..keyPtr = ffi.nullptr
      ..keyLen = 0;
  }

  if (options.hasKey) {
    if (options.key.isEmpty) {
      optionsPtr.ref.keyPtr = ffi.nullptr;
      optionsPtr.ref.keyLen = 0;
    } else {
      keyPtr = pkg_ffi.calloc<ffi.Uint8>(options.key.length);
      keyPtr.asTypedList(options.key.length).setAll(0, options.key);
      optionsPtr.ref.keyPtr = keyPtr;
      optionsPtr.ref.keyLen = options.key.length;
    }
    optionsPtr.ref.flags |= zfh.zfhOptionHasKey;
  }

  if (options.hasSeed) {
    optionsPtr.ref.flags |= zfh.zfhOptionHasSeed;
    optionsPtr.ref.seed = options.seed.toUnsigned(64);
  }

  if (useMmap) {
    optionsPtr.ref.flags |= zfh.zfhOptionUseMmap;
  }

  requestPtr.ref
    ..structSize = ffi.sizeOf<zfh.ZfhRequest>()
    ..optionsPtr = optionsPtr
    ..operationPtr = hasOperation
        ? ffi.Pointer<ffi.Void>.fromAddress(operationPtrAddress)
        : ffi.nullptr
    ..operationLen = hasOperation ? operationLen : 0;

  return _RequestAllocation(
    requestPtr: requestPtr,
    optionsPtr: optionsPtr,
    keyPtr: keyPtr,
  );
}

_AlignedAllocation _allocateAligned(int requiredSize, int requiredAlign) {
  if (requiredSize <= 0 ||
      requiredAlign <= 0 ||
      !_isPowerOfTwo(requiredAlign)) {
    throw const FlutterFileHashException(
      code: 'invalid_state',
      message: 'Native hasher returned invalid state size or alignment.',
    );
  }

  final capacity = requiredSize + requiredAlign - 1;
  final basePtr = pkg_ffi.calloc<ffi.Uint8>(capacity);
  final baseAddress = basePtr.address;
  final alignedAddress = (baseAddress + requiredAlign - 1) & -requiredAlign;
  final offset = alignedAddress - baseAddress;

  return _AlignedAllocation(
    basePtr: basePtr,
    alignedPtr: ffi.Pointer<ffi.Void>.fromAddress(alignedAddress),
    len: capacity - offset,
  );
}

bool _isPowerOfTwo(int value) => value != 0 && (value & (value - 1)) == 0;

final class _AlignedAllocation {
  const _AlignedAllocation({
    required this.basePtr,
    required this.alignedPtr,
    required this.len,
  });

  final ffi.Pointer<ffi.Uint8> basePtr;
  final ffi.Pointer<ffi.Void> alignedPtr;
  final int len;
}

final class _RequestAllocation {
  const _RequestAllocation({
    required this.requestPtr,
    required this.optionsPtr,
    required this.keyPtr,
  });

  factory _RequestAllocation.empty() {
    return _RequestAllocation(
      requestPtr: ffi.nullptr,
      optionsPtr: ffi.nullptr,
      keyPtr: null,
    );
  }

  final ffi.Pointer<zfh.ZfhRequest> requestPtr;
  final ffi.Pointer<zfh.ZfhOptions> optionsPtr;
  final ffi.Pointer<ffi.Uint8>? keyPtr;

  void dispose() {
    final key = keyPtr;
    if (key != null) {
      pkg_ffi.calloc.free(key);
    }
    if (optionsPtr != ffi.nullptr) {
      pkg_ffi.calloc.free(optionsPtr);
    }
    if (requestPtr != ffi.nullptr) {
      pkg_ffi.calloc.free(requestPtr);
    }
  }
}
