/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License,Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "../../SDL_internal.h"
#include "SDL_mutex.h"

#ifdef __OHOS__

#include <js_native_api.h>
#include <js_native_api_types.h>
#include <hilog/log.h>

#include "SDL_stdinc.h"
#include "SDL_assert.h"
#include "SDL_atomic.h"
#include "SDL_hints.h"
#include "SDL_log.h"
#include "SDL_main.h"
#include "SDL_timer.h"

#include "SDL_system.h"

#ifdef __cplusplus
extern "C" {
#endif
#include "../../events/SDL_events_c.h"
#include "../../events/SDL_mouse_c.h"
#include "../../events/SDL_keyboard_c.h"
#include "../../video/SDL_egl_c.h"
#ifdef __cplusplus
}
#endif

#include "../../video/ohos/SDL_ohostouch.h"
#include "../../video/ohos/SDL_ohosmouse.h"
#include "../../video/ohos/SDL_ohoskeyboard.h"
#include "../../video/ohos/SDL_ohosvideo.h"

#include <ace/xcomponent/native_xcomponent_key_event.h>
#include <pthread.h>
#include <sys/types.h>
#include <unistd.h>
#include <ace/xcomponent/native_interface_xcomponent.h>
#include <arkui/ui_input_event.h>
#include "SDL_ohos_xcomponent.h"
#include "adapter_c/adapter_c.h"
#include "SDL_ohosplugin.h"
#include "SDL_ohos.h"

#define OHOS_DELAY_TEN 10

/* Last native pointer position for relative-mode delta when ArkUI rawDelta is unavailable. */
static float s_voxeraLastMouseX = -1.0f;
static float s_voxeraLastMouseY = -1.0f;

void OHOS_VoxeraResetRelativeMouseTracking(void)
{
    s_voxeraLastMouseX = -1.0f;
    s_voxeraLastMouseY = -1.0f;
}

static OH_NativeXComponent_Callback callback;
static OH_NativeXComponent_MouseEvent_Callback mouseCallback;

static std::string GetXComponentIdByNative(OH_NativeXComponent *component)
{
    char idStr[OH_XCOMPONENT_ID_LEN_MAX + 1] = {'\0'};
    uint64_t idSize = OH_XCOMPONENT_ID_LEN_MAX + 1;
    if (OH_NATIVEXCOMPONENT_RESULT_SUCCESS != OH_NativeXComponent_GetXComponentId(component, idStr, &idSize)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Export: OH_NativeXComponent_GetXComponentId fail");
        return "";
    }
    std::string curXComponentId(idStr);
    return curXComponentId;
}

static SDL_Window *GetWindowFromXComponent(OH_NativeXComponent *component)
{
    std::string curXComponentId = GetXComponentIdByNative(component);
    if (curXComponentId.empty()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "get xComponent error");
        return nullptr;
    }
    SDL_VideoDevice *_this = SDL_GetVideoDevice();
    if (_this == nullptr) {
        return nullptr;
    }
    SDL_Window *resultWindow = nullptr;
    SDL_Window *curWindow = _this->windows;
    while (curWindow) {
        if (curWindow->xcompentId == nullptr) {
            curWindow = curWindow->next;
            continue;
        }
        std::string xComponentId(curWindow->xcompentId);
        if (xComponentId == curXComponentId) {
            resultWindow = curWindow;
            break;
        }
        curWindow = curWindow->next;
    }
    return resultWindow;
}

static void setWindowDataValue(SDL_WindowData *data, uint64_t width, uint64_t height,
                               double offsetX, double offsetY, void *native_window)
{
    data->height = height;
    data->width = width;
    data->x = offsetX;
    data->y = offsetY;
    data->native_window = (OHNativeWindow *)(native_window);
    if (data->native_window == NULL) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Could not fetch native window from UI thread");
    }
}

