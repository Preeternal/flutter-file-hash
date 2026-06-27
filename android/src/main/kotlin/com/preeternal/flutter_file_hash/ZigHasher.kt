package com.preeternal.flutter_file_hash

internal object ZigHasher {
    init {
        System.loadLibrary("flutter_file_hash")
    }

    external fun apiVersion(): Int

    external fun expectedApiVersion(): Int

    external fun streamHasherCreate(
        algorithmId: Int,
        key: ByteArray?,
        seed: Long,
        hasSeed: Boolean,
        operationId: String?
    ): Long

    external fun streamHasherUpdate(
        handle: Long,
        data: ByteArray,
        length: Int
    )

    external fun streamHasherFinal(handle: Long): ByteArray?

    external fun streamHasherFree(handle: Long)

    external fun cancelOperation(operationId: String)
}
