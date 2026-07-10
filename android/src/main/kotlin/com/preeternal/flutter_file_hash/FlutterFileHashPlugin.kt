package com.preeternal.flutter_file_hash

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.FileNotFoundException
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap

class FlutterFileHashPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    private lateinit var scope: CoroutineScope
    private val activeOperations = ConcurrentHashMap<String, HashOperation>()
    private val cancelledOperationIds = Collections.newSetFromMap(
        ConcurrentHashMap<String, Boolean>()
    )

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = flutterPluginBinding
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_file_hash")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "fileHashUri" -> fileHashUri(call, result)
            "cancelOperation" -> {
                cancelOperation(call.argument<String>("operationId"))
                result.success(null)
            }
            "getRuntimeDiagnostics" -> runtimeDiagnostics(result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        activeOperations.values.forEach { it.cancel() }
        activeOperations.clear()
        cancelledOperationIds.clear()
        scope.cancel()
    }

    private fun runtimeDiagnostics(result: Result) {
        try {
            result.success(
                mapOf(
                    "engine" to "zig",
                    "zigApiVersion" to ZigHasher.apiVersion(),
                    "zigExpectedApiVersion" to ZigHasher.expectedApiVersion(),
                    "zigApiCompatible" to (ZigHasher.apiVersion() == ZigHasher.expectedApiVersion())
                )
            )
        } catch (error: UnsatisfiedLinkError) {
            result.error("unavailable_native_runtime", error.message, null)
        } catch (error: Exception) {
            result.error("hash_failed", "Failed to read runtime diagnostics", error.message)
        }
    }

    private fun fileHashUri(call: MethodCall, result: Result) {
        val path = call.argument<String>("path")
        val algorithmId = call.argument<Int>("algorithmId")
        val hasKey = call.argument<Boolean>("hasKey") ?: false
        val key = call.argument<ByteArray>("key")
        val hasSeed = call.argument<Boolean>("hasSeed") ?: false
        val operation = createOperation(call.argument<String>("operationId"))

        if (path.isNullOrBlank() || algorithmId == null) {
            result.error("invalid_argument", "`path` and `algorithmId` are required.", null)
            finishOperation(operation)
            return
        }

        scope.launch {
            try {
                val seed = parseUnsignedSeed(call.argument<String>("seed"))
                operation?.throwIfCancelled()
                val hex = hashUri(
                    path = path,
                    algorithmId = algorithmId,
                    key = if (hasKey) key ?: ByteArray(0) else null,
                    seed = seed,
                    hasSeed = hasSeed,
                    operation = operation
                )
                operation?.throwIfCancelled()
                result.success(hex)
            } catch (error: IllegalArgumentException) {
                result.error("invalid_argument", error.message, null)
            } catch (error: FileNotFoundException) {
                result.error("file_not_found", error.message, null)
            } catch (error: SecurityException) {
                result.error("access_denied", error.message, null)
            } catch (error: CancellationException) {
                result.error("cancelled", "Hash computation cancelled", null)
            } catch (error: Exception) {
                if (operation?.isCancelled == true) {
                    result.error("cancelled", "Hash computation cancelled", null)
                } else {
                    result.error("hash_failed", error.message ?: "Failed to compute hash", null)
                }
            } finally {
                finishOperation(operation)
            }
        }
    }

    private fun hashUri(
        path: String,
        algorithmId: Int,
        key: ByteArray?,
        seed: Long,
        hasSeed: Boolean,
        operation: HashOperation?
    ): String {
        val uri = Uri.parse(path)
        if (uri.scheme.equals("content", ignoreCase = true)) {
            val descriptor = try {
                binding.applicationContext.contentResolver.openFileDescriptor(uri, "r")
            } catch (_: FileNotFoundException) {
                // Some virtual document providers expose a stream but not an fd.
                null
            }

            if (descriptor != null) {
                return hashFileDescriptor(
                    descriptor = descriptor,
                    algorithmId = algorithmId,
                    key = key,
                    seed = seed,
                    hasSeed = hasSeed,
                    operation = operation
                )
            }
        }

        return hashUriStreaming(path, algorithmId, key, seed, hasSeed, operation)
    }

    private fun hashFileDescriptor(
        descriptor: ParcelFileDescriptor,
        algorithmId: Int,
        key: ByteArray?,
        seed: Long,
        hasSeed: Boolean,
        operation: HashOperation?
    ): String {
        fun hashOpenDescriptor(openDescriptor: ParcelFileDescriptor): String {
            operation?.throwIfCancelled()
            val digest = ZigHasher.fileHashFd(
                algorithmId,
                openDescriptor.fd,
                key,
                seed,
                hasSeed,
                operation?.id
            ) ?: throw IllegalStateException("Zig engine returned null digest")
            operation?.throwIfCancelled()
            return toHex(digest)
        }

        return if (operation != null) {
            operation.useCloseable(descriptor) { openDescriptor ->
                openDescriptor.use(::hashOpenDescriptor)
            }
        } else {
            descriptor.use(::hashOpenDescriptor)
        }
    }

    private fun hashUriStreaming(
        path: String,
        algorithmId: Int,
        key: ByteArray?,
        seed: Long,
        hasSeed: Boolean,
        operation: HashOperation?
    ): String {
        val inputStream = openInputStream(binding.applicationContext, path)
        return if (operation != null) {
            operation.useCloseable(inputStream) { stream ->
                stream.use {
                    hashStream(it, algorithmId, key, seed, hasSeed, operation)
                }
            }
        } else {
            inputStream.use {
                hashStream(it, algorithmId, key, seed, hasSeed, null)
            }
        }
    }

    private fun hashStream(
        stream: java.io.InputStream,
        algorithmId: Int,
        key: ByteArray?,
        seed: Long,
        hasSeed: Boolean,
        operation: HashOperation?
    ): String {
        val handle = ZigHasher.streamHasherCreate(
            algorithmId,
            key,
            seed,
            hasSeed,
            operation?.id
        )
        require(handle != 0L) { "Failed to create Zig streaming hasher" }

        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var read: Int
        try {
            operation?.throwIfCancelled()
            while (stream.read(buffer).also { read = it } != -1) {
                operation?.throwIfCancelled()
                if (read > 0) {
                    ZigHasher.streamHasherUpdate(handle, buffer, read)
                }
            }
            operation?.throwIfCancelled()

            val digest =
                ZigHasher.streamHasherFinal(handle)
                    ?: throw IllegalStateException("Zig engine returned null digest")
            operation?.throwIfCancelled()
            return toHex(digest)
        } finally {
            ZigHasher.streamHasherFree(handle)
        }
    }

    private fun cancelOperation(operationId: String?) {
        if (operationId.isNullOrBlank()) {
            return
        }

        cancelledOperationIds.add(operationId)
        activeOperations[operationId]?.cancel()

        try {
            ZigHasher.cancelOperation(operationId)
        } catch (_: UnsatisfiedLinkError) {
            // Runtime load failures are surfaced by the active operation.
        }
    }

    private fun createOperation(operationId: String?): HashOperation? {
        if (operationId.isNullOrBlank()) {
            return null
        }

        val operation = HashOperation(operationId)
        activeOperations[operationId] = operation
        if (cancelledOperationIds.remove(operationId)) {
            operation.cancel()
        }
        return operation
    }

    private fun finishOperation(operation: HashOperation?) {
        if (operation == null) {
            return
        }
        activeOperations.remove(operation.id, operation)
        cancelledOperationIds.remove(operation.id)
    }
}