/* Callbacks*/
static void OnSurfaceCreatedCB(OH_NativeXComponent *component, void *window)
{
    uint64_t width;
    uint64_t height;
    double offsetX;
    double offsetY;
    OH_NativeXComponent_GetXComponentSize(component, window, &width, &height);
    OH_NativeXComponent_GetXComponentOffset(component, window, &offsetX, &offsetY);

    std::string curXComponentId = GetXComponentIdByNative(component);
    if (curXComponentId.empty()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "get xComponent error");
        return;
    }
    SDL_Log("Xcompent is created, component is %s, nativewidow is %p", curXComponentId.c_str(), window);

    SDL_LockMutex(g_ohosPageMutex);
    SDL_WindowData *data = OhosPluginManager::GetInstance()->GetWindowDataByXComponent(component);
    if (data == nullptr) {
        SDL_WindowData *data = (SDL_WindowData *)SDL_malloc(sizeof(SDL_WindowData));
        setWindowDataValue(data, width, height, offsetX, offsetY, window);
        OhosPluginManager::GetInstance()->SetNativeXComponentList(component, data);
    } else {
        setWindowDataValue(data, width, height, offsetX, offsetY, window);
    }
    SDL_UnlockMutex(g_ohosPageMutex);
}

static void OnSurfaceChangedCB(OH_NativeXComponent *component, void *window)
{
    uint64_t width;
    uint64_t height;
    double offsetX;
    double offsetY;
    OH_NativeXComponent_GetXComponentSize(component, window, &width, &height);
    OH_NativeXComponent_GetXComponentOffset(component, window, &offsetX, &offsetY);
    SDL_Log("Xcompent is changeing, xcomponent is %p", component);

    SDL_LockMutex(g_ohosPageMutex);
    SDL_WindowData *data = OhosPluginManager::GetInstance()->GetWindowDataByXComponent(component);
    if (data != nullptr) {
        setWindowDataValue(data, width, height, offsetX, offsetY, window);
    }

    SDL_Window *curWindow = GetWindowFromXComponent(component);
    if (curWindow != nullptr) {
        OHOS_SendResize(curWindow);
    }
    SDL_UnlockMutex(g_ohosPageMutex);
}

static void OnSurfaceDestroyedCB(OH_NativeXComponent *component, void *window)
{
    int nb_attempt = 50;
    char idStr[OH_XCOMPONENT_ID_LEN_MAX + 1] = {'\0'};
    uint64_t idSize = OH_XCOMPONENT_ID_LEN_MAX + 1;

    SDL_Log("Xcompent is destroying, component is %p.", component);
    std::string curXComponentId = GetXComponentIdByNative(component);
    if (curXComponentId.empty()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "get xComponent error");
        return;
    }
}

/* Key */
void onKeyEvent(OH_NativeXComponent *component, void *window)
{
    OH_NativeXComponent_KeyEvent *keyEvent = NULL;
    if (OH_NativeXComponent_GetKeyEvent(component, &keyEvent) >= 0) {
        OH_NativeXComponent_KeyAction action;
        OH_NativeXComponent_KeyCode code;
        OH_NativeXComponent_EventSourceType sourceType;

        OH_NativeXComponent_GetKeyEventAction(keyEvent, &action);
        OH_NativeXComponent_GetKeyEventCode(keyEvent, &code);

        if (OH_NATIVEXCOMPONENT_KEY_ACTION_DOWN == action) {
            static int s_keyLogCount = 0;
            if (s_keyLogCount < 8) {
                SDL_Log("Voxera: native key down code=%d", (int)code);
                ++s_keyLogCount;
            }
            OHOS_QueueKeyEvent(code, 1);
        } else if (OH_NATIVEXCOMPONENT_KEY_ACTION_UP == action) {
            OHOS_QueueKeyEvent(code, 0);
        }
    }
}

/* Touch */
void onNativeTouch(OH_NativeXComponent *component, void *window)
{
    OH_NativeXComponent_TouchEvent touchEvent;
    float tiltX = 0.0f;
    float tiltY = 0.0f;
    OH_NativeXComponent_TouchPointToolType toolType = OH_NATIVEXCOMPONENT_TOOL_TYPE_UNKNOWN;

    SDL_LockMutex(g_ohosPageMutex);
    OH_NativeXComponent_GetTouchEvent(component, window, &touchEvent);
    OH_NativeXComponent_GetTouchPointToolType(component, 0, &toolType);
    tiltX = touchEvent.x;
    tiltY = touchEvent.y;

    OhosTouchId ohosTouch;
    ohosTouch.touchDeviceIdIn = touchEvent.deviceId;
    ohosTouch.pointerFingerIdIn = touchEvent.id;
    ohosTouch.action = touchEvent.type;
    ohosTouch.x = tiltX;
    ohosTouch.y = tiltY;
    ohosTouch.p = touchEvent.force;
    
    SDL_Window *curWindow = GetWindowFromXComponent(component);
    if (curWindow == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Get cur window error");
        SDL_UnlockMutex(g_ohosPageMutex);
        return;
    }
    OHOS_OnTouch(curWindow, &ohosTouch);

    SDL_UnlockMutex(g_ohosPageMutex);
}

