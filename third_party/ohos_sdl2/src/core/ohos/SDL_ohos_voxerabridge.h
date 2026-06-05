/*
 * Voxera / Luanti: embed SDL into an existing ArkUI XComponent (no SDL NAPI init).
 */
#pragma once

#include <stdbool.h>

struct OH_NativeXComponent;

#ifdef __cplusplus
extern "C" {
#endif

/* Register OH_NativeXComponent + native window with SDL OHOS plugin (call before SDL video init). */
bool OHOS_VoxeraRegisterSurface(struct OH_NativeXComponent *component, void *nativeWindow);

/* Drop stale EGLSurface on plugin window data before SDL_CreateWindowFrom (e.g. after a probe). */
void OHOS_VoxeraClearPluginEgl(struct OH_NativeXComponent *component);

/* After window maximize/restore: update SDL window size and post SDL_WINDOWEVENT_RESIZED. */
void OHOS_VoxeraNotifySurfaceChanged(struct OH_NativeXComponent *component, void *nativeWindow);

/* Forward ArkUI pointer/keyboard to SDL (Voxera registers its own surface callbacks). */
bool OHOS_VoxeraRegisterInputCallbacks(struct OH_NativeXComponent *component);

/** Touch from XComponent DispatchTouchEvent (ARM devices; x86 emulator often uses mouse only). */
void OHOS_VoxeraDispatchTouchEvent(struct OH_NativeXComponent *component, void *window);

/** Inject a key from ArkUI when XComponent does not receive focus (PC 2in1). */
void OHOS_VoxeraInjectKeyEvent(int keycode, int down);

/** Relative mouse motion from ArkUI onMouse (rawDeltaX/Y), flushed on the SDL thread. */
void OHOS_VoxeraInjectMouseMotion(int dx, int dy);

/** Register porting/UI hook when SDL_SetRelativeMouseMode toggles (enter/leave game). */
typedef void (*OHOS_VoxeraRelativeMouseNotifier)(int enabled);
void OHOS_VoxeraSetRelativeMouseNotifier(OHOS_VoxeraRelativeMouseNotifier notifier);

#ifdef __cplusplus
}
#endif
