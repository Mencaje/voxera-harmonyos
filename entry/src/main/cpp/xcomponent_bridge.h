#pragma once

#include <napi/native_api.h>

namespace voxera {

bool InitXComponentBridge(napi_env env, napi_value exports);

} // namespace voxera