/* Mouse */
void onNativeMouse(OH_NativeXComponent *component, void *window)
{
    OH_NativeXComponent_MouseEvent mouseEvent;
    OHOSWindowSize windowsize;

    if (!component || !window) {
        return;
    }
    if (OH_NativeXComponent_GetMouseEvent(component, window, &mouseEvent) != 0) {
        return;
    }

    windowsize.action = (int)mouseEvent.action;
    windowsize.state = (int)mouseEvent.button;
    windowsize.x = mouseEvent.x;
    windowsize.y = mouseEvent.y;

    SDL_LockMutex(g_ohosPageMutex);
    SDL_Window *curWindow = GetWindowFromXComponent(component);
    if (!curWindow) {
        SDL_UnlockMutex(g_ohosPageMutex);
        return;
    }

    if (OHOS_GetRelativeMouseEnabled()) {
        if (windowsize.action == OHOS_MOUSE_ACTION_MOVE) {
            if (s_voxeraLastMouseX >= 0.0f) {
                const int dx = (int)(mouseEvent.x - s_voxeraLastMouseX);
                const int dy = (int)(mouseEvent.y - s_voxeraLastMouseY);
                if (dx != 0 || dy != 0) {
                    OHOS_QueueMouseMotion(dx, dy);
                }
            }
            s_voxeraLastMouseX = mouseEvent.x;
            s_voxeraLastMouseY = mouseEvent.y;
            SDL_UnlockMutex(g_ohosPageMutex);
            return;
        }
        if (windowsize.action == OHOS_MOUSE_ACTION_PRESS ||
                windowsize.action == OHOS_MOUSE_ACTION_RELEASE) {
            s_voxeraLastMouseX = mouseEvent.x;
            s_voxeraLastMouseY = mouseEvent.y;
        }
    }

    OHOS_OnMouse(curWindow, &windowsize, SDL_FALSE);
    SDL_UnlockMutex(g_ohosPageMutex);
}

static void OnDispatchTouchEventCB(OH_NativeXComponent *component, void *window)
{
    OH_NativeXComponent_TouchEvent touchEvent;
    OhosTouchId ohosTouch;
    int32_t ret = OH_NativeXComponent_GetTouchEvent(component, window, &touchEvent);
    SDL_LockMutex(g_ohosPageMutex);
    ohosTouch.touchDeviceIdIn = touchEvent.deviceId;
    ohosTouch.pointerFingerIdIn = touchEvent.id;
    ohosTouch.action = touchEvent.type;
    ohosTouch.x = touchEvent.x;
    ohosTouch.y = touchEvent.y;
    ohosTouch.p = touchEvent.force;
    SDL_Window *curWindow = GetWindowFromXComponent(component);
    if (window == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Get cur window error");
        SDL_UnlockMutex(g_ohosPageMutex);
        return;
    }
    OHOS_OnTouch(curWindow, &ohosTouch);
    SDL_UnlockMutex(g_ohosPageMutex);
}

void OnHoverEvent(OH_NativeXComponent *component, bool isHover)
{
}

static void OnVoxeraAxisInputEvent(OH_NativeXComponent *component, ArkUI_UIInputEvent *event,
        ArkUI_UIInputEvent_Type type)
{
    if (!component || !event || type != ARKUI_UIINPUTEVENT_TYPE_AXIS) {
        return;
    }

    SDL_LockMutex(g_ohosPageMutex);
    SDL_Window *curWindow = GetWindowFromXComponent(component);
    if (!curWindow) {
        SDL_UnlockMutex(g_ohosPageMutex);
        return;
    }

    const double vertical = OH_ArkUI_AxisEvent_GetVerticalAxisValue(event);
    const double horizontal = OH_ArkUI_AxisEvent_GetHorizontalAxisValue(event);
    SDL_UnlockMutex(g_ohosPageMutex);

    if (vertical != 0.0) {
        SDL_SendMouseWheel(curWindow, 0, 0.0f, (float)-vertical, SDL_MOUSEWHEEL_NORMAL);
    }
    if (horizontal != 0.0) {
        SDL_SendMouseWheel(curWindow, 0, (float)-horizontal, 0.0f, SDL_MOUSEWHEEL_NORMAL);
    }
}

