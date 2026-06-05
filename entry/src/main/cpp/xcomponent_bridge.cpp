#include "xcomponent_bridge.h"
#include "luanti_host.h"

#ifdef VOXERA_LINK_LUANTI
#include "porting_ohos.h"
#endif

#include <ace/xcomponent/native_interface_xcomponent.h>
#include <hilog/log.h>
#include <napi/native_api.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0000
#define LOG_TAG "VoxeraXComponent"

namespace {
OH_NativeXComponent *g_nativeXComponent = nullptr;
bool g_callbacksRegistered = false;

void OnSurfaceCreated(OH_NativeXComponent *component, void *window)
{
    voxera::OnSurfaceCreated(component, window);
}

void OnSurfaceChanged(OH_NativeXComponent *component, void *window)
{
    voxera::OnSurfaceChanged(component, window);
}

void OnSurfaceDestroyed(OH_NativeXComponent * /*component*/, void * /*window*/)
{
    voxera::OnSurfaceDestroyed();
}

// Must outlive RegisterCallback — stack-local callback caused SIGSEGV on surface create.
// Touch only via ArkUI overlay (native + overlay = double-click -> menu crash on ARM).
static OH_NativeXComponent_Callback g_xcomponentCallback = {
    .OnSurfaceCreated = OnSurfaceCreated,
    .OnSurfaceChanged = OnSurfaceChanged,
    .OnSurfaceDestroyed = OnSurfaceDestroyed,
    .DispatchTouchEvent = nullptr,
};

bool RegisterXComponentCallbacks(OH_NativeXComponent *component)
{
    if (component == nullptr) {
        OH_LOG_ERROR(LOG_APP, "RegisterXComponentCallbacks: null component");
        return false;
    }
    if (g_callbacksRegistered && g_nativeXComponent == component) {
        return true;
    }

    const int32_t ret = OH_NativeXComponent_RegisterCallback(component, &g_xcomponentCallback);
    if (ret != 0) {
        OH_LOG_ERROR(LOG_APP, "RegisterCallback failed: %{public}d", ret);
        return false;
    }

    g_nativeXComponent = component;
    g_callbacksRegistered = true;
#ifdef VOXERA_LINK_LUANTI
    porting::ohosRegisterXComponentInput(component);
#endif
    OH_LOG_INFO(LOG_APP, "XComponent callbacks registered");
    return true;
}
} // namespace

namespace voxera {

bool InitXComponentBridge(napi_env env, napi_value exports)
{
    napi_value exportInstance = nullptr;
    if (napi_get_named_property(env, exports, OH_NATIVE_XCOMPONENT_OBJ, &exportInstance) != napi_ok) {
        // Normal when libentry.so is imported from ArkTS before XComponent exists.
        return false;
    }

    OH_NativeXComponent *component = nullptr;
    if (napi_unwrap(env, exportInstance, reinterpret_cast<void **>(&component)) != napi_ok ||
        component == nullptr) {
        /* Expected when libentry.so loads before the Game XComponent exists. */
        OH_LOG_INFO(LOG_APP, "XComponent not ready for unwrap (will register on onLoad)");
        return false;
    }

    return RegisterXComponentCallbacks(component);
}

} // namespace voxera
