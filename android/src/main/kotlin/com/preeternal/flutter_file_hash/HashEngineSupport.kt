package com.preeternal.flutter_file_hash

import android.content.Context
import android.net.Uri
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.InputStream

internal const val DEFAULT_BUFFER_SIZE = 64 * 1024

internal fun openInputStream(
    context: Context,
    filePath: String
): InputStream {
    val uri = Uri.parse(filePath)
    return when (uri.scheme?.lowercase()) {
        null, "", "file" -> {
            val path = if (uri.scheme == "file") uri.path ?: filePath else filePath
            val file = File(path)
            if (!file.exists()) {
                throw FileNotFoundException("File not found: $filePath")
            }
            FileInputStream(file)
        }
        "content" -> {
            context.contentResolver.openInputStream(uri)
                ?: throw FileNotFoundException("Cannot open content uri: $filePath")
        }
        else -> {
            context.contentResolver.openInputStream(uri)
                ?: throw FileNotFoundException("Unsupported uri scheme or cannot open: $filePath")
        }
    }
}

internal fun toHex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it) }

internal fun parseUnsignedSeed(seed: String?): Long {
    if (seed.isNullOrBlank()) {
        return 0L
    }

    val normalized = seed.trim()
    val (digits, radix) = if (normalized.startsWith("0x", ignoreCase = true)) {
        Pair(normalized.substring(2), 16)
    } else {
        Pair(normalized, 10)
    }

    require(digits.isNotEmpty()) {
        "Seed must be a non-negative u64 decimal string or 0x hex string"
    }

    return try {
        java.lang.Long.parseUnsignedLong(digits, radix)
    } catch (e: NumberFormatException) {
        throw IllegalArgumentException("Seed must fit into an unsigned 64-bit integer", e)
    }
}