void OnFocusEvent(OH_NativeXComponent *component, void *window)
{
    if (!component) {
        return;
    }
    SDL_LockMutex(g_ohosPageMutex);
    SDL_Window *curWindow = GetWindowFromXComponent(component);
    if (curWindow) {
        SDL_SetKeyboardFocus(curWindow);
    }
    SDL_UnlockMutex(g_ohosPageMutex);
}

void OnBlurEvent(OH_NativeXComponent *component, void *window)
{
}

void OHOS_XcomponentExport(napi_env env, napi_value exports)
{
    napi_value exportInstance = NULL;
    OH_NativeXComponent *nativeXComponent = NULL;
    if ((NULL == env) || (NULL == exports)) {
        return;
    }
    
    if (napi_ok != napi_get_named_property(env, exports, OH_NATIVE_XCOMPONENT_OBJ, &exportInstance)) {
        return;
    }
    
    if (napi_ok != napi_unwrap(env, exportInstance, (void **)(&nativeXComponent))) {
        return;
    }
    std::string xComponentId = GetXComponentIdByNative(nativeXComponent);
    if (xComponentId.empty()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "get xComponent error");
        return;
    }

    SDL_Log("Xcompent js callback is coming, xcompent id is %s.", xComponentId.c_str());

    SDL_LockMutex(g_ohosPageMutex);
    OhosPluginManager::GetInstance()->SetNativeXComponent(xComponentId, nativeXComponent);
    SDL_UnlockMutex(g_ohosPageMutex);

    callback.OnSurfaceCreated = OnSurfaceCreatedCB;
    callback.OnSurfaceChanged = OnSurfaceChangedCB;
    callback.OnSurfaceDestroyed = OnSurfaceDestroyedCB;
    callback.DispatchTouchEvent = onNativeTouch;
    OH_NativeXComponent_RegisterCallback(nativeXComponent, &callback);

    mouseCallback.DispatchMouseEvent = onNativeMouse;
    mouseCallback.DispatchHoverEvent = OnHoverEvent;
    OH_NativeXComponent_RegisterMouseEventCallback(nativeXComponent, &mouseCallback);

    /* Keys: ArkUI Game.ets onKeyPreIme -> injectKeyEvent. Native callback duplicates input. */
    OH_NativeXComponent_RegisterFocusEventCallback(nativeXComponent, OnFocusEvent);
    OH_NativeXComponent_RegisterBlurEventCallback(nativeXComponent, OnBlurEvent);
    OH_NativeXComponent_RegisterUIInputEventCallback(nativeXComponent, OnVoxeraAxisInputEvent,
            ARKUI_UIINPUTEVENT_TYPE_AXIS);
    return;
}

/* Voxera: register XComponent from entry.so (libraryname) before SDL video init. */
extern "C" bool OHOS_VoxeraRegisterPluginSurface(OH_NativeXComponent *component, void *nativeWindow)
{
    if (!component || !nativeWindow) {
        return false;
    }

    uint64_t width = 0;
    uint64_t height = 0;
    double offsetX = 0;
    double offsetY = 0;
    char idStr[OH_XCOMPONENT_ID_LEN_MAX + 1] = {'\0'};

    if (OH_NativeXComponent_GetXComponentSize(component, nativeWindow, &width, &height) !=
        OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
        width = 1280;
        height = 720;
    }
    OH_NativeXComponent_GetXComponentOffset(component, nativeWindow, &offsetX, &offsetY);

    uint64_t idSize = OH_XCOMPONENT_ID_LEN_MAX + 1;
    if (OH_NativeXComponent_GetXComponentId(component, idStr, &idSize) !=
        OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Voxera: GetXComponentId failed");
        return false;
    }

    SDL_Log("Voxera: register plugin surface id=%s component=%p window=%p", idStr, component,
            nativeWindow);

    OHOS_SetScreenResolution((int)width, (int)height, SDL_PIXELFORMAT_RGBA8888, 60.0f, 1.0);
    OHOS_SetScreenSize((int)width, (int)height);

    SDL_LockMutex(g_ohosPageMutex);
    std::string curXComponentId(idStr);
    OhosPluginManager::GetInstance()->SetNativeXComponent(curXComponentId, component);

    SDL_WindowData *data = OhosPluginManager::GetInstance()->GetWindowDataByXComponent(component);
    if (data == nullptr) {
        data = (SDL_WindowData *)SDL_malloc(sizeof(SDL_WindowData));
        if (!data) {
            SDL_UnlockMutex(g_ohosPageMutex);
            return false;
        }
    }
    setWindowDataValue(data, width, height, offsetX, offsetY, nativeWindow);
    OhosPluginManager::GetInstance()->SetNativeXComponentList(component, data);
    SDL_UnlockMutex(g_ohosPageMutex);

    return true;
}

