import 'dart:ffi' as ffi;

const String zfhAssetId =
    'package:flutter_file_hash/src/zig_files_hash_bindings.dart';
const int zfhApiVersionExpected = 3;
const int zfhOk = 0;
const int zfhOptionHasSeed = 1 << 0;
const int zfhOptionHasKey = 1 << 1;

final class ZfhOptions extends ffi.Struct {
  @ffi.Uint32()
  external int structSize;

  @ffi.Uint32()
  external int flags;

  @ffi.Uint64()
  external int seed;

  external ffi.Pointer<ffi.Uint8> keyPtr;

  @ffi.Size()
  external int keyLen;
}

final class ZfhRequest extends ffi.Struct {
  @ffi.Uint32()
  external int structSize;

  external ffi.Pointer<ZfhOptions> optionsPtr;

  external ffi.Pointer<ffi.Void> operationPtr;

  @ffi.Size()
  external int operationLen;
}

@ffi.Native<ffi.Uint32 Function()>(
  assetId: zfhAssetId,
  symbol: 'zfh_api_version',
)
external int zfhApiVersion();

@ffi.Native<ffi.Size Function()>(
  assetId: zfhAssetId,
  symbol: 'zfh_max_digest_length',
)
external int zfhMaxDigestLength();

@ffi.Native<ffi.Pointer<ffi.Char> Function(ffi.Int32)>(
  assetId: zfhAssetId,
  symbol: 'zfh_error_message',
)
external ffi.Pointer<ffi.Char> zfhErrorMessage(int code);

@ffi.Native<ffi.Size Function()>(
  assetId: zfhAssetId,
  symbol: 'zfh_hasher_state_size',
)
external int zfhHasherStateSize();

@ffi.Native<ffi.Size Function()>(
  assetId: zfhAssetId,
  symbol: 'zfh_hasher_state_align',
)
external int zfhHasherStateAlign();

@ffi.Native<
  ffi.Int32 Function(
    ffi.Int32,
    ffi.Pointer<ZfhRequest>,
    ffi.Pointer<ffi.Void>,
    ffi.Size,
  )
>(assetId: zfhAssetId, symbol: 'zfh_hasher_init_inplace')
external int zfhHasherInitInplace(
  int algorithm,
  ffi.Pointer<ZfhRequest> requestPtr,
  ffi.Pointer<ffi.Void> statePtr,
  int stateLen,
);

@ffi.Native<
  ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Size,
    ffi.Pointer<ffi.Uint8>,
    ffi.Size,
  )
>(assetId: zfhAssetId, symbol: 'zfh_hasher_update')
external int zfhHasherUpdate(
  ffi.Pointer<ffi.Void> statePtr,
  int stateLen,
  ffi.Pointer<ffi.Uint8> dataPtr,
  int dataLen,
);

@ffi.Native<
  ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Size,
    ffi.Pointer<ffi.Uint8>,
    ffi.Size,
    ffi.Pointer<ffi.Size>,
  )
>(assetId: zfhAssetId, symbol: 'zfh_hasher_final')
external int zfhHasherFinal(
  ffi.Pointer<ffi.Void> statePtr,
  int stateLen,
  ffi.Pointer<ffi.Uint8> outPtr,
  int outLen,
  ffi.Pointer<ffi.Size> writtenLenPtr,
);
