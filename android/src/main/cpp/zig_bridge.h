#pragma once

#include <jni.h>

#include <cstdint>
#include <string>
#include <vector>

namespace filehash {
namespace zig {

jint ApiVersion();

jint ExpectedApiVersion();

bool StreamHasherCreate(
    JNIEnv *env,
    jint algorithm_id,
    bool has_key,
    const std::vector<uint8_t> &key,
    bool has_seed,
    uint64_t seed,
    const std::string &operation_id,
    jlong *out_handle
);

bool StreamHasherUpdate(
    JNIEnv *env,
    jlong handle,
    const std::vector<uint8_t> &data
);

bool StreamHasherFinal(
    JNIEnv *env,
    jlong handle,
    std::vector<uint8_t> *out_digest
);

void StreamHasherFree(jlong handle);

void CancelOperation(const std::string &operation_id);

} // namespace zig
} // namespace filehash