extern "C" void OHOS_VoxeraClearPluginEglSurface(OH_NativeXComponent *component)
{
    if (!component) {
        return;
    }

    SDL_LockMutex(g_ohosPageMutex);
    SDL_WindowData *data = OhosPluginManager::GetInstance()->GetWindowDataByXComponent(component);
    if (data) {
        data->egl_xcomponent = EGL_NO_SURFACE;
    }
    SDL_UnlockMutex(g_ohosPageMutex);
}

extern "C" void OHOS_VoxeraNotifySurfaceChangedPlugin(OH_NativeXComponent *component, void *window)
{
    if (!component || !window) {
        return;
    }

    uint64_t width = 0;
    uint64_t height = 0;
    double offsetX = 0;
    double offsetY = 0;

    if (OH_NativeXComponent_GetXComponentSize(component, window, &width, &height) !=
        OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
        return;
    }
    OH_NativeXComponent_GetXComponentOffset(component, window, &offsetX, &offsetY);

    SDL_Log("Voxera: surface changed %ux%u offset=%.0f,%.0f", (unsigned)width, (unsigned)height,
            offsetX, offsetY);

    OHOS_SetScreenResolution((int)width, (int)height, SDL_PIXELFORMAT_RGBA8888, 60.0f, 1.0);
    OHOS_SetScreenSize((int)width, (int)height);

    SDL_LockMutex(g_ohosPageMutex);
    SDL_WindowData *data = OhosPluginManager::GetInstance()->GetWindowDataByXComponent(component);
    if (data != nullptr) {
        setWindowDataValue(data, width, height, offsetX, offsetY, window);
    }

    SDL_Window *curWindow = GetWindowFromXComponent(component);
    if (curWindow != nullptr) {
        OHOS_SendResize(curWindow);
    }
    SDL_UnlockMutex(g_ohosPageMutex);
}

static OH_NativeXComponent_MouseEvent_Callback g_voxeraMouseCallback;

extern "C" void OHOS_VoxeraInjectKeyEventPlugin(int keycode, int down)
{
    OHOS_QueueKeyEvent(keycode, down);
}

extern "C" void OHOS_VoxeraInjectMouseMotionPlugin(int dx, int dy)
{
    OHOS_QueueMouseMotion(dx, dy);
}

extern "C" void OHOS_VoxeraDispatchTouchEventPlugin(OH_NativeXComponent *component, void *window)
{
    onNativeTouch(component, window);
}

extern "C" bool OHOS_VoxeraRegisterInputCallbacksPlugin(OH_NativeXComponent *component)
{
    if (!component) {
        return false;
    }

    g_voxeraMouseCallback.DispatchMouseEvent = onNativeMouse;
    g_voxeraMouseCallback.DispatchHoverEvent = OnHoverEvent;
    if (OH_NativeXComponent_RegisterMouseEventCallback(component, &g_voxeraMouseCallback) != 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Voxera: RegisterMouseEventCallback failed");
        return false;
    }

    OH_NativeXComponent_RegisterFocusEventCallback(component, OnFocusEvent);
    OH_NativeXComponent_RegisterBlurEventCallback(component, OnBlurEvent);
    if (OH_NativeXComponent_RegisterUIInputEventCallback(component, OnVoxeraAxisInputEvent,
            ARKUI_UIINPUTEVENT_TYPE_AXIS) != 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Voxera: RegisterUIInputEventCallback failed");
        return false;
    }
    SDL_Log("Voxera: XComponent mouse/axis callbacks registered (keys via ArkUI)");
    return true;
}

#endif /* __OHOS__ */

/* vi: set ts=4 sw=4 expandtab: */
