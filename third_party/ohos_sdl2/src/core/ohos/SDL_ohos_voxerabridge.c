/*
 * Voxera / Luanti: register pre-created XComponent surface with HarmonyOS SDL2.
 * Thin wrapper — avoid SDK headers here (const symbols duplicate per translation unit).
 */
#include "SDL_ohos_voxerabridge.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OH_NativeXComponent OH_NativeXComponent;

extern bool OHOS_VoxeraRegisterPluginSurface(OH_NativeXComponent *component, void *nativeWindow);
extern void OHOS_VoxeraClearPluginEglSurface(OH_NativeXComponent *component);
extern void OHOS_VoxeraNotifySurfaceChangedPlugin(OH_NativeXComponent *component, void *nativeWindow);
extern bool OHOS_VoxeraRegisterInputCallbacksPlugin(OH_NativeXComponent *component);
extern void OHOS_VoxeraInjectKeyEventPlugin(int keycode, int down);
extern void OHOS_VoxeraInjectMouseMotionPlugin(int dx, int dy);
extern void OHOS_VoxeraSetRelativeMouseNotifierPlugin(OHOS_VoxeraRelativeMouseNotifier notifier);

bool OHOS_VoxeraRegisterSurface(OH_NativeXComponent *component, void *nativeWindow)
{
    if (!component || !nativeWindow) {
        return false;
    }
    return OHOS_VoxeraRegisterPluginSurface(component, nativeWindow);
}

void OHOS_VoxeraClearPluginEgl(OH_NativeXComponent *component)
{
    if (component) {
        OHOS_VoxeraClearPluginEglSurface(component);
    }
}

void OHOS_VoxeraNotifySurfaceChanged(OH_NativeXComponent *component, void *nativeWindow)
{
    if (component && nativeWindow) {
        OHOS_VoxeraNotifySurfaceChangedPlugin(component, nativeWindow);
    }
}

bool OHOS_VoxeraRegisterInputCallbacks(OH_NativeXComponent *component)
{
    if (!component) {
        return false;
    }
    return OHOS_VoxeraRegisterInputCallbacksPlugin(component);
}

void OHOS_VoxeraInjectKeyEvent(int keycode, int down)
{
    OHOS_VoxeraInjectKeyEventPlugin(keycode, down);
}

void OHOS_VoxeraInjectMouseMotion(int dx, int dy)
{
    OHOS_VoxeraInjectMouseMotionPlugin(dx, dy);
}

void OHOS_VoxeraSetRelativeMouseNotifier(OHOS_VoxeraRelativeMouseNotifier notifier)
{
    OHOS_VoxeraSetRelativeMouseNotifierPlugin(notifier);
}
