#include "zig_bridge.h"

#include <cstddef>
#include <cstdint>
#include <mutex>
#include <new>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "error_mapping.h"
#include "jni_utils.h"
#include "zig_files_hash_c_api.h"

namespace {

struct PreparedRequest {
    zfh_algorithm algorithm = ZFH_ALG_SHA_256;
    zfh_options options{};
    bool has_options = false;
};

struct ZigOperationState {
    std::vector<uint8_t> storage;
    void *state_ptr = nullptr;
    size_t state_len = 0;
};

std::mutex g_operation_mutex;
std::unordered_map<std::string, ZigOperationState *> g_operations;
std::unordered_set<std::string> g_cancelled_operation_ids;

bool IsPowerOfTwo(size_t value) {
    return value != 0 && ((value & (value - 1)) == 0);
}

bool InitAlignedStorage(
    size_t required_size,
    size_t required_align,
    std::vector<uint8_t> *storage,
    void **out_ptr,
    size_t *out_len
) {
    if (required_size == 0 || required_align == 0 || !IsPowerOfTwo(required_align)) {
        return false;
    }

    const size_t capacity = required_size + required_align - 1;
    storage->resize(capacity);

    void *base = storage->data();
    const uintptr_t base_addr = reinterpret_cast<uintptr_t>(base);
    const uintptr_t aligned_addr =
        (base_addr + (required_align - 1)) & ~(static_cast<uintptr_t>(required_align - 1));

    *out_ptr = reinterpret_cast<void *>(aligned_addr);
    *out_len = capacity - static_cast<size_t>(aligned_addr - base_addr);
    return true;
}

bool InitOperationState(ZigOperationState *operation, zfh_error *out_error) {
    if (!InitAlignedStorage(
            zfh_operation_state_size(),
            zfh_operation_state_align(),
            &operation->storage,
            &operation->state_ptr,
            &operation->state_len
        )) {
        *out_error = ZFH_UNKNOWN_ERROR;
        return false;
    }

    *out_error = zfh_operation_init_inplace(operation->state_ptr, operation->state_len);
    return *out_error == ZFH_OK;
}

void RegisterOperation(const std::string &operation_id, ZigOperationState *operation) {
    if (operation_id.empty() || operation == nullptr) {
        return;
    }

    std::lock_guard<std::mutex> lock(g_operation_mutex);
    g_operations[operation_id] = operation;
    if (g_cancelled_operation_ids.erase(operation_id) > 0) {
        (void)zfh_operation_cancel(operation->state_ptr, operation->state_len);
    }
}

void UnregisterOperation(const std::string &operation_id, ZigOperationState *operation) {
    if (operation_id.empty()) {
        return;
    }

    std::lock_guard<std::mutex> lock(g_operation_mutex);
    const auto it = g_operations.find(operation_id);
    if (it != g_operations.end() && it->second == operation) {
        g_operations.erase(it);
    }
    g_cancelled_operation_ids.erase(operation_id);
}

void CancelOperationById(const std::string &operation_id) {
    if (operation_id.empty()) {
        return;
    }

    std::lock_guard<std::mutex> lock(g_operation_mutex);
    const auto it = g_operations.find(operation_id);
    if (it == g_operations.end()) {
        g_cancelled_operation_ids.insert(operation_id);
        return;
    }

    ZigOperationState *operation = it->second;
    if (operation != nullptr) {
        (void)zfh_operation_cancel(operation->state_ptr, operation->state_len);
    }
}

zfh_options BuildOptions(
    bool has_key,
    const std::vector<uint8_t> &key_bytes,
    bool has_seed,
    uint64_t seed
) {
    zfh_options options{};
    options.struct_size = ZFH_OPTIONS_STRUCT_SIZE;
    options.flags = 0;
    options.seed = 0;
    options.key_ptr = nullptr;
    options.key_len = 0;

    if (has_key) {
        options.flags |= ZFH_OPTION_HAS_KEY;
        options.key_ptr = key_bytes.empty() ? &filehash::jni::kEmptyByte : key_bytes.data();
        options.key_len = key_bytes.size();
    }

    if (has_seed) {
        options.flags |= ZFH_OPTION_HAS_SEED;
        options.seed = seed;
    }

    return options;
}

bool PrepareRequest(
    JNIEnv *env,
    jint algorithm_id,
    bool has_key,
    const std::vector<uint8_t> &key,
    bool has_seed,
    uint64_t seed,
    PreparedRequest *out_request
) {
    if (algorithm_id < ZFH_ALG_SHA_224 || algorithm_id > ZFH_ALG_HMAC_SHA_1) {
        filehash::jni::ThrowException(
            env,
            "java/lang/IllegalArgumentException",
            "Unsupported algorithm id: " + std::to_string(algorithm_id)
        );
        return false;
    }

    out_request->algorithm = static_cast<zfh_algorithm>(algorithm_id);
    out_request->options = BuildOptions(has_key, key, has_seed, seed);
    out_request->has_options = has_key || has_seed;
    return true;
}

zfh_request BuildZfhRequest(
    const PreparedRequest &prepared,
    ZigOperationState *operation
) {
    zfh_request request{};
    request.struct_size = ZFH_REQUEST_STRUCT_SIZE;
    request.options_ptr = prepared.has_options ? &prepared.options : nullptr;
    if (operation != nullptr) {
        request.operation_ptr = operation->state_ptr;
        request.operation_len = operation->state_len;
    }
    return request;
}

struct ZigStreamState {
    std::vector<uint8_t> storage;
    void *state_ptr = nullptr;
    size_t state_len = 0;
    ZigOperationState operation;
    bool has_operation = false;
    std::string operation_id;
};

bool InitStreamStateInplace(
    const PreparedRequest &prepared,
    const std::string &operation_id,
    ZigStreamState *state,
    zfh_error *out_error
) {
    if (!operation_id.empty()) {
        if (!InitOperationState(&state->operation, out_error)) {
            return false;
        }
        state->has_operation = true;
        state->operation_id = operation_id;
        RegisterOperation(operation_id, &state->operation);
    }

    if (!InitAlignedStorage(
            zfh_hasher_state_size(),
            zfh_hasher_state_align(),
            &state->storage,
            &state->state_ptr,
            &state->state_len
        )) {
        *out_error = ZFH_UNKNOWN_ERROR;
        if (state->has_operation) {
            UnregisterOperation(state->operation_id, &state->operation);
            state->has_operation = false;
        }
        return false;
    }

    zfh_request request = BuildZfhRequest(prepared, state->has_operation ? &state->operation : nullptr);
    const zfh_request *request_ptr =
        (prepared.has_options || state->has_operation) ? &request : nullptr;

    *out_error = zfh_hasher_init_inplace(
        prepared.algorithm,
        request_ptr,
        state->state_ptr,
        state->state_len
    );
    if (*out_error != ZFH_OK && state->has_operation) {
        UnregisterOperation(state->operation_id, &state->operation);
        state->has_operation = false;
    }
    return *out_error == ZFH_OK;
}

} // namespace

namespace filehash {
namespace zig {

jint ApiVersion() {
    return static_cast<jint>(zfh_api_version());
}

jint ExpectedApiVersion() {
    return static_cast<jint>(ZFH_API_VERSION);
}

bool FileHashFd(
    JNIEnv *env,
    jint algorithm_id,
    jint fd,
    bool has_key,
    const std::vector<uint8_t> &key,
    bool has_seed,
    uint64_t seed,
    const std::string &operation_id,
    std::vector<uint8_t> *out_digest
) {
    if (fd < 0) {
        filehash::jni::ThrowException(
            env,
            "java/lang/IllegalArgumentException",
            "Invalid file descriptor"
        );
        return false;
    }

    PreparedRequest prepared{};
    if (!PrepareRequest(env, algorithm_id, has_key, key, has_seed, seed, &prepared)) {
        return false;
    }

    std::vector<uint8_t> digest(zfh_max_digest_length());
    ZigOperationState operation{};
    const bool has_operation = !operation_id.empty();

    if (has_operation) {
        zfh_error operation_error = ZFH_OK;
        if (!InitOperationState(&operation, &operation_error)) {
            return ThrowForZfhError(env, operation_error, "zfh_operation_init_inplace");
        }
        RegisterOperation(operation_id, &operation);
    }

    zfh_request request = BuildZfhRequest(prepared, has_operation ? &operation : nullptr);
    const zfh_request *request_ptr =
        (prepared.has_options || has_operation) ? &request : nullptr;
    size_t written = 0;
    const zfh_error code = zfh_fd_hash(
        prepared.algorithm,
        static_cast<int>(fd),
        request_ptr,
        digest.data(),
        digest.size(),
        &written
    );

    if (has_operation) {
        UnregisterOperation(operation_id, &operation);
    }

    if (code != ZFH_OK) {
        return ThrowForZfhError(env, code, "zfh_fd_hash");
    }

    digest.resize(written);
    *out_digest = std::move(digest);
    return true;
}

bool StreamHasherCreate(
    JNIEnv *env,
    jint algorithm_id,
    bool has_key,
    const std::vector<uint8_t> &key,
    bool has_seed,
    uint64_t seed,
    const std::string &operation_id,
    jlong *out_handle
) {
    PreparedRequest request{};
    if (!PrepareRequest(env, algorithm_id, has_key, key, has_seed, seed, &request)) {
        return false;
    }

    auto *state = new (std::nothrow) ZigStreamState();
    if (state == nullptr) {
        filehash::jni::ThrowException(
            env,
            "java/lang/OutOfMemoryError",
            "Failed to allocate stream hasher state"
        );
        return false;
    }

    zfh_error init_error = ZFH_OK;
    if (!InitStreamStateInplace(request, operation_id, state, &init_error)) {
        delete state;
        return ThrowForZfhError(env, init_error, "zfh_hasher_init_inplace");
    }

    *out_handle = static_cast<jlong>(reinterpret_cast<intptr_t>(state));
    return true;
}

bool StreamHasherUpdate(
    JNIEnv *env,
    jlong handle,
    const std::vector<uint8_t> &data
) {
    if (handle == 0) {
        filehash::jni::ThrowException(
            env,
            "java/lang/IllegalArgumentException",
            "Invalid stream hasher handle"
        );
        return false;
    }

    auto *state = reinterpret_cast<ZigStreamState *>(static_cast<intptr_t>(handle));
    const uint8_t *data_ptr = data.empty() ? &filehash::jni::kEmptyByte : data.data();

    const zfh_error code = zfh_hasher_update(
        state->state_ptr,
        state->state_len,
        data_ptr,
        data.size()
    );
    if (code != ZFH_OK) {
        return ThrowForZfhError(env, code, "zfh_hasher_update");
    }

    return true;
}

bool StreamHasherFinal(
    JNIEnv *env,
    jlong handle,
    std::vector<uint8_t> *out_digest
) {
    if (handle == 0) {
        filehash::jni::ThrowException(
            env,
            "java/lang/IllegalArgumentException",
            "Invalid stream hasher handle"
        );
        return false;
    }

    auto *state = reinterpret_cast<ZigStreamState *>(static_cast<intptr_t>(handle));
    std::vector<uint8_t> digest(zfh_max_digest_length());
    size_t written = 0;

    const zfh_error code = zfh_hasher_final(
        state->state_ptr,
        state->state_len,
        digest.data(),
        digest.size(),
        &written
    );
    if (code != ZFH_OK) {
        return ThrowForZfhError(env, code, "zfh_hasher_final");
    }

    digest.resize(written);
    *out_digest = std::move(digest);
    return true;
}

void StreamHasherFree(jlong handle) {
    if (handle == 0) {
        return;
    }

    auto *state = reinterpret_cast<ZigStreamState *>(static_cast<intptr_t>(handle));
    if (state->has_operation) {
        UnregisterOperation(state->operation_id, &state->operation);
    }
    delete state;
}

void CancelOperation(const std::string &operation_id) {
    CancelOperationById(operation_id);
}

} // namespace zig
} // namespace filehash
